-- =============================================================================
-- CONNEXION : AUDITEUR / Audit_CyTech_2026!
-- ROLE      : ROLE_AUDITEUR
-- OBJECTIF  : Lecture seule sur tout Cergy
-- =============================================================================
SET SERVEROUTPUT ON;
SET LINESIZE 120;
PROMPT ================================================
PROMPT  AUDITEUR — Role : ROLE_AUDITEUR (lecture seule)
PROMPT ================================================

-- CE QU'IL PEUT FAIRE
PROMPT
PROMPT [OK] SELECT PC Cergy :
SELECT COUNT(*) AS nb_pc FROM APPLI_GLPI.CYT_COMPUTERS WHERE is_deleted=0;

PROMPT
PROMPT [OK] SELECT audit log :
SELECT table_name, operation, log_date
FROM   APPLI_GLPI.CYT_AUDIT_LOG WHERE ROWNUM<=5 ORDER BY log_date DESC;

PROMPT
PROMPT [OK] SELECT vue globale :
SELECT site, COUNT(*) nb FROM APPLI_GLPI.V_GLOBAL_COMPUTERS GROUP BY site;

-- CE QU'IL NE PEUT PAS FAIRE
PROMPT
PROMPT [INTERDIT] INSERT -> ORA-01031 attendu :
BEGIN
  INSERT INTO APPLI_GLPI.CYT_COMPUTERS (serial, computer_name, entity_id, profile_id)
  VALUES ('TEST','TEST',1,1);
EXCEPTION
  WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('INSERT interdit : ' || SQLERRM);
END;
/

PROMPT
PROMPT [INTERDIT] UPDATE -> ORA-01031 attendu :
BEGIN
  UPDATE APPLI_GLPI.CYT_COMPUTERS SET status='HORS_SERVICE' WHERE ROWNUM=1;
EXCEPTION
  WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('UPDATE interdit : ' || SQLERRM);
END;
/

PROMPT
PROMPT [INTERDIT] DELETE -> ORA-01031 attendu :
BEGIN
  DELETE FROM APPLI_GLPI.CYT_USERS WHERE ROWNUM=1;
EXCEPTION
  WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('DELETE interdit : ' || SQLERRM);
END;
/
PROMPT ================================================
