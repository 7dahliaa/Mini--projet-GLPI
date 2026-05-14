-- =============================================================================
-- FICHIER  : cergy/03_schema_tables.sql
-- INSTANCE : cergy_db (Lead)
-- NOTION   : DDL — Tables, Contraintes, Cluster, Fragmentation verticale
--
-- TABLES (17 sources GLPI + 1 nouvelle) :
--   glpi_entities              → CYT_ENTITIES        (+ colonnes Lead exclusives)
--   glpi_locations             → CYT_LOCATIONS
--   glpi_manufacturers         → CYT_MANUFACTURERS
--   glpi_computertypes         → CYT_COMPUTER_TYPES
--   glpi_computermodels        → CYT_COMPUTER_MODELS
--   glpi_profiles              → CYT_PROFILES
--   glpi_networks              → CYT_NETWORKS        (enrichie : vlan_id, subnet, gateway)
--   glpi_groups                → CYT_GROUPS
--   glpi_groups_users          → CYT_GROUPS_USERS
--   glpi_networkports          → CYT_NETWORKPORTS    (dans CLU_NETWORK)
--   glpi_networkports_ntwk     → CYT_PORT_LINKS      (dans CLU_NETWORK)
--   glpi_users                 → CYT_USERS           (fragment chaud)
--   glpi_users (suite)         → CYT_USERS_DETAIL    (fragment froid → TS_CERGY_COLD)
--   glpi_profiles_users        → CYT_USERS_PROFILES
--   glpi_computers             → CYT_COMPUTERS       (fragment chaud)
--   glpi_computers (suite)     → CYT_COMPUTERS_DETAIL(fragment froid → TS_CERGY_COLD)
--   glpi_networkequipments     → CYT_NETEQUIP
--   glpi_ipaddresses           → CYT_IPADDRESSES
--   glpi_infocoms              → CYT_INFOCOMS
--   glpi_logs                  → CYT_AUDIT_LOG       (enrichie)
--   NOUVELLE                   → CYT_ASSET_TRANSFER  (UC07 — absente de GLPI)
--
-- FRAGMENTATION VERTICALE (par fréquence d'accès) :
--   CYT_USERS     (chaud) + CYT_USERS_DETAIL     (froid)
--   CYT_COMPUTERS (chaud) + CYT_COMPUTERS_DETAIL (froid)
--
-- FRAGMENTATION VERTICALE INTER-SITES (colonnes Lead uniquement) :
--   CYT_ENTITIES contient des colonnes absentes de pau/03_schema_tables.sql :
--     dblink_connection, is_lead, pau_last_sync
--   → Pau n'en a pas besoin pour fonctionner seul (UC09)
--
-- CLUSTER CLU_NETWORK :
--   CYT_NETWORKPORTS + CYT_PORT_LINKS regroupés physiquement par port_id
--   → Optimise le JOIN systématique UC04 (diagnostic réseau)
-- =============================================================================

-- Nettoyage complet (ordre inverse des FK)
WHENEVER SQLERROR CONTINUE;
DROP TABLE CYT_AUDIT_LOG         CASCADE CONSTRAINTS PURGE;
DROP TABLE CYT_ASSET_TRANSFER    CASCADE CONSTRAINTS PURGE;
DROP TABLE CYT_INFOCOMS          CASCADE CONSTRAINTS PURGE;
DROP TABLE CYT_IPADDRESSES       CASCADE CONSTRAINTS PURGE;
DROP TABLE CYT_COMPUTERS_DETAIL  CASCADE CONSTRAINTS PURGE;
DROP TABLE CYT_COMPUTERS         CASCADE CONSTRAINTS PURGE;
DROP TABLE CYT_NETEQUIP          CASCADE CONSTRAINTS PURGE;
DROP TABLE CYT_PORT_LINKS        CASCADE CONSTRAINTS PURGE;
DROP TABLE CYT_NETWORKPORTS      CASCADE CONSTRAINTS PURGE;
DROP TABLE CYT_USERS_PROFILES    CASCADE CONSTRAINTS PURGE;
DROP TABLE CYT_GROUPS_USERS      CASCADE CONSTRAINTS PURGE;
DROP TABLE CYT_GROUPS            CASCADE CONSTRAINTS PURGE;
DROP TABLE CYT_USERS_DETAIL      CASCADE CONSTRAINTS PURGE;
DROP TABLE CYT_USERS             CASCADE CONSTRAINTS PURGE;
DROP TABLE CYT_PROFILES          CASCADE CONSTRAINTS PURGE;
DROP TABLE CYT_NETWORKS          CASCADE CONSTRAINTS PURGE;
DROP TABLE CYT_COMPUTER_MODELS   CASCADE CONSTRAINTS PURGE;
DROP TABLE CYT_COMPUTER_TYPES    CASCADE CONSTRAINTS PURGE;
DROP TABLE CYT_MANUFACTURERS     CASCADE CONSTRAINTS PURGE;
DROP TABLE CYT_LOCATIONS         CASCADE CONSTRAINTS PURGE;
DROP TABLE CYT_ENTITIES          CASCADE CONSTRAINTS PURGE;
DROP CLUSTER CLU_NETWORK INCLUDING TABLES CASCADE CONSTRAINTS;
DROP SEQUENCE SEQ_NETWORKPORT_ID;

-- =============================================================================
-- 1. CYT_ENTITIES
--    Source : glpi_entities (simplifié — on retire les 40+ colonnes de config
--    applicative GLPI : alert_*, calendar, mailing_signature...)
--
--    FRAGMENTATION VERTICALE INTER-SITES :
--    Colonnes présentes UNIQUEMENT sur Cergy (Lead) :
--      dblink_connection → chaîne TNS pour joindre l'autre site
--      is_lead           → booléen qui identifie l'instance Lead
--      pau_last_sync     → timestamp dernière sync réussie avec Pau
--    Justification : Pau n'orchestre aucun DBLink, n'a pas besoin de ces colonnes.
--    Si Pau les avait, elles seraient toujours NULL → gaspillage + confusion.
-- =============================================================================
WHENEVER SQLERROR EXIT SQL.SQLCODE;
CREATE TABLE CYT_ENTITIES (
  entity_id          NUMBER         GENERATED ALWAYS AS IDENTITY,
  entity_name        VARCHAR2(100)  NOT NULL,
  site_code          VARCHAR2(10)   NOT NULL,
  address            VARCHAR2(255),
  town               VARCHAR2(100),
  postcode           VARCHAR2(10),
  country            VARCHAR2(50)   DEFAULT 'France',
  phonenumber        VARCHAR2(30),
  email              VARCHAR2(100),
  -- Colonnes exclusives au Lead (fragmentation verticale inter-sites)
  dblink_connection  VARCHAR2(500),   -- ex: '(DESCRIPTION=(ADDRESS=...))'
  is_lead            NUMBER(1)        DEFAULT 0 CHECK (is_lead IN (0,1)),
  pau_last_sync      DATE,
  date_created       DATE            DEFAULT SYSDATE NOT NULL,
  CONSTRAINT PK_CYT_ENTITIES   PRIMARY KEY (entity_id)
    USING INDEX TABLESPACE TS_CERGY_IDX,
  CONSTRAINT UQ_ENTITY_SITE     UNIQUE (site_code)
    USING INDEX TABLESPACE TS_CERGY_IDX,
  CONSTRAINT CHK_ENTITY_SITE    CHECK (site_code IN ('CERGY','PAU'))
) TABLESPACE TS_CERGY_DATA;

INSERT INTO CYT_ENTITIES (entity_name, site_code, address, town, postcode,
                           dblink_connection, is_lead)
VALUES ('CY Tech Cergy', 'CERGY', '2 avenue Adolphe Chauvin', 'Pontoise', '95302',
        '(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=pau_db)(PORT=1521))(CONNECT_DATA=(SID=XE)))',
        1);

INSERT INTO CYT_ENTITIES (entity_name, site_code, address, town, postcode,
                           is_lead)
VALUES ('CY Tech Pau', 'PAU', '1 allée du Parc Montaury', 'Anglet', '64600', 0);
COMMIT;


-- =============================================================================
-- 2. CYT_LOCATIONS
--    Source : glpi_locations
--    Retiré : ancestors_cache, sons_cache, completename (gestion interne GLPI)
-- =============================================================================
CREATE TABLE CYT_LOCATIONS (
  location_id    NUMBER        GENERATED ALWAYS AS IDENTITY,
  entity_id      NUMBER        NOT NULL,
  location_name  VARCHAR2(100) NOT NULL,
  building       VARCHAR2(100),
  room           VARCHAR2(50),
  floor          NUMBER(2),
  latitude       VARCHAR2(30),
  longitude      VARCHAR2(30),
  date_created   DATE          DEFAULT SYSDATE NOT NULL,
  CONSTRAINT PK_CYT_LOCATIONS  PRIMARY KEY (location_id)
    USING INDEX TABLESPACE TS_CERGY_IDX,
  CONSTRAINT UQ_LOCATION        UNIQUE (entity_id, building, room)
    USING INDEX TABLESPACE TS_CERGY_IDX
) TABLESPACE TS_CERGY_DATA;

INSERT INTO CYT_LOCATIONS (entity_id, location_name, building, room, floor)
VALUES (1, 'Salle Info A012', 'Bâtiment A', 'Salle 012', 0);
INSERT INTO CYT_LOCATIONS (entity_id, location_name, building, room, floor)
VALUES (1, 'Salle Info B201', 'Bâtiment B', 'Salle 201', 2);
INSERT INTO CYT_LOCATIONS (entity_id, location_name, building, room, floor)
VALUES (1, 'Salle Serveurs', 'Bâtiment A', 'Salle S01', -1);
COMMIT;


-- =============================================================================
-- 3. CYT_MANUFACTURERS
--    Source : glpi_manufacturers (table quasi identique, renommée + tablespace)
-- =============================================================================
CREATE TABLE CYT_MANUFACTURERS (
  manufacturer_id   NUMBER        GENERATED ALWAYS AS IDENTITY,
  manufacturer_name VARCHAR2(100) NOT NULL,
  date_created      DATE          DEFAULT SYSDATE,
  CONSTRAINT PK_CYT_MANUFACTURERS PRIMARY KEY (manufacturer_id)
    USING INDEX TABLESPACE TS_CERGY_IDX,
  CONSTRAINT UQ_MANUFACTURER     UNIQUE (manufacturer_name)
    USING INDEX TABLESPACE TS_CERGY_IDX
) TABLESPACE TS_CERGY_DATA;

INSERT INTO CYT_MANUFACTURERS (manufacturer_name) VALUES ('Dell');
INSERT INTO CYT_MANUFACTURERS (manufacturer_name) VALUES ('HP');
INSERT INTO CYT_MANUFACTURERS (manufacturer_name) VALUES ('Lenovo');
INSERT INTO CYT_MANUFACTURERS (manufacturer_name) VALUES ('Apple');
INSERT INTO CYT_MANUFACTURERS (manufacturer_name) VALUES ('Cisco');
INSERT INTO CYT_MANUFACTURERS (manufacturer_name) VALUES ('TP-Link');
COMMIT;


-- =============================================================================
-- 4. CYT_COMPUTER_TYPES
--    Source : glpi_computertypes
-- =============================================================================
CREATE TABLE CYT_COMPUTER_TYPES (
  type_id   NUMBER       GENERATED ALWAYS AS IDENTITY,
  type_name VARCHAR2(50) NOT NULL,
  CONSTRAINT PK_CYT_COMP_TYPES PRIMARY KEY (type_id)
    USING INDEX TABLESPACE TS_CERGY_IDX,
  CONSTRAINT UQ_COMP_TYPE       UNIQUE (type_name)
    USING INDEX TABLESPACE TS_CERGY_IDX
) TABLESPACE TS_CERGY_DATA;

INSERT INTO CYT_COMPUTER_TYPES (type_name) VALUES ('Desktop');
INSERT INTO CYT_COMPUTER_TYPES (type_name) VALUES ('Laptop');
INSERT INTO CYT_COMPUTER_TYPES (type_name) VALUES ('Serveur');
INSERT INTO CYT_COMPUTER_TYPES (type_name) VALUES ('Workstation');
COMMIT;


-- =============================================================================
-- 5. CYT_COMPUTER_MODELS
--    Source : glpi_computermodels
--    Retiré : picture_front, picture_rear, required_units, depth,
--             power_connections (colonnes rack sans rapport avec nos PC)
-- =============================================================================
CREATE TABLE CYT_COMPUTER_MODELS (
  model_id       NUMBER        GENERATED ALWAYS AS IDENTITY,
  model_name     VARCHAR2(100) NOT NULL,
  product_number VARCHAR2(100),
  date_created   DATE          DEFAULT SYSDATE,
  CONSTRAINT PK_CYT_COMP_MODELS PRIMARY KEY (model_id)
    USING INDEX TABLESPACE TS_CERGY_IDX,
  CONSTRAINT UQ_COMP_MODEL      UNIQUE (model_name)
    USING INDEX TABLESPACE TS_CERGY_IDX
) TABLESPACE TS_CERGY_DATA;

INSERT INTO CYT_COMPUTER_MODELS (model_name, product_number)
VALUES ('Dell OptiPlex 7090',  'OPX7090');
INSERT INTO CYT_COMPUTER_MODELS (model_name, product_number)
VALUES ('HP EliteBook 840 G9', 'ELB840G9');
INSERT INTO CYT_COMPUTER_MODELS (model_name, product_number)
VALUES ('Lenovo ThinkPad X1',  'TPX1C10');
INSERT INTO CYT_COMPUTER_MODELS (model_name, product_number)
VALUES ('Dell Latitude 5520',  'LAT5520');
COMMIT;


-- =============================================================================
-- 6. CYT_PROFILES
--    Source : glpi_profiles
--    Retiré : colonnes helpdesk/ticket hors périmètre projet
-- =============================================================================
CREATE TABLE CYT_PROFILES (
  profile_id    NUMBER        GENERATED ALWAYS AS IDENTITY,
  profile_name  VARCHAR2(100) NOT NULL,
  interface     VARCHAR2(20)  DEFAULT 'central'
                CHECK (interface IN ('central','helpdesk')),
  is_default    NUMBER(1)     DEFAULT 0 CHECK (is_default IN (0,1)),
  date_created  DATE          DEFAULT SYSDATE,
  date_mod      DATE,
  CONSTRAINT PK_CYT_PROFILES PRIMARY KEY (profile_id)
    USING INDEX TABLESPACE TS_CERGY_IDX,
  CONSTRAINT UQ_PROFILE_NAME  UNIQUE (profile_name)
    USING INDEX TABLESPACE TS_CERGY_IDX
) TABLESPACE TS_CERGY_DATA;

INSERT INTO CYT_PROFILES (profile_name, interface, is_default)
VALUES ('Super-Admin', 'central', 0);
INSERT INTO CYT_PROFILES (profile_name, interface, is_default)
VALUES ('Technicien', 'central', 1);
INSERT INTO CYT_PROFILES (profile_name, interface, is_default)
VALUES ('RH', 'helpdesk', 0);
INSERT INTO CYT_PROFILES (profile_name, interface, is_default)
VALUES ('Auditeur', 'central', 0);
COMMIT;


-- =============================================================================
-- 7. CYT_NETWORKS
--    Source : glpi_networks (très basique dans GLPI : juste name + comment)
--    Enrichi : vlan_id, subnet, gateway, ip_version
--    Justification UC04 : le diagnostic réseau nécessite de savoir
--    à quel VLAN/sous-réseau appartient un port — données absentes dans GLPI
-- =============================================================================
CREATE TABLE CYT_NETWORKS (
  network_id    NUMBER        GENERATED ALWAYS AS IDENTITY,
  entity_id     NUMBER        NOT NULL,
  network_name  VARCHAR2(100) NOT NULL,
  vlan_id       NUMBER(4),
  subnet        VARCHAR2(50),
  gateway       VARCHAR2(50),
  ip_version    NUMBER(1)     DEFAULT 4 CHECK (ip_version IN (4,6)),
  remarks       VARCHAR2(500),
  date_created  DATE          DEFAULT SYSDATE NOT NULL,
  date_mod      DATE,
  CONSTRAINT PK_CYT_NETWORKS  PRIMARY KEY (network_id)
    USING INDEX TABLESPACE TS_CERGY_IDX,
  CONSTRAINT UQ_NETWORK_VLAN   UNIQUE (entity_id, vlan_id)
    USING INDEX TABLESPACE TS_CERGY_IDX,
  CONSTRAINT CHK_VLAN_RANGE    CHECK (vlan_id BETWEEN 1 AND 4094)
) TABLESPACE TS_CERGY_DATA;

INSERT INTO CYT_NETWORKS (entity_id, network_name, vlan_id, subnet, gateway)
VALUES (1, 'VLAN_ADMIN_CERGY',     10, '192.168.10.0/24', '192.168.10.1');
INSERT INTO CYT_NETWORKS (entity_id, network_name, vlan_id, subnet, gateway)
VALUES (1, 'VLAN_ETUDIANTS_CERGY', 20, '192.168.20.0/24', '192.168.20.1');
INSERT INTO CYT_NETWORKS (entity_id, network_name, vlan_id, subnet, gateway)
VALUES (1, 'VLAN_INFRA_CERGY',     30, '10.0.30.0/24',    '10.0.30.1');
COMMIT;


-- =============================================================================
-- 8. CYT_GROUPS
--    Source : glpi_groups
--    Retiré : ldap_field, ldap_value, ldap_group_dn, ancestors_cache,
--             sons_cache, completename (gestion interne GLPI/LDAP)
--    UC05 : droits par groupe — UC06 : is_recursive pour l'itinérance cross-site
-- =============================================================================
CREATE TABLE CYT_GROUPS (
  group_id      NUMBER        GENERATED ALWAYS AS IDENTITY,
  entity_id     NUMBER        NOT NULL,
  group_name    VARCHAR2(100) NOT NULL,
  group_code    VARCHAR2(50),
  is_recursive  NUMBER(1)     DEFAULT 0 CHECK (is_recursive IN (0,1)),
  is_usergroup  NUMBER(1)     DEFAULT 1 CHECK (is_usergroup IN (0,1)),
  remarks       VARCHAR2(500),
  date_created  DATE          DEFAULT SYSDATE NOT NULL,
  date_mod      DATE,
  CONSTRAINT PK_CYT_GROUPS   PRIMARY KEY (group_id)
    USING INDEX TABLESPACE TS_CERGY_IDX,
  CONSTRAINT UQ_GROUP_CODE    UNIQUE (entity_id, group_code)
    USING INDEX TABLESPACE TS_CERGY_IDX
) TABLESPACE TS_CERGY_DATA;

-- is_recursive=1 → le groupe couvre Cergy ET Pau (itinérance UC06)
INSERT INTO CYT_GROUPS (entity_id, group_name, group_code, is_recursive)
VALUES (1, 'Direction SI',      'DSI',        1);
INSERT INTO CYT_GROUPS (entity_id, group_name, group_code, is_recursive)
VALUES (1, 'Techniciens Cergy', 'TECH_CERGY', 0);
INSERT INTO CYT_GROUPS (entity_id, group_name, group_code, is_recursive)
VALUES (1, 'Service RH',        'RH',         1);
INSERT INTO CYT_GROUPS (entity_id, group_name, group_code, is_recursive)
VALUES (1, 'Auditeurs',         'AUDIT',      1);
COMMIT;


-- =============================================================================
-- 9. CYT_GROUPS_USERS
--    Source : glpi_groups_users
-- =============================================================================
CREATE TABLE CYT_GROUPS_USERS (
  gu_id        NUMBER    GENERATED ALWAYS AS IDENTITY,
  user_id      NUMBER    NOT NULL,
  group_id     NUMBER    NOT NULL,
  is_manager   NUMBER(1) DEFAULT 0 CHECK (is_manager IN (0,1)),
  is_dynamic   NUMBER(1) DEFAULT 0 CHECK (is_dynamic IN (0,1)),
  date_created DATE      DEFAULT SYSDATE NOT NULL,
  CONSTRAINT PK_CYT_GROUPS_USERS PRIMARY KEY (gu_id)
    USING INDEX TABLESPACE TS_CERGY_IDX,
  CONSTRAINT UQ_GU_UNICITY        UNIQUE (user_id, group_id)
    USING INDEX TABLESPACE TS_CERGY_IDX
) TABLESPACE TS_CERGY_DATA;


-- =============================================================================
-- 10. CLUSTER CLU_NETWORK
--     Regroupe CYT_NETWORKPORTS et CYT_PORT_LINKS dans les mêmes blocs disque
--     par la clé port_id.
--     Justification UC04 : ces deux tables sont TOUJOURS jointes ensemble
--     dans V_NETWORK_MAPPING → co-localisation = 1 seul accès disque
--     au lieu de 2 accès séparés.
--     SIZE 1024 : ~200 octets (NETWORKPORTS) + ~50 octets (PORT_LINKS) + marge
-- =============================================================================
CREATE CLUSTER CLU_NETWORK (port_id NUMBER)
  SIZE 1024
  TABLESPACE TS_CERGY_DATA
  STORAGE (INITIAL 10M NEXT 5M);

-- Index obligatoire sur le cluster avant de créer les tables
-- Pointe vers des blocs (pas des lignes) → très compact
CREATE INDEX IDX_CLU_NETWORK ON CLUSTER CLU_NETWORK
  TABLESPACE TS_CERGY_IDX;

-- Séquence pour port_id (IDENTITY impossible dans un cluster Oracle)
CREATE SEQUENCE SEQ_NETWORKPORT_ID START WITH 1 INCREMENT BY 1 NOCACHE;


-- =============================================================================
-- 11. CYT_NETWORKPORTS  (dans le cluster)
--     Source : glpi_networkports
--     FRAGMENTATION VERTICALE :
--       Chaud (cette table) : port_id, items_id, item_type, entity_id,
--                             mac_address, port_status, network_id
--                             → tout ce qui est lu dans UC04, V_NETWORK_MAPPING
--       Froid (absent ici) : statistiques SNMP (ifspeed, ifinbytes,
--                            ifoutbytes, ifinerrors) → non implémentées
--                            car hors périmètre demandé
--     Ajout : network_id → lien direct vers le VLAN (absent dans GLPI)
-- =============================================================================
CREATE TABLE CYT_NETWORKPORTS (
  port_id        NUMBER         NOT NULL,  -- clé cluster (via SEQ_NETWORKPORT_ID)
  items_id       NUMBER         NOT NULL,  -- ID équipement (computer ou netequip)
  item_type      VARCHAR2(20)   NOT NULL
                 CHECK (item_type IN ('COMPUTER','NETEQUIP')),
  entity_id      NUMBER         NOT NULL,
  logical_number NUMBER         DEFAULT 0 NOT NULL,
  port_name      VARCHAR2(100),            -- ex: 'eth0', 'GigabitEthernet0/5'
  mac_address    VARCHAR2(20),
  network_id     NUMBER,                   -- VLAN associé (enrichissement)
  port_status    VARCHAR2(20)   DEFAULT 'ACTIVE'
                 CHECK (port_status IN ('ACTIVE','INACTIVE','UNKNOWN')),
  is_deleted     NUMBER(1)      DEFAULT 0 CHECK (is_deleted IN (0,1)),
  date_created   DATE           DEFAULT SYSDATE NOT NULL,
  date_mod       DATE,
  CONSTRAINT PK_CYT_NETWORKPORTS PRIMARY KEY (port_id)
    USING INDEX TABLESPACE TS_CERGY_IDX,
  CONSTRAINT UQ_NETPORT_MAC       UNIQUE (mac_address)
    USING INDEX TABLESPACE TS_CERGY_IDX
) CLUSTER CLU_NETWORK(port_id);


-- =============================================================================
-- 12. CYT_PORT_LINKS  (dans le cluster)
--     Source : glpi_networkports_networkports
--     Liaison port ↔ port : ex. eth0 du PC-12 → GigabitEthernet0/5 du Switch
--     STOCKÉE dans le même cluster via port_src → co-localisée avec
--     la ligne CYT_NETWORKPORTS correspondante dans le même bloc disque
-- =============================================================================
CREATE TABLE CYT_PORT_LINKS (
  link_id      NUMBER GENERATED ALWAYS AS IDENTITY,
  port_src     NUMBER NOT NULL,  -- port côté source (clé cluster)
  port_dst     NUMBER NOT NULL,  -- port côté destination (switch)
  date_created DATE   DEFAULT SYSDATE,
  CONSTRAINT PK_CYT_PORT_LINKS PRIMARY KEY (link_id)
    USING INDEX TABLESPACE TS_CERGY_IDX,
  CONSTRAINT UQ_PORT_LINK       UNIQUE (port_src, port_dst)
    USING INDEX TABLESPACE TS_CERGY_IDX
) CLUSTER CLU_NETWORK(port_src);


-- =============================================================================
-- 13. CYT_USERS — Fragment "chaud"
--     Source : glpi_users (68 colonnes dans GLPI !)
--
--     FRAGMENTATION VERTICALE par fréquence d'accès :
--     CHAUD (cette table, TS_CERGY_DATA) :
--       Colonnes lues dans 90% des requêtes : auth, itinérance, inventaire
--       → UC01, UC02, UC06 font des SELECT sur ces colonnes à chaque opération
--     FROID (CYT_USERS_DETAIL, TS_CERGY_COLD) :
--       Colonnes lues uniquement lors de la consultation du profil détaillé :
--       phone, mobile, tokens, préférences UI
--
--     RENOMMAGES depuis GLPI :
--       `name`     → `login`        (name est mot-clé Oracle)
--       `password` → `password_hash`(plus explicite)
--
--     RETIRÉS de GLPI (hors périmètre) :
--       list_limit, date_format, number_format, csv_delimiter,
--       is_ids_visible, priority_1..6, followup_private,
--       cookie_token, password_forget_token, user_dn, user_dn_hash
-- =============================================================================
CREATE TABLE CYT_USERS (
  user_id       NUMBER        GENERATED ALWAYS AS IDENTITY,
  login         VARCHAR2(100) NOT NULL,
  password_hash VARCHAR2(255) NOT NULL,
  realname      VARCHAR2(100),
  firstname     VARCHAR2(100),
  entity_id     NUMBER        NOT NULL,  -- site de rattachement principal
  profile_id    NUMBER        NOT NULL,
  is_active     NUMBER(1)     DEFAULT 1 CHECK (is_active IN (0,1)),
  is_deleted    NUMBER(1)     DEFAULT 0 CHECK (is_deleted IN (0,1)),
  last_login    DATE,
  date_created  DATE          DEFAULT SYSDATE NOT NULL,
  date_mod      DATE,
  CONSTRAINT PK_CYT_USERS   PRIMARY KEY (user_id)
    USING INDEX TABLESPACE TS_CERGY_IDX,
  CONSTRAINT UQ_USER_LOGIN   UNIQUE (login)
    USING INDEX TABLESPACE TS_CERGY_IDX
) TABLESPACE TS_CERGY_DATA;


-- =============================================================================
-- 13b. CYT_USERS_DETAIL — Fragment "froid"
--      Source : colonnes de glpi_users rarement lues
--      Stocké dans TS_CERGY_COLD → les blocs de TS_CERGY_DATA
--      contiennent plus de lignes utiles = moins d'I/O pour UC01/UC06
--      Relation 1:1 avec CYT_USERS via FK + ON DELETE CASCADE
-- =============================================================================
CREATE TABLE CYT_USERS_DETAIL (
  user_id              NUMBER        NOT NULL,
  phone                VARCHAR2(30),
  phone2               VARCHAR2(30),
  mobile               VARCHAR2(30),
  registration_number  VARCHAR2(50),  -- numéro étudiant/employé (ajouté — absent GLPI)
  language             CHAR(10)      DEFAULT 'fr_FR',
  remarks              CLOB,
  personal_token       VARCHAR2(255),
  api_token            VARCHAR2(255),
  password_last_update DATE,
  CONSTRAINT PK_CYT_USERS_DETAIL PRIMARY KEY (user_id)
    USING INDEX TABLESPACE TS_CERGY_IDX
) TABLESPACE TS_CERGY_COLD;


-- =============================================================================
-- 14. CYT_USERS_PROFILES
--     Source : glpi_profiles_users
--     Un user peut avoir des droits différents selon le site (entity_id)
-- =============================================================================
CREATE TABLE CYT_USERS_PROFILES (
  up_id              NUMBER    GENERATED ALWAYS AS IDENTITY,
  user_id            NUMBER    NOT NULL,
  profile_id         NUMBER    NOT NULL,
  entity_id          NUMBER    NOT NULL,
  is_default_profile NUMBER(1) DEFAULT 0 CHECK (is_default_profile IN (0,1)),
  is_dynamic         NUMBER(1) DEFAULT 0 CHECK (is_dynamic IN (0,1)),
  CONSTRAINT PK_CYT_USERS_PROFILES PRIMARY KEY (up_id)
    USING INDEX TABLESPACE TS_CERGY_IDX,
  CONSTRAINT UQ_UP_UNICITY          UNIQUE (user_id, profile_id, entity_id)
    USING INDEX TABLESPACE TS_CERGY_IDX
) TABLESPACE TS_CERGY_DATA;


-- =============================================================================
-- 15. CYT_COMPUTERS — Fragment "chaud"
--     Source : glpi_computers
--
--     FRAGMENTATION VERTICALE par fréquence d'accès :
--     CHAUD (cette table, TS_CERGY_DATA) :
--       serial, computer_name, entity_id, location_id, status, type, model
--       → tout ce qui est lu dans UC01 (inventaire), UC07 (transfert),
--         V_NETWORK_MAPPING (diagnostic)
--     FROID (CYT_COMPUTERS_DETAIL, TS_CERGY_COLD) :
--       uuid, otherserial, ticket_tco, last_boot, last_inventory_update
--       → consultés uniquement lors de l'ouverture d'une fiche détaillée
--
--     RENOMMAGES : `name` → `computer_name` (clarté + évite mot-clé Oracle)
--     RETIRÉS : networks_id (géré via CYT_NETWORKPORTS), autoupdate_system
--               (applicatif GLPI)
-- =============================================================================
CREATE TABLE CYT_COMPUTERS (
  computer_id     NUMBER        GENERATED ALWAYS AS IDENTITY,
  serial          VARCHAR2(100) NOT NULL,
  computer_name   VARCHAR2(100) NOT NULL,
  entity_id       NUMBER        NOT NULL,
  location_id     NUMBER,
  type_id         NUMBER,
  model_id        NUMBER,
  manufacturer_id NUMBER,
  user_id         NUMBER,        -- utilisateur affecté
  tech_user_id    NUMBER,        -- technicien responsable
  status          VARCHAR2(20)  DEFAULT 'ACTIF'
                  CHECK (status IN ('ACTIF','HORS_SERVICE','EN_STOCK',
                                    'EN_REPARATION','TRANSFERT','RETIRE')),
  is_deleted      NUMBER(1)     DEFAULT 0 CHECK (is_deleted IN (0,1)),
  date_purchase   DATE,
  date_created    DATE          DEFAULT SYSDATE NOT NULL,
  date_mod        DATE,
  CONSTRAINT PK_CYT_COMPUTERS     PRIMARY KEY (computer_id)
    USING INDEX TABLESPACE TS_CERGY_IDX,
  CONSTRAINT UQ_COMP_SERIAL        UNIQUE (serial)
    USING INDEX TABLESPACE TS_CERGY_IDX
) TABLESPACE TS_CERGY_DATA;


-- =============================================================================
-- 15b. CYT_COMPUTERS_DETAIL — Fragment "froid"
--      Source : colonnes de glpi_computers non critiques pour les requêtes
--      courantes. Lues uniquement lors de la consultation détaillée d'un PC.
--      ON DELETE CASCADE → suppression du détail si le PC est supprimé
-- =============================================================================
CREATE TABLE CYT_COMPUTERS_DETAIL (
  computer_id           NUMBER        NOT NULL,
  uuid                  VARCHAR2(255),
  otherserial           VARCHAR2(100), -- numéro d'inventaire interne
  ticket_tco            NUMBER(20,4)  DEFAULT 0,
  last_inventory_update DATE,
  last_boot             DATE,
  is_dynamic            NUMBER(1)     DEFAULT 0,
  remarks               CLOB,
  CONSTRAINT PK_CYT_COMP_DETAIL PRIMARY KEY (computer_id)
    USING INDEX TABLESPACE TS_CERGY_IDX
) TABLESPACE TS_CERGY_COLD;


-- =============================================================================
-- 16. CYT_NETEQUIP
--     Source : glpi_networkequipments
--     Switchs, routeurs, points d'accès — UC04
--     Pas de fragmentation verticale : table moins volumineuse et
--     souvent lue en entier lors du diagnostic réseau
-- =============================================================================
CREATE TABLE CYT_NETEQUIP (
  netequip_id     NUMBER        GENERATED ALWAYS AS IDENTITY,
  entity_id       NUMBER        NOT NULL,
  location_id     NUMBER,
  manufacturer_id NUMBER,
  netequip_name   VARCHAR2(100) NOT NULL,
  serial          VARCHAR2(100),
  equip_type      VARCHAR2(20)  DEFAULT 'SWITCH'
                  CHECK (equip_type IN ('SWITCH','ROUTER','AP','FIREWALL','OTHER')),
  nb_ports        NUMBER(5),
  ram_mb          NUMBER,
  sysdescr        CLOB,
  is_deleted      NUMBER(1)     DEFAULT 0 CHECK (is_deleted IN (0,1)),
  date_created    DATE          DEFAULT SYSDATE NOT NULL,
  date_mod        DATE,
  CONSTRAINT PK_CYT_NETEQUIP       PRIMARY KEY (netequip_id)
    USING INDEX TABLESPACE TS_CERGY_IDX,
  CONSTRAINT UQ_NETEQ_SERIAL        UNIQUE (serial)
    USING INDEX TABLESPACE TS_CERGY_IDX
) TABLESPACE TS_CERGY_DATA;


-- =============================================================================
-- 17. CYT_IPADDRESSES
--     Source : glpi_ipaddresses
--     Simplifié : retrait de binary_0..3 (représentation interne MySQL GLPI)
--     On stocke directement l'IP lisible humainement
-- =============================================================================
CREATE TABLE CYT_IPADDRESSES (
  ip_id        NUMBER       GENERATED ALWAYS AS IDENTITY,
  entity_id    NUMBER       NOT NULL,
  items_id     NUMBER       NOT NULL,
  item_type    VARCHAR2(20) NOT NULL CHECK (item_type IN ('COMPUTER','NETEQUIP')),
  ip_version   NUMBER(1)    DEFAULT 4 CHECK (ip_version IN (4,6)),
  ip_address   VARCHAR2(50) NOT NULL,
  is_deleted   NUMBER(1)    DEFAULT 0 CHECK (is_deleted IN (0,1)),
  date_created DATE         DEFAULT SYSDATE NOT NULL,
  CONSTRAINT PK_CYT_IPADDRESSES PRIMARY KEY (ip_id)
    USING INDEX TABLESPACE TS_CERGY_IDX,
  CONSTRAINT UQ_IP_ADDRESS        UNIQUE (ip_address, entity_id)
    USING INDEX TABLESPACE TS_CERGY_IDX
) TABLESPACE TS_CERGY_DATA;


-- =============================================================================
-- 18. CYT_INFOCOMS
--     Source : glpi_infocoms
--     Garanties et informations financières des équipements
-- =============================================================================
CREATE TABLE CYT_INFOCOMS (
  infocom_id        NUMBER       GENERATED ALWAYS AS IDENTITY,
  items_id          NUMBER       NOT NULL,
  item_type         VARCHAR2(20) NOT NULL CHECK (item_type IN ('COMPUTER','NETEQUIP')),
  entity_id         NUMBER       NOT NULL,
  buy_date          DATE,
  warranty_date     DATE,
  warranty_months   NUMBER(3)    DEFAULT 0,
  purchase_value    NUMBER(20,4) DEFAULT 0,
  order_number      VARCHAR2(100),
  immo_number       VARCHAR2(100),
  decommission_date DATE,
  date_created      DATE         DEFAULT SYSDATE,
  CONSTRAINT PK_CYT_INFOCOMS  PRIMARY KEY (infocom_id)
    USING INDEX TABLESPACE TS_CERGY_IDX,
  CONSTRAINT UQ_INFOCOM_ITEM   UNIQUE (item_type, items_id)
    USING INDEX TABLESPACE TS_CERGY_IDX
) TABLESPACE TS_CERGY_DATA;


-- =============================================================================
-- 19. CYT_ASSET_TRANSFER — NOUVELLE TABLE (absente de GLPI)
--     Stockée dans TS_CERGY_LEAD : table exclusive au Lead
--     Pau ne transfère pas vers lui-même — Cergy centralise tout UC07
-- =============================================================================
CREATE TABLE CYT_ASSET_TRANSFER (
  transfer_id   NUMBER        GENERATED ALWAYS AS IDENTITY,
  computer_id   NUMBER        NOT NULL,
  entity_src    NUMBER        NOT NULL,
  entity_dst    NUMBER        NOT NULL,
  initiated_by  NUMBER        NOT NULL,
  transfer_date DATE          DEFAULT SYSDATE NOT NULL,
  reason        VARCHAR2(255),
  status        VARCHAR2(20)  DEFAULT 'EN_COURS'
                CHECK (status IN ('EN_COURS','TERMINE','ANNULE')),
  CONSTRAINT PK_CYT_TRANSFER    PRIMARY KEY (transfer_id)
    USING INDEX TABLESPACE TS_CERGY_IDX,
  CONSTRAINT CHK_TRANS_DIFF      CHECK (entity_src <> entity_dst)
) TABLESPACE TS_CERGY_LEAD;


-- =============================================================================
-- 20. CYT_AUDIT_LOG
--     Source : glpi_logs
--     Enrichi : ajout entity_id (distinguer Cergy/Pau dans l'audit global),
--               operation VARCHAR2 (remplace linked_action int cryptique GLPI)
--     Stocké dans TS_AUDIT pour isoler les INSERT massifs des triggers
-- =============================================================================
CREATE TABLE CYT_AUDIT_LOG (
  log_id     NUMBER        GENERATED ALWAYS AS IDENTITY,
  table_name VARCHAR2(50)  NOT NULL,
  item_id    NUMBER        NOT NULL,
  entity_id  NUMBER,
  operation  VARCHAR2(10)  NOT NULL CHECK (operation IN ('INSERT','UPDATE','DELETE')),
  user_db    VARCHAR2(100) DEFAULT USER NOT NULL,
  old_value  VARCHAR2(500),
  new_value  VARCHAR2(500),
  log_date   DATE          DEFAULT SYSDATE NOT NULL,
  CONSTRAINT PK_CYT_AUDIT_LOG PRIMARY KEY (log_id)
    USING INDEX TABLESPACE TS_AUDIT
) TABLESPACE TS_AUDIT;


-- =============================================================================
-- GRANTs : voir cergy/02b_grants.sql (execute par system apres ce fichier)
-- Les GRANTs sont dans un fichier separe car ils necessitent le prefixe
-- APPLI_GLPI. et doivent etre executes par system, pas par APPLI_GLPI.