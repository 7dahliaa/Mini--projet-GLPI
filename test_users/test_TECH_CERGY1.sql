-- =============================================================================
-- CONNEXION : TECH_CERGY1 / Tech1_Cergy_2026!
-- ROLE      : ROLE_TECH_CERGY
-- OBJECTIF  : Technicien site Cergy - gestion des assets locaux
-- LANCER    : @test_TECH_CERGY1.sql depuis SQLPlus connecte en TECH_CERGY1
-- =============================================================================
SET SERVEROUTPUT ON;
SET LINESIZE 120;
PROMPT ================================================
PROMPT  TECH_CERGY1 — Role : ROLE_TECH_CERGY
PROMPT ================================================

-- CE QU'IL PEUT FAIRE
PROMPT
PROMPT [OK] SELECT sur les PC Cergy :
SELECT computer_id, computer_name, status FROM APPLI_GLPI.CYT_COMPUTERS WHERE ROWNUM<=3;

PROMPT
PROMPT [OK] INSERT une nouvelle localisation :
INSERT INTO APPLI_GLPI.CYT_LOCATIONS (entity_id, location_name, building, room)
VALUES (1, 'Salle TEST', 'Bat-Test', 'S00');
COMMIT;
DBMS_OUTPUT.PUT_LINE('INSERT localisation : OK');

PROMPT
PROMPT [OK] UPDATE statut d''un PC :
UPDATE APPLI_GLPI.CYT_COMPUTERS SET status='EN_STOCK'
WHERE computer_id=(SELECT MIN(computer_id) FROM APPLI_GLPI.CYT_COMPUTERS);
COMMIT;
SELECT computer_id, status FROM APPLI_GLPI.CYT_COMPUTERS WHERE status='EN_STOCK' AND ROWNUM=1;

-- Remise en etat
UPDATE APPLI_GLPI.CYT_COMPUTERS SET status='ACTIF'
WHERE computer_id=(SELECT MIN(computer_id) FROM APPLI_GLPI.CYT_COMPUTERS);
COMMIT;
DELETE FROM APPLI_GLPI.CYT_LOCATIONS WHERE location_name='Salle TEST';
COMMIT;

-- CE QU'IL NE PEUT PAS FAIRE
PROMPT
PROMPT [INTERDIT] DROP TABLE -> ORA-01031 attendu :
BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE APPLI_GLPI.CYT_COMPUTERS';
EXCEPTION
  WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('DROP TABLE interdit : ' || SQLERRM);
END;
/

PROMPT
PROMPT [INTERDIT] DELETE sur CYT_ENTITIES -> ORA-01031 attendu :
BEGIN
  DELETE FROM APPLI_GLPI.CYT_ENTITIES;
EXCEPTION
  WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('DELETE ENTITIES interdit : ' || SQLERRM);
END;
/

PROMPT
PROMPT [INTERDIT] Acces DBLink Pau -> ORA-02019 attendu :
BEGIN
  DECLARE v NUMBER;
  BEGIN
    SELECT COUNT(*) INTO v FROM APPLI_GLPI.CYT_COMPUTERS@DBLINK_PAU;
    DBMS_OUTPUT.PUT_LINE('DBLink accessible : ' || v);
  EXCEPTION
    WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('DBLink interdit : ' || SQLERRM);
  END;
END;
/
PROMPT ================================================
