-- Fichier pour créer les vues sur notre base principale (Cergy)

-- 1. Vue pour avoir l'inventaire global des PC
-- On fusionne les tables de Cergy et de Pau avec un UNION ALL.
-- J'ai rajouté une colonne 'site' en dur pour savoir facilement d'où vient chaque ligne.
CREATE OR REPLACE VIEW V_GLOBAL_COMPUTERS AS
  SELECT c.computer_id, c.serial, c.computer_name,
         c.status, c.date_created, c.date_purchase,
         'CERGY' AS site
  FROM   CYT_COMPUTERS c
  WHERE  c.is_deleted = 0
UNION ALL
  SELECT p.computer_id, p.serial, p.computer_name,
         p.status, p.date_created, p.date_purchase,
         'PAU' AS site
  FROM   CYT_COMPUTERS@DBLINK_PAU p
  WHERE  p.is_deleted = 0;


-- 2. Vue pour rassembler tous les utilisateurs
-- Ça fait une liste unique des comptes des deux sites. 
CREATE OR REPLACE VIEW V_GLOBAL_USERS AS
  SELECT u.user_id, u.login, u.realname, u.firstname,
         u.is_active, u.last_login, 'CERGY' AS site
  FROM   CYT_USERS u
  WHERE  u.is_deleted = 0
UNION ALL
  SELECT p.user_id, p.login, p.realname, p.firstname,
         p.is_active, p.last_login, 'PAU' AS site
  FROM   CYT_USERS@DBLINK_PAU p
  WHERE  p.is_deleted = 0;


-- 3. Vue pour le plan d'adressage IP
-- On met en commun toutes les IP de Cergy et Pau pour repérer rapidement s'il y a des conflits.
-- Pour Pau, je passe par le lien en lecture seule, c'est plus sécurisé.
CREATE OR REPLACE VIEW V_GLOBAL_IPPLAN AS
  SELECT ip.ip_id, ip.ip_address, ip.ip_version,
         ip.items_id, ip.item_type,
         'CERGY' AS site
  FROM   CYT_IPADDRESSES ip
  WHERE  ip.is_deleted = 0
UNION ALL
  SELECT ip.ip_id, ip.ip_address, ip.ip_version,
         ip.items_id, ip.item_type,
         'PAU' AS site
  FROM   CYT_IPADDRESSES@DBLINK_PAU_RO ip
  WHERE  ip.is_deleted = 0;


-- 4. Vue sécurisée pour l'audit
-- Cette vue sert uniquement au rôle auditeur. Ils n'ont le droit de voir que ça.
-- On fait un LEFT JOIN avec un ROW_NUMBER() pour avoir facilement la toute dernière action d'audit du PC.
CREATE OR REPLACE VIEW V_PAU_READONLY AS
SELECT
  c.computer_id,
  c.computer_name,
  c.serial,
  c.status,
  c.date_created,
  a.table_name AS last_audit_table,
  a.operation  AS last_operation,
  a.log_date   AS last_audit_date
FROM   CYT_COMPUTERS@DBLINK_PAU_RO c
LEFT JOIN (
  SELECT item_id, table_name, operation, log_date,
         ROW_NUMBER() OVER (PARTITION BY item_id ORDER BY log_date DESC) AS rn
  FROM   CYT_AUDIT_LOG@DBLINK_PAU_RO
  WHERE  table_name = 'CYT_COMPUTERS'
) a ON a.item_id = c.computer_id AND a.rn = 1
WHERE  c.is_deleted = 0;


-- 5. Vue matérialisée pour l'inventaire global
-- Contrairement aux autres vues, celle-ci stocke vraiment les données en "dur".
-- Je l'ai programmée pour qu'elle s'actualise toute seule chaque nuit à 2h du mat.
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
  FROM   CYT_COMPUTERS c
  LEFT JOIN CYT_MANUFACTURERS   m  ON m.manufacturer_id = c.manufacturer_id
  LEFT JOIN CYT_COMPUTER_MODELS mo ON mo.model_id       = c.model_id
  WHERE  c.is_deleted = 0
  UNION ALL
  -- On comble avec des NULL pour la marque et le modèle côté Pau car on ne les ramène pas dans cette requête
  SELECT p.computer_id, p.serial, p.computer_name,
         p.status, p.date_created, p.date_purchase,
         NULL AS manufacturer_name, NULL AS model_name,
         'PAU' AS site
  FROM   CYT_COMPUTERS@DBLINK_PAU p
  WHERE  p.is_deleted = 0;

-- Petite ligne pratique à garder si on veut forcer la mise à jour à la main
-- EXEC DBMS_MVIEW.REFRESH('MV_INVENTORY_GLOBAL', 'C');

-- On affiche rapidement ce qu'on vient de créer pour vérifier que tout est là
SELECT view_name FROM user_views  WHERE view_name LIKE 'V_%' ORDER BY 1;
SELECT mview_name FROM user_mviews WHERE mview_name LIKE 'MV_%';
