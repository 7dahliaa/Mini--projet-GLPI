-- Script de génération de données pour le site (Pau)

-- On active l'affichage console pour voir nos messages de progression
SET SERVEROUTPUT ON SIZE 1000000;

-- Je vide toutes les tables dans un ordre précis pour ne pas avoir de soucis avec les clés étrangères.
DELETE FROM CYT_AUDIT_LOG;
DELETE FROM CYT_INFOCOMS;
DELETE FROM CYT_IPADDRESSES;
DELETE FROM CYT_COMPUTERS_DETAIL;
DELETE FROM CYT_PORT_LINKS;
DELETE FROM CYT_NETWORKPORTS;
DELETE FROM CYT_COMPUTERS;
DELETE FROM CYT_NETEQUIP;
DELETE FROM CYT_USERS_DETAIL;
DELETE FROM CYT_USERS;
COMMIT;

-- Création des salles pour Pau
BEGIN
  FOR i IN 1..5 LOOP
    INSERT INTO CYT_LOCATIONS (entity_id, location_name, building, room, floor)
    VALUES (1, 'Salle PAU '||TO_CHAR(i,'FM000'),
            'Bat-PAU-'||CHR(64+i), 'S'||TO_CHAR(i*10), MOD(i,3));
  END LOOP;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('Localisations Pau inserees');
END;
/

-- Ajout du matériel réseau (les switchs)
BEGIN
  FOR i IN 1..10 LOOP
    INSERT INTO CYT_NETEQUIP (entity_id, location_id, manufacturer_id,
      netequip_name, serial, equip_type, nb_ports)
    VALUES (1, MOD(i,3)+1, 4,
            'SW-PAU-'||TO_CHAR(i,'FM00'),
            'SN-SW-PAU-'||TO_CHAR(i,'FM0000'),
            'SWITCH', 48);
  END LOOP;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('Switchs Pau inseres');
END;
/

-- Création des 500 utilisateurs de Pau
DECLARE
  v_uid NUMBER;
BEGIN
  FOR i IN 1..500 LOOP
    -- On génère des chaînes aléatoires pour les mots de passe et les noms 
    INSERT INTO CYT_USERS (login, password_hash, realname, firstname,
      entity_id, profile_id, is_active)
    VALUES ('pau_user'||TO_CHAR(i),
            DBMS_RANDOM.STRING('A',60),
            DBMS_RANDOM.STRING('U',8),
            DBMS_RANDOM.STRING('L',6),
            1, 1, 1) RETURNING user_id INTO v_uid;
    -- On leur attribue le français par défaut
    INSERT INTO CYT_USERS_DETAIL (user_id, language)
    VALUES (v_uid, 'fr_FR');
    -- On valide tous les 100 pour pas faire planter la base
    IF MOD(i,100)=0 THEN COMMIT; END IF;
  END LOOP;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('500 users Pau inseres');
END;
/

-- Création de l'inventaire des 2000 ordinateurs
DECLARE
  v_cid   NUMBER;
  -- Comme pour Cergy, je stocke les IDs des salles et des users dans des tableaux en mémoire
  TYPE t_ids IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
  v_locs  t_ids;
  v_users t_ids;
  v_nloc  NUMBER := 0;
  v_nuser NUMBER := 0;
BEGIN
  FOR r IN (SELECT location_id FROM CYT_LOCATIONS ORDER BY location_id) LOOP
    v_nloc := v_nloc + 1;
    v_locs(v_nloc) := r.location_id;
  END LOOP;
  FOR r IN (SELECT user_id FROM CYT_USERS ORDER BY user_id) LOOP
    v_nuser := v_nuser + 1;
    v_users(v_nuser) := r.user_id;
  END LOOP;

  DBMS_OUTPUT.PUT_LINE('Locations : '||v_nloc||' | Users : '||v_nuser);

  FOR i IN 1..2000 LOOP
    INSERT INTO CYT_COMPUTERS (serial, computer_name, entity_id, location_id,
      type_id, model_id, manufacturer_id, user_id, status, date_created)
    VALUES (
      'SN-PAU-'||TO_CHAR(i,'FM00000'),
      'PC-PAU-'||TO_CHAR(i,'FM00000'),
      1,
      -- J'utilise les modulos pour répartir les PC équitablement entre les salles et les utilisateurs
      v_locs(MOD(i-1,v_nloc)+1),
      MOD(i,3)+1, MOD(i,2)+1, MOD(i,4)+1,
      v_users(MOD(i-1,v_nuser)+1),
      CASE WHEN MOD(i,15)=0 THEN 'HORS_SERVICE'
           WHEN MOD(i,20)=0 THEN 'EN_STOCK'
           ELSE 'ACTIF' END,
      SYSDATE - DBMS_RANDOM.VALUE(0,1825)
    ) RETURNING computer_id INTO v_cid;

    -- Ajout des détails techniques (UUID, coût...)
    INSERT INTO CYT_COMPUTERS_DETAIL (computer_id, uuid, ticket_tco)
    VALUES (v_cid, SYS_GUID(), ROUND(DBMS_RANDOM.VALUE(500,3000),2));

    IF MOD(i,200)=0 THEN COMMIT; END IF;
  END LOOP;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('2000 PC Pau inseres');
END;
/

-- On connecte les PC aux switchs
DECLARE
  v_pid  NUMBER;
  v_spid NUMBER;
  v_sw   NUMBER;
  v_b1 VARCHAR2(2); v_b2 VARCHAR2(2); v_b3 VARCHAR2(2);
  v_b4 VARCHAR2(2); v_b5 VARCHAR2(2);
BEGIN
  SELECT COUNT(*) INTO v_sw FROM CYT_NETEQUIP;

  FOR c IN (SELECT computer_id FROM CYT_COMPUTERS WHERE ROWNUM<=2000) LOOP
    v_pid  := SEQ_NETWORKPORT_ID.NEXTVAL;
    -- Génération d'une adresse MAC avec du calcul hexadecimal
    v_b1 := TO_CHAR(MOD(TRUNC(v_pid/1),256),'FM0X');
    v_b2 := TO_CHAR(MOD(TRUNC(v_pid/256),256),'FM0X');
    v_b3 := TO_CHAR(MOD(TRUNC(v_pid/65536),256),'FM0X');
    v_b4 := TO_CHAR(MOD(c.computer_id,256),'FM0X');
    v_b5 := TO_CHAR(MOD(TRUNC(c.computer_id/256),256),'FM0X');

    -- Port du côté de l'ordinateur
    INSERT INTO CYT_NETWORKPORTS (port_id, items_id, item_type, entity_id,
      logical_number, port_name, mac_address, network_id, port_status)
    VALUES (v_pid, c.computer_id, 'COMPUTER', 1, 0, 'eth0',
            v_b1||':'||v_b2||':'||v_b3||':'||v_b4||':'||v_b5||':03',
            MOD(v_pid,3)+1, 'ACTIVE');

    -- Port du côté du switch
    v_spid := SEQ_NETWORKPORT_ID.NEXTVAL;
    INSERT INTO CYT_NETWORKPORTS (port_id, items_id, item_type, entity_id,
      logical_number, port_name, network_id, port_status)
    VALUES (v_spid, MOD(c.computer_id,v_sw)+1, 'NETEQUIP', 1,
            MOD(c.computer_id,48),
            'GigabitEthernet0/'||TO_CHAR(MOD(c.computer_id,48)),
            MOD(v_spid,3)+1, 'ACTIVE');

    -- On crée le lien physique entre le PC et le switch
    INSERT INTO CYT_PORT_LINKS (port_src, port_dst) VALUES (v_pid, v_spid);

    IF MOD(v_pid,200)=0 THEN COMMIT; END IF;
  END LOOP;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('Ports Pau inseres');
END;
/

-- Attribution des adresses IP
-- Très important : on décale la plage réseau (10.1.x.y) pour être sûr de ne pas avoir de conflits avec les IP générées sur le site de Cergy (qui sont en 10.0.x.y)
DECLARE
  v_o2 NUMBER; v_o3 NUMBER; v_o4 NUMBER;
BEGIN
  FOR c IN (SELECT computer_id, entity_id FROM CYT_COMPUTERS WHERE ROWNUM<=2000) LOOP
    -- On force le premier octet variable à 1 (v_o2) pour faire la plage 10.1
    v_o2 := 1 + TRUNC((c.computer_id-1)/65025);
    v_o3 := TRUNC(MOD((c.computer_id-1),65025)/255);
    v_o4 := MOD((c.computer_id-1),255)+1;
    INSERT INTO CYT_IPADDRESSES (entity_id, items_id, item_type, ip_address)
    VALUES (c.entity_id, c.computer_id, 'COMPUTER',
            '10.'||TO_CHAR(v_o2)||'.'||TO_CHAR(v_o3)||'.'||TO_CHAR(v_o4));
    IF MOD(c.computer_id,300)=0 THEN COMMIT; END IF;
  END LOOP;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('IPs Pau inserees');
END;
/

-- Tableau récapitulatif pour vérifier à la fin que tout a bien été inséré
SELECT 'CYT_COMPUTERS' t, COUNT(*) n FROM CYT_COMPUTERS UNION ALL
SELECT 'CYT_USERS',    COUNT(*) FROM CYT_USERS           UNION ALL
SELECT 'CYT_NETWORKPORTS', COUNT(*) FROM CYT_NETWORKPORTS UNION ALL
SELECT 'CYT_PORT_LINKS',   COUNT(*) FROM CYT_PORT_LINKS  UNION ALL
SELECT 'CYT_IPADDRESSES',  COUNT(*) FROM CYT_IPADDRESSES UNION ALL
SELECT 'CYT_NETEQUIP',     COUNT(*) FROM CYT_NETEQUIP;
