-- =============================================================================
-- FICHIER  : pau/03_schema_tables.sql
-- INSTANCE : pau_db (Spoke)
-- NOTION   : DDL — même structure que Cergy avec les différences suivantes :
--
--   1. FRAGMENTATION HORIZONTALE : seules les lignes entity_id=PAU ici
--   2. TABLESPACES : TS_PAU_DATA, TS_PAU_IDX, TS_PAU_COLD, TS_PAU_AUDIT
--   3. FRAGMENTATION VERTICALE INTER-SITES :
--      CYT_ENTITIES ne contient PAS les colonnes Lead :
--        dblink_connection, is_lead, pau_last_sync → absentes ici
--      Justification : Pau n'orchestre aucun DBLink (UC09 — autonomie locale)
--   4. PAS de CYT_ASSET_TRANSFER : Pau ne centralise pas les transferts
--   5. PAS de TS_CERGY_LEAD
-- =============================================================================

WHENEVER SQLERROR CONTINUE;
DROP TABLE CYT_AUDIT_LOG         CASCADE CONSTRAINTS PURGE;
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
-- CYT_ENTITIES — version Pau
-- DIFFÉRENCE vs Cergy : pas de dblink_connection, is_lead, pau_last_sync
-- Ces colonnes sont exclusives au Lead (fragmentation verticale inter-sites)
-- =============================================================================
WHENEVER SQLERROR EXIT SQL.SQLCODE;
CREATE TABLE CYT_ENTITIES (
  entity_id    NUMBER        GENERATED ALWAYS AS IDENTITY,
  entity_name  VARCHAR2(100) NOT NULL,
  site_code    VARCHAR2(10)  NOT NULL,
  address      VARCHAR2(255),
  town         VARCHAR2(100),
  postcode     VARCHAR2(10),
  country      VARCHAR2(50)  DEFAULT 'France',
  phonenumber  VARCHAR2(30),
  email        VARCHAR2(100),
  date_created DATE          DEFAULT SYSDATE NOT NULL,
  CONSTRAINT PK_CYT_ENTITIES  PRIMARY KEY (entity_id)
    USING INDEX TABLESPACE TS_PAU_IDX,
  CONSTRAINT UQ_ENTITY_SITE    UNIQUE (site_code)
    USING INDEX TABLESPACE TS_PAU_IDX,
  CONSTRAINT CHK_ENTITY_SITE   CHECK (site_code IN ('CERGY','PAU'))
) TABLESPACE TS_PAU_DATA;

-- Fragmentation horizontale : Pau ne stocke que son entité locale
INSERT INTO CYT_ENTITIES (entity_name, site_code, address, town, postcode)
VALUES ('CY Tech Pau', 'PAU', '1 allée du Parc Montaury', 'Anglet', '64600');
COMMIT;

CREATE TABLE CYT_LOCATIONS (
  location_id   NUMBER        GENERATED ALWAYS AS IDENTITY,
  entity_id     NUMBER        NOT NULL,
  location_name VARCHAR2(100) NOT NULL,
  building      VARCHAR2(100),
  room          VARCHAR2(50),
  floor         NUMBER(2),
  latitude      VARCHAR2(30),
  longitude     VARCHAR2(30),
  date_created  DATE          DEFAULT SYSDATE NOT NULL,
  CONSTRAINT PK_CYT_LOCATIONS PRIMARY KEY (location_id)
    USING INDEX TABLESPACE TS_PAU_IDX,
  CONSTRAINT FK_LOC_ENTITY     FOREIGN KEY (entity_id)
    REFERENCES CYT_ENTITIES(entity_id),
  CONSTRAINT UQ_LOCATION       UNIQUE (entity_id, building, room)
    USING INDEX TABLESPACE TS_PAU_IDX
) TABLESPACE TS_PAU_DATA;

INSERT INTO CYT_LOCATIONS (entity_id, location_name, building, room, floor)
VALUES (1, 'Salle Info C101', 'Bâtiment C', 'Salle 101', 1);
INSERT INTO CYT_LOCATIONS (entity_id, location_name, building, room, floor)
VALUES (1, 'Salle Serveurs Pau', 'Bâtiment C', 'Salle S01', -1);
COMMIT;

CREATE TABLE CYT_MANUFACTURERS (
  manufacturer_id   NUMBER        GENERATED ALWAYS AS IDENTITY,
  manufacturer_name VARCHAR2(100) NOT NULL,
  date_created      DATE          DEFAULT SYSDATE,
  CONSTRAINT PK_CYT_MANUFACTURERS PRIMARY KEY (manufacturer_id)
    USING INDEX TABLESPACE TS_PAU_IDX,
  CONSTRAINT UQ_MANUFACTURER      UNIQUE (manufacturer_name)
    USING INDEX TABLESPACE TS_PAU_IDX
) TABLESPACE TS_PAU_DATA;

INSERT INTO CYT_MANUFACTURERS (manufacturer_name) VALUES ('Dell');
INSERT INTO CYT_MANUFACTURERS (manufacturer_name) VALUES ('HP');
INSERT INTO CYT_MANUFACTURERS (manufacturer_name) VALUES ('Lenovo');
INSERT INTO CYT_MANUFACTURERS (manufacturer_name) VALUES ('Apple');
INSERT INTO CYT_MANUFACTURERS (manufacturer_name) VALUES ('Cisco');
INSERT INTO CYT_MANUFACTURERS (manufacturer_name) VALUES ('TP-Link');
COMMIT;

CREATE TABLE CYT_COMPUTER_TYPES (
  type_id   NUMBER       GENERATED ALWAYS AS IDENTITY,
  type_name VARCHAR2(50) NOT NULL,
  CONSTRAINT PK_CYT_COMP_TYPES PRIMARY KEY (type_id)
    USING INDEX TABLESPACE TS_PAU_IDX,
  CONSTRAINT UQ_COMP_TYPE       UNIQUE (type_name)
    USING INDEX TABLESPACE TS_PAU_IDX
) TABLESPACE TS_PAU_DATA;

INSERT INTO CYT_COMPUTER_TYPES (type_name) VALUES ('Desktop');
INSERT INTO CYT_COMPUTER_TYPES (type_name) VALUES ('Laptop');
INSERT INTO CYT_COMPUTER_TYPES (type_name) VALUES ('Serveur');
INSERT INTO CYT_COMPUTER_TYPES (type_name) VALUES ('Workstation');
COMMIT;

CREATE TABLE CYT_COMPUTER_MODELS (
  model_id       NUMBER        GENERATED ALWAYS AS IDENTITY,
  model_name     VARCHAR2(100) NOT NULL,
  product_number VARCHAR2(100),
  date_created   DATE          DEFAULT SYSDATE,
  CONSTRAINT PK_CYT_COMP_MODELS PRIMARY KEY (model_id)
    USING INDEX TABLESPACE TS_PAU_IDX,
  CONSTRAINT UQ_COMP_MODEL      UNIQUE (model_name)
    USING INDEX TABLESPACE TS_PAU_IDX
) TABLESPACE TS_PAU_DATA;

INSERT INTO CYT_COMPUTER_MODELS (model_name, product_number)
VALUES ('Dell OptiPlex 7090',  'OPX7090');
INSERT INTO CYT_COMPUTER_MODELS (model_name, product_number)
VALUES ('HP EliteBook 840 G9', 'ELB840G9');
INSERT INTO CYT_COMPUTER_MODELS (model_name, product_number)
VALUES ('Lenovo ThinkPad X1',  'TPX1C10');
INSERT INTO CYT_COMPUTER_MODELS (model_name, product_number)
VALUES ('Dell Latitude 5520',  'LAT5520');
COMMIT;

CREATE TABLE CYT_PROFILES (
  profile_id   NUMBER        GENERATED ALWAYS AS IDENTITY,
  profile_name VARCHAR2(100) NOT NULL,
  interface    VARCHAR2(20)  DEFAULT 'central'
               CHECK (interface IN ('central','helpdesk')),
  is_default   NUMBER(1)     DEFAULT 0 CHECK (is_default IN (0,1)),
  date_created DATE          DEFAULT SYSDATE,
  date_mod     DATE,
  CONSTRAINT PK_CYT_PROFILES PRIMARY KEY (profile_id)
    USING INDEX TABLESPACE TS_PAU_IDX,
  CONSTRAINT UQ_PROFILE_NAME  UNIQUE (profile_name)
    USING INDEX TABLESPACE TS_PAU_IDX
) TABLESPACE TS_PAU_DATA;

INSERT INTO CYT_PROFILES (profile_name, interface, is_default)
VALUES ('Technicien', 'central', 1);
INSERT INTO CYT_PROFILES (profile_name, interface, is_default)
VALUES ('RH', 'helpdesk', 0);
INSERT INTO CYT_PROFILES (profile_name, interface, is_default)
VALUES ('Auditeur', 'central', 0);
COMMIT;

-- VLANs Pau : plan IP distinct de Cergy (pas de collision d'adresses)
CREATE TABLE CYT_NETWORKS (
  network_id   NUMBER        GENERATED ALWAYS AS IDENTITY,
  entity_id    NUMBER        NOT NULL,
  network_name VARCHAR2(100) NOT NULL,
  vlan_id      NUMBER(4),
  subnet       VARCHAR2(50),
  gateway      VARCHAR2(50),
  ip_version   NUMBER(1)     DEFAULT 4 CHECK (ip_version IN (4,6)),
  remarks      VARCHAR2(500),
  date_created DATE          DEFAULT SYSDATE NOT NULL,
  date_mod     DATE,
  CONSTRAINT PK_CYT_NETWORKS PRIMARY KEY (network_id)
    USING INDEX TABLESPACE TS_PAU_IDX,
  CONSTRAINT FK_NET_ENTITY    FOREIGN KEY (entity_id)
    REFERENCES CYT_ENTITIES(entity_id),
  CONSTRAINT UQ_NETWORK_VLAN  UNIQUE (entity_id, vlan_id)
    USING INDEX TABLESPACE TS_PAU_IDX,
  CONSTRAINT CHK_VLAN_RANGE   CHECK (vlan_id BETWEEN 1 AND 4094)
) TABLESPACE TS_PAU_DATA;

INSERT INTO CYT_NETWORKS (entity_id, network_name, vlan_id, subnet, gateway)
VALUES (1, 'VLAN_ADMIN_PAU',     110, '192.168.110.0/24', '192.168.110.1');
INSERT INTO CYT_NETWORKS (entity_id, network_name, vlan_id, subnet, gateway)
VALUES (1, 'VLAN_ETUDIANTS_PAU', 120, '192.168.120.0/24', '192.168.120.1');
INSERT INTO CYT_NETWORKS (entity_id, network_name, vlan_id, subnet, gateway)
VALUES (1, 'VLAN_INFRA_PAU',     130, '10.0.130.0/24',    '10.0.130.1');
COMMIT;

CREATE TABLE CYT_GROUPS (
  group_id     NUMBER        GENERATED ALWAYS AS IDENTITY,
  entity_id    NUMBER        NOT NULL,
  group_name   VARCHAR2(100) NOT NULL,
  group_code   VARCHAR2(50),
  is_recursive NUMBER(1)     DEFAULT 0 CHECK (is_recursive IN (0,1)),
  is_usergroup NUMBER(1)     DEFAULT 1 CHECK (is_usergroup IN (0,1)),
  remarks      VARCHAR2(500),
  date_created DATE          DEFAULT SYSDATE NOT NULL,
  date_mod     DATE,
  CONSTRAINT PK_CYT_GROUPS  PRIMARY KEY (group_id)
    USING INDEX TABLESPACE TS_PAU_IDX,
  CONSTRAINT FK_GRP_ENTITY   FOREIGN KEY (entity_id)
    REFERENCES CYT_ENTITIES(entity_id),
  CONSTRAINT UQ_GROUP_CODE   UNIQUE (entity_id, group_code)
    USING INDEX TABLESPACE TS_PAU_IDX
) TABLESPACE TS_PAU_DATA;

INSERT INTO CYT_GROUPS (entity_id, group_name, group_code)
VALUES (1, 'Techniciens Pau', 'TECH_PAU');
COMMIT;

-- Cluster réseau — même logique que Cergy
CREATE CLUSTER CLU_NETWORK (port_id NUMBER)
  SIZE 1024 TABLESPACE TS_PAU_DATA;

CREATE INDEX IDX_CLU_NETWORK ON CLUSTER CLU_NETWORK
  TABLESPACE TS_PAU_IDX;

CREATE SEQUENCE SEQ_NETWORKPORT_ID START WITH 1 INCREMENT BY 1 NOCACHE;

CREATE TABLE CYT_NETWORKPORTS (
  port_id        NUMBER        NOT NULL,
  items_id       NUMBER        NOT NULL,
  item_type      VARCHAR2(20)  NOT NULL CHECK (item_type IN ('COMPUTER','NETEQUIP')),
  entity_id      NUMBER        NOT NULL,
  logical_number NUMBER        DEFAULT 0 NOT NULL,
  port_name      VARCHAR2(100),
  mac_address    VARCHAR2(20),
  network_id     NUMBER,
  port_status    VARCHAR2(20)  DEFAULT 'ACTIVE'
                 CHECK (port_status IN ('ACTIVE','INACTIVE','UNKNOWN')),
  is_deleted     NUMBER(1)     DEFAULT 0 CHECK (is_deleted IN (0,1)),
  date_created   DATE          DEFAULT SYSDATE NOT NULL,
  date_mod       DATE,
  CONSTRAINT PK_CYT_NETWORKPORTS PRIMARY KEY (port_id)
    USING INDEX TABLESPACE TS_PAU_IDX,
  CONSTRAINT FK_NETPORT_ENTITY    FOREIGN KEY (entity_id)
    REFERENCES CYT_ENTITIES(entity_id),
  CONSTRAINT FK_NETPORT_NETWORK   FOREIGN KEY (network_id)
    REFERENCES CYT_NETWORKS(network_id),
  CONSTRAINT UQ_NETPORT_MAC       UNIQUE (mac_address)
    USING INDEX TABLESPACE TS_PAU_IDX
) CLUSTER CLU_NETWORK(port_id);

CREATE TABLE CYT_PORT_LINKS (
  link_id      NUMBER GENERATED ALWAYS AS IDENTITY,
  port_src     NUMBER NOT NULL,
  port_dst     NUMBER NOT NULL,
  date_created DATE   DEFAULT SYSDATE,
  CONSTRAINT PK_CYT_PORT_LINKS PRIMARY KEY (link_id)
    USING INDEX TABLESPACE TS_PAU_IDX,
  CONSTRAINT UQ_PORT_LINK       UNIQUE (port_src, port_dst)
    USING INDEX TABLESPACE TS_PAU_IDX,
  CONSTRAINT FK_PORTLINK_SRC    FOREIGN KEY (port_src)
    REFERENCES CYT_NETWORKPORTS(port_id),
  CONSTRAINT FK_PORTLINK_DST    FOREIGN KEY (port_dst)
    REFERENCES CYT_NETWORKPORTS(port_id)
) CLUSTER CLU_NETWORK(port_src);

-- CYT_USERS chaud
CREATE TABLE CYT_USERS (
  user_id       NUMBER        GENERATED ALWAYS AS IDENTITY,
  login         VARCHAR2(100) NOT NULL,
  password_hash VARCHAR2(255) NOT NULL,
  realname      VARCHAR2(100),
  firstname     VARCHAR2(100),
  entity_id     NUMBER        NOT NULL,
  profile_id    NUMBER        NOT NULL,
  is_active     NUMBER(1)     DEFAULT 1 CHECK (is_active IN (0,1)),
  is_deleted    NUMBER(1)     DEFAULT 0 CHECK (is_deleted IN (0,1)),
  last_login    DATE,
  date_created  DATE          DEFAULT SYSDATE NOT NULL,
  date_mod      DATE,
  CONSTRAINT PK_CYT_USERS   PRIMARY KEY (user_id)
    USING INDEX TABLESPACE TS_PAU_IDX,
  CONSTRAINT FK_USER_ENTITY  FOREIGN KEY (entity_id)
    REFERENCES CYT_ENTITIES(entity_id),
  CONSTRAINT FK_USER_PROFILE FOREIGN KEY (profile_id)
    REFERENCES CYT_PROFILES(profile_id),
  CONSTRAINT UQ_USER_LOGIN   UNIQUE (login)
    USING INDEX TABLESPACE TS_PAU_IDX
) TABLESPACE TS_PAU_DATA;

-- CYT_USERS_DETAIL froid
CREATE TABLE CYT_USERS_DETAIL (
  user_id              NUMBER        NOT NULL,
  phone                VARCHAR2(30),
  phone2               VARCHAR2(30),
  mobile               VARCHAR2(30),
  registration_number  VARCHAR2(50),
  language             CHAR(10)      DEFAULT 'fr_FR',
  remarks              CLOB,
  personal_token       VARCHAR2(255),
  api_token            VARCHAR2(255),
  password_last_update DATE,
  CONSTRAINT PK_CYT_USERS_DETAIL PRIMARY KEY (user_id)
    USING INDEX TABLESPACE TS_PAU_IDX,
  CONSTRAINT FK_USERDET_USER      FOREIGN KEY (user_id)
    REFERENCES CYT_USERS(user_id) ON DELETE CASCADE
) TABLESPACE TS_PAU_COLD;

CREATE TABLE CYT_GROUPS_USERS (
  gu_id        NUMBER    GENERATED ALWAYS AS IDENTITY,
  user_id      NUMBER    NOT NULL,
  group_id     NUMBER    NOT NULL,
  is_manager   NUMBER(1) DEFAULT 0 CHECK (is_manager IN (0,1)),
  is_dynamic   NUMBER(1) DEFAULT 0 CHECK (is_dynamic IN (0,1)),
  date_created DATE      DEFAULT SYSDATE NOT NULL,
  CONSTRAINT PK_CYT_GROUPS_USERS PRIMARY KEY (gu_id)
    USING INDEX TABLESPACE TS_PAU_IDX,
  CONSTRAINT FK_GU_USER           FOREIGN KEY (user_id)
    REFERENCES CYT_USERS(user_id)  ON DELETE CASCADE,
  CONSTRAINT FK_GU_GROUP          FOREIGN KEY (group_id)
    REFERENCES CYT_GROUPS(group_id) ON DELETE CASCADE,
  CONSTRAINT UQ_GU_UNICITY        UNIQUE (user_id, group_id)
    USING INDEX TABLESPACE TS_PAU_IDX
) TABLESPACE TS_PAU_DATA;

CREATE TABLE CYT_USERS_PROFILES (
  up_id              NUMBER    GENERATED ALWAYS AS IDENTITY,
  user_id            NUMBER    NOT NULL,
  profile_id         NUMBER    NOT NULL,
  entity_id          NUMBER    NOT NULL,
  is_default_profile NUMBER(1) DEFAULT 0 CHECK (is_default_profile IN (0,1)),
  is_dynamic         NUMBER(1) DEFAULT 0 CHECK (is_dynamic IN (0,1)),
  CONSTRAINT PK_CYT_USERS_PROFILES PRIMARY KEY (up_id)
    USING INDEX TABLESPACE TS_PAU_IDX,
  CONSTRAINT FK_UP_USER             FOREIGN KEY (user_id)
    REFERENCES CYT_USERS(user_id) ON DELETE CASCADE,
  CONSTRAINT FK_UP_PROFILE          FOREIGN KEY (profile_id)
    REFERENCES CYT_PROFILES(profile_id),
  CONSTRAINT FK_UP_ENTITY           FOREIGN KEY (entity_id)
    REFERENCES CYT_ENTITIES(entity_id),
  CONSTRAINT UQ_UP_UNICITY          UNIQUE (user_id, profile_id, entity_id)
    USING INDEX TABLESPACE TS_PAU_IDX
) TABLESPACE TS_PAU_DATA;

-- CYT_COMPUTERS chaud
CREATE TABLE CYT_COMPUTERS (
  computer_id     NUMBER        GENERATED ALWAYS AS IDENTITY,
  serial          VARCHAR2(100) NOT NULL,
  computer_name   VARCHAR2(100) NOT NULL,
  entity_id       NUMBER        NOT NULL,
  location_id     NUMBER,
  type_id         NUMBER,
  model_id        NUMBER,
  manufacturer_id NUMBER,
  user_id         NUMBER,
  tech_user_id    NUMBER,
  status          VARCHAR2(20)  DEFAULT 'ACTIF'
                  CHECK (status IN ('ACTIF','HORS_SERVICE','EN_STOCK',
                                    'EN_REPARATION','TRANSFERT','RETIRE')),
  is_deleted      NUMBER(1)     DEFAULT 0 CHECK (is_deleted IN (0,1)),
  date_purchase   DATE,
  date_created    DATE          DEFAULT SYSDATE NOT NULL,
  date_mod        DATE,
  CONSTRAINT PK_CYT_COMPUTERS     PRIMARY KEY (computer_id)
    USING INDEX TABLESPACE TS_PAU_IDX,
  CONSTRAINT UQ_COMP_SERIAL        UNIQUE (serial)
    USING INDEX TABLESPACE TS_PAU_IDX,
  CONSTRAINT FK_COMP_ENTITY        FOREIGN KEY (entity_id)
    REFERENCES CYT_ENTITIES(entity_id),
  CONSTRAINT FK_COMP_LOCATION      FOREIGN KEY (location_id)
    REFERENCES CYT_LOCATIONS(location_id),
  CONSTRAINT FK_COMP_TYPE          FOREIGN KEY (type_id)
    REFERENCES CYT_COMPUTER_TYPES(type_id),
  CONSTRAINT FK_COMP_MODEL         FOREIGN KEY (model_id)
    REFERENCES CYT_COMPUTER_MODELS(model_id),
  CONSTRAINT FK_COMP_MANUFACTURER  FOREIGN KEY (manufacturer_id)
    REFERENCES CYT_MANUFACTURERS(manufacturer_id),
  CONSTRAINT FK_COMP_USER          FOREIGN KEY (user_id)
    REFERENCES CYT_USERS(user_id),
  CONSTRAINT FK_COMP_TECH          FOREIGN KEY (tech_user_id)
    REFERENCES CYT_USERS(user_id)
) TABLESPACE TS_PAU_DATA;

-- CYT_COMPUTERS_DETAIL froid
CREATE TABLE CYT_COMPUTERS_DETAIL (
  computer_id           NUMBER       NOT NULL,
  uuid                  VARCHAR2(255),
  otherserial           VARCHAR2(100),
  ticket_tco            NUMBER(20,4) DEFAULT 0,
  last_inventory_update DATE,
  last_boot             DATE,
  is_dynamic            NUMBER(1)    DEFAULT 0,
  remarks               CLOB,
  CONSTRAINT PK_CYT_COMP_DETAIL PRIMARY KEY (computer_id)
    USING INDEX TABLESPACE TS_PAU_IDX,
  CONSTRAINT FK_COMPDET_COMP     FOREIGN KEY (computer_id)
    REFERENCES CYT_COMPUTERS(computer_id) ON DELETE CASCADE
) TABLESPACE TS_PAU_COLD;

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
  CONSTRAINT PK_CYT_NETEQUIP      PRIMARY KEY (netequip_id)
    USING INDEX TABLESPACE TS_PAU_IDX,
  CONSTRAINT FK_NETEQ_ENTITY       FOREIGN KEY (entity_id)
    REFERENCES CYT_ENTITIES(entity_id),
  CONSTRAINT FK_NETEQ_LOCATION     FOREIGN KEY (location_id)
    REFERENCES CYT_LOCATIONS(location_id),
  CONSTRAINT FK_NETEQ_MANUFACTURER FOREIGN KEY (manufacturer_id)
    REFERENCES CYT_MANUFACTURERS(manufacturer_id),
  CONSTRAINT UQ_NETEQ_SERIAL       UNIQUE (serial)
    USING INDEX TABLESPACE TS_PAU_IDX
) TABLESPACE TS_PAU_DATA;

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
    USING INDEX TABLESPACE TS_PAU_IDX,
  CONSTRAINT FK_IP_ENTITY        FOREIGN KEY (entity_id)
    REFERENCES CYT_ENTITIES(entity_id),
  CONSTRAINT UQ_IP_ADDRESS        UNIQUE (ip_address, entity_id)
    USING INDEX TABLESPACE TS_PAU_IDX
) TABLESPACE TS_PAU_DATA;

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
    USING INDEX TABLESPACE TS_PAU_IDX,
  CONSTRAINT UQ_INFOCOM_ITEM   UNIQUE (item_type, items_id)
    USING INDEX TABLESPACE TS_PAU_IDX,
  CONSTRAINT FK_IC_ENTITY      FOREIGN KEY (entity_id)
    REFERENCES CYT_ENTITIES(entity_id)
) TABLESPACE TS_PAU_DATA;

-- Audit local Pau dans TS_PAU_AUDIT
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
    USING INDEX TABLESPACE TS_PAU_AUDIT
) TABLESPACE TS_PAU_AUDIT;

-- GRANTs pour APPLI_GLPI sur Pau (utilisé par les DBLinks depuis Cergy)
GRANT SELECT, INSERT, UPDATE, DELETE ON CYT_COMPUTERS        TO ROLE_APPLI_GLPI;
GRANT SELECT, INSERT, UPDATE, DELETE ON CYT_COMPUTERS_DETAIL TO ROLE_APPLI_GLPI;
GRANT SELECT, INSERT, UPDATE, DELETE ON CYT_USERS            TO ROLE_APPLI_GLPI;
GRANT SELECT, INSERT, UPDATE, DELETE ON CYT_USERS_DETAIL     TO ROLE_APPLI_GLPI;
GRANT SELECT, INSERT, UPDATE, DELETE ON CYT_NETWORKPORTS     TO ROLE_APPLI_GLPI;
GRANT SELECT, INSERT, UPDATE, DELETE ON CYT_PORT_LINKS       TO ROLE_APPLI_GLPI;
GRANT SELECT, INSERT, UPDATE, DELETE ON CYT_IPADDRESSES      TO ROLE_APPLI_GLPI;
GRANT SELECT, INSERT, UPDATE, DELETE ON CYT_NETEQUIP         TO ROLE_APPLI_GLPI;
GRANT SELECT, INSERT, UPDATE, DELETE ON CYT_NETWORKS         TO ROLE_APPLI_GLPI;
GRANT SELECT, INSERT, UPDATE, DELETE ON CYT_GROUPS           TO ROLE_APPLI_GLPI;
GRANT SELECT, INSERT, UPDATE, DELETE ON CYT_GROUPS_USERS     TO ROLE_APPLI_GLPI;
GRANT INSERT                         ON CYT_AUDIT_LOG        TO ROLE_APPLI_GLPI;
GRANT SELECT                         ON CYT_COMPUTERS        TO ROLE_AUDITEUR_PAU;
GRANT SELECT                         ON CYT_AUDIT_LOG        TO ROLE_AUDITEUR_PAU;
GRANT SELECT                         ON CYT_USERS            TO ROLE_AUDITEUR_PAU;
GRANT SELECT, INSERT, UPDATE         ON CYT_COMPUTERS        TO ROLE_TECH_PAU;
GRANT SELECT, INSERT, UPDATE         ON CYT_NETWORKPORTS     TO ROLE_TECH_PAU;
GRANT SELECT, INSERT, UPDATE         ON CYT_NETEQUIP         TO ROLE_TECH_PAU;
GRANT SELECT                         ON CYT_ENTITIES         TO ROLE_TECH_PAU;
GRANT SELECT                         ON CYT_LOCATIONS        TO ROLE_TECH_PAU;

SELECT table_name, tablespace_name
FROM   user_tables
WHERE  table_name LIKE 'CYT_%'
ORDER BY table_name;