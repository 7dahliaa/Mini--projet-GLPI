-- -----------------------------------------------------------------------------
-- Connexion : TECH_PAU1 / Tech1_Pau_2026! (localhost:1522 - oracle_pau)
-- Rôle      : ROLE_TECH_PAU
-- Objectif  : Démonstration des privilèges du technicien sur le site de Pau
-- -----------------------------------------------------------------------------
SET SERVEROUTPUT ON;
SET LINESIZE 120;
SET PAGESIZE 20;

PROMPT ================================================
PROMPT  TECH_PAU1 -- Role : ROLE_TECH_PAU (site Pau)
PROMPT ================================================

-- 1. Privilèges locaux (Actions autorisées)
PROMPT
PROMPT [OK] SELECT PC Pau (autonome) :
SELECT computer_id, computer_name, status
FROM   APPLI_GLPI.CYT_COMPUTERS
WHERE  ROWNUM <= 3
ORDER BY computer_id;

PROMPT
PROMPT [OK] Nombre total de PC sur Pau :
SELECT COUNT(*) AS nb_pc_pau FROM APPLI_GLPI.CYT_COMPUTERS WHERE is_deleted=0;

PROMPT
PROMPT [OK] UPDATE statut d un PC Pau -- AVANT :
SELECT computer_id, computer_name, status
FROM   APPLI_GLPI.CYT_COMPUTERS
WHERE  computer_id=(SELECT MIN(computer_id) FROM APPLI_GLPI.CYT_COMPUTERS);

UPDATE APPLI_GLPI.CYT_COMPUTERS
SET    status='EN_REPARATION'
WHERE  computer_id=(SELECT MIN(computer_id) FROM APPLI_GLPI.CYT_COMPUTERS);
COMMIT;

PROMPT APRES UPDATE :
SELECT computer_id, computer_name, status
FROM   APPLI_GLPI.CYT_COMPUTERS
WHERE  computer_id=(SELECT MIN(computer_id) FROM APPLI_GLPI.CYT_COMPUTERS);

-- Rétablissement de l'état initial pour laisser l'environnement propre
UPDATE APPLI_GLPI.CYT_COMPUTERS SET status='ACTIF'
WHERE  computer_id=(SELECT MIN(computer_id) FROM APPLI_GLPI.CYT_COMPUTERS);
COMMIT;
PROMPT Remis en ACTIF.

PROMPT
PROMPT [OK] SELECT utilisateurs Pau :
SELECT user_id, login, is_active
FROM   APPLI_GLPI.CYT_USERS WHERE ROWNUM <= 3;

-- 2. Tests de sécurité (Actions interdites)
PROMPT
PROMPT [INTERDIT] DROP TABLE -> ORA-01031 attendu :
BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE APPLI_GLPI.CYT_COMPUTERS';
EXCEPTION
  WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('  DROP TABLE interdit : ' || SQLERRM);
END;
/

PROMPT
PROMPT [INTERDIT] DELETE sur CYT_ENTITIES -> interdit :
BEGIN
  EXECUTE IMMEDIATE 'DELETE FROM APPLI_GLPI.CYT_ENTITIES';
EXCEPTION
  WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('  DELETE ENTITIES interdit : ' || SQLERRM);
END;
/

PROMPT
PROMPT [UC09] Pau est autonome - donnees locales completes :
SELECT 'COMPUTERS'   t, COUNT(*) n FROM APPLI_GLPI.CYT_COMPUTERS   UNION ALL
SELECT 'USERS',         COUNT(*) FROM APPLI_GLPI.CYT_USERS          UNION ALL
SELECT 'NETWORKPORTS',  COUNT(*) FROM APPLI_GLPI.CYT_NETWORKPORTS;

PROMPT
PROMPT ================================================
PROMPT  Fin des tests TECH_PAU1
PROMPT  Bilan : Pau autonome / memes droits que Cergy
PROMPT          mais isole sur son instance locale
PROMPT ================================================