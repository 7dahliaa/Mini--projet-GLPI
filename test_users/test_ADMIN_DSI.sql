-- =============================================================================
-- CONNEXION : ADMIN_DSI / DSI_CyTech_2026!
-- ROLE      : ROLE_DSI_ADMIN
-- OBJECTIF  : Vision globale Cergy + Pau, tous droits
-- =============================================================================
SET SERVEROUTPUT ON;
SET LINESIZE 120;
PROMPT ================================================
PROMPT  ADMIN_DSI — Role : ROLE_DSI_ADMIN (tous droits)
PROMPT ================================================

PROMPT
PROMPT [OK] Vision globale Cergy + Pau :
SELECT site, COUNT(*) AS nb_pc,
       SUM(CASE WHEN status='ACTIF' THEN 1 ELSE 0 END) AS actifs
FROM   APPLI_GLPI.V_GLOBAL_COMPUTERS
GROUP BY site ORDER BY site;

PROMPT
PROMPT [OK] MV Inventory Global (snapshot) :
SELECT COUNT(*) AS total FROM APPLI_GLPI.MV_INVENTORY_GLOBAL;

PROMPT
PROMPT [OK] Audit recent :
SELECT table_name, operation, user_db, log_date
FROM   APPLI_GLPI.V_AUDIT_RECENT WHERE ROWNUM<=5;

PROMPT
PROMPT [OK] F_COUNT_ASSETS (fonction analytique) :
SELECT APPLI_GLPI.F_COUNT_ASSETS('CERGY')           AS total_cergy,
       APPLI_GLPI.F_COUNT_ASSETS('CERGY','ACTIF')   AS actifs_cergy
FROM   DUAL;
PROMPT ================================================
