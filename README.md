# Mini-Projet GLPI - Base de Données Oracle Répartie

Ce projet est une simulation d'un système d'information distribué de type **GLPI** (Gestion Libre de Parc Informatique), s'appuyant sur des bases de données Oracle. Il modélise deux sites géographiques distincts : un site principal (Cergy) et un site secondaire (Pau).

## Architecture

- **Cergy (Lead)** : Héberge la base de données principale (Port local `1523`).
- **Pau (Spoke)** : Héberge la base de données secondaire (Port local `1522`).
- **Communication** : Le site de Cergy communique avec le site de Pau via des **DBLinks** pour consolider les vues globales et interroger l'ensemble du parc informatique.

## Technologies

- **SGBD** : Oracle Database (image Docker `gvenzl/oracle-free:latest`)
- **Déploiement** : Docker & Docker Compose
- **Scripts** : Bash, SQL, PL/SQL

## Structure du projet

- `cergy/` : Scripts SQL d'initialisation pour le site principal (tablespaces, rôles, schémas, DBLinks, triggers, données).
- `pau/` : Scripts SQL d'initialisation pour le site secondaire.
- `test_users/` : Scripts de test métier organisés par profils utilisateurs (Admin, Auditeur, Ressources Humaines, Technicien).
- `run_all.sh` : Script d'orchestration global qui exécute la séquence d'installation des deux bases de manière chronologique.
- `docker-compose.yml` : Configuration des conteneurs Oracle.

## Installation et Déploiement

### Prérequis

- [Docker](https://www.docker.com/) et Docker Compose installés.
- Un terminal compatible Bash (Git Bash sous Windows, WSL, ou Linux/macOS).

### Lancement

1. **Démarrer les conteneurs Oracle :**

   ```bash
   docker-compose up -d
   ```

   _(Attendez quelques minutes lors du premier lancement pour que les bases Oracle s'initialisent correctement)._

2. **Créer l'architecture et injecter les données :**
   Une fois les bases accessibles, lancez le script de déploiement automatique :
   ```bash
   ./run_all.sh
   ```
   Ce script se charge de valider les connexions, de construire les espaces de tables, de créer les utilisateurs, d'établir les liens entre les bases et de générer un jeu de données (environ 5000 enregistrements).

## Tests métier

Vous pouvez tester les droits et procédures avec différents rôles (ex: DSI, Technicien, RH) en utilisant les scripts présents dans le dossier `test_users/`.
