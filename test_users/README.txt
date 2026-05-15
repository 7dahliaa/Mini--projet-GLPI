=== DOSSIER TESTS UTILISATEURS ===

Ces scripts SQL permettent de demonstrer les droits de chaque
utilisateur en se connectant directement depuis SQLPlus.

ARCHITECTURE RESEAU :
--------------------
oracle_cergy : port externe 1523 (host) -> 1521 (container)
oracle_pau   : port externe 1522 (host) -> 1521 (container)

OPTION 1 — Connexion depuis le HOST (Mac/ LINUX aussi je croiss ayiii ) :
------------------------------------------------
# Technicien Cergy
sqlplus 'TECH_CERGY1/Tech1_Cergy_2026!@//localhost:1523/FREEPDB1'

# Service RH
sqlplus 'RH_USER/RH_CyTech_2026!@//localhost:1523/FREEPDB1'

# Auditeur (Lecture seule)
sqlplus 'AUDITEUR/Audit_CyTech_2026!@//localhost:1523/FREEPDB1'

# Administrateur DSI (Accès total)
sqlplus 'ADMIN_DSI/DSI_CyTech_2026!@//localhost:1523/FREEPDB1'

Puis dans SQLPlus :
SQL> @chemin/vers/test_TECH_CERGY1.sql

OPTION 2 — Connexion depuis l'interieur du container :
-------------------------------------------------------
docker exec -it oracle_cergy bash
export ORACLE_HOME=$(find /opt/oracle/product -name "sqlplus" -type f 2>/dev/null | head -1 | sed 's|/bin/sqlplus||')
export PATH=$ORACLE_HOME/bin:$PATH

# Copier les fichiers dans le container d'abord :
# docker cp cergy/test_TECH_CERGY1.sql oracle_cergy:/tmp/
# docker cp cergy/test_RH_USER.sql oracle_cergy:/tmp/
# docker cp cergy/test_AUDITEUR.sql oracle_cergy:/tmp/
# docker cp cergy/test_ADMIN_DSI.sql oracle_cergy:/tmp/

# TECH_CERGY1 (technicien site Cergy)
sqlplus "TECH_CERGY1/Tech1_Cergy_2026!@//localhost:1521/FREEPDB1"
SQL> @/tmp/test_TECH_CERGY1.sql

# RH_USER (service RH)
sqlplus "RH_USER/RH_CyTech_2026!@//localhost:1521/FREEPDB1"
SQL> @/tmp/test_RH_USER.sql

# AUDITEUR (lecture seule)
sqlplus "AUDITEUR/Audit_CyTech_2026!@//localhost:1521/FREEPDB1"
SQL> @/tmp/test_AUDITEUR.sql

# ADMIN_DSI (vision globale Cergy + Pau)
sqlplus "ADMIN_DSI/DSI_CyTech_2026!@//localhost:1521/FREEPDB1"
SQL> @/tmp/test_ADMIN_DSI.sql


# TECH_PAU1 — depuis Pau (port 1522)

sqlplus 'TECH_PAU1/Tech1_Pau_2026!@//localhost:1522/FREEPDB1'
SQL> @test_users/test_TECH_PAU1.sql

# AUDITEUR_PAU — depuis Pau (port 1522)
sqlplus 'AUDITEUR_PAU/Audit_Pau_2026!@//localhost:1522/FREEPDB1'
SQL> @test_users/test_AUDITEUR_PAU.sql



COMPTES ET MOTS DE PASSE :
--------------------------
TECH_CERGY1  / Tech1_Cergy_2026!   -> ROLE_TECH_CERGY  (DML assets Cergy)
TECH_CERGY2  / Tech2_Cergy_2026!   -> ROLE_TECH_CERGY  (DML assets Cergy)
RH_USER      / RH_CyTech_2026!     -> ROLE_RH          (DML utilisateurs)
AUDITEUR     / Audit_CyTech_2026!  -> ROLE_AUDITEUR    (SELECT seul)
ADMIN_DSI    / DSI_CyTech_2026!    -> ROLE_DSI_ADMIN   (tous droits)
APPLI_GLPI   / AppGLPI_2026!       -> proprietaire schema (DDL + DML)

FICHIERS :
----------
test_TECH_CERGY1.sql -> DML assets ok / DROP interdit / DBLink interdit
test_RH_USER.sql     -> DML users ok  / CYT_COMPUTERS interdit
test_AUDITEUR.sql    -> SELECT partout / INSERT/UPDATE/DELETE interdits
test_ADMIN_DSI.sql   -> Vision globale Cergy+Pau / toutes les vues