-- =============================================================================
-- FICHIER  : pau/02b_grants.sql
-- EXECUTÉ  : par APPLI_GLPI (propriétaire des tables Pau)
-- NOTION   : GRANTs sur objets côté Pau
-- =============================================================================

-- ── ROLE_TECH_PAU ─────────────────────────────────────────────────────────────
-- Technicien Pau : DML sur les assets, SELECT sur les référentiels
GRANT SELECT, INSERT, UPDATE ON CYT_COMPUTERS        TO ROLE_TECH_PAU;
GRANT SELECT, INSERT, UPDATE ON CYT_COMPUTERS_DETAIL TO ROLE_TECH_PAU;
GRANT SELECT, INSERT, UPDATE ON CYT_LOCATIONS        TO ROLE_TECH_PAU;
GRANT SELECT, INSERT, UPDATE ON CYT_NETWORKPORTS     TO ROLE_TECH_PAU;
GRANT SELECT, INSERT, UPDATE ON CYT_NETEQUIP         TO ROLE_TECH_PAU;
GRANT SELECT, INSERT, UPDATE ON CYT_IPADDRESSES      TO ROLE_TECH_PAU;
GRANT SELECT                 ON CYT_ENTITIES         TO ROLE_TECH_PAU;
GRANT SELECT                 ON CYT_MANUFACTURERS    TO ROLE_TECH_PAU;
GRANT SELECT                 ON CYT_NETWORKS         TO ROLE_TECH_PAU;
GRANT SELECT                 ON CYT_USERS            TO ROLE_TECH_PAU;

-- ── ROLE_AUDITEUR_PAU ─────────────────────────────────────────────────────────
-- Auditeur local Pau : lecture seule via connexion directe
GRANT SELECT ON CYT_COMPUTERS    TO ROLE_AUDITEUR_PAU;
GRANT SELECT ON CYT_USERS        TO ROLE_AUDITEUR_PAU;
GRANT SELECT ON CYT_AUDIT_LOG    TO ROLE_AUDITEUR_PAU;
GRANT SELECT ON CYT_NETWORKPORTS TO ROLE_AUDITEUR_PAU;
GRANT SELECT ON CYT_NETEQUIP     TO ROLE_AUDITEUR_PAU;
GRANT SELECT ON CYT_ENTITIES     TO ROLE_AUDITEUR_PAU;
GRANT SELECT ON CYT_LOCATIONS    TO ROLE_AUDITEUR_PAU;
GRANT SELECT ON CYT_IPADDRESSES  TO ROLE_AUDITEUR_PAU;

-- ── GRANTs DIRECTS pour AUDITEUR_PAU ─────────────────────────────────────────
-- UC08 : Audit de conformité depuis Cergy via DBLINK_PAU_RO
-- Les privilèges via rôle ne sont pas propagés dans les connexions DBLink
-- (comportement Oracle standard). Les GRANTs directs SELECT sont nécessaires
-- pour que AUDITEUR_PAU puisse lire les tables via DBLINK_PAU_RO depuis Cergy.
-- AUDITEUR_PAU ne reçoit que SELECT — lecture seule garantie.
GRANT SELECT ON CYT_COMPUTERS        TO AUDITEUR_PAU;
GRANT SELECT ON CYT_COMPUTERS_DETAIL TO AUDITEUR_PAU;
GRANT SELECT ON CYT_USERS            TO AUDITEUR_PAU;
GRANT SELECT ON CYT_USERS_DETAIL     TO AUDITEUR_PAU;
GRANT SELECT ON CYT_AUDIT_LOG        TO AUDITEUR_PAU;
GRANT SELECT ON CYT_NETWORKPORTS     TO AUDITEUR_PAU;
GRANT SELECT ON CYT_NETEQUIP         TO AUDITEUR_PAU;
GRANT SELECT ON CYT_ENTITIES         TO AUDITEUR_PAU;
GRANT SELECT ON CYT_LOCATIONS        TO AUDITEUR_PAU;
GRANT SELECT ON CYT_IPADDRESSES      TO AUDITEUR_PAU;
GRANT SELECT ON CYT_NETWORKS         TO AUDITEUR_PAU;

-- Vérification
SELECT grantee, table_name, privilege
FROM   user_tab_privs_made
ORDER BY grantee, table_name, privilege;