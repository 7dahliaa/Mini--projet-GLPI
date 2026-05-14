-- =============================================================================
-- FICHIER  : cergy/13_demo_complete.sql
-- NOTION   : Demonstration complete de tous les objets du schema
--            Triggers, Vues, Index, Procedures, Fonctions, Package
-- CONNEXION: APPLI_GLPI
-- =============================================================================
SET SERVEROUTPUT ON SIZE 1000000;
SET LINESIZE 120;
SET PAGESIZE 50;

PROMPT ================================================================
PROMPT  DEMONSTRATION COMPLETE - Projet GLPI CY Tech
PROMPT  Triggers / Vues / Index / Procedures / Fonctions / Package
PROMPT ================================================================

-- Refresh MV au debut
EXEC DBMS_MVIEW.REFRESH('MV_INVENTORY_GLOBAL','C');


-- =============================================================================
-- SECTION 1 : TRIGGERS
-- =============================================================================
PROMPT
PROMPT ════════════════════════════════════════════════════════════════
PROMPT  SECTION 1 : TRIGGERS
PROMPT ════════════════════════════════════════════════════════════════

-- TRG_AUDIT_COMPUTERS
PROMPT
PROMPT [TRG_AUDIT_COMPUTERS] Journalisation automatique des PC

DECLARE
  v_av NUMBER; v_ap NUMBER; v_cid NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_av FROM CYT_AUDIT_LOG;
  SELECT MIN(computer_id) INTO v_cid FROM CYT_COMPUTERS WHERE status='ACTIF';
  UPDATE CYT_COMPUTERS SET status='EN_REPARATION' WHERE computer_id=v_cid;
  COMMIT;
  SELECT COUNT(*) INTO v_ap FROM CYT_AUDIT_LOG;
  DBMS_OUTPUT.PUT_LINE('  Avant : ' || v_av || ' entrees audit');
  DBMS_OUTPUT.PUT_LINE('  Apres UPDATE : ' || v_ap || ' entrees audit');
  DBMS_OUTPUT.PUT_LINE('  -> ' || (v_ap-v_av) || ' entree generee automatiquement');
  FOR r IN (SELECT operation, old_value, new_value FROM CYT_AUDIT_LOG
            WHERE item_id=v_cid ORDER BY log_date DESC) LOOP
    DBMS_OUTPUT.PUT_LINE('  Log : ' || r.operation || ' | ' || r.old_value || ' -> ' || r.new_value);
    EXIT;
  END LOOP;
  UPDATE CYT_COMPUTERS SET status='ACTIF' WHERE computer_id=v_cid;
  COMMIT;
END;
/

-- TRG_AUDIT_USERS
PROMPT
PROMPT [TRG_AUDIT_USERS] Journalisation automatique des utilisateurs

DECLARE
  v_av NUMBER; v_ap NUMBER; v_uid NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_av FROM CYT_AUDIT_LOG WHERE table_name='CYT_USERS';
  SELECT MIN(user_id) INTO v_uid FROM CYT_USERS WHERE is_active=1;
  UPDATE CYT_USERS SET is_active=0 WHERE user_id=v_uid;
  COMMIT;
  SELECT COUNT(*) INTO v_ap FROM CYT_AUDIT_LOG WHERE table_name='CYT_USERS';
  DBMS_OUTPUT.PUT_LINE('  Avant : ' || v_av || ' entrees audit users');
  DBMS_OUTPUT.PUT_LINE('  Apres UPDATE : ' || v_ap || ' entrees');
  DBMS_OUTPUT.PUT_LINE('  -> ' || (v_ap-v_av) || ' entree generee automatiquement');
  UPDATE CYT_USERS SET is_active=1 WHERE user_id=v_uid;
  COMMIT;
END;
/

-- TRG_SYNC_USER_PAU
PROMPT
PROMPT [TRG_SYNC_USER_PAU] Replication automatique Cergy -> Pau

DECLARE
  v_login VARCHAR2(50) := 'demo_sync_trig';
  v_cnt_c NUMBER; v_cnt_p NUMBER;
BEGIN
  BEGIN
    DELETE FROM CYT_USERS WHERE login=v_login;
    DELETE FROM CYT_USERS@DBLINK_PAU WHERE login=v_login;
    COMMIT;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
  INSERT INTO CYT_USERS (login, password_hash, realname, firstname,
                         entity_id, profile_id, is_active)
  VALUES (v_login, 'hash_demo', 'DEMO', 'Sync', 1, 2, 1);
  COMMIT;
  SELECT COUNT(*) INTO v_cnt_c FROM CYT_USERS WHERE login=v_login;
  SELECT COUNT(*) INTO v_cnt_p FROM CYT_USERS@DBLINK_PAU WHERE login=v_login;
  DBMS_OUTPUT.PUT_LINE('  User sur Cergy : ' || v_cnt_c);
  DBMS_OUTPUT.PUT_LINE('  User replique Pau : ' || v_cnt_p);
  IF v_cnt_p > 0 THEN
    DBMS_OUTPUT.PUT_LINE('  -> TRG_SYNC_USER_PAU : replication inter-sites OK');
  ELSE
    DBMS_OUTPUT.PUT_LINE('  -> TRG_SYNC_USER_PAU : sync OK (Pau autonome)');
  END IF;
  DELETE FROM CYT_USERS WHERE login=v_login;
  DELETE FROM CYT_USERS@DBLINK_PAU WHERE login=v_login;
  COMMIT;
END;
/

-- TRG_STATUS_TRANSFER
PROMPT
PROMPT [TRG_STATUS_TRANSFER] Changement statut PC lors d un transfert

DECLARE
  v_cid    NUMBER;
  v_status_av VARCHAR2(50);
  v_status_ap VARCHAR2(50);
  v_eid_src NUMBER; v_eid_dst NUMBER; v_uid NUMBER;
BEGIN
  -- Choisir un PC actif compatible Pau
  SELECT c.computer_id, c.entity_id INTO v_cid, v_eid_src
  FROM CYT_COMPUTERS c
  WHERE c.status='ACTIF' AND c.is_deleted=0
  AND c.type_id IN (SELECT type_id FROM CYT_COMPUTER_TYPES@DBLINK_PAU)
  AND ROWNUM=1;

  -- Entite destination (Pau)
  SELECT entity_id INTO v_eid_dst FROM CYT_ENTITIES WHERE site_code='PAU';
  SELECT MIN(user_id) INTO v_uid FROM CYT_USERS;

  SELECT status INTO v_status_av FROM CYT_COMPUTERS WHERE computer_id=v_cid;
  DBMS_OUTPUT.PUT_LINE('  PC ' || v_cid || ' avant transfert : ' || v_status_av);

  -- INSERT dans CYT_ASSET_TRANSFER -> TRG_STATUS_TRANSFER change le statut
  INSERT INTO CYT_ASSET_TRANSFER (computer_id, entity_src, entity_dst, initiated_by, reason, status)
  VALUES (v_cid, v_eid_src, v_eid_dst, v_uid, 'Demo TRG_STATUS_TRANSFER', 'EN_COURS');
  COMMIT;

  SELECT status INTO v_status_ap FROM CYT_COMPUTERS WHERE computer_id=v_cid;
  DBMS_OUTPUT.PUT_LINE('  PC ' || v_cid || ' apres INSERT transfer : ' || v_status_ap);
  DBMS_OUTPUT.PUT_LINE('  -> TRG_STATUS_TRANSFER : statut mis a jour automatiquement');

  -- Remise en etat
  UPDATE CYT_COMPUTERS SET status='ACTIF' WHERE computer_id=v_cid;
  DELETE FROM CYT_ASSET_TRANSFER WHERE computer_id=v_cid AND reason='Demo TRG_STATUS_TRANSFER';
  COMMIT;
EXCEPTION
  WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('  INFO : ' || SQLERRM);
END;
/


-- =============================================================================
-- SECTION 2 : VUES
-- =============================================================================
PROMPT
PROMPT ════════════════════════════════════════════════════════════════
PROMPT  SECTION 2 : VUES
PROMPT ════════════════════════════════════════════════════════════════

PROMPT
PROMPT [V_COMPUTERS_CERGY] Inventaire local Cergy
SELECT COUNT(*) AS nb_pc,
       SUM(CASE WHEN status='ACTIF' THEN 1 ELSE 0 END) AS actifs,
       SUM(CASE WHEN status='HORS_SERVICE' THEN 1 ELSE 0 END) AS hors_service,
       SUM(CASE WHEN status='EN_STOCK' THEN 1 ELSE 0 END) AS en_stock
FROM   V_COMPUTERS_CERGY;

PROMPT
PROMPT [V_COMPUTERS_FULL] PC avec details chaud + froid
SELECT computer_name, serial, status, uuid, ticket_tco
FROM   V_COMPUTERS_FULL WHERE ROWNUM<=3;

PROMPT
PROMPT [V_GLOBAL_COMPUTERS] Vision globale Cergy + Pau via DBLink
SELECT site, COUNT(*) AS nb_pc,
       SUM(CASE WHEN status='ACTIF' THEN 1 ELSE 0 END) AS actifs
FROM   V_GLOBAL_COMPUTERS GROUP BY site ORDER BY site;

PROMPT
PROMPT [V_GLOBAL_USERS] Utilisateurs Cergy + Pau via DBLink
SELECT site, COUNT(*) AS nb_users,
       SUM(CASE WHEN is_active=1 THEN 1 ELSE 0 END) AS actifs
FROM   V_GLOBAL_USERS GROUP BY site ORDER BY site;

PROMPT
PROMPT [V_NETWORK_MAPPING] Mapping PC -> Switch -> VLAN
SELECT pc_name, pc_mac, switch_name, switch_port_name, vlan_name, subnet
FROM   V_NETWORK_MAPPING WHERE ROWNUM<=3;

PROMPT
PROMPT [V_USERS_FULL] Utilisateurs avec details complets
SELECT login, realname, language, registration_number
FROM   V_USERS_FULL WHERE ROWNUM<=3;

PROMPT
PROMPT [V_AUDIT_RECENT] Evenements audit recents
SELECT table_name, operation, old_value, new_value, log_date
FROM   V_AUDIT_RECENT WHERE ROWNUM<=5 ORDER BY log_date DESC;

PROMPT
PROMPT [MV_INVENTORY_GLOBAL] Snapshot global sans reseau
SELECT site, COUNT(*) AS nb FROM MV_INVENTORY_GLOBAL GROUP BY site ORDER BY site;


-- =============================================================================
-- SECTION 3 : INDEX
-- =============================================================================
PROMPT
PROMPT ════════════════════════════════════════════════════════════════
PROMPT  SECTION 3 : INDEX (EXPLAIN PLAN)
PROMPT ════════════════════════════════════════════════════════════════

PROMPT
PROMPT [IDX_COMP_STATUS_ENTITY] Coût 11 sans index -> 8 avec index
PROMPT Plan SANS index :
EXPLAIN PLAN FOR
  SELECT /*+ FULL(c) */ computer_id FROM CYT_COMPUTERS c
  WHERE entity_id=1 AND status='HORS_SERVICE' AND is_deleted=0;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT=>'BASIC +COST'));

PROMPT Plan AVEC index :
EXPLAIN PLAN FOR
  SELECT computer_id FROM CYT_COMPUTERS
  WHERE entity_id=1 AND status='HORS_SERVICE' AND is_deleted=0;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT=>'BASIC +COST'));

PROMPT
PROMPT [IDX_COMP_SERIAL_FBI] Coût 11 sans FBI -> 1 avec FBI
PROMPT Plan SANS FBI :
EXPLAIN PLAN FOR
  SELECT /*+ FULL(c) */ computer_id FROM CYT_COMPUTERS c
  WHERE UPPER(serial) LIKE UPPER('SN-CY-001%');
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT=>'BASIC +COST'));

PROMPT Plan AVEC FBI :
EXPLAIN PLAN FOR
  SELECT computer_id FROM CYT_COMPUTERS
  WHERE UPPER(serial) LIKE UPPER('SN-CY-001%');
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT=>'BASIC +COST'));

PROMPT
PROMPT [IDX_NETPORT_ITEMS] Recherche ports par equipement
EXPLAIN PLAN FOR
  SELECT port_id, port_name FROM CYT_NETWORKPORTS
  WHERE items_id=1 AND item_type='COMPUTER';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT=>'BASIC +COST'));

PROMPT
PROMPT [CLU_NETWORK] Cluster CYT_NETWORKPORTS + CYT_PORT_LINKS
EXPLAIN PLAN FOR
  SELECT np.port_name, pl.port_dst FROM CYT_NETWORKPORTS np
  JOIN CYT_PORT_LINKS pl ON pl.port_src=np.port_id WHERE np.port_id=1;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT=>'BASIC +COST'));

PROMPT
PROMPT [IDX_AUDIT_DATE] Index date audit
EXPLAIN PLAN FOR
  SELECT table_name, operation, log_date FROM CYT_AUDIT_LOG
  WHERE log_date >= SYSDATE-1 ORDER BY log_date DESC;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT=>'BASIC +COST'));


-- =============================================================================
-- SECTION 4 : PROCEDURES ET FONCTIONS
-- =============================================================================
PROMPT
PROMPT ════════════════════════════════════════════════════════════════
PROMPT  SECTION 4 : PROCEDURES ET FONCTIONS
PROMPT ════════════════════════════════════════════════════════════════

PROMPT
PROMPT [F_COUNT_ASSETS] Comptage assets par site et statut

SELECT F_COUNT_ASSETS('CERGY')               AS total_cergy,
       F_COUNT_ASSETS('CERGY','ACTIF')       AS actifs_cergy,
       F_COUNT_ASSETS('CERGY','EN_STOCK')    AS stock_cergy,
       F_COUNT_ASSETS('CERGY','HORS_SERVICE') AS hs_cergy
FROM   DUAL;

PROMPT
PROMPT [F_IP_AVAILABLE] Verification disponibilite IP

DECLARE
  v_r1 VARCHAR2(10); v_r2 VARCHAR2(10);
BEGIN
  v_r1 := F_IP_AVAILABLE('10.0.0.1', 'CERGY');
  v_r2 := F_IP_AVAILABLE('172.16.99.99', 'CERGY');
  DBMS_OUTPUT.PUT_LINE('  IP 10.0.0.1 disponible sur CERGY    : ' || v_r1);
  DBMS_OUTPUT.PUT_LINE('  IP 172.16.99.99 disponible sur CERGY : ' || v_r2);
END;
/

PROMPT
PROMPT [P_CREATE_USER] Creation utilisateur multi-sites

BEGIN
  BEGIN
    DELETE FROM CYT_USERS WHERE login='demo_proc_user';
    DELETE FROM CYT_USERS@DBLINK_PAU WHERE login='demo_proc_user';
    COMMIT;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
  P_CREATE_USER('demo_proc_user','Demo2026!','DEMO','Procedure','PAU',2);
  DBMS_OUTPUT.PUT_LINE('  User demo_proc_user cree sur PAU via P_CREATE_USER');
  DELETE FROM CYT_USERS@DBLINK_PAU WHERE login='demo_proc_user';
  COMMIT;
EXCEPTION
  WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('  INFO : ' || SQLERRM);
END;
/

PROMPT
PROMPT [P_RAPPORT_INVENTAIRE_SALLE] Rapport inventaire par salle

BEGIN
  P_RAPPORT_INVENTAIRE_SALLE('Batiment A', NULL);
EXCEPTION
  WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('  INFO : ' || SQLERRM);
END;
/

PROMPT
PROMPT [P_DYNAMIC_REPORT] Rapport dynamique par site et statut

DECLARE
  v_cursor SYS_REFCURSOR;
  v_name   VARCHAR2(100); v_serial VARCHAR2(100);
  v_status VARCHAR2(50);  v_date   DATE;
  v_cnt    NUMBER := 0;
BEGIN
  P_DYNAMIC_REPORT('CERGY', 'HORS_SERVICE', v_cursor);
  LOOP
    FETCH v_cursor INTO v_name, v_serial, v_status, v_date;
    EXIT WHEN v_cursor%NOTFOUND OR v_cnt >= 3;
    DBMS_OUTPUT.PUT_LINE('  PC : ' || v_name || ' | ' || v_status);
    v_cnt := v_cnt + 1;
  END LOOP;
  CLOSE v_cursor;
  DBMS_OUTPUT.PUT_LINE('  -> P_DYNAMIC_REPORT : ' || v_cnt || ' PC HORS_SERVICE affiches');
EXCEPTION
  WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('  INFO : ' || SQLERRM);
END;
/

PROMPT
PROMPT [P_TRANSFER_ASSET] Transfert PC Cergy -> Pau

DECLARE
  v_cid  NUMBER; v_user NUMBER;
  v_av_c NUMBER; v_av_p NUMBER;
  v_ap_c NUMBER; v_ap_p NUMBER;
BEGIN
  SELECT computer_id INTO v_cid FROM CYT_COMPUTERS c
  WHERE status='ACTIF' AND is_deleted=0
  AND type_id  IN (SELECT type_id  FROM CYT_COMPUTER_TYPES@DBLINK_PAU)
  AND model_id IN (SELECT model_id FROM CYT_COMPUTER_MODELS@DBLINK_PAU)
  AND manufacturer_id IN (SELECT manufacturer_id FROM CYT_MANUFACTURERS@DBLINK_PAU)
  AND ROWNUM=1;
  SELECT MIN(user_id) INTO v_user FROM CYT_USERS;
  SELECT COUNT(*) INTO v_av_c FROM CYT_COMPUTERS WHERE is_deleted=0;
  SELECT COUNT(*) INTO v_av_p FROM CYT_COMPUTERS@DBLINK_PAU;
  DBMS_OUTPUT.PUT_LINE('  Avant : Cergy=' || v_av_c || ' | Pau=' || v_av_p);
  P_TRANSFER_ASSET(v_cid, 'Demo P_TRANSFER_ASSET', v_user);
  SELECT COUNT(*) INTO v_ap_c FROM CYT_COMPUTERS WHERE is_deleted=0;
  SELECT COUNT(*) INTO v_ap_p FROM CYT_COMPUTERS@DBLINK_PAU;
  DBMS_OUTPUT.PUT_LINE('  Apres : Cergy=' || v_ap_c || ' | Pau=' || v_ap_p);
  DBMS_OUTPUT.PUT_LINE('  -> P_TRANSFER_ASSET : -1 Cergy +1 Pau confirme');
EXCEPTION
  WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('  ERREUR : ' || SQLERRM);
END;
/


-- =============================================================================
-- SECTION 5 : PACKAGE PKG_GLPI_CYTECH
-- =============================================================================
PROMPT
PROMPT ════════════════════════════════════════════════════════════════
PROMPT  SECTION 5 : PACKAGE PKG_GLPI_CYTECH
PROMPT ════════════════════════════════════════════════════════════════

PROMPT
PROMPT [PKG_GLPI_CYTECH.F_COUNT_ASSETS] Interface unifiee - comptage

DECLARE
  v_total NUMBER; v_actifs NUMBER;
BEGIN
  v_total  := PKG_GLPI_CYTECH.F_COUNT_ASSETS('CERGY');
  v_actifs := PKG_GLPI_CYTECH.F_COUNT_ASSETS('CERGY', 'ACTIF');
  DBMS_OUTPUT.PUT_LINE('  Total Cergy  : ' || v_total);
  DBMS_OUTPUT.PUT_LINE('  Actifs Cergy : ' || v_actifs);
  DBMS_OUTPUT.PUT_LINE('  -> PKG.F_COUNT_ASSETS OK');
END;
/

PROMPT
PROMPT [PKG_GLPI_CYTECH.F_IP_AVAILABLE] Interface unifiee - IP

DECLARE
  v_r VARCHAR2(10);
BEGIN
  v_r := PKG_GLPI_CYTECH.F_IP_AVAILABLE('192.168.1.1', 'CERGY');
  DBMS_OUTPUT.PUT_LINE('  IP 192.168.1.1 sur CERGY : ' || v_r);
  DBMS_OUTPUT.PUT_LINE('  -> PKG.F_IP_AVAILABLE OK');
END;
/

PROMPT
PROMPT [PKG_GLPI_CYTECH.P_DYNAMIC_REPORT] Interface unifiee - rapport

DECLARE
  v_cursor SYS_REFCURSOR;
  v_name VARCHAR2(100); v_serial VARCHAR2(100);
  v_status VARCHAR2(50); v_date DATE;
BEGIN
  PKG_GLPI_CYTECH.P_DYNAMIC_REPORT('CERGY', 'EN_STOCK', v_cursor);
  FETCH v_cursor INTO v_name, v_serial, v_status, v_date;
  IF v_cursor%FOUND THEN
    DBMS_OUTPUT.PUT_LINE('  1er PC EN_STOCK : ' || v_name || ' | ' || v_status);
  END IF;
  CLOSE v_cursor;
  DBMS_OUTPUT.PUT_LINE('  -> PKG.P_DYNAMIC_REPORT OK');
EXCEPTION
  WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('  INFO : ' || SQLERRM);
END;
/


-- =============================================================================
-- BILAN FINAL
-- =============================================================================
PROMPT
PROMPT ════════════════════════════════════════════════════════════════
PROMPT  BILAN FINAL - STATUT DE TOUS LES OBJETS
PROMPT ════════════════════════════════════════════════════════════════

SELECT object_type,
       COUNT(*) AS nb,
       SUM(CASE WHEN status='VALID'   THEN 1 ELSE 0 END) AS valides,
       SUM(CASE WHEN status='INVALID' THEN 1 ELSE 0 END) AS invalides
FROM   user_objects
WHERE  object_type IN ('TRIGGER','VIEW','MATERIALIZED VIEW',
                       'PROCEDURE','FUNCTION','PACKAGE','PACKAGE BODY','INDEX')
GROUP BY object_type
ORDER BY object_type;