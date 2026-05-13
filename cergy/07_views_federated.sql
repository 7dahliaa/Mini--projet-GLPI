-- =============================================================================
-- FICHIER  : cergy/07_views_federated.sql
-- INSTANCE : cergy_db (Lead)
-- NOTION   : Vues fédérées + Vue matérialisée (BDDR)
-- PRÉREQUIS: 06_dblinks.sql exécuté et DBLinks validés
-- =============================================================================

-- =============================================================================
-- 1. V_GLOBAL_COMPUTERS — UC03 (pilotage DSI)
--    Vision unifiée de l'inventaire Cergy + Pau en temps réel via DBLink
-- =============================================================================
CREATE OR REPLACE VIEW V_GLOBAL_COMPUTERS AS
  SELECT c.computer_id, c.serial, c.computer_name,
         c.status, c.date_created, c.date_purchase,
         'CERGY' AS site
  FROM   CYT_COMPUTERS c
  WHERE  c.is_deleted = 0
UNION ALL
  SELECT p.computer_id, p.serial, p.computer_name,
         p.status, p.date_created, p.date_purchase,
         'PAU' AS site
  FROM   CYT_COMPUTERS@DBLINK_PAU p
  WHERE  p.is_deleted = 0;


-- =============================================================================
-- 2. V_GLOBAL_USERS — UC06 (itinérance)
--    Liste tous les users des deux sites — utilisée par le trigger
--    TRG_SYNC_USER_PAU pour vérifier si un user existe déjà côté Pau
-- =============================================================================
CREATE OR REPLACE VIEW V_GLOBAL_USERS AS
  SELECT u.user_id, u.login, u.realname, u.firstname,
         u.is_active, u.last_login, 'CERGY' AS site
  FROM   CYT_USERS u
  WHERE  u.is_deleted = 0
UNION ALL
  SELECT p.user_id, p.login, p.realname, p.firstname,
         p.is_active, p.last_login, 'PAU' AS site
  FROM   CYT_USERS@DBLINK_PAU p
  WHERE  p.is_deleted = 0;


-- =============================================================================
-- 3. V_GLOBAL_IPPLAN — UC01 étendu
--    Plan d'adressage IP consolidé des deux sites
--    L'auditeur vérifie qu'il n'y a pas de collision d'IP
-- =============================================================================
CREATE OR REPLACE VIEW V_GLOBAL_IPPLAN AS
  SELECT ip.ip_id, ip.ip_address, ip.ip_version,
         ip.items_id, ip.item_type,
         'CERGY' AS site
  FROM   CYT_IPADDRESSES ip
  WHERE  ip.is_deleted = 0
UNION ALL
  SELECT ip.ip_id, ip.ip_address, ip.ip_version,
         ip.items_id, ip.item_type,
         'PAU' AS site
  FROM   CYT_IPADDRESSES@DBLINK_PAU_RO ip
  WHERE  ip.is_deleted = 0;


-- =============================================================================
-- 4. V_PAU_READONLY — UC08 (audit)
--    Vue en lecture seule sur les tables clés de Pau
--    Utilisée exclusivement par ROLE_AUDITEUR via DBLINK_PAU_RO
-- =============================================================================
CREATE OR REPLACE VIEW V_PAU_READONLY AS
SELECT
  c.computer_id,
  c.computer_name,
  c.serial,
  c.status,
  c.date_created,
  a.table_name AS last_audit_table,
  a.operation  AS last_operation,
  a.log_date   AS last_audit_date
FROM   CYT_COMPUTERS@DBLINK_PAU_RO c
LEFT JOIN (
  SELECT item_id, table_name, operation, log_date,
         ROW_NUMBER() OVER (PARTITION BY item_id ORDER BY log_date DESC) AS rn
  FROM   CYT_AUDIT_LOG@DBLINK_PAU_RO
  WHERE  table_name = 'CYT_COMPUTERS'
) a ON a.item_id = c.computer_id AND a.rn = 1
WHERE  c.is_deleted = 0;


-- =============================================================================
-- 5. MV_INVENTORY_GLOBAL — Vue matérialisée (UC03)
--    Snapshot nightly — DSI interroge sans requête réseau en temps réel
-- =============================================================================
CREATE MATERIALIZED VIEW MV_INVENTORY_GLOBAL
  BUILD IMMEDIATE
  REFRESH COMPLETE
  START WITH SYSDATE
  NEXT TRUNC(SYSDATE + 1) + 2/24
AS
  SELECT c.computer_id, c.serial, c.computer_name,
         c.status, c.date_created, c.date_purchase,
         m.manufacturer_name, mo.model_name,
         'CERGY' AS site
  FROM   CYT_COMPUTERS c
  LEFT JOIN CYT_MANUFACTURERS   m  ON m.manufacturer_id = c.manufacturer_id
  LEFT JOIN CYT_COMPUTER_MODELS mo ON mo.model_id       = c.model_id
  WHERE  c.is_deleted = 0
  UNION ALL
  SELECT p.computer_id, p.serial, p.computer_name,
         p.status, p.date_created, p.date_purchase,
         NULL AS manufacturer_name, NULL AS model_name,
         'PAU' AS site
  FROM   CYT_COMPUTERS@DBLINK_PAU p
  WHERE  p.is_deleted = 0;

-- Refresh manuel si besoin
-- EXEC DBMS_MVIEW.REFRESH('MV_INVENTORY_GLOBAL', 'C');

SELECT view_name FROM user_views  WHERE view_name LIKE 'V_%' ORDER BY 1;
SELECT mview_name FROM user_mviews WHERE mview_name LIKE 'MV_%';
