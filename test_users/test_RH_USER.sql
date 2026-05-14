-- =============================================================================
-- CONNEXION : RH_USER / RH_CyTech_2026!
-- ROLE      : ROLE_RH
-- OBJECTIF  : Service RH - gestion utilisateurs uniquement
-- =============================================================================
SET SERVEROUTPUT ON;
SET LINESIZE 120;
PROMPT ================================================
PROMPT  RH_USER — Role : ROLE_RH
PROMPT ================================================

-- CE QU'IL PEUT FAIRE
PROMPT
PROMPT [OK] SELECT utilisateurs :
SELECT user_id, login, realname, is_active
FROM   APPLI_GLPI.CYT_USERS WHERE ROWNUM<=5;

PROMPT
PROMPT [OK] INSERT un nouvel utilisateur :
INSERT INTO APPLI_GLPI.CYT_USERS (login, password_hash, realname, firstname, entity_id, profile_id, is_active)
VALUES ('test_rh_demo', 'hash_demo', 'DEMO', 'RH', 1, 2, 1);
COMMIT;
SELECT user_id, login FROM APPLI_GLPI.CYT_USERS WHERE login='test_rh_demo';

-- Nettoyage
DELETE FROM APPLI_GLPI.CYT_USERS WHERE login='test_rh_demo';
COMMIT;

-- CE QU'IL NE PEUT PAS FAIRE
PROMPT
PROMPT [INTERDIT] SELECT sur CYT_COMPUTERS -> ORA-01031 attendu :
BEGIN
  DECLARE v NUMBER;
  BEGIN
    SELECT COUNT(*) INTO v FROM APPLI_GLPI.CYT_COMPUTERS;
    DBMS_OUTPUT.PUT_LINE('Acces CYT_COMPUTERS : ' || v);
  EXCEPTION
    WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('CYT_COMPUTERS interdit : ' || SQLERRM);
  END;
END;
/

PROMPT
PROMPT [INTERDIT] DROP TABLE -> ORA-01031 attendu :
BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE APPLI_GLPI.CYT_USERS';
EXCEPTION
  WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('DROP TABLE interdit : ' || SQLERRM);
END;
/
PROMPT ================================================
