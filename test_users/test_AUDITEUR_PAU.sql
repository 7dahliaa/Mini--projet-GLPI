-- =============================================================================
-- CONNEXION : AUDITEUR_PAU / Audit_Pau_2026!
-- PORT      : localhost:1522 (oracle_pau)
-- ROLE      : ROLE_AUDITEUR_PAU
-- OBJECTIF  : Lecture seule Pau + utilisé par DBLINK_PAU_RO depuis Cergy (UC08)
-- LANCER    : @test_users/test_AUDITEUR_PAU.sql
-- =============================================================================
SET SERVEROUTPUT ON;
SET LINESIZE 120;
SET PAGESIZE 20;

PROMPT ================================================
PROMPT  AUDITEUR_PAU -- Role : ROLE_AUDITEUR_PAU
PROMPT  Lecture seule Pau + compte DBLINK_PAU_RO
PROMPT ================================================

-- ── CE QU'IL PEUT FAIRE ──────────────────────────────────────────────────────
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

-- ── CE QU'IL NE PEUT PAS FAIRE ───────────────────────────────────────────────
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

PROMPT
PROMPT [INFO] Ce compte est aussi utilise par DBLINK_PAU_RO depuis Cergy (UC08)
PROMPT        Cergy lit APPLI_GLPI.CYT_COMPUTERS@DBLINK_PAU_RO en lecture seule

PROMPT
PROMPT ================================================
PROMPT  Fin des tests AUDITEUR_PAU
PROMPT  Bilan : lecture seule Pau / ecriture impossible
PROMPT          compte utilise pour UC08 (audit depuis Cergy)
PROMPT ================================================
