-- Création du lien vers la base de données de Pau
-- On se connecte avec le compte de l'application GLPI
CREATE DATABASE LINK DBLINK_PAU
  CONNECT TO APPLI_GLPI IDENTIFIED BY "AppGLPI_2026!"
  USING '(DESCRIPTION=
           (ADDRESS=(PROTOCOL=TCP)(HOST=oracle_pau)(PORT=1521))
           (CONNECT_DATA=(SERVICE_NAME=FREEPDB1)))';

-- Création d'un deuxième lien pour les audits (RO = Read Only / lecture seule)
-- C'est le même serveur mais on utilise le compte auditeur
CREATE DATABASE LINK DBLINK_PAU_RO
  CONNECT TO AUDITEUR_PAU IDENTIFIED BY "Audit_Pau_2026!"
  USING '(DESCRIPTION=
           (ADDRESS=(PROTOCOL=TCP)(HOST=oracle_pau)(PORT=1521))
           (CONNECT_DATA=(SERVICE_NAME=FREEPDB1)))';

-- Tests de validation pour vérifier que les liens marchent bien
-- Test 1 : Petit ping basique pour voir si le serveur distant répond
SELECT 'PING PAU OK' AS test, SYSDATE AS date_test FROM DUAL@DBLINK_PAU;

-- Test 2 : On compte les PC pour voir si le premier lien a bien accès aux tables
SELECT 'DBLINK_PAU OK'    AS test, COUNT(*) AS nb FROM CYT_COMPUTERS@DBLINK_PAU;

-- Test 3 : On vérifie l'accès du lien en lecture seule sur la table des utilisateurs
SELECT 'DBLINK_PAU_RO OK' AS test, COUNT(*) AS nb FROM CYT_USERS@DBLINK_PAU_RO;
