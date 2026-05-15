-- =============================================================================
-- CONNEXION : TECH_CERGY1 / Tech1_Cergy_2026!
-- ROLE      : ROLE_TECH_CERGY
-- OBJECTIF  : Démonstration droits technicien site Cergy
-- LANCER    : @test_users/test_TECH_CERGY1.sql
-- =============================================================================
SET SERVEROUTPUT ON;
SET LINESIZE 120;
SET PAGESIZE 20;

PROMPT ================================================
PROMPT  TECH_CERGY1 -- Role : ROLE_TECH_CERGY
PROMPT ================================================

-- ── SELECT : voir les PC ─────────────────────────────────────────────────────
PROMPT
PROMPT [OK] SELECT sur les PC Cergy :

SELECT computer_id, computer_name, status
FROM   APPLI_GLPI.CYT_COMPUTERS
WHERE  ROWNUM <= 3
ORDER BY computer_id;

-- ── INSERT : ajouter une localisation ────────────────────────────────────────
PROMPT
PROMPT [OK] INSERT une nouvelle localisation :

INSERT INTO APPLI_GLPI.CYT_LOCATIONS (entity_id, location_name, building, room)
VALUES (1, 'Salle TEST TECH', 'Bat-Test', 'S99');
COMMIT;

PROMPT Verification apres INSERT :
SELECT location_id, location_name, building, room
FROM   APPLI_GLPI.CYT_LOCATIONS
WHERE  location_name = 'Salle TEST TECH';

-- ── UPDATE : modifier le statut d'un PC ──────────────────────────────────────
PROMPT
PROMPT [OK] UPDATE statut d un PC -- AVANT :

SELECT computer_id, computer_name, status
FROM   APPLI_GLPI.CYT_COMPUTERS
WHERE  computer_id = (SELECT MIN(computer_id) FROM APPLI_GLPI.CYT_COMPUTERS);

UPDATE APPLI_GLPI.CYT_COMPUTERS
SET    status = 'EN_REPARATION'
WHERE  computer_id = (SELECT MIN(computer_id) FROM APPLI_GLPI.CYT_COMPUTERS);
COMMIT;

PROMPT APRES update :
SELECT computer_id, computer_name, status
FROM   APPLI_GLPI.CYT_COMPUTERS
WHERE  computer_id = (SELECT MIN(computer_id) FROM APPLI_GLPI.CYT_COMPUTERS);

-- Remise en etat
UPDATE APPLI_GLPI.CYT_COMPUTERS SET status = 'ACTIF'
WHERE  computer_id = (SELECT MIN(computer_id) FROM APPLI_GLPI.CYT_COMPUTERS);
COMMIT;
PROMPT Remis en ACTIF.

-- ── CE QU'IL NE PEUT PAS FAIRE ───────────────────────────────────────────────
PROMPT
PROMPT [INTERDIT] DROP TABLE -> ORA-01031 attendu :
BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE APPLI_GLPI.CYT_COMPUTERS';
EXCEPTION
  WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('  DROP TABLE interdit : ' || SQLERRM);
END;
/

PROMPT
PROMPT [INTERDIT] DELETE sur CYT_ENTITIES -> ORA-01031 attendu :
BEGIN
  EXECUTE IMMEDIATE 'DELETE FROM APPLI_GLPI.CYT_ENTITIES';
EXCEPTION
  WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('  DELETE ENTITIES interdit : ' || SQLERRM);
END;
/

PROMPT
PROMPT [INTERDIT] DELETE sur CYT_LOCATIONS -> ORA-41900 attendu :
BEGIN
  EXECUTE IMMEDIATE 'DELETE FROM APPLI_GLPI.CYT_LOCATIONS WHERE location_name=''Salle TEST TECH''';
  DBMS_OUTPUT.PUT_LINE('  DELETE effectue (inattendu)');
EXCEPTION
  WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('  DELETE LOCATIONS interdit : ' || SQLERRM);
END;
/

PROMPT
PROMPT [INTERDIT] Acces DBLink Pau -> ORA-02019 attendu :
BEGIN
  DECLARE v NUMBER;
  BEGIN
    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM APPLI_GLPI.CYT_COMPUTERS@DBLINK_PAU' INTO v;
    DBMS_OUTPUT.PUT_LINE('  DBLink accessible : ' || v);
  EXCEPTION
    WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('  DBLink interdit (attendu) : ' || SQLERRM);
  END;
END;
/

PROMPT
PROMPT ================================================
PROMPT  Fin des tests pour TECH_CERGY1
PROMPT  Nettoyage : se reconnecter en APPLI_GLPI pour
PROMPT  supprimer la localisation test si necessaire
PROMPT ================================================