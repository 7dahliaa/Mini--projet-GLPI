-- Script pour générer un gros jeu de données de test pour le site de Cergy
-- On active l'affichage console pour voir nos messages de progression
SET SERVEROUTPUT ON SIZE 1000000;

-- Grand ménage : on vide toutes les tables avant de commencer pour partir sur une base propre.
DELETE FROM CYT_AUDIT_LOG;
DELETE FROM CYT_ASSET_TRANSFER;
DELETE FROM CYT_INFOCOMS;
DELETE FROM CYT_IPADDRESSES;
DELETE FROM CYT_COMPUTERS_DETAIL;
DELETE FROM CYT_PORT_LINKS;
DELETE FROM CYT_NETWORKPORTS;
DELETE FROM CYT_COMPUTERS;
DELETE FROM CYT_NETEQUIP;
DELETE FROM CYT_GROUPS_USERS;
DELETE FROM CYT_USERS_PROFILES;
DELETE FROM CYT_USERS_DETAIL;
DELETE FROM CYT_USERS;
DELETE FROM CYT_LOCATIONS WHERE location_id > 3;
COMMIT;

-- On génère 10 salles automatiquement avec une boucle
BEGIN
  FOR i IN 1..10 LOOP
    INSERT INTO CYT_LOCATIONS (entity_id, location_name, building, room, floor)
    VALUES (1, 'Salle ' || TO_CHAR(i, 'FM000'),
            'Batiment ' || CHR(64 + MOD(i, 4) + 1),
            'Salle ' || TO_CHAR(i * 10), MOD(i, 4));
  END LOOP;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('Localisations inserees');
END;
/

-- Création d'une vingtaine d'équipements réseau 
BEGIN
  FOR i IN 1..20 LOOP
    INSERT INTO CYT_NETEQUIP (entity_id, location_id, manufacturer_id,
      netequip_name, serial, equip_type, nb_ports)
    VALUES (1, MOD(i, 3) + 1, 5,
            'SW-BAT-' || CHR(64 + MOD(i,4) + 1) || '-' || TO_CHAR(i, 'FM00'),
            'SN-SW-' || TO_CHAR(i, 'FM0000'),
            CASE WHEN MOD(i, 5) = 0 THEN 'ROUTER' ELSE 'SWITCH' END, 48);
  END LOOP;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('Switchs inseres');
END;
/

-- Création de 1000 utilisateurs. 
-- Super important : on désactive le trigger de synchro avec Pau le temps de l'insertion, 
ALTER TRIGGER TRG_SYNC_USER_PAU DISABLE;

DECLARE
  v_prenom VARCHAR2(50);
  v_nom    VARCHAR2(50);
  v_uid    NUMBER;
BEGIN
  FOR i IN 1..1000 LOOP
    -- On utilise DBMS_RANDOM pour générer des faux noms et prénoms
    v_prenom := DBMS_RANDOM.STRING('L', 6);
    v_nom    := DBMS_RANDOM.STRING('U', 8);
    INSERT INTO CYT_USERS (login, password_hash, realname, firstname,
      entity_id, profile_id, is_active, date_created)
    VALUES (LOWER(v_prenom) || TO_CHAR(i),
            DBMS_RANDOM.STRING('A', 60),
            v_nom, INITCAP(v_prenom), 1,
            CASE WHEN MOD(i,10)=0 THEN 1 ELSE 2 END,
            CASE WHEN MOD(i,20)=0 THEN 0 ELSE 1 END,
            SYSDATE - DBMS_RANDOM.VALUE(0, 730))
    RETURNING user_id INTO v_uid;
    -- On rajoute les détails comme le téléphone pour chaque utilisateur créé
    INSERT INTO CYT_USERS_DETAIL (user_id, phone, language, registration_number)
    VALUES (v_uid,
            '06' || TO_CHAR(TRUNC(DBMS_RANDOM.VALUE(10000000, 99999999))),
            CASE WHEN MOD(i,10)=0 THEN 'en_US' ELSE 'fr_FR' END,
            'CYT-' || TO_CHAR(2020 + MOD(i, 6)) || '-' || TO_CHAR(i, 'FM00000'));
    -- On valide par paquets de 100 pour ne pas saturer la mémoire
    IF MOD(i, 100) = 0 THEN COMMIT; END IF;
  END LOOP;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('1000 users inseres');
END;
/

-- On réactive le trigger maintenant qu'on a fini l'insertion 
ALTER TRIGGER TRG_SYNC_USER_PAU ENABLE;

-- Création de l'inventaire des 3000 ordinateurs
DECLARE
  v_cid   NUMBER;
 
  TYPE t_ids IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
  v_locs  t_ids;
  v_users t_ids;
  v_nloc  NUMBER := 0;
  v_nuser NUMBER := 0;
BEGIN
  -- Je charge toutes les salles et tous les users dans mes tableaux
  FOR r IN (SELECT location_id FROM CYT_LOCATIONS ORDER BY location_id) LOOP
    v_nloc := v_nloc + 1;
    v_locs(v_nloc) := r.location_id;
  END LOOP;
  FOR r IN (SELECT user_id FROM CYT_USERS ORDER BY user_id) LOOP
    v_nuser := v_nuser + 1;
    v_users(v_nuser) := r.user_id;
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('Locations: ' || v_nloc || ' | Users: ' || v_nuser);
  FOR i IN 1..3000 LOOP
    INSERT INTO CYT_COMPUTERS (serial, computer_name, entity_id, location_id,
      type_id, model_id, manufacturer_id, user_id,
      status, date_purchase, date_created)
    VALUES (
      'SN-CY-' || TO_CHAR(i, 'FM00000'),
      'PC-CERGY-' || TO_CHAR(i, 'FM00000'),
      1,
      -- Je pioche aléatoirement une salle et un utilisateur grâce aux modulos
      v_locs(MOD(i-1, v_nloc) + 1),
      MOD(i, 4)+1, MOD(i, 4)+1, MOD(i, 4)+1,
      v_users(MOD(i-1, v_nuser) + 1),
      CASE WHEN MOD(i,20)=0 THEN 'HORS_SERVICE'
           WHEN MOD(i,15)=0 THEN 'EN_STOCK'
           WHEN MOD(i,50)=0 THEN 'EN_REPARATION'
           ELSE 'ACTIF' END,
      SYSDATE - DBMS_RANDOM.VALUE(30, 1825),
      SYSDATE - DBMS_RANDOM.VALUE(0, 1825)
    ) RETURNING computer_id INTO v_cid;
    INSERT INTO CYT_COMPUTERS_DETAIL (computer_id, uuid, ticket_tco, last_boot)
    VALUES (v_cid, SYS_GUID(),
            ROUND(DBMS_RANDOM.VALUE(500,3000),2),
            SYSDATE - DBMS_RANDOM.VALUE(0,30));
    IF MOD(i,200)=0 THEN COMMIT; END IF;
  END LOOP;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('3000 PC inseres');
END;
/

-- Partie réseau : on crée des ports pour les PC et on les relie aux switchs
DECLARE
  v_pid NUMBER; v_spid NUMBER; v_sw NUMBER;
  v_b1 VARCHAR2(2); v_b2 VARCHAR2(2); v_b3 VARCHAR2(2);
  v_b4 VARCHAR2(2); v_b5 VARCHAR2(2);
BEGIN
  SELECT COUNT(*) INTO v_sw FROM CYT_NETEQUIP;
  FOR c IN (SELECT computer_id FROM CYT_COMPUTERS
            WHERE is_deleted=0 AND ROWNUM<=3000) LOOP
    v_pid := SEQ_NETWORKPORT_ID.NEXTVAL;
    -- Générer de fausses adresses MAC en hexadécimal
    v_b1 := TO_CHAR(MOD(TRUNC(v_pid/1),256),'FM0X');
    v_b2 := TO_CHAR(MOD(TRUNC(v_pid/256),256),'FM0X');
    v_b3 := TO_CHAR(MOD(TRUNC(v_pid/65536),256),'FM0X');
    v_b4 := TO_CHAR(MOD(c.computer_id,256),'FM0X');
    v_b5 := TO_CHAR(MOD(TRUNC(c.computer_id/256),256),'FM0X');
    INSERT INTO CYT_NETWORKPORTS (port_id, items_id, item_type, entity_id,
      logical_number, port_name, mac_address, network_id, port_status)
    VALUES (v_pid, c.computer_id, 'COMPUTER', 1, 0, 'eth0',
            v_b1||':'||v_b2||':'||v_b3||':'||v_b4||':'||v_b5||':02',
            MOD(v_pid,3)+1, 'ACTIVE');
    -- Création du port côté switch
    v_spid := SEQ_NETWORKPORT_ID.NEXTVAL;
    INSERT INTO CYT_NETWORKPORTS (port_id, items_id, item_type, entity_id,
      logical_number, port_name, network_id, port_status)
    VALUES (v_spid, MOD(c.computer_id,v_sw)+1, 'NETEQUIP', 1,
            MOD(c.computer_id,48),
            'GigabitEthernet0/'||TO_CHAR(MOD(c.computer_id,48)),
            MOD(v_spid,3)+1, 'ACTIVE');
    -- On branche le PC sur le switch
    INSERT INTO CYT_PORT_LINKS (port_src, port_dst) VALUES (v_pid, v_spid);
    IF MOD(v_pid,200)=0 THEN COMMIT; END IF;
  END LOOP;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('Ports et liaisons inseres');
END;
/

-- On attribue une adresse IP unique à chaque ordinateur
DECLARE
  v_o2 NUMBER; v_o3 NUMBER; v_o4 NUMBER;
BEGIN
  FOR c IN (SELECT computer_id, entity_id FROM CYT_COMPUTERS
            WHERE is_deleted=0 AND ROWNUM<=3000) LOOP
    -- Je découpe l'ID pour fabriquer les différents nombres de l'IP (ex: 10.x.y.z)
    -- Comme ça on est sûr de ne jamais avoir de conflit
    v_o2 := TRUNC((c.computer_id-1)/65025);
    v_o3 := TRUNC(MOD((c.computer_id-1),65025)/255);
    v_o4 := MOD((c.computer_id-1),255)+1;
    INSERT INTO CYT_IPADDRESSES (entity_id, items_id, item_type, ip_address)
    VALUES (c.entity_id, c.computer_id, 'COMPUTER',
            '10.'||TO_CHAR(v_o2)||'.'||TO_CHAR(v_o3)||'.'||TO_CHAR(v_o4));
    IF MOD(c.computer_id,300)=0 THEN COMMIT; END IF;
  END LOOP;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('IPs inserees');
END;
/

-- Requête de vérification finale pour voir si tout s'est bien passé
SELECT 'CYT_COMPUTERS'    t, COUNT(*) n FROM CYT_COMPUTERS    UNION ALL
SELECT 'CYT_USERS',          COUNT(*) FROM CYT_USERS           UNION ALL
SELECT 'CYT_NETWORKPORTS',   COUNT(*) FROM CYT_NETWORKPORTS    UNION ALL
SELECT 'CYT_PORT_LINKS',     COUNT(*) FROM CYT_PORT_LINKS      UNION ALL
SELECT 'CYT_IPADDRESSES',    COUNT(*) FROM CYT_IPADDRESSES     UNION ALL
SELECT 'CYT_NETEQUIP',       COUNT(*) FROM CYT_NETEQUIP        UNION ALL
SELECT 'CYT_AUDIT_LOG',      COUNT(*) FROM CYT_AUDIT_LOG;
