-- -----------------------------------------------------------------------------
-- Connexion : AUDITEUR / Audit_CyTech_2026!
-- Rôle      : ROLE_AUDITEUR
-- Objectif  : Lecture seule globale (Tables Cergy + Vues fédérées et MV)
-- -----------------------------------------------------------------------------
SET SERVEROUTPUT ON;
SET LINESIZE 120;
SET PAGESIZE 20;

PROMPT ================================================
PROMPT  AUDITEUR -- Role : ROLE_AUDITEUR (lecture seule)
PROMPT ================================================

-- 1. Privilèges de lecture (Actions autorisées)
PROMPT
PROMPT [OK] SELECT PC Cergy :
SELECT COUNT(*) AS nb_pc FROM APPLI_GLPI.CYT_COMPUTERS WHERE is_deleted=0;

PROMPT
PROMPT [OK] SELECT audit log (5 derniers) :
SELECT table_name, operation, log_date
FROM   APPLI_GLPI.CYT_AUDIT_LOG
WHERE  ROWNUM <= 5
ORDER BY log_date DESC;

PROMPT
PROMPT [OK] SELECT vue globale Cergy + Pau :
SELECT site, COUNT(*) nb FROM APPLI_GLPI.V_GLOBAL_COMPUTERS GROUP BY site ORDER BY site;

PROMPT
PROMPT [OK] SELECT vue reseau :
SELECT pc_name, switch_name, vlan_name
FROM   APPLI_GLPI.V_NETWORK_MAPPING WHERE ROWNUM <= 3;

PROMPT
PROMPT [OK] SELECT MV snapshot :
SELECT site, COUNT(*) nb FROM APPLI_GLPI.MV_INVENTORY_GLOBAL GROUP BY site;


-- 2. Tests de sécurité (Actions interdites - ORA-01031 attendu)
PROMPT
PROMPT [INTERDIT] INSERT -> ORA-01031 attendu :
BEGIN
  EXECUTE IMMEDIATE 'INSERT INTO APPLI_GLPI.CYT_COMPUTERS
    (serial, computer_name, entity_id) VALUES (''TEST'',''TEST'',1)';
EXCEPTION
  WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('  INSERT interdit : ' || SQLERRM);
END;
/

PROMPT
PROMPT [INTERDIT] UPDATE -> ORA-01031 attendu :
BEGIN
  EXECUTE IMMEDIATE 'UPDATE APPLI_GLPI.CYT_COMPUTERS
    SET status=''HORS_SERVICE'' WHERE ROWNUM=1';
EXCEPTION
  WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('  UPDATE interdit : ' || SQLERRM);
END;
/

PROMPT
PROMPT [INTERDIT] DELETE -> ORA-01031 attendu :
BEGIN
  EXECUTE IMMEDIATE 'DELETE FROM APPLI_GLPI.CYT_USERS WHERE ROWNUM=1';
EXCEPTION
  WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('  DELETE interdit : ' || SQLERRM);
END;
/

PROMPT
PROMPT [INTERDIT] DROP TABLE -> ORA-01031 attendu :
BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE APPLI_GLPI.CYT_COMPUTERS';
EXCEPTION
  WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('  DROP TABLE interdit : ' || SQLERRM);
END;
/

PROMPT
PROMPT ================================================
PROMPT  Fin des tests AUDITEUR
PROMPT  Bilan : SELECT partout / ecriture impossible
PROMPT ================================================