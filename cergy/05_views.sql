-- =============================================================================
-- FICHIER  : cergy/05_views.sql
-- INSTANCE : cergy_db (Lead)
-- NOTION   : Vues simples + Vue matérialisée
-- NOTE     : Les vues fédérées (via DBLink) sont dans 07_views_federated.sql
--            car elles dépendent du DBLink créé dans 06_dblinks.sql
-- =============================================================================

-- =============================================================================
-- 1. V_COMPUTERS_CERGY
--    Vue d'inventaire local Cergy — UC01
--    Encapsule la jointure entre CYT_COMPUTERS, CYT_LOCATIONS,
--    CYT_MANUFACTURERS, CYT_COMPUTER_MODELS, CYT_COMPUTER_TYPES
--    Utilisée par ROLE_TECH_CERGY au quotidien
-- =============================================================================
CREATE OR REPLACE VIEW V_COMPUTERS_CERGY AS
SELECT
  c.computer_id,
  c.computer_name,
  c.serial,
  c.status,
  c.date_purchase,
  c.date_created,
  -- Localisation
  l.building,
  l.room,
  l.floor,
  -- Référentiels
  m.manufacturer_name,
  mo.model_name,
  t.type_name,
  -- Utilisateur affecté
  u.login           AS user_login,
  u.realname        AS user_name
FROM   CYT_COMPUTERS c
LEFT JOIN CYT_LOCATIONS      l  ON l.location_id     = c.location_id
LEFT JOIN CYT_MANUFACTURERS  m  ON m.manufacturer_id = c.manufacturer_id
LEFT JOIN CYT_COMPUTER_MODELS mo ON mo.model_id      = c.model_id
LEFT JOIN CYT_COMPUTER_TYPES  t  ON t.type_id        = c.type_id
LEFT JOIN CYT_USERS           u  ON u.user_id         = c.user_id
WHERE  c.entity_id  = (SELECT entity_id FROM CYT_ENTITIES WHERE site_code = 'CERGY')
AND    c.is_deleted = 0;


-- =============================================================================
-- 2. V_NETWORK_MAPPING
--    Vue de diagnostic réseau — UC04
--    Répond à : "Le PC X est branché sur quel port de quel switch ?"
--    Encapsule la jointure en 6 tables.
--    Le cluster CLU_NETWORK optimise le JOIN NETWORKPORTS ↔ PORT_LINKS
-- =============================================================================
CREATE OR REPLACE VIEW V_NETWORK_MAPPING AS
SELECT
  -- PC
  c.computer_id,
  c.computer_name    AS pc_name,
  c.serial           AS pc_serial,
  c.status           AS pc_status,
  -- Port du PC
  np_pc.port_id      AS pc_port_id,
  np_pc.port_name    AS pc_port_name,
  np_pc.mac_address  AS pc_mac,
  -- Liaison physique
  pl.link_id,
  -- Port du switch
  np_sw.port_id      AS switch_port_id,
  np_sw.port_name    AS switch_port_name,
  np_sw.logical_number AS switch_port_number,
  -- Switch
  sw.netequip_id,
  sw.netequip_name   AS switch_name,
  sw.equip_type,
  -- Localisation du switch (= point de raccordement physique)
  l.building,
  l.room,
  l.floor,
  -- VLAN
  n.network_name     AS vlan_name,
  n.vlan_id,
  n.subnet,
  -- Site
  e.site_code
FROM   CYT_COMPUTERS c
  JOIN CYT_NETWORKPORTS np_pc
       ON  np_pc.items_id  = c.computer_id
       AND np_pc.item_type = 'COMPUTER'
       AND np_pc.is_deleted = 0
  JOIN CYT_PORT_LINKS pl
       ON  pl.port_src = np_pc.port_id
  JOIN CYT_NETWORKPORTS np_sw
       ON  np_sw.port_id = pl.port_dst
  JOIN CYT_NETEQUIP sw
       ON  sw.netequip_id = np_sw.items_id
       AND np_sw.item_type = 'NETEQUIP'
  LEFT JOIN CYT_LOCATIONS l
       ON  l.location_id = sw.location_id
  LEFT JOIN CYT_NETWORKS n
       ON  n.network_id = np_pc.network_id
  JOIN CYT_ENTITIES e
       ON  e.entity_id = c.entity_id
WHERE  c.is_deleted = 0;


-- =============================================================================
-- 3. V_USERS_FULL
--    Vue RH complète — UC02 + UC05
--    Reconstruit la table complète CYT_USERS + CYT_USERS_DETAIL
--    (inverse de la fragmentation verticale, pour consultation profil complet)
-- =============================================================================
CREATE OR REPLACE VIEW V_USERS_FULL AS
SELECT
  u.user_id,
  u.login,
  u.realname,
  u.firstname,
  u.is_active,
  u.last_login,
  u.date_created,
  -- Fragment froid
  ud.phone,
  ud.mobile,
  ud.registration_number,
  ud.language,
  -- Profil et site
  p.profile_name,
  e.site_code,
  e.entity_name,
  -- Groupe
  g.group_name,
  g.group_code
FROM   CYT_USERS u
JOIN   CYT_PROFILES    p   ON p.profile_id = u.profile_id
JOIN   CYT_ENTITIES    e   ON e.entity_id  = u.entity_id
LEFT JOIN CYT_USERS_DETAIL ud ON ud.user_id = u.user_id
LEFT JOIN CYT_GROUPS_USERS gu ON gu.user_id = u.user_id
LEFT JOIN CYT_GROUPS       g  ON g.group_id = gu.group_id
WHERE  u.is_deleted = 0;


-- =============================================================================
-- 4. V_AUDIT_RECENT
--    Vue auditeur — UC08
--    Derniers 30 jours d'activité sur toutes les tables
-- =============================================================================
CREATE OR REPLACE VIEW V_AUDIT_RECENT AS
SELECT
  log_id,
  table_name,
  item_id,
  entity_id,
  operation,
  user_db,
  old_value,
  new_value,
  log_date
FROM   CYT_AUDIT_LOG
WHERE  log_date >= SYSDATE - 30
ORDER BY log_date DESC;


-- =============================================================================
-- 5. V_COMPUTERS_FULL
--    Reconstruit CYT_COMPUTERS complet (fragment chaud + froid)
--    Utilisée uniquement lors de la consultation détaillée d'un PC
--    (n'est PAS utilisée dans les requêtes d'inventaire courantes — trop large)
-- =============================================================================
CREATE OR REPLACE VIEW V_COMPUTERS_FULL AS
SELECT
  c.*,
  cd.uuid,
  cd.otherserial,
  cd.ticket_tco,
  cd.last_inventory_update,
  cd.last_boot,
  cd.remarks
FROM   CYT_COMPUTERS c
LEFT JOIN CYT_COMPUTERS_DETAIL cd ON cd.computer_id = c.computer_id
WHERE  c.is_deleted = 0;


-- =============================================================================
-- 6. MV_INVENTORY_GLOBAL — Vue matérialisée
--    Snapshot de l'inventaire global consolidé (Cergy + Pau via DBLink)
--    Refresh complet chaque nuit → le DSI interroge localement sans
--    déclencher une requête distante à chaque fois (UC03)
--    DÉPEND du DBLink → créé dans 07_views_federated.sql
--    (commenté ici pour référence, décommenté après création du DBLink)
-- =============================================================================
-- CREATE MATERIALIZED VIEW MV_INVENTORY_GLOBAL
--   BUILD IMMEDIATE
--   REFRESH COMPLETE
--   START WITH SYSDATE
--   NEXT TRUNC(SYSDATE + 1) + 2/24   -- refresh chaque nuit à 2h
-- AS
--   SELECT c.computer_id, c.serial, c.computer_name,
--          c.status, c.date_created, 'CERGY' AS site
--   FROM   CYT_COMPUTERS c
--   WHERE  c.is_deleted = 0
--   UNION ALL
--   SELECT p.computer_id, p.serial, p.computer_name,
--          p.status, p.date_created, 'PAU' AS site
--   FROM   CYT_COMPUTERS@DBLINK_PAU p
--   WHERE  p.is_deleted = 0;

-- Vérification
SELECT view_name FROM user_views WHERE view_name LIKE 'V_%' ORDER BY view_name;
