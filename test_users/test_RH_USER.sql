-- -----------------------------------------------------------------------------
-- Connexion : RH_USER / RH_CyTech_2026!
-- Rôle      : ROLE_RH
-- Objectif  : Gestion des utilisateurs uniquement (DML ciblé sur CYT_USERS)
-- -----------------------------------------------------------------------------
SET SERVEROUTPUT ON;
SET LINESIZE 120;
SET PAGESIZE 20;

PROMPT ================================================
PROMPT  RH_USER -- Role : ROLE_RH
PROMPT ================================================

-- 1. Actions autorisées (Consultation et modification des données utilisateurs)
PROMPT
PROMPT [OK] SELECT utilisateurs :
SELECT user_id, login, realname, is_active
FROM   APPLI_GLPI.CYT_USERS WHERE ROWNUM <= 5;

PROMPT
PROMPT [OK] INSERT un nouvel utilisateur -- État initial :
SELECT COUNT(*) AS nb_users FROM APPLI_GLPI.CYT_USERS;

DECLARE
  v_login VARCHAR2(50) := 'rh_demo_' || TO_CHAR(SYSDATE,'MI');
BEGIN
  INSERT INTO APPLI_GLPI.CYT_USERS (
    login, password_hash, realname, firstname, entity_id, profile_id, is_active
  ) VALUES (v_login, 'hash_demo', 'DEMO', 'RH', 1, 2, 1);
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('  User insere : ' || v_login);
END;
/

PROMPT APRES INSERT :
SELECT COUNT(*) AS nb_users FROM APPLI_GLPI.CYT_USERS;

PROMPT
PROMPT [OK] UPDATE is_active d un utilisateur -- AVANT :
SELECT user_id, login, is_active
FROM   APPLI_GLPI.CYT_USERS WHERE ROWNUM=1;

UPDATE APPLI_GLPI.CYT_USERS SET is_active=0
WHERE  user_id=(SELECT MIN(user_id) FROM APPLI_GLPI.CYT_USERS);
COMMIT;

PROMPT APRES UPDATE :
SELECT user_id, login, is_active
FROM   APPLI_GLPI.CYT_USERS WHERE ROWNUM=1;

-- Rétablissement de l'état initial pour laisser l'environnement propre
UPDATE APPLI_GLPI.CYT_USERS SET is_active=1
WHERE  user_id=(SELECT MIN(user_id) FROM APPLI_GLPI.CYT_USERS);
COMMIT;
PROMPT Remis en is_active=1.


-- 2. Tests de sécurité (Contrôle strict des restrictions d'accès)
PROMPT
PROMPT [INTERDIT] SELECT sur CYT_COMPUTERS -> interdit :
BEGIN
  EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM APPLI_GLPI.CYT_COMPUTERS';
EXCEPTION
  WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('  CYT_COMPUTERS interdit : ' || SQLERRM);
END;
/

PROMPT
PROMPT [INTERDIT] DELETE sur CYT_USERS -> interdit :
BEGIN
  EXECUTE IMMEDIATE 'DELETE FROM APPLI_GLPI.CYT_USERS WHERE ROWNUM=1';
EXCEPTION
  WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('  DELETE interdit : ' || SQLERRM);
END;
/

PROMPT
PROMPT [INTERDIT] DROP TABLE -> ORA-01031 attendu :
BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE APPLI_GLPI.CYT_USERS';
EXCEPTION
  WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('  DROP TABLE interdit : ' || SQLERRM);
END;
/

PROMPT
PROMPT ================================================
PROMPT  Fin des tests RH_USER
PROMPT  Bilan : DML users ok / assets inaccessibles
PROMPT ================================================