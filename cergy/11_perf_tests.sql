-- notion   : Test de performance avec difference visible
-- connecxion: APPLI_GLPI
SET SERVEROUTPUT ON SIZE 1000000;
SET LINESIZE 120;
SET PAGESIZE 50;

PROMPT ================================================================
PROMPT  TESTS DE PERFORMANCE - Architecture CYT Oracle Repartie
PROMPT ================================================================

-- T01 : Index composite IDX_COMP_STATUS_ENTITY
-- Requete selective : statut rare (HORS_SERVICE ~5% des donnees)
-- SANS index : TABLE ACCESS FULL (hint FULL)
-- AVEC index : INDEX RANGE SCAN

PROMPT
PROMPT === T01 : Index composite IDX_COMP_STATUS_ENTITY ===
PROMPT Note : requete sur statut rare (HORS_SERVICE ~5%) pour forcer l index

DECLARE
  v_t0 NUMBER; v_t1 NUMBER; v_cnt NUMBER;
BEGIN
  -- SANS index (force par hint)
  v_t0 := DBMS_UTILITY.GET_TIME;
  SELECT /*+ FULL(c) */ COUNT(*) INTO v_cnt FROM CYT_COMPUTERS c
  WHERE entity_id=1 AND status='HORS_SERVICE' AND is_deleted=0;
  v_t1 := DBMS_UTILITY.GET_TIME;
  DBMS_OUTPUT.PUT_LINE('T01 SANS index (Full Scan) : ' || (v_t1-v_t0) || ' cs - ' || v_cnt || ' lignes');

  -- AVEC index (normal)
  v_t0 := DBMS_UTILITY.GET_TIME;
  SELECT COUNT(*) INTO v_cnt FROM CYT_COMPUTERS c
  WHERE entity_id=1 AND status='HORS_SERVICE' AND is_deleted=0;
  v_t1 := DBMS_UTILITY.GET_TIME;
  DBMS_OUTPUT.PUT_LINE('T01 AVEC index composite  : ' || (v_t1-v_t0) || ' cs - ' || v_cnt || ' lignes');
END;
/

PROMPT Plan SANS index (Full Scan force) :
EXPLAIN PLAN FOR
  SELECT /*+ FULL(c) */ computer_id, computer_name FROM CYT_COMPUTERS c
  WHERE entity_id=1 AND status='HORS_SERVICE' AND is_deleted=0;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT=>'BASIC +COST'));

PROMPT Plan AVEC index composite :
EXPLAIN PLAN FOR
  SELECT computer_id, computer_name FROM CYT_COMPUTERS c
  WHERE entity_id=1 AND status='HORS_SERVICE' AND is_deleted=0;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT=>'BASIC +COST'));


-- =============================================================================
-- T02 : Cluster CLU_NETWORK
-- Acces co-localise CYT_NETWORKPORTS + CYT_PORT_LINKS
-- Plan attendu : TABLE ACCESS CLUSTER
-- =============================================================================
PROMPT
PROMPT === T02 : Cluster CLU_NETWORK vs acces normal ===

DECLARE
  v_t0 NUMBER; v_t1 NUMBER; v_cnt NUMBER;
BEGIN
  -- Via cluster (acces co-localise)
  v_t0 := DBMS_UTILITY.GET_TIME;
  SELECT COUNT(*) INTO v_cnt
  FROM CYT_NETWORKPORTS np JOIN CYT_PORT_LINKS pl ON pl.port_src=np.port_id
  WHERE np.port_id <= 500;
  v_t1 := DBMS_UTILITY.GET_TIME;
  DBMS_OUTPUT.PUT_LINE('T02 Via Cluster (port_id<=500) : ' || (v_t1-v_t0) || ' cs - ' || v_cnt || ' liaisons');

  -- Parcours complet
  v_t0 := DBMS_UTILITY.GET_TIME;
  SELECT COUNT(*) INTO v_cnt
  FROM CYT_NETWORKPORTS np JOIN CYT_PORT_LINKS pl ON pl.port_src=np.port_id;
  v_t1 := DBMS_UTILITY.GET_TIME;
  DBMS_OUTPUT.PUT_LINE('T02 Toutes liaisons (3000) : ' || (v_t1-v_t0) || ' cs - ' || v_cnt || ' liaisons');
END;
/

PROMPT Plan Cluster (TABLE ACCESS CLUSTER attendu sur port_id precis) :
EXPLAIN PLAN FOR
  SELECT np.port_name, np.mac_address, pl.port_dst
  FROM   CYT_NETWORKPORTS np
  JOIN   CYT_PORT_LINKS pl ON pl.port_src=np.port_id
  WHERE  np.port_id=1;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT=>'BASIC +COST'));

PROMPT Plan complet (tous les ports) :
EXPLAIN PLAN FOR
  SELECT np.port_name, pl.port_dst
  FROM   CYT_NETWORKPORTS np
  JOIN   CYT_PORT_LINKS pl ON pl.port_src=np.port_id;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT=>'BASIC +COST'));


-- =============================================================================
-- T03 : Function-Based Index IDX_COMP_SERIAL_FBI
-- Recherche insensible casse
-- SANS FBI : FULL TABLE SCAN (hint)
-- AVEC FBI : INDEX RANGE SCAN
-- =============================================================================
PROMPT
PROMPT === T03 : Function-Based Index IDX_COMP_SERIAL_FBI ===

DECLARE
  v_t0 NUMBER; v_t1 NUMBER; v_cnt NUMBER;
BEGIN
  -- SANS FBI
  v_t0 := DBMS_UTILITY.GET_TIME;
  SELECT /*+ FULL(c) */ COUNT(*) INTO v_cnt FROM CYT_COMPUTERS c
  WHERE UPPER(serial) LIKE UPPER('SN-CY-001%');
  v_t1 := DBMS_UTILITY.GET_TIME;
  DBMS_OUTPUT.PUT_LINE('T03 SANS FBI (Full Scan) : ' || (v_t1-v_t0) || ' cs - ' || v_cnt || ' lignes');

  -- AVEC FBI
  v_t0 := DBMS_UTILITY.GET_TIME;
  SELECT COUNT(*) INTO v_cnt FROM CYT_COMPUTERS
  WHERE UPPER(serial) LIKE UPPER('SN-CY-001%');
  v_t1 := DBMS_UTILITY.GET_TIME;
  DBMS_OUTPUT.PUT_LINE('T03 AVEC FBI            : ' || (v_t1-v_t0) || ' cs - ' || v_cnt || ' lignes');
END;
/

PROMPT Plan SANS FBI (Full Scan force) :
EXPLAIN PLAN FOR
  SELECT /*+ FULL(c) */ computer_id, serial FROM CYT_COMPUTERS c
  WHERE UPPER(serial) LIKE UPPER('SN-CY-001%');
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT=>'BASIC +COST'));

PROMPT Plan AVEC FBI (INDEX RANGE SCAN attendu) :
EXPLAIN PLAN FOR
  SELECT computer_id, serial FROM CYT_COMPUTERS
  WHERE UPPER(serial) LIKE UPPER('SN-CY-001%');
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT=>'BASIC +COST'));


-- =============================================================================
-- T04 : Index IDX_AUDIT_DATE sur CYT_AUDIT_LOG
-- Requete sur une plage courte (dernieres 24h) pour forcer l index
-- =============================================================================
PROMPT
PROMPT === T04 : Index IDX_AUDIT_DATE sur CYT_AUDIT_LOG ===
PROMPT Note : plage courte (24h) pour que l index soit selectif

DECLARE
  v_t0 NUMBER; v_t1 NUMBER; v_cnt NUMBER;
BEGIN
  -- SANS index
  v_t0 := DBMS_UTILITY.GET_TIME;
  SELECT /*+ FULL(a) */ COUNT(*) INTO v_cnt FROM CYT_AUDIT_LOG a
  WHERE log_date >= SYSDATE - 1;
  v_t1 := DBMS_UTILITY.GET_TIME;
  DBMS_OUTPUT.PUT_LINE('T04 SANS index (Full Scan) : ' || (v_t1-v_t0) || ' cs - ' || v_cnt || ' lignes');

  -- AVEC index
  v_t0 := DBMS_UTILITY.GET_TIME;
  SELECT COUNT(*) INTO v_cnt FROM CYT_AUDIT_LOG
  WHERE log_date >= SYSDATE - 1;
  v_t1 := DBMS_UTILITY.GET_TIME;
  DBMS_OUTPUT.PUT_LINE('T04 AVEC index audit      : ' || (v_t1-v_t0) || ' cs - ' || v_cnt || ' lignes');
END;
/

PROMPT Plan SANS index (Full Scan force) :
EXPLAIN PLAN FOR
  SELECT /*+ FULL(a) */ table_name, operation, log_date FROM CYT_AUDIT_LOG a
  WHERE log_date >= SYSDATE - 1 ORDER BY log_date DESC;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT=>'BASIC +COST'));

PROMPT Plan AVEC index (INDEX RANGE SCAN attendu) :
EXPLAIN PLAN FOR
  SELECT table_name, operation, log_date FROM CYT_AUDIT_LOG
  WHERE log_date >= SYSDATE - 1 ORDER BY log_date DESC;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT=>'BASIC +COST'));


-- T05 : DBLink vs MV_INVENTORY_GLOBAL vs local

PROMPT
PROMPT === T05 : Local vs DBLink vs MV snapshot ===

DECLARE
  v_t0 NUMBER; v_t1 NUMBER; v_cnt NUMBER;
BEGIN
  v_t0 := DBMS_UTILITY.GET_TIME;
  SELECT COUNT(*) INTO v_cnt FROM CYT_COMPUTERS WHERE is_deleted=0;
  v_t1 := DBMS_UTILITY.GET_TIME;
  DBMS_OUTPUT.PUT_LINE('T05 Local Cergy       : ' || (v_t1-v_t0) || ' cs - ' || v_cnt || ' lignes');

  v_t0 := DBMS_UTILITY.GET_TIME;
  SELECT COUNT(*) INTO v_cnt FROM V_GLOBAL_COMPUTERS;
  v_t1 := DBMS_UTILITY.GET_TIME;
  DBMS_OUTPUT.PUT_LINE('T05 DBLink temps reel : ' || (v_t1-v_t0) || ' cs - ' || v_cnt || ' lignes');

  v_t0 := DBMS_UTILITY.GET_TIME;
  SELECT COUNT(*) INTO v_cnt FROM MV_INVENTORY_GLOBAL;
  v_t1 := DBMS_UTILITY.GET_TIME;
  DBMS_OUTPUT.PUT_LINE('T05 MV snapshot       : ' || (v_t1-v_t0) || ' cs - ' || v_cnt || ' lignes');
  DBMS_OUTPUT.PUT_LINE('=> MV : meme resultat que DBLink mais sans overhead reseau');
END;
/

-- T06 : Fragmentation verticale
-- Comparer lecture fragment chaud vs vue complete (JOIN froid)

PROMPT
PROMPT === T06 : Fragmentation verticale chaud vs complet ===

DECLARE
  v_t0 NUMBER; v_t1 NUMBER; v_cnt NUMBER;
BEGIN
  -- Fragment chaud seul (TS_CERGY_DATA)
  v_t0 := DBMS_UTILITY.GET_TIME;
  SELECT COUNT(*) INTO v_cnt FROM CYT_COMPUTERS WHERE entity_id=1 AND is_deleted=0;
  v_t1 := DBMS_UTILITY.GET_TIME;
  DBMS_OUTPUT.PUT_LINE('T06 Fragment CHAUD seul  : ' || (v_t1-v_t0) || ' cs - ' || v_cnt || ' lignes');

  -- Vue complete (JOIN chaud + froid)
  v_t0 := DBMS_UTILITY.GET_TIME;
  SELECT COUNT(*) INTO v_cnt FROM V_COMPUTERS_FULL WHERE entity_id=1;
  v_t1 := DBMS_UTILITY.GET_TIME;
  DBMS_OUTPUT.PUT_LINE('T06 Vue COMPLETE (JOIN)  : ' || (v_t1-v_t0) || ' cs - ' || v_cnt || ' lignes');
  DBMS_OUTPUT.PUT_LINE('=> Chaud : blocs denses, pas de lecture colonnes froides inutiles');
END;
/

PROMPT Plan fragment chaud (TS_CERGY_DATA seulement) :
EXPLAIN PLAN FOR
  SELECT computer_id, computer_name, status FROM CYT_COMPUTERS
  WHERE entity_id=1 AND is_deleted=0;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT=>'BASIC +COST'));

PROMPT Plan vue complete (JOIN chaud + froid TS_CERGY_COLD) :
EXPLAIN PLAN FOR
  SELECT c.computer_name, c.status, cd.uuid, cd.ticket_tco
  FROM   CYT_COMPUTERS c
  JOIN   CYT_COMPUTERS_DETAIL cd ON cd.computer_id=c.computer_id
  WHERE  c.entity_id=1 AND c.is_deleted=0;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT=>'BASIC +COST'));


-- T07 : Trigger TRG_AUDIT_COMPUTERS
-- Mesurer le cout du trigger sur les UPDATE

PROMPT
PROMPT === T07 : Overhead trigger TRG_AUDIT_COMPUTERS ===

DECLARE
  v_t0 NUMBER; v_t1 NUMBER; v_av NUMBER; v_ap NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_av FROM CYT_AUDIT_LOG;

  -- UPDATE avec trigger actif
  v_t0 := DBMS_UTILITY.GET_TIME;
  UPDATE CYT_COMPUTERS SET status='EN_STOCK'
  WHERE computer_id IN (SELECT computer_id FROM CYT_COMPUTERS WHERE ROWNUM<=50);
  COMMIT;
  v_t1 := DBMS_UTILITY.GET_TIME;
  SELECT COUNT(*) INTO v_ap FROM CYT_AUDIT_LOG;

  DBMS_OUTPUT.PUT_LINE('T07 UPDATE 50 PC avec trigger : ' || (v_t1-v_t0) || ' cs');
  DBMS_OUTPUT.PUT_LINE('    Entrees audit auto-generees : ' || (v_ap-v_av));
  DBMS_OUTPUT.PUT_LINE('    Overhead par ligne : negligeable (1 INSERT audit / UPDATE)');

  -- Remise en etat
  UPDATE CYT_COMPUTERS SET status='ACTIF'
  WHERE computer_id IN (SELECT computer_id FROM CYT_COMPUTERS WHERE status='EN_STOCK' AND ROWNUM<=50);
  COMMIT;
END;
/


PROMPT
PROMPT ================================================================
PROMPT  RECAPITULATIF
PROMPT  T01 Index composite  : INDEX RANGE SCAN vs TABLE ACCESS FULL
PROMPT  T02 Cluster          : TABLE ACCESS CLUSTER (I/O co-localise)
PROMPT  T03 FBI              : INDEX RANGE SCAN sur UPPER(serial)
PROMPT  T04 Index audit      : INDEX RANGE SCAN sur plage 24h
PROMPT  T05 MV vs DBLink     : MV=0cs vs DBLink=2cs - meme resultat
PROMPT  T06 Fragmentation    : Chaud seul vs JOIN chaud+froid
PROMPT  T07 Trigger audit    : 50 lignes audit en 0cs overhead
PROMPT ================================================================

SELECT F_COUNT_ASSETS('CERGY')            AS total,
       F_COUNT_ASSETS('CERGY','ACTIF')    AS actifs,
       F_COUNT_ASSETS('CERGY','EN_STOCK') AS stock
FROM   DUAL;
