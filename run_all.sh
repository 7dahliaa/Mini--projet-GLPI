#!/bin/bash
# Script principal de lancement pour le projet
# Ça va automatiser tout le déploiement de notre base répartie sur les deux conteneurs Docker

# variables de couleurs pour avoir un affichage plus lisible dans le terminal
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# On centralise les infos de connexion ici pour pouvoir les changer facilement si besoin
CERGY="oracle_cergy"
PAU="oracle_pau"
SYS_PASS="OracleHomeUser1"
APP_PASS="AppGLPI_2026!"
SERVICE="FREEPDB1"
PORT="1521"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# fonctions d'affichage pour structurer la sortie console (ph = gros titre, ok = succès, etc.)
ph()  { echo ""; echo -e "${BOLD}${BLUE}================================================================${NC}"; echo -e "${BOLD}${BLUE}  $1${NC}"; echo -e "${BOLD}${BLUE}================================================================${NC}"; }
ps_() { echo -e "${CYAN}  ▶ $1${NC}"; }
ok()  { echo -e "${GREEN}  ✓ $1${NC}"; }
err() { echo -e "${RED}  ✗ ERREUR : $1${NC}"; }
wrn() { echo -e "${YELLOW}  ⚠ $1${NC}"; }

# Fonction pour vérifier si on arrive à se connecter à la base
test_conn() {
    local container=$1 user=$2 pass=$3
    local result
    result=$(docker exec -i "$container" bash << BASHEOF
export ORACLE_HOME=\$(find /opt/oracle/product -name "sqlplus" -type f 2>/dev/null | head -1 | sed 's|/bin/sqlplus||')
export PATH=\$ORACLE_HOME/bin:\$PATH
export LD_LIBRARY_PATH=\$ORACLE_HOME/lib:\$LD_LIBRARY_PATH
sqlplus -S "${user}/${pass}@//localhost:${PORT}/${SERVICE}" << SQLEOF
SET HEADING OFF FEEDBACK OFF
SELECT 'CONN_OK' FROM DUAL;
EXIT;
SQLEOF
BASHEOF
    2>&1)
    echo "$result" | grep -q "CONN_OK"
}

# La fonction la plus importante : elle copie un de nos fichiers SQL dans le conteneur Docker et l'exécute
run_sql() {
    local container=$1 sql_file=$2 desc=$3 user=$4 critical=${5:-""}
    local pass; [ "$user" = "system" ] && pass="$SYS_PASS" || pass="$APP_PASS"
    ps_ "$desc"

    docker cp "${DIR}/${sql_file}" "${container}:/tmp/s.sql" 2>/dev/null
    if [ $? -ne 0 ]; then
        err "Copie impossible : $sql_file"
        [ "$critical" ] && exit 1
        return 1
    fi

    local out
    out=$(docker exec -i "$container" bash << BASHEOF
export ORACLE_HOME=\$(find /opt/oracle/product -name "sqlplus" -type f 2>/dev/null | head -1 | sed 's|/bin/sqlplus||')
export PATH=\$ORACLE_HOME/bin:\$PATH
export LD_LIBRARY_PATH=\$ORACLE_HOME/lib:\$LD_LIBRARY_PATH
sqlplus -S "${user}/${pass}@//localhost:${PORT}/${SERVICE}" << SQLEOF
SET ECHO OFF FEEDBACK ON SERVEROUTPUT ON SIZE 1000000
@/tmp/s.sql
EXIT;
SQLEOF
BASHEOF
    2>&1)
    local code=$?

    if [ $code -ne 0 ]; then
        err "Échec $sql_file (code $code)"
        echo "$out" | grep -v "^$" | tail -12
        [ "$critical" ] && { echo -e "${RED}Arrêt.${NC}"; exit 1; }
        return 1
    fi
    ok "$desc"
}

# Fonction pour donner tous les droits de création (DDL) à notre utilisateur applicatif
grant_appli() {
    local container=$1 site=$2
    ps_ "[$site] Privilèges DDL pour APPLI_GLPI..."
    docker exec -i "$container" bash << BASHEOF
export ORACLE_HOME=\$(find /opt/oracle/product -name "sqlplus" -type f 2>/dev/null | head -1 | sed 's|/bin/sqlplus||')
export PATH=\$ORACLE_HOME/bin:\$PATH
sqlplus -S "system/${SYS_PASS}@//localhost:${PORT}/${SERVICE}" << SQLEOF
GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW, CREATE MATERIALIZED VIEW,
      CREATE SEQUENCE, CREATE TRIGGER, CREATE PROCEDURE,
      CREATE DATABASE LINK, CREATE CLUSTER, UNLIMITED TABLESPACE
TO APPLI_GLPI;
EXIT;
SQLEOF
BASHEOF
    ok "[$site] Privilèges accordés à APPLI_GLPI"
}

# ── DÉBUT DU SCRIPT ────────────────────────────────────────────────────────────
clear
echo -e "${BOLD}${BLUE}"
echo "  ╔═══════════════════════════════════════════════════════════╗"
echo "  ║    DÉPLOIEMENT CYT — Oracle Réparti                       ║"
echo "  ║    Cergy (Lead) + Pau (Spoke) — ING2 BDD Avancées         ║"
echo "  ╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

ph "VÉRIFICATIONS PRÉALABLES"

# Étape de base : on s'assure que les deux conteneurs Docker sont bien allumés
docker ps --format '{{.Names}}' | grep -q "^${CERGY}$" || { err "oracle_cergy non démarré — lance: docker compose up -d"; exit 1; }
docker ps --format '{{.Names}}' | grep -q "^${PAU}$"   || { err "oracle_pau non démarré — lance: docker compose up -d"; exit 1; }
ok "Containers actifs"

# On vérifie qu'on n'a pas oublié de fichiers SQL dans les dossiers avant de lancer la machine
MISSING=0
for f in cergy/01_tablespaces.sql cergy/02_users_roles.sql cergy/03_schema_tables.sql \
          cergy/04_index.sql cergy/05_views.sql cergy/06_dblinks.sql \
          cergy/07_views_federated.sql cergy/08_triggers.sql \
          cergy/09_procedures_fonctions.sql cergy/10_data_generation.sql \
          cergy/03b_fk.sql cergy/02b_grants.sql cergy/11_perf_tests.sql \
          cergy/12_uc_tests.sql \
          pau/01_tablespaces.sql pau/02_users_roles.sql pau/03_schema_tables.sql \
          pau/03b_fk.sql pau/02b_grants.sql pau/04_index.sql pau/08_triggers.sql pau/10_data_generation.sql; do
    [ ! -f "${DIR}/$f" ] && { err "Manquant : $f"; MISSING=1; }
done
[ $MISSING -eq 1 ] && exit 1
ok "Tous les fichiers présents"

# Boucle d'attente pour Cergy : on teste la connexion toutes les 10 secondes 
ps_ "Attente Oracle Cergy (peut prendre 1-2 min au premier démarrage)..."
for i in $(seq 1 18); do
    test_conn "$CERGY" "system" "$SYS_PASS" && break
    echo -n " $i..."
    sleep 10
done
test_conn "$CERGY" "system" "$SYS_PASS" || { err "Oracle Cergy inaccessible après 3 min"; exit 1; }
ok "Oracle Cergy prêt"

# Pareil pour la base de Pau
ps_ "Attente Oracle Pau..."
for i in $(seq 1 18); do
    test_conn "$PAU" "system" "$SYS_PASS" && break
    echo -n " $i..."
    sleep 10
done
test_conn "$PAU" "system" "$SYS_PASS" || { err "Oracle Pau inaccessible après 3 min"; exit 1; }
ok "Oracle Pau prêt"

# Pause pour vérifier que tout est bon
echo ""; echo -e "${YELLOW}${BOLD}Prêt. ENTRÉE pour continuer (CTRL+C pour annuler)...${NC}"; read -r

# ── ÉTAPE 1 : PAU ─────────────────────────────────────────────────────────────
ph "ÉTAPE 1/5 — PAU : Infrastructure"
# On commence obligatoirement par Pau, car le lien (DBLink) côté Cergy aura besoin que le compte existe en face

run_sql "$PAU" "pau/01_tablespaces.sql"   "[PAU][system]     01 — Tablespaces"        "system"     "critical"
run_sql "$PAU" "pau/02_users_roles.sql"   "[PAU][system]     02 — Users & Rôles"      "system"     "critical"
grant_appli "$PAU" "PAU"
run_sql "$PAU" "pau/03_schema_tables.sql" "[PAU][APPLI_GLPI] 03 — Schema + Cluster"   "APPLI_GLPI" "critical"
run_sql "$PAU" "pau/03b_fk.sql"          "[PAU][APPLI_GLPI] 03b— Contraintes FK"    "APPLI_GLPI"
run_sql "$PAU" "pau/02b_grants.sql"      "[PAU][APPLI_GLPI] 02b— GRANTs sur tables" "APPLI_GLPI"
run_sql "$PAU" "pau/04_index.sql"         "[PAU][APPLI_GLPI] 04 — Index"              "APPLI_GLPI"
ok "Étape 1 terminée — Pau prêt"

# ── ÉTAPE 2 : CERGY ───────────────────────────────────────────────────────────
ph "ÉTAPE 2/5 — CERGY : Infrastructure + Schema"
# Maintenant on prépare la base principale avec l'architecture locale

run_sql "$CERGY" "cergy/01_tablespaces.sql"   "[CERGY][system]     01 — Tablespaces"               "system"     "critical"
run_sql "$CERGY" "cergy/02_users_roles.sql"   "[CERGY][system]     02 — Users & Rôles"             "system"     "critical"
grant_appli "$CERGY" "CERGY"
run_sql "$CERGY" "cergy/03_schema_tables.sql" "[CERGY][APPLI_GLPI] 03 — Schema + Cluster + Frag." "APPLI_GLPI" "critical"
run_sql "$CERGY" "cergy/03b_fk.sql"         "[CERGY][APPLI_GLPI] 03b— Contraintes FK"             "APPLI_GLPI"
run_sql "$CERGY" "cergy/02b_grants.sql"    "[CERGY][APPLI_GLPI] 02b— GRANTs sur tables"          "APPLI_GLPI"
run_sql "$CERGY" "cergy/04_index.sql"         "[CERGY][APPLI_GLPI] 04 — Index"                    "APPLI_GLPI"
run_sql "$CERGY" "cergy/05_views.sql"         "[CERGY][APPLI_GLPI] 05 — Vues locales"             "APPLI_GLPI"
ok "Étape 2 terminée"

# ── ÉTAPE 3 : DBLinks ─────────────────────────────────────────────────────────
ph "ÉTAPE 3/5 — CERGY : DBLinks vers Pau"
# C'est ici qu'on relie les deux bases entre elles

run_sql "$CERGY" "cergy/06_dblinks.sql"         "[CERGY][APPLI_GLPI] 06 — DBLinks"              "APPLI_GLPI" "critical"
run_sql "$CERGY" "cergy/07_views_federated.sql" "[CERGY][APPLI_GLPI] 07 — Vues fédérées + MV"  "APPLI_GLPI"
ok "Étape 3 terminée"

# ── ÉTAPE 4 : PL/SQL ──────────────────────────────────────────────────────────
ph "ÉTAPE 4/5 — PL/SQL"
# On ajoute toute la logique de l'application (les triggers, les procédures stockées, etc.)

run_sql "$CERGY" "cergy/08_triggers.sql"             "[CERGY][APPLI_GLPI] 08 — Triggers"           "APPLI_GLPI"
run_sql "$PAU"   "pau/08_triggers.sql"               "[PAU][APPLI_GLPI]   08 — Triggers audit"     "APPLI_GLPI"
run_sql "$CERGY" "cergy/09_procedures_fonctions.sql" "[CERGY][APPLI_GLPI] 09 — Procédures+Package" "APPLI_GLPI"
ok "Étape 4 terminée"

# ── ÉTAPE 5 : Données + Tests ─────────────────────────────────────────────────
ph "ÉTAPE 5/5 — Données + Tests"
# On remplit les bases avec notre jeu de test
wrn "Génération ~5000 lignes — 3-5 minutes"

run_sql "$CERGY" "cergy/10_data_generation.sql" "[CERGY][APPLI_GLPI] 10 — 3000 PC + 1000 users" "APPLI_GLPI"
run_sql "$PAU"   "pau/10_data_generation.sql"   "[PAU][APPLI_GLPI]   10 — 2000 PC + 500 users"  "APPLI_GLPI"

# On met à jour la vue matérialisée à la main pour être sûr qu'elle a bien récupéré les données insérées
ps_ "Rafraîchissement MV_INVENTORY_GLOBAL..."
docker exec -i "$CERGY" bash << BASHEOF > /dev/null 2>&1
export ORACLE_HOME=\$(find /opt/oracle/product -name "sqlplus" -type f 2>/dev/null | head -1 | sed 's|/bin/sqlplus||')
export PATH=\$ORACLE_HOME/bin:\$PATH
sqlplus -S "APPLI_GLPI/${APP_PASS}@//localhost:${PORT}/${SERVICE}" << SQLEOF
EXEC DBMS_MVIEW.REFRESH('MV_INVENTORY_GLOBAL','C');
EXIT;
SQLEOF
BASHEOF
ok "MV_INVENTORY_GLOBAL rafraîchie"

# On lance les petits tests de performances pour vérifier que nos index fonctionnent
run_sql "$CERGY" "cergy/11_perf_tests.sql" "[CERGY][APPLI_GLPI] 11 — EXPLAIN PLAN + perf" "APPLI_GLPI"

# ── RÉSUMÉ DE FIN ──────────────────────────────────────────────────────────────
ph "VÉRIFICATION FINALE"

# SQL pour compter tout ce qu'on a créé 
docker exec -i "$CERGY" bash << BASHEOF
export ORACLE_HOME=\$(find /opt/oracle/product -name "sqlplus" -type f 2>/dev/null | head -1 | sed 's|/bin/sqlplus||')
export PATH=\$ORACLE_HOME/bin:\$PATH
sqlplus -S "APPLI_GLPI/${APP_PASS}@//localhost:${PORT}/${SERVICE}" << SQLEOF
SET LINESIZE 50 PAGESIZE 20
SELECT object_type, COUNT(*) nb FROM user_objects
WHERE  object_type IN ('TABLE','VIEW','MATERIALIZED VIEW','TRIGGER',
                       'PROCEDURE','FUNCTION','PACKAGE','INDEX','SEQUENCE')
GROUP BY object_type ORDER BY object_type;
SELECT 'CYT_COMPUTERS' t, COUNT(*) n FROM CYT_COMPUTERS
UNION ALL SELECT 'CYT_USERS', COUNT(*) FROM CYT_USERS;
EXIT;
SQLEOF
BASHEOF

echo -e "${BOLD}${GREEN}"
echo "  ╔═══════════════════════════════════════════════════════════╗"
echo "  ║    DÉPLOIEMENT TERMINÉ                                    ║"
echo "  ║  Tables propriétaire : APPLI_GLPI                         ║"
echo "  ║  Connexion Cergy :                                        ║"
echo "  ║  docker exec -it oracle_cergy bash                        ║"
echo "  ║  sqlplus APPLI_GLPI/AppGLPI_2026!@//localhost:1521/FREE   ║"
echo "  ╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
