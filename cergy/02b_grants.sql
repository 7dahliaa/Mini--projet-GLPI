-- =============================================================================
-- FICHIER  : cergy/02b_grants.sql
-- EXECUTÉ  : par APPLI_GLPI (propriétaire des tables)
-- NOTION   : GRANTs sur objets — le propriétaire distribue ses droits
-- ORDRE    : après 03_schema_tables.sql et 03b_fk.sql
-- =============================================================================
-- APPLI_GLPI est propriétaire des tables → il peut GRANT sans préfixe
-- C'est le modèle Oracle standard : owner distribue, system n'intervient pas

-- ── ROLE_TECH_CERGY ──────────────────────────────────────────────────────────
-- Technicien : DML sur les assets, SELECT sur les référentiels
GRANT SELECT, INSERT, UPDATE ON CYT_COMPUTERS        TO ROLE_TECH_CERGY;
GRANT SELECT, INSERT, UPDATE ON CYT_COMPUTERS_DETAIL TO ROLE_TECH_CERGY;
GRANT SELECT, INSERT, UPDATE ON CYT_LOCATIONS        TO ROLE_TECH_CERGY;
GRANT SELECT, INSERT, UPDATE ON CYT_NETWORKPORTS     TO ROLE_TECH_CERGY;
GRANT SELECT, INSERT, UPDATE ON CYT_PORT_LINKS       TO ROLE_TECH_CERGY;
GRANT SELECT, INSERT, UPDATE ON CYT_NETEQUIP         TO ROLE_TECH_CERGY;
GRANT SELECT, INSERT, UPDATE ON CYT_IPADDRESSES      TO ROLE_TECH_CERGY;
GRANT SELECT                 ON CYT_ENTITIES         TO ROLE_TECH_CERGY;
GRANT SELECT                 ON CYT_MANUFACTURERS    TO ROLE_TECH_CERGY;
GRANT SELECT                 ON CYT_COMPUTER_MODELS  TO ROLE_TECH_CERGY;
GRANT SELECT                 ON CYT_COMPUTER_TYPES   TO ROLE_TECH_CERGY;
GRANT SELECT                 ON CYT_NETWORKS         TO ROLE_TECH_CERGY;
GRANT SELECT                 ON CYT_USERS            TO ROLE_TECH_CERGY;
GRANT SELECT                 ON CYT_GROUPS           TO ROLE_TECH_CERGY;
GRANT SELECT                 ON CYT_GROUPS_USERS     TO ROLE_TECH_CERGY;

-- ── ROLE_RH ──────────────────────────────────────────────────────────────────
-- RH : uniquement la gestion des utilisateurs
GRANT SELECT, INSERT, UPDATE         ON CYT_USERS          TO ROLE_RH;
GRANT SELECT, INSERT, UPDATE         ON CYT_USERS_DETAIL   TO ROLE_RH;
GRANT SELECT, INSERT, UPDATE         ON CYT_USERS_PROFILES TO ROLE_RH;
GRANT SELECT, INSERT, UPDATE, DELETE ON CYT_GROUPS_USERS   TO ROLE_RH;
GRANT SELECT                         ON CYT_PROFILES       TO ROLE_RH;
GRANT SELECT                         ON CYT_ENTITIES       TO ROLE_RH;
GRANT SELECT                         ON CYT_GROUPS         TO ROLE_RH;

-- ── ROLE_AUDITEUR ─────────────────────────────────────────────────────────────
-- Auditeur : lecture seule sur tout — pas d'écriture possible
GRANT SELECT ON CYT_COMPUTERS        TO ROLE_AUDITEUR;
GRANT SELECT ON CYT_COMPUTERS_DETAIL TO ROLE_AUDITEUR;
GRANT SELECT ON CYT_USERS            TO ROLE_AUDITEUR;
GRANT SELECT ON CYT_USERS_DETAIL     TO ROLE_AUDITEUR;
GRANT SELECT ON CYT_NETWORKPORTS     TO ROLE_AUDITEUR;
GRANT SELECT ON CYT_PORT_LINKS       TO ROLE_AUDITEUR;
GRANT SELECT ON CYT_NETEQUIP         TO ROLE_AUDITEUR;
GRANT SELECT ON CYT_NETWORKS         TO ROLE_AUDITEUR;
GRANT SELECT ON CYT_AUDIT_LOG        TO ROLE_AUDITEUR;
GRANT SELECT ON CYT_ASSET_TRANSFER   TO ROLE_AUDITEUR;
GRANT SELECT ON CYT_ENTITIES         TO ROLE_AUDITEUR;
GRANT SELECT ON CYT_LOCATIONS        TO ROLE_AUDITEUR;
GRANT SELECT ON CYT_GROUPS           TO ROLE_AUDITEUR;
GRANT SELECT ON CYT_GROUPS_USERS     TO ROLE_AUDITEUR;
GRANT SELECT ON CYT_IPADDRESSES      TO ROLE_AUDITEUR;
GRANT SELECT ON CYT_INFOCOMS         TO ROLE_AUDITEUR;
GRANT SELECT ON CYT_PROFILES         TO ROLE_AUDITEUR;

-- ── ROLE_APPLI_GLPI ───────────────────────────────────────────────────────────
-- Compte applicatif : DML complet (utilisé par les DBLinks depuis Cergy)
-- Note : APPLI_GLPI étant propriétaire, il a déjà tous les droits sur ses tables
-- Ce GRANT est pour les connexions entrantes via DBLink depuis Pau si besoin

-- Vérification finale
SELECT grantee, table_name, privilege
FROM   user_tab_privs_made   -- vue du propriétaire : droits accordés par moi
ORDER BY grantee, table_name, privilege;
