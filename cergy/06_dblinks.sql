-- =============================================================================
-- FICHIER  : cergy/06_dblinks.sql
-- INSTANCE : oracle_cergy (container Docker, port externe 1523)
-- NOTION   : Database Links (BDDR)
-- OBJECTIF : Communication Cergy → Pau pour UC03, UC06, UC07, UC08
--
-- SETUP DOCKER (d'après docker-compose.yml) :
--   container Cergy : oracle_cergy  → port externe 1523, interne 1521
--   container Pau   : oracle_pau    → port externe 1522, interne 1521
--   réseau Docker   : cine_net (bridge)
--   SERVICE_NAME    : FREEPDB1 (image gvenzl/oracle-free)
--   password sys    : OracleHomeUser1
--
-- CONNEXION pour exécuter ce fichier :
--   docker exec -it oracle_cergy sqlplus system/OracleHomeUser1@//localhost:1521/FREEPDB1
-- =============================================================================

-- DBLink applicatif : UC06 (sync users) + UC07 (transfert PC)
-- HOST = nom du container dans cine_net (résolution Docker interne)
CREATE DATABASE LINK DBLINK_PAU
  CONNECT TO APPLI_GLPI IDENTIFIED BY "AppGLPI_2026!"
  USING '(DESCRIPTION=
           (ADDRESS=(PROTOCOL=TCP)(HOST=oracle_pau)(PORT=1521))
           (CONNECT_DATA=(SERVICE_NAME=FREEPDB1)))';

-- DBLink lecture seule : UC08 (audit conformité)
CREATE DATABASE LINK DBLINK_PAU_RO
  CONNECT TO AUDITEUR_PAU IDENTIFIED BY "Audit_Pau_2026!"
  USING '(DESCRIPTION=
           (ADDRESS=(PROTOCOL=TCP)(HOST=oracle_pau)(PORT=1521))
           (CONNECT_DATA=(SERVICE_NAME=FREEPDB1)))';

-- Tests de validation
SELECT 'PING PAU OK' AS test, SYSDATE AS date_test FROM DUAL@DBLINK_PAU;
SELECT 'DBLINK_PAU OK'    AS test, COUNT(*) AS nb FROM CYT_COMPUTERS@DBLINK_PAU;
SELECT 'DBLINK_PAU_RO OK' AS test, COUNT(*) AS nb FROM CYT_USERS@DBLINK_PAU_RO;
