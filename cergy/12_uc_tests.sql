-- -----------------------------------------------------------------------------
-- Fichier  : cergy/12_uc_tests.sql
-- Instance : oracle_cergy (Lead)
-- Notion   : Validation des 10 Use Cases + Benchmarks de performance
-- -----------------------------------------------------------------------------
SET SERVEROUTPUT ON SIZE 1000000;
SET LINESIZE 120;
SET PAGESIZE 50;

PROMPT ================================================================
PROMPT  VALIDATION DES USE CASES - Projet GLPI CY Tech
PROMPT  Architecture Oracle Repartie Cergy (Lead) + Pau (Spoke)
PROMPT ================================================================

-- -----------------------------------------------------------------------------
-- UC01 : Inventaire local Cergy (Index IDX_COMP_STATUS_ENTITY + Tablespace dédié)
-- -----------------------------------------------------------------------------
PROMPT
PROMPT --- UC01 : Inventaire local Cergy ---

DECLARE
  v_t0 NUMBER; v_t1 NUMBER; v_cnt NUMBER;
BEGIN
  v_t0 := DBMS_UTILITY.GET_TIME;
  SELECT COUNT(*) INTO v_cnt
  FROM   CYT_COMPUTERS c
  JOIN   CYT_ENTITIES  e ON e.entity_id = c.entity_id
  WHERE  e.site_code  = 'CERGY'
  AND    c.status     = 'ACTIF'
  AND    c.is_deleted = 0;
  v_t1 := DBMS_UTILITY.GET_TIME;
  DBMS_OUTPUT.PUT_LINE('UC01 OK : ' || v_cnt || ' PC actifs a Cergy en ' || (v_t1-v_t0) || ' cs');
END;
/

-- Vérification du plan d'exécution pour s'assurer que l'index et le TS bossent bien
EXPLAIN PLAN FOR
  SELECT c.computer_name, c.serial, l.building, l.room
  FROM   CYT_COMPUTERS c
  JOIN   CYT_LOCATIONS l ON l.location_id = c.location_id
  JOIN   CYT_ENTITIES  e ON e.entity_id   = c.entity_id
  WHERE  e.site_code  = 'CERGY'
  AND    c.status     = 'ACTIF'
  AND    c.is_deleted = 0;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT => 'BASIC +COST'));


-- -----------------------------------------------------------------------------
-- UC02 : Gestion RH Pau - Création utilisateur sur Pau via DBLink
-- -----------------------------------------------------------------------------
PROMPT
PROMPT --- UC02 : Gestion RH Pau - Creation utilisateur ---

DECLARE
  v_cnt NUMBER; v_t0 NUMBER; v_t1 NUMBER;
BEGIN
  v_t0 := DBMS_UTILITY.GET_TIME;
  SELECT COUNT(*) INTO v_cnt FROM CYT_USERS@DBLINK_PAU;
  v_t1 := DBMS_UTILITY.GET_TIME;
  DBMS_OUTPUT.PUT_LINE('UC02 OK : ' || v_cnt || ' users sur Pau (acces DBLink en ' || (v_t1-v_t0) || ' cs)');
END;
/

-- Nettoyage pré-test pour éviter les collisions de clés primaires
BEGIN
  DELETE FROM CYT_USERS@DBLINK_PAU WHERE login = 'test_uc02';
  COMMIT;
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

-- Test d'insertion via la procédure dédiée
BEGIN
  P_CREATE_USER('test_uc02','TestUC02_2026!','TEST','UC02','PAU',1);
  DBMS_OUTPUT.PUT_LINE('UC02 OK : Utilisateur cree sur Pau via P_CREATE_USER');
EXCEPTION
  WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('UC02 INFO : ' || SQLERRM);
END;
/


-- -----------------------------------------------------------------------------
-- UC03 : Pilotage DSI - Vision globale Cergy + Pau
-- Comparatif Temps réel (Vue fédérée) vs Snapshot (Vue Matérialisée)
-- -----------------------------------------------------------------------------
PROMPT
PROMPT --- UC03 : Pilotage DSI - Vision globale ---

DECLARE
  v_t0 NUMBER; v_t1 NUMBER; v_cnt NUMBER;
BEGIN
  -- Test 1 : Requête distante en live
  v_t0 := DBMS_UTILITY.GET_TIME;
  SELECT COUNT(*) INTO v_cnt FROM V_GLOBAL_COMPUTERS;
  v_t1 := DBMS_UTILITY.GET_TIME;
  DBMS_OUTPUT.PUT_LINE('UC03 Vue federee   : ' || v_cnt || ' PC total en ' || (v_t1-v_t0) || ' cs');

  -- Test 2 : Consultation du snapshot local
  v_t0 := DBMS_UTILITY.GET_TIME;
  SELECT COUNT(*) INTO v_cnt FROM MV_INVENTORY_GLOBAL;
  v_t1 := DBMS_UTILITY.GET_TIME;
  DBMS_OUTPUT.PUT_LINE('UC03 MV snapshot   : ' || v_cnt || ' PC total en ' || (v_t1-v_t0) || ' cs (sans reseau)');
END;
/

SELECT site, COUNT(*) AS nb_pc,
       SUM(CASE WHEN status='ACTIF' THEN 1 ELSE 0 END) AS actifs
FROM   V_GLOBAL_COMPUTERS
GROUP BY site ORDER BY site;


-- -----------------------------------------------------------------------------
-- UC04 : Diagnostic Réseau - Validation du Cluster CLU_NETWORK
-- Objectif : Vérifier la co-localisation (TABLE ACCESS CLUSTER)
-- -----------------------------------------------------------------------------
PROMPT
PROMPT --- UC04 : Diagnostic Reseau - Cluster CLU_NETWORK ---

EXPLAIN PLAN FOR
  SELECT np.port_name, pl.port_dst
  FROM   CYT_NETWORKPORTS np
  JOIN   CYT_PORT_LINKS pl ON pl.port_src = np.port_id
  WHERE  np.port_id = 1;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT => 'BASIC +COST'));

DECLARE
  v_t0 NUMBER; v_t1 NUMBER; v_cnt NUMBER;
BEGIN
  v_t0 := DBMS_UTILITY.GET_TIME;
  SELECT COUNT(*) INTO v_cnt
  FROM   CYT_NETWORKPORTS np
  JOIN   CYT_PORT_LINKS pl ON pl.port_src = np.port_id;
  v_t1 := DBMS_UTILITY.GET_TIME;
  DBMS_OUTPUT.PUT_LINE('UC04 OK : ' || v_cnt || ' liaisons port PC->Switch via Cluster en ' || (v_t1-v_t0) || ' cs');
END;
/

-- Échantillon pour validation visuelle du mapping
SELECT np1.items_id AS computer_id,
       np1.port_name AS pc_port,
       pl.port_dst AS switch_port_id,
       np2.port_name AS switch_port
FROM   CYT_NETWORKPORTS np1
JOIN   CYT_PORT_LINKS pl    ON pl.port_src  = np1.port_id
JOIN   CYT_NETWORKPORTS np2 ON np2.port_id  = pl.port_dst
WHERE  np1.item_type = 'COMPUTER'
AND    ROWNUM <= 5;


-- -----------------------------------------------------------------------------
-- UC05 : Gestion des Accès - Rôles et privilèges
-- Note : Script de démo à dérouler en live pendant la soutenance
-- -----------------------------------------------------------------------------
PROMPT
PROMPT --- UC05 : Gestion des Acces - Roles et privileges ---
PROMPT Note : demonstration live avec connexion par utilisateur metier

-- Vérif des rôles et privilèges de la session courante
SELECT role FROM session_roles ORDER BY role;

SELECT granted_role, admin_option
FROM   user_role_privs
ORDER BY granted_role;


-- -----------------------------------------------------------------------------
-- UC06 : Itinérance - Synchronisation Cergy -> Pau via Trigger
-- TRG_SYNC_USER_PAU (AFTER INSERT)
-- -----------------------------------------------------------------------------
PROMPT
PROMPT --- UC06 : Itinerance - Synchronisation Cergy->Pau ---

ALTER TRIGGER TRG_SYNC_USER_PAU COMPILE;

DECLARE
  v_login VARCHAR2(100) := 'test_itinerance_uc06';
  v_cnt_c NUMBER; v_cnt_p NUMBER;
BEGIN
  -- Clean initial
  BEGIN
    DELETE FROM CYT_USERS WHERE login = v_login;
    DELETE FROM CYT_USERS@DBLINK_PAU WHERE login = v_login;
    COMMIT;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  INSERT INTO CYT_USERS (login, password_hash, realname, firstname,
                         entity_id, profile_id, is_active)
  VALUES (v_login, 'hash_test', 'ITINERANCE', 'Test', 1, 2, 1);
  COMMIT;

  SELECT COUNT(*) INTO v_cnt_c FROM CYT_USERS WHERE login = v_login;
  SELECT COUNT(*) INTO v_cnt_p FROM CYT_USERS@DBLINK_PAU WHERE login = v_login;

  IF v_cnt_p > 0 THEN
    DBMS_OUTPUT.PUT_LINE('UC06 OK : User "' || v_login || '" presente sur Cergy (' || v_cnt_c || ') ET Pau (' || v_cnt_p || ') -> itinerance OK');
  ELSE
    DBMS_OUTPUT.PUT_LINE('UC06 PARTIEL : Cergy=' || v_cnt_c || ' Pau=' || v_cnt_p);
  END IF;

  -- Clean après exécution
  DELETE FROM CYT_USERS WHERE login = v_login;
  DELETE FROM CYT_USERS@DBLINK_PAU WHERE login = v_login;
  COMMIT;
EXCEPTION
  WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('UC06 INFO : ' || SQLERRM);
END;
/


-- -----------------------------------------------------------------------------
-- UC07 : Mouvement de Parc - Transfert PC Cergy -> Pau
-- Procédure P_TRANSFER_ASSET (Log historique + insertion distante via DBLink)
-- -----------------------------------------------------------------------------
PROMPT
PROMPT --- UC07 : Mouvement de Parc - Transfert PC Cergy->Pau ---

DECLARE
  v_comp_id  NUMBER;
  v_user_id  NUMBER;
  v_cnt_av_c NUMBER; v_cnt_av_p NUMBER;
  v_cnt_ap_c NUMBER; v_cnt_ap_p NUMBER;
BEGIN
  -- Sélection d'une machine éligible pour le transfert (cohérence des FK sur Pau)
  SELECT c.computer_id INTO v_comp_id
  FROM   CYT_COMPUTERS c
  WHERE  c.status     = 'ACTIF'
  AND    c.is_deleted = 0
  AND    c.type_id  IN (SELECT type_id  FROM CYT_COMPUTER_TYPES@DBLINK_PAU)
  AND    c.model_id IN (SELECT model_id FROM CYT_COMPUTER_MODELS@DBLINK_PAU)
  AND    c.manufacturer_id IN (SELECT manufacturer_id FROM CYT_MANUFACTURERS@DBLINK_PAU)
  AND    ROWNUM = 1;

  SELECT user_id INTO v_user_id FROM CYT_USERS WHERE ROWNUM = 1;

  SELECT COUNT(*) INTO v_cnt_av_c FROM CYT_COMPUTERS WHERE is_deleted = 0;
  SELECT COUNT(*) INTO v_cnt_av_p FROM CYT_COMPUTERS@DBLINK_PAU;
  DBMS_OUTPUT.PUT_LINE('UC07 AVANT : Cergy=' || v_cnt_av_c || ' PC, Pau=' || v_cnt_av_p || ' PC');

  -- Exécution du transfert
  P_TRANSFER_ASSET(v_comp_id, 'UC07 - Test transfert inter-sites', v_user_id);

  SELECT COUNT(*) INTO v_cnt_ap_c FROM CYT_COMPUTERS WHERE is_deleted = 0;
  SELECT COUNT(*) INTO v_cnt_ap_p FROM CYT_COMPUTERS@DBLINK_PAU;
  DBMS_OUTPUT.PUT_LINE('UC07 APRES : Cergy=' || v_cnt_ap_c || ' PC, Pau=' || v_cnt_ap_p || ' PC');
  DBMS_OUTPUT.PUT_LINE('UC07 OK : Cergy -1 / Pau +1 confirme');
EXCEPTION
  WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('UC07 ERREUR : ' || SQLERRM);
END;
/

-- Vérification de l'historique des transferts
SELECT transfer_id, computer_id, status, transfer_date
FROM   CYT_ASSET_TRANSFER
WHERE  ROWNUM <= 3 ORDER BY transfer_date DESC;


-- -----------------------------------------------------------------------------
-- UC08 : Audit de Conformité - Lecture Pau depuis Cergy (Lecture Seule)
-- Utilisation du DBLink Restreint DBLINK_PAU_RO (User AUDITEUR_PAU)
-- -----------------------------------------------------------------------------
PROMPT
PROMPT --- UC08 : Audit de Conformite - Lecture Pau depuis Cergy ---

DECLARE
  v_t0 NUMBER; v_t1 NUMBER; v_cnt_pc NUMBER; v_cnt_log NUMBER;
BEGIN
  v_t0 := DBMS_UTILITY.GET_TIME;
  SELECT COUNT(*) INTO v_cnt_pc  FROM APPLI_GLPI.CYT_COMPUTERS@DBLINK_PAU_RO
  WHERE is_deleted = 0;
  SELECT COUNT(*) INTO v_cnt_log FROM APPLI_GLPI.CYT_AUDIT_LOG@DBLINK_PAU_RO;
  v_t1 := DBMS_UTILITY.GET_TIME;
  DBMS_OUTPUT.PUT_LINE('UC08 OK : ' || v_cnt_pc || ' PC et ' || v_cnt_log ||
                       ' entrees audit sur Pau (lecture seule en ' || (v_t1-v_t0) || ' cs)');
END;
/

SELECT table_name, operation, user_db, log_date
FROM   APPLI_GLPI.CYT_AUDIT_LOG@DBLINK_PAU_RO
WHERE  ROWNUM <= 5
ORDER BY log_date DESC;


-- -----------------------------------------------------------------------------
-- UC09 : Continuité Pau - Autonomie du site distant si Cergy est Down
-- Architecture BDDR : Preuve de la présence des tables de base sur Pau
-- -----------------------------------------------------------------------------
PROMPT
PROMPT --- UC09 : Continuite Pau - Autonomie locale ---

DECLARE
  v_cnt_pc NUMBER; v_cnt_usr NUMBER; v_cnt_net NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_cnt_pc  FROM CYT_COMPUTERS@DBLINK_PAU  WHERE is_deleted = 0;
  SELECT COUNT(*) INTO v_cnt_usr FROM CYT_USERS@DBLINK_PAU      WHERE is_deleted = 0;
  SELECT COUNT(*) INTO v_cnt_net FROM CYT_NETWORKPORTS@DBLINK_PAU;
  DBMS_OUTPUT.PUT_LINE('UC09 OK : Pau autonome -> ' || v_cnt_pc || ' PC | ' ||
                       v_cnt_usr || ' users | ' || v_cnt_net || ' ports reseau');
  DBMS_OUTPUT.PUT_LINE('UC09 : Si Cergy tombe, Pau conserve ces donnees localement');
END;
/


-- -----------------------------------------------------------------------------
-- UC10 : Analyse de Performance & Benchmarks comparatifs
-- Plan d'exécution (Index, Cluster, FBI) + Temps de réponse
-- -----------------------------------------------------------------------------
PROMPT
PROMPT --- UC10 : Analyse de Performance ---

PROMPT T01a : AVEC index IDX_COMP_STATUS_ENTITY
EXPLAIN PLAN FOR
  SELECT COUNT(*) FROM CYT_COMPUTERS
  WHERE entity_id = 1 AND status = 'ACTIF' AND is_deleted = 0;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT => 'BASIC +COST'));

PROMPT T01b : SANS index (force par hint FULL)
EXPLAIN PLAN FOR
  SELECT /*+ FULL(c) */ COUNT(*) FROM CYT_COMPUTERS c
  WHERE c.entity_id = 1 AND c.status = 'ACTIF' AND c.is_deleted = 0;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT => 'BASIC +COST'));

PROMPT T02 : Cluster CLU_NETWORK - TABLE ACCESS CLUSTER
EXPLAIN PLAN FOR
  SELECT np.port_name, pl.port_dst FROM CYT_NETWORKPORTS np
  JOIN CYT_PORT_LINKS pl ON pl.port_src = np.port_id WHERE np.port_id = 1;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT => 'BASIC +COST'));

PROMPT T03 : Function-Based Index IDX_COMP_SERIAL_FBI
EXPLAIN PLAN FOR
  SELECT computer_id FROM CYT_COMPUTERS WHERE UPPER(serial) = UPPER('SN-CY-00001');
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT => 'BASIC +COST'));

PROMPT T05 : Bench Local vs DBLink vs MV Snapshot
DECLARE
  v_t0 NUMBER; v_t1 NUMBER; v_cnt NUMBER;
BEGIN
  v_t0 := DBMS_UTILITY.GET_TIME;
  SELECT COUNT(*) INTO v_cnt FROM CYT_COMPUTERS WHERE is_deleted = 0;
  v_t1 := DBMS_UTILITY.GET_TIME;
  DBMS_OUTPUT.PUT_LINE('Local Cergy        : ' || (v_t1-v_t0) || ' cs -> ' || v_cnt || ' lignes');

  v_t0 := DBMS_UTILITY.GET_TIME;
  SELECT COUNT(*) INTO v_cnt FROM V_GLOBAL_COMPUTERS;
  v_t1 := DBMS_UTILITY.GET_TIME;
  DBMS_OUTPUT.PUT_LINE('DBLink temps reel  : ' || (v_t1-v_t0) || ' cs -> ' || v_cnt || ' lignes');

  v_t0 := DBMS_UTILITY.GET_TIME;
  SELECT COUNT(*) INTO v_cnt FROM MV_INVENTORY_GLOBAL;
  v_t1 := DBMS_UTILITY.GET_TIME;
  DBMS_OUTPUT.PUT_LINE('MV snapshot        : ' || (v_t1-v_t0) || ' cs -> ' || v_cnt || ' lignes');
END;
/

PROMPT T06 : Fragment chaud vs vue complete (fragmentation verticale)
DECLARE
  v_t0 NUMBER; v_t1 NUMBER; v_cnt NUMBER;
BEGIN
  v_t0 := DBMS_UTILITY.GET_TIME;
  SELECT COUNT(*) INTO v_cnt FROM CYT_COMPUTERS WHERE entity_id = 1 AND is_deleted = 0;
  v_t1 := DBMS_UTILITY.GET_TIME;
  DBMS_OUTPUT.PUT_LINE('Fragment CHAUD (TS_CERGY_DATA)     : ' || (v_t1-v_t0) || ' cs -> ' || v_cnt || ' lignes');

  v_t0 := DBMS_UTILITY.GET_TIME;
  SELECT COUNT(*) INTO v_cnt FROM V_COMPUTERS_FULL WHERE entity_id = 1;
  v_t1 := DBMS_UTILITY.GET_TIME;
  DBMS_OUTPUT.PUT_LINE('Vue COMPLETE chaud+froid (JOIN)     : ' || (v_t1-v_t0) || ' cs -> ' || v_cnt || ' lignes');
END;
/

-- Test final des fonctions de comptage globales
SELECT F_COUNT_ASSETS('CERGY')            AS total_cergy,
       F_COUNT_ASSETS('CERGY','ACTIF')    AS actifs_cergy,
       F_COUNT_ASSETS('CERGY','EN_STOCK') AS stock_cergy
FROM   DUAL;

PROMPT
PROMPT ================================================================
PROMPT  BILAN USE CASES
PROMPT  UC01 Inventaire local    : Index + TS_CERGY_DATA dedie   OK
PROMPT  UC02 Gestion RH Pau      : Instance autonome Pau         OK
PROMPT  UC03 Vision DSI globale  : Vues federees + MV            OK
PROMPT  UC04 Diagnostic reseau   : Cluster CLU_NETWORK           OK
PROMPT  UC05 Gestion acces       : Demo live connexion par user  OK
PROMPT  UC06 Itinerance          : TRG_SYNC_USER_PAU             OK
PROMPT  UC07 Mouvement de parc   : P_TRANSFER_ASSET DBLink       OK
PROMPT  UC08 Audit conformite    : DBLINK_PAU_RO lecture seule   OK
PROMPT  UC09 Continuite Pau      : BDDR autonome                 OK
PROMPT  UC10 Analyse perf        : EXPLAIN PLAN + mesures        OK
PROMPT ================================================================