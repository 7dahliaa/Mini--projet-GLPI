-- -----------------------------------------------------------------------------
-- Connexion : ADMIN_DSI / DSI_CyTech_2026!
-- Rôle      : ROLE_DSI_ADMIN (Full privilèges)
-- Objectif  : Validation des accès DSI — Vision globale Cergy + Pau
-- -----------------------------------------------------------------------------
SET SERVEROUTPUT ON;
SET LINESIZE 120;
PROMPT ================================================
PROMPT  ADMIN_DSI — Role : ROLE_DSI_ADMIN (tous droits)
PROMPT ================================================

-- 1. Vérification de la vue fédérée (Temps réel via DBLink)
PROMPT
PROMPT [OK] Vision globale Cergy + Pau :
SELECT site, COUNT(*) AS nb_pc,
       SUM(CASE WHEN status='ACTIF' THEN 1 ELSE 0 END) AS actifs
FROM   APPLI_GLPI.V_GLOBAL_COMPUTERS
GROUP BY site ORDER BY site;

-- 2. Vérification du snapshot local (Vue Matérialisée)
PROMPT
PROMPT [OK] MV Inventory Global (snapshot) :
SELECT COUNT(*) AS total FROM APPLI_GLPI.MV_INVENTORY_GLOBAL;

-- 3. Check des derniers logs d'audit globaux
PROMPT
PROMPT [OK] Audit recent :
SELECT table_name, operation, user_db, log_date
FROM   APPLI_GLPI.V_AUDIT_RECENT WHERE ROWNUM<=5;

-- 4. Test de la fonction analytique de comptage
PROMPT
PROMPT [OK] F_COUNT_ASSETS (fonction analytique) :
SELECT APPLI_GLPI.F_COUNT_ASSETS('CERGY')           AS total_cergy,
       APPLI_GLPI.F_COUNT_ASSETS('CERGY','ACTIF')   AS actifs_cergy
FROM   DUAL;

PROMPT ================================================
