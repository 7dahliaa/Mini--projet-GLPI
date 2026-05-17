-- -----------------------------------------------------------------------------
-- Connexion : AUDITEUR_PAU / Audit_Pau_2026! (localhost:1522 - oracle_pau)
-- Rôle      : ROLE_AUDITEUR_PAU
-- Objectif  : Lecture seule Pau + Compte cible pour DBLINK_PAU_RO (UC08)
-- -----------------------------------------------------------------------------
SET SERVEROUTPUT ON;
SET LINESIZE 120;
SET PAGESIZE 20;

PROMPT ================================================
PROMPT  AUDITEUR_PAU -- Role : ROLE_AUDITEUR_PAU
PROMPT  Lecture seule Pau + compte DBLINK_PAU_RO
PROMPT ================================================

-- 1. Privilèges de lecture (Actions autorisées)
PROMPT
PROMPT [OK] SELECT PC Pau :
SELECT COUNT(*) AS nb_pc FROM APPLI_GLPI.CYT_COMPUTERS WHERE is_deleted=0;

PROMPT
PROMPT [OK] SELECT audit log Pau :
SELECT table_name, operation, log_date
FROM   APPLI_GLPI.CYT_AUDIT_LOG
WHERE  ROWNUM <= 5
ORDER BY log_date DESC;

PROMPT
PROMPT [OK] SELECT users Pau :
SELECT COUNT(*) AS nb_users FROM APPLI_GLPI.CYT_USERS;

PROMPT
PROMPT [OK] SELECT ports reseau Pau :
SELECT COUNT(*) AS nb_ports FROM APPLI_GLPI.CYT_NETWORKPORTS;


-- 2. Tests de sécurité (Actions interdites)
PROMPT
PROMPT [INTERDIT] INSERT -> interdit :
BEGIN
  EXECUTE IMMEDIATE 'INSERT INTO APPLI_GLPI.CYT_COMPUTERS
    (serial, computer_name, entity_id) VALUES (''TEST'',''TEST'',1)';
EXCEPTION
  WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('  INSERT interdit : ' || SQLERRM);
END;
/

PROMPT
PROMPT [INTERDIT] UPDATE -> interdit :
BEGIN
  EXECUTE IMMEDIATE 'UPDATE APPLI_GLPI.CYT_COMPUTERS
    SET status=''HORS_SERVICE'' WHERE ROWNUM=1';
EXCEPTION
  WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('  UPDATE interdit : ' || SQLERRM);
END;
/

PROMPT
PROMPT [INTERDIT] DELETE -> interdit :
BEGIN
  EXECUTE IMMEDIATE 'DELETE FROM APPLI_GLPI.CYT_COMPUTERS WHERE ROWNUM=1';
EXCEPTION
  WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('  DELETE interdit : ' || SQLERRM);
END;
/


-- 3. Note pour la soutenance
PROMPT
PROMPT ================================================
PROMPT  Fin des tests AUDITEUR_PAU
PROMPT  Bilan : lecture seule Pau / ecriture impossible
PROMPT          compte utilise pour UC08 (audit depuis Cergy)
PROMPT ================================================

PROMPT ================================================
PROMPT  FIN DES TESTS - AUDITEUR_PAU
PROMPT  Bilan : Lecture seule validee / Ecritures impossibles
PROMPT ================================================