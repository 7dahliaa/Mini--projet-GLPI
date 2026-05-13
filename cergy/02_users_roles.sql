-- =============================================================================
-- FICHIER  : cergy/02_users_roles.sql
-- INSTANCE : cergy_db (Lead)
-- NOTION   : Utilisateurs & Rôles Oracle
-- SOURCE   : Réadaptation de glpi_profiles + glpi_profiles_users + glpi_groups
-- OBJECTIF : Principe du moindre privilège — chaque acteur a exactement
--            les droits nécessaires, ni plus.
-- =============================================================================

-- =============================================================================
-- PARTIE 1 — RÔLES
-- =============================================================================
BEGIN
  FOR r IN (SELECT role_name FROM dba_roles
            WHERE  role_name IN ('ROLE_DSI_ADMIN','ROLE_TECH_CERGY',
                                 'ROLE_RH','ROLE_AUDITEUR','ROLE_APPLI_GLPI')) LOOP
    EXECUTE IMMEDIATE 'DROP ROLE ' || r.role_name;
  END LOOP;
END;
/

-- Directeur SI : vision globale, tous droits, accès DBLink
WHENEVER SQLERROR EXIT SQL.SQLCODE;
CREATE ROLE ROLE_DSI_ADMIN;

-- Technicien Cergy : DML sur assets Cergy, pas de DDL
CREATE ROLE ROLE_TECH_CERGY;

-- Service RH : uniquement les tables utilisateurs
CREATE ROLE ROLE_RH;

-- Auditeur : lecture seule partout + lecture Pau via DBLink (UC08)
CREATE ROLE ROLE_AUDITEUR;

-- Compte applicatif : DML complet, utilisé par les DBLinks et l'application
CREATE ROLE ROLE_APPLI_GLPI;

-- Privilèges de session
GRANT CREATE SESSION TO ROLE_DSI_ADMIN;
GRANT CREATE SESSION TO ROLE_TECH_CERGY;
GRANT CREATE SESSION TO ROLE_RH;
GRANT CREATE SESSION TO ROLE_AUDITEUR;
GRANT CREATE SESSION TO ROLE_APPLI_GLPI;

-- Privilèges DSI
GRANT SELECT ANY TABLE     TO ROLE_DSI_ADMIN;
GRANT INSERT ANY TABLE     TO ROLE_DSI_ADMIN;
GRANT UPDATE ANY TABLE     TO ROLE_DSI_ADMIN;
GRANT DELETE ANY TABLE     TO ROLE_DSI_ADMIN;
GRANT CREATE ANY VIEW      TO ROLE_DSI_ADMIN;
GRANT CREATE DATABASE LINK TO ROLE_DSI_ADMIN;
GRANT EXECUTE ANY PROCEDURE TO ROLE_DSI_ADMIN;

-- Auditeur : lecture seule
GRANT SELECT ANY TABLE TO ROLE_AUDITEUR;

-- Appli : DBLink
GRANT CREATE DATABASE LINK TO ROLE_APPLI_GLPI;

-- =============================================================================
-- PARTIE 2 — UTILISATEURS
-- =============================================================================
BEGIN
  FOR u IN (SELECT username FROM dba_users
            WHERE  username IN ('ADMIN_DSI','TECH_CERGY1','TECH_CERGY2',
                                'RH_USER','AUDITEUR','APPLI_GLPI')) LOOP
    EXECUTE IMMEDIATE 'DROP USER ' || u.username || ' CASCADE';
  END LOOP;
END;
/

CREATE USER ADMIN_DSI
  IDENTIFIED BY "DSI_CyTech_2026!"
  DEFAULT TABLESPACE TS_CERGY_DATA
  TEMPORARY TABLESPACE TEMP
  QUOTA UNLIMITED ON TS_CERGY_DATA
  QUOTA UNLIMITED ON TS_CERGY_IDX
  QUOTA UNLIMITED ON TS_CERGY_COLD
  QUOTA UNLIMITED ON TS_CERGY_LEAD
  QUOTA UNLIMITED ON TS_AUDIT;

CREATE USER TECH_CERGY1
  IDENTIFIED BY "Tech1_Cergy_2026!"
  DEFAULT TABLESPACE TS_CERGY_DATA
  TEMPORARY TABLESPACE TEMP
  QUOTA 200M ON TS_CERGY_DATA;

CREATE USER TECH_CERGY2
  IDENTIFIED BY "Tech2_Cergy_2026!"
  DEFAULT TABLESPACE TS_CERGY_DATA
  TEMPORARY TABLESPACE TEMP
  QUOTA 200M ON TS_CERGY_DATA;

CREATE USER RH_USER
  IDENTIFIED BY "RH_CyTech_2026!"
  DEFAULT TABLESPACE TS_CERGY_DATA
  TEMPORARY TABLESPACE TEMP
  QUOTA 50M ON TS_CERGY_DATA;

-- Auditeur : QUOTA 0 → impossible d'écrire, seulement lire
CREATE USER AUDITEUR
  IDENTIFIED BY "Audit_CyTech_2026!"
  DEFAULT TABLESPACE TS_CERGY_DATA
  TEMPORARY TABLESPACE TEMP
  QUOTA 0 ON TS_CERGY_DATA;

CREATE USER APPLI_GLPI
  IDENTIFIED BY "AppGLPI_2026!"
  DEFAULT TABLESPACE TS_CERGY_DATA
  TEMPORARY TABLESPACE TEMP
  QUOTA UNLIMITED ON TS_CERGY_DATA
  QUOTA UNLIMITED ON TS_AUDIT;

-- =============================================================================
-- PARTIE 3 — ATTRIBUTION
-- =============================================================================
GRANT ROLE_DSI_ADMIN  TO ADMIN_DSI;
GRANT ROLE_TECH_CERGY TO TECH_CERGY1;
GRANT ROLE_TECH_CERGY TO TECH_CERGY2;
GRANT ROLE_RH         TO RH_USER;
GRANT ROLE_AUDITEUR   TO AUDITEUR;
GRANT ROLE_APPLI_GLPI TO APPLI_GLPI;

-- Vérification
SELECT u.username,
       u.default_tablespace,
       u.account_status,
       rp.granted_role
FROM   dba_users u
LEFT JOIN dba_role_privs rp ON rp.grantee = u.username
WHERE  u.username IN ('ADMIN_DSI','TECH_CERGY1','TECH_CERGY2',
                      'RH_USER','AUDITEUR','APPLI_GLPI')
ORDER BY u.username;
