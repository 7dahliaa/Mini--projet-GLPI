-- =============================================================================
-- FICHIER  : cergy/04_index.sql
-- INSTANCE : cergy_db (Lead)
-- NOTION   : Index B-TREE, composites, function-based
-- NOTE     : L'index du cluster (IDX_CLU_NETWORK) est créé dans 03_schema_tables.sql
--            Les index des PK et UNIQUE sont créés avec les contraintes (03_schema)
--            Ce fichier crée UNIQUEMENT les index supplémentaires de performance
-- =============================================================================

-- -----------------------------------------------------------------------------
-- CYT_COMPUTERS
-- -----------------------------------------------------------------------------

-- UC01 : filtrer les PC par site (requête la plus fréquente de tout le projet)
CREATE INDEX IDX_COMP_ENTITY
  ON CYT_COMPUTERS(entity_id)
  TABLESPACE TS_CERGY_IDX;

-- UC01 + UC07 : filtrer par statut ET site (ex: tous les PC EN_STOCK à Cergy)
CREATE INDEX IDX_COMP_STATUS_ENTITY
  ON CYT_COMPUTERS(entity_id, status)
  TABLESPACE TS_CERGY_IDX;

-- UC01 : recherche par numéro de série insensible à la casse
-- Function-Based Index — permet WHERE UPPER(serial) = UPPER(:v)
CREATE INDEX IDX_COMP_SERIAL_FBI
  ON CYT_COMPUTERS(UPPER(serial))
  TABLESPACE TS_CERGY_IDX;

-- UC07 : retrouver rapidement les PC d'un technicien (transferts)
CREATE INDEX IDX_COMP_TECH
  ON CYT_COMPUTERS(tech_user_id)
  TABLESPACE TS_CERGY_IDX;

-- -----------------------------------------------------------------------------
-- CYT_USERS
-- -----------------------------------------------------------------------------

-- UC02 : lister les users d'un site
CREATE INDEX IDX_USER_ENTITY
  ON CYT_USERS(entity_id)
  TABLESPACE TS_CERGY_IDX;

-- UC06 : recherche itinérance — login + is_active souvent filtrés ensemble
CREATE INDEX IDX_USER_LOGIN_ACTIVE
  ON CYT_USERS(login, is_active)
  TABLESPACE TS_CERGY_IDX;

-- -----------------------------------------------------------------------------
-- CYT_NETWORKPORTS
-- -----------------------------------------------------------------------------

-- UC04 : trouver les ports d'un équipement (items_id + item_type toujours ensemble)
CREATE INDEX IDX_NETPORT_ITEMS
  ON CYT_NETWORKPORTS(items_id, item_type)
  TABLESPACE TS_CERGY_IDX;

-- UC04 : filtrer les ports par VLAN
CREATE INDEX IDX_NETPORT_NETWORK
  ON CYT_NETWORKPORTS(network_id)
  TABLESPACE TS_CERGY_IDX;

-- -----------------------------------------------------------------------------
-- CYT_IPADDRESSES
-- -----------------------------------------------------------------------------

-- UC01 : plan IP par site
CREATE INDEX IDX_IP_ENTITY
  ON CYT_IPADDRESSES(entity_id)
  TABLESPACE TS_CERGY_IDX;

-- UC04 : retrouver l'IP d'un équipement
CREATE INDEX IDX_IP_ITEMS
  ON CYT_IPADDRESSES(items_id, item_type)
  TABLESPACE TS_CERGY_IDX;

-- -----------------------------------------------------------------------------
-- CYT_AUDIT_LOG
-- -----------------------------------------------------------------------------

-- UC08 : audit des 30 derniers jours (log_date le plus filtré)
CREATE INDEX IDX_AUDIT_DATE
  ON CYT_AUDIT_LOG(log_date, entity_id)
  TABLESPACE TS_AUDIT;

-- UC08 : audit par table (ex: tous les DELETE sur CYT_COMPUTERS)
CREATE INDEX IDX_AUDIT_TABLE_OP
  ON CYT_AUDIT_LOG(table_name, operation)
  TABLESPACE TS_AUDIT;

-- -----------------------------------------------------------------------------
-- CYT_ASSET_TRANSFER
-- -----------------------------------------------------------------------------

-- UC07 : suivi chronologique des transferts
CREATE INDEX IDX_TRANSFER_DATE
  ON CYT_ASSET_TRANSFER(transfer_date)
  TABLESPACE TS_CERGY_IDX;

-- UC07 : retrouver les transferts d'un PC
CREATE INDEX IDX_TRANSFER_COMP
  ON CYT_ASSET_TRANSFER(computer_id, status)
  TABLESPACE TS_CERGY_IDX;

-- -----------------------------------------------------------------------------
-- CYT_GROUPS_USERS
-- -----------------------------------------------------------------------------

-- UC05/UC06 : trouver le groupe d'un utilisateur
CREATE INDEX IDX_GU_USER
  ON CYT_GROUPS_USERS(user_id)
  TABLESPACE TS_CERGY_IDX;

-- Vérification
SELECT index_name, table_name, index_type, uniqueness, tablespace_name
FROM   user_indexes
WHERE  table_name LIKE 'CYT_%'
ORDER BY table_name, index_name;
