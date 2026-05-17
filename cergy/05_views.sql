-- -----------------------------------------------------------------------------
-- Fichier  : cergy/05_views.sql
-- Instance : cergy_db (Lead)
-- Notion   : Vues simples + Vue matérialisée
-- Note     : Les vues fédérées (via DBLink) sont déportées dans le script 07
-- -----------------------------------------------------------------------------

-- 1. V_COMPUTERS_CERGY : Inventaire local Cergy (UC01)
-- Récupère les PC avec leur loc, modèle et utilisateur attribué.
-- Utilisé au quotidien par le rôle ROLE_TECH_CERGY.
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
  -- User info
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


-- 2. V_NETWORK_MAPPING : Diagnostic réseau (UC04)
-- Mapping complet PC ↔ Switch ↔ VLAN ↔ Site.
-- Le cluster CLU_NETWORK optimise la jointure critique entre NETWORKPORTS et PORT_LINKS.
CREATE OR REPLACE VIEW V_NETWORK_MAPPING AS
SELECT
  -- PC & Port de départ
  c.computer_id,
  c.computer_name    AS pc_name,
  c.serial           AS pc_serial,
  c.status           AS pc_status,
  np_pc.port_id      AS pc_port_id,
  np_pc.port_name    AS pc_port_name,
  np_pc.mac_address  AS pc_mac,
  
  -- Liaison physique
  pl.link_id,
  
  -- Switch & Port d'arrivée
  np_sw.port_id      AS switch_port_id,
  np_sw.port_name    AS switch_port_name,
  np_sw.logical_number AS switch_port_number,
  sw.netequip_id,
  sw.netequip_name   AS switch_name,
  sw.equip_type,
  
  -- Emplacement physique du switch, VLAN et Site
  l.building,
  l.room,
  l.floor,
  n.network_name     AS vlan_name,
  n.vlan_id,
  n.subnet,
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


-- 3. V_USERS_FULL : Vue RH globale (UC02 + UC05)
-- Inverse la fragmentation verticale en recollant le fragment chaud (USERS) et froid (DETAIL).
CREATE OR REPLACE VIEW V_USERS_FULL AS
SELECT
  u.user_id,
  u.login,
  u.realname,
  u.firstname,
  u.is_active,
  u.last_login,
  u.date_created,
  -- Données fragment froid
  ud.phone,
  ud.mobile,
  ud.registration_number,
  ud.language,
  -- Profil, entité et groupe
  p.profile_name,
  e.site_code,
  e.entity_name,
  g.group_name,
  g.group_code
FROM   CYT_USERS u
JOIN   CYT_PROFILES    p   ON p.profile_id = u.profile_id
JOIN   CYT_ENTITIES    e   ON e.entity_id  = u.entity_id
LEFT JOIN CYT_USERS_DETAIL ud ON ud.user_id = u.user_id
LEFT JOIN CYT_GROUPS_USERS gu ON gu.user_id = u.user_id
LEFT JOIN CYT_GROUPS       g  ON g.group_id = gu.group_id
WHERE  u.is_deleted = 0;


-- 4. V_AUDIT_RECENT : Logs récents (UC08)
-- Historique des modifications sur les 30 derniers jours, toutes tables confondues.
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


-- 5. V_COMPUTERS_FULL : Fiche PC complète
-- Fusionne les fragments chaud et froid de CYT_COMPUTERS. 
-- /!\ Trop lourde pour l'inventaire courant, à réserver aux consultations de fiches détaillées.
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


-- 6. MV_INVENTORY_GLOBAL : Vue matérialisée (UC03)
-- Snapshot de l'inventaire consolidé Cergy + Pau (via DBLink).
-- Refresh complet automatique toutes les nuits à 2h pour éviter de spammer le lien distant.
-- Dépend du DBLink -> Laisser commenté tant que le script 07 n'a pas tourné.
-- -----------------------------------------------------------------------------
-- CREATE MATERIALIZED VIEW MV_INVENTORY_GLOBAL
--   BUILD IMMEDIATE
--   REFRESH COMPLETE
--   START WITH SYSDATE
--   NEXT TRUNC(SYSDATE + 1) + 2/24
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

-- Check rapide des vues créées
SELECT view_name FROM user_views WHERE view_name LIKE 'V_%' ORDER BY view_name;