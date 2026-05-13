-- =============================================================================
-- FICHIER  : cergy/11_perf_tests.sql
-- INSTANCE : cergy_db (Lead)
-- NOTION   : EXPLAIN PLAN + mesure des temps d'exécution
-- OBJECTIF : Démontrer que l'architecture (index, cluster, fragmentation)
--            améliore les performances vs un Full Table Scan
-- MÉTHODE  : Chaque test est exécuté AVANT et APRÈS (drop/create index)
--            pour comparer les plans d'exécution
-- =============================================================================

SET SERVEROUTPUT ON SIZE 1000000;

-- =============================================================================
-- T01 — UC01 : Inventaire des PC actifs de Cergy
--              AVANT index : FULL TABLE SCAN
--              APRÈS index IDX_COMP_STATUS_ENTITY : INDEX RANGE SCAN
-- =============================================================================
PROMPT === T01 : Inventaire PC actifs Cergy ===

-- Plan AVEC index (état normal)
EXPLAIN PLAN FOR
  SELECT c.computer_name, c.serial, l.building, l.room
  FROM   CYT_COMPUTERS c
  LEFT JOIN CYT_LOCATIONS l ON l.location_id = c.location_id
  WHERE  c.entity_id = 1
  AND    c.status    = 'ACTIF'
  AND    c.is_deleted = 0;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT => 'BASIC +COST'));

-- Mesure du temps T01
DECLARE
  v_t0  NUMBER;
  v_t1  NUMBER;
  v_cnt NUMBER;
BEGIN
  v_t0 := DBMS_UTILITY.GET_TIME;
  SELECT COUNT(*) INTO v_cnt
  FROM   CYT_COMPUTERS c
  LEFT JOIN CYT_LOCATIONS l ON l.location_id = c.location_id
  WHERE  c.entity_id  = 1
  AND    c.status     = 'ACTIF'
  AND    c.is_deleted = 0;
  v_t1 := DBMS_UTILITY.GET_TIME;
  DBMS_OUTPUT.PUT_LINE('T01 (avec index) : ' || (v_t1 - v_t0) || ' cs — ' || v_cnt || ' lignes');
END;
/

-- Simulation SANS index (drop temporaire)
DROP INDEX IDX_COMP_STATUS_ENTITY;

DECLARE
  v_t0 NUMBER; v_t1 NUMBER; v_cnt NUMBER;
BEGIN
  v_t0 := DBMS_UTILITY.GET_TIME;
  SELECT COUNT(*) INTO v_cnt
  FROM   CYT_COMPUTERS c
  WHERE  c.entity_id = 1 AND c.status = 'ACTIF' AND c.is_deleted = 0;
  v_t1 := DBMS_UTILITY.GET_TIME;
  DBMS_OUTPUT.PUT_LINE('T01 (sans index) : ' || (v_t1 - v_t0) || ' cs — ' || v_cnt || ' lignes');
END;
/

-- Recréer l'index
CREATE INDEX IDX_COMP_STATUS_ENTITY ON CYT_COMPUTERS(entity_id, status)
  TABLESPACE TS_CERGY_IDX;


-- =============================================================================
-- T02 — UC04 : Diagnostic réseau — port switch d'un PC
--              Cluster CLU_NETWORK vs tables séparées
--              Plan attendu : TABLE ACCESS CLUSTER (0 I/O supplémentaire)
-- =============================================================================
PROMPT === T02 : Diagnostic reseau (cluster) ===

EXPLAIN PLAN FOR
  SELECT c.computer_name, np.port_name AS pc_port,
         np_sw.port_name AS switch_port, sw.netequip_name
  FROM   CYT_COMPUTERS c
  JOIN   CYT_NETWORKPORTS np   ON np.items_id  = c.computer_id
                               AND np.item_type = 'COMPUTER'
  JOIN   CYT_PORT_LINKS pl     ON pl.port_src   = np.port_id
  JOIN   CYT_NETWORKPORTS np_sw ON np_sw.port_id = pl.port_dst
  JOIN   CYT_NETEQUIP sw       ON sw.netequip_id = np_sw.items_id
  WHERE  c.computer_id = 42;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT => 'BASIC +COST'));

DECLARE
  v_t0 NUMBER; v_t1 NUMBER; v_cnt NUMBER;
BEGIN
  v_t0 := DBMS_UTILITY.GET_TIME;
  SELECT COUNT(*) INTO v_cnt
  FROM   V_NETWORK_MAPPING WHERE computer_id = 42;
  v_t1 := DBMS_UTILITY.GET_TIME;
  DBMS_OUTPUT.PUT_LINE('T02 via V_NETWORK_MAPPING : ' || (v_t1 - v_t0) || ' cs');
END;
/


-- =============================================================================
-- T03 — UC01 : Recherche par serial insensible à la casse
--              Function-Based Index IDX_COMP_SERIAL_FBI
--              Plan attendu : INDEX RANGE SCAN (FBI) vs FULL TABLE SCAN
-- =============================================================================
PROMPT === T03 : Recherche serial insensible casse (FBI) ===

EXPLAIN PLAN FOR
  SELECT computer_id, computer_name, status
  FROM   CYT_COMPUTERS
  WHERE  UPPER(serial) = UPPER('sn-cy-00042');

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT => 'BASIC +COST'));

DECLARE
  v_t0 NUMBER; v_t1 NUMBER; v_cnt NUMBER;
BEGIN
  v_t0 := DBMS_UTILITY.GET_TIME;
  SELECT COUNT(*) INTO v_cnt FROM CYT_COMPUTERS
  WHERE  UPPER(serial) = UPPER('sn-cy-00042');
  v_t1 := DBMS_UTILITY.GET_TIME;
  DBMS_OUTPUT.PUT_LINE('T03 (FBI) : ' || (v_t1 - v_t0) || ' cs');
END;
/


-- =============================================================================
-- T04 — UC08 : Audit des 30 derniers jours
--              Index IDX_AUDIT_DATE sur (log_date, entity_id)
-- =============================================================================
PROMPT === T04 : Audit 30 derniers jours ===

EXPLAIN PLAN FOR
  SELECT table_name, operation, user_db, log_date
  FROM   CYT_AUDIT_LOG
  WHERE  log_date  >= SYSDATE - 30
  AND    entity_id  = 1
  ORDER BY log_date DESC;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT => 'BASIC +COST'));

DECLARE
  v_t0 NUMBER; v_t1 NUMBER; v_cnt NUMBER;
BEGIN
  v_t0 := DBMS_UTILITY.GET_TIME;
  SELECT COUNT(*) INTO v_cnt FROM CYT_AUDIT_LOG
  WHERE log_date >= SYSDATE - 30 AND entity_id = 1;
  v_t1 := DBMS_UTILITY.GET_TIME;
  DBMS_OUTPUT.PUT_LINE('T04 (audit index) : ' || (v_t1 - v_t0) || ' cs');
END;
/


-- =============================================================================
-- T05 — UC03 : Vue globale Cergy + Pau via DBLink vs vue locale
--              Mesure de l'overhead réseau inter-sites
-- =============================================================================
PROMPT === T05 : Vue globale (DBLink overhead) ===

DECLARE
  v_t0 NUMBER; v_t1 NUMBER; v_cnt NUMBER;
BEGIN
  -- Local uniquement
  v_t0 := DBMS_UTILITY.GET_TIME;
  SELECT COUNT(*) INTO v_cnt FROM CYT_COMPUTERS WHERE is_deleted = 0;
  v_t1 := DBMS_UTILITY.GET_TIME;
  DBMS_OUTPUT.PUT_LINE('T05 local seulement  : ' || (v_t1 - v_t0) || ' cs — ' || v_cnt || ' lignes');

  -- Global via V_GLOBAL_COMPUTERS (DBLink)
  v_t0 := DBMS_UTILITY.GET_TIME;
  SELECT COUNT(*) INTO v_cnt FROM V_GLOBAL_COMPUTERS;
  v_t1 := DBMS_UTILITY.GET_TIME;
  DBMS_OUTPUT.PUT_LINE('T05 global (DBLink)  : ' || (v_t1 - v_t0) || ' cs — ' || v_cnt || ' lignes');

  -- Via MV_INVENTORY_GLOBAL (snapshot local — pas de réseau)
  v_t0 := DBMS_UTILITY.GET_TIME;
  SELECT COUNT(*) INTO v_cnt FROM MV_INVENTORY_GLOBAL;
  v_t1 := DBMS_UTILITY.GET_TIME;
  DBMS_OUTPUT.PUT_LINE('T05 MV (snapshot)    : ' || (v_t1 - v_t0) || ' cs — ' || v_cnt || ' lignes');
END;
/


-- =============================================================================
-- T06 — UC01 : Fragmentation verticale — lecture chaud vs complet
--              Démontrer que lire CYT_COMPUTERS (chaud) est plus rapide
--              que lire V_COMPUTERS_FULL (chaud + froid via JOIN)
-- =============================================================================
PROMPT === T06 : Fragmentation verticale (chaud vs complet) ===

DECLARE
  v_t0 NUMBER; v_t1 NUMBER; v_cnt NUMBER;
BEGIN
  -- Fragment chaud uniquement (inventaire courant UC01)
  v_t0 := DBMS_UTILITY.GET_TIME;
  SELECT COUNT(*) INTO v_cnt FROM CYT_COMPUTERS
  WHERE entity_id = 1 AND is_deleted = 0;
  v_t1 := DBMS_UTILITY.GET_TIME;
  DBMS_OUTPUT.PUT_LINE('T06 fragment chaud   : ' || (v_t1 - v_t0) || ' cs — ' || v_cnt || ' lignes');

  -- Vue complète (chaud + froid — consultation fiche détaillée)
  v_t0 := DBMS_UTILITY.GET_TIME;
  SELECT COUNT(*) INTO v_cnt FROM V_COMPUTERS_FULL
  WHERE entity_id = 1;
  v_t1 := DBMS_UTILITY.GET_TIME;
  DBMS_OUTPUT.PUT_LINE('T06 vue complete     : ' || (v_t1 - v_t0) || ' cs — ' || v_cnt || ' lignes');
END;
/


-- =============================================================================
-- RÉCAPITULATIF — à compléter dans le rapport avec les résultats réels
-- =============================================================================
PROMPT =============================================
PROMPT RESULTATS A REPORTER DANS LE RAPPORT :
PROMPT T01 : Index composite vs Full Scan (UC01)
PROMPT T02 : Cluster vs accès aléatoire (UC04)
PROMPT T03 : FBI vs Full Scan (UC01 casse)
PROMPT T04 : Index audit vs Full Scan (UC08)
PROMPT T05 : Local vs DBLink vs MV (UC03)
PROMPT T06 : Chaud vs Complet (fragmentation verticale)
PROMPT =============================================

-- F_COUNT_ASSETS pour vérification rapide
SELECT F_COUNT_ASSETS('CERGY')            AS total,
       F_COUNT_ASSETS('CERGY', 'ACTIF')   AS actifs,
       F_COUNT_ASSETS('CERGY', 'EN_STOCK') AS stock
FROM   DUAL;
