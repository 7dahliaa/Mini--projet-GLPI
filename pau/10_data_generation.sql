-- =============================================================================
-- FICHIER  : pau/10_data_generation.sql
-- NOTION   : Génération données test Pau — 2000 PC, 500 users
-- =============================================================================
SET SERVEROUTPUT ON SIZE 1000000;

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

-- Localisations Pau
BEGIN
  FOR i IN 1..5 LOOP
    INSERT INTO CYT_LOCATIONS (entity_id, location_name, building, room, floor)
    VALUES (1, 'Salle PAU '||TO_CHAR(i,'FM000'),
            'Bat-PAU-'||CHR(64+i), 'S'||TO_CHAR(i*10), MOD(i,3));
  END LOOP;
  COMMIT;
END;
/

-- Switchs Pau
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
END;
/

-- Users Pau (500)
DECLARE v_uid NUMBER;
BEGIN
  FOR i IN 1..500 LOOP
    INSERT INTO CYT_USERS (login, password_hash, realname, firstname,
      entity_id, profile_id, is_active)
    VALUES ('pau_user'||TO_CHAR(i), DBMS_RANDOM.STRING('A',60),
            DBMS_RANDOM.STRING('U',8), DBMS_RANDOM.STRING('L',6),
            1, 1, 1) RETURNING user_id INTO v_uid;
    INSERT INTO CYT_USERS_DETAIL (user_id, language)
    VALUES (v_uid, 'fr_FR');
    IF MOD(i,100)=0 THEN COMMIT; END IF;
  END LOOP;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('500 users Pau insérés');
END;
/

-- PC Pau (2000)
DECLARE
  v_max_loc  NUMBER;
  v_max_user NUMBER;
  v_cid      NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_max_loc  FROM CYT_LOCATIONS;
  SELECT COUNT(*) INTO v_max_user FROM CYT_USERS;
  FOR i IN 1..2000 LOOP
    INSERT INTO CYT_COMPUTERS (serial, computer_name, entity_id, location_id,
      type_id, model_id, manufacturer_id, user_id, status, date_created)
    VALUES ('SN-PAU-'||TO_CHAR(i,'FM00000'),
            'PC-PAU-'||TO_CHAR(i,'FM00000'),
            1, MOD(i,v_max_loc)+1,
            MOD(i,3)+1, MOD(i,2)+1, MOD(i,4)+1,
            MOD(i,v_max_user)+1,
            CASE WHEN MOD(i,15)=0 THEN 'HORS_SERVICE'
                 WHEN MOD(i,20)=0 THEN 'EN_STOCK'
                 ELSE 'ACTIF' END,
            SYSDATE - DBMS_RANDOM.VALUE(0,1825)) RETURNING computer_id INTO v_cid;
    INSERT INTO CYT_COMPUTERS_DETAIL (computer_id, uuid, ticket_tco)
    VALUES (v_cid, SYS_GUID(), ROUND(DBMS_RANDOM.VALUE(500,3000),2));
    IF MOD(i,200)=0 THEN COMMIT; END IF;
  END LOOP;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('2000 PC Pau insérés');
END;
/

-- Ports réseau Pau
DECLARE v_pid NUMBER; v_spid NUMBER; v_sw NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_sw FROM CYT_NETEQUIP;
  FOR c IN (SELECT computer_id FROM CYT_COMPUTERS WHERE ROWNUM<=2000) LOOP
    v_pid  := SEQ_NETWORKPORT_ID.NEXTVAL;
    v_spid := SEQ_NETWORKPORT_ID.NEXTVAL;
    INSERT INTO CYT_NETWORKPORTS (port_id, items_id, item_type, entity_id,
      logical_number, port_name, network_id, port_status)
    VALUES (v_pid, c.computer_id, 'COMPUTER', 1, 0, 'eth0',
            MOD(v_pid,3)+1, 'ACTIVE');
    INSERT INTO CYT_NETWORKPORTS (port_id, items_id, item_type, entity_id,
      logical_number, port_name, network_id, port_status)
    VALUES (v_spid, MOD(c.computer_id,v_sw)+1, 'NETEQUIP', 1,
            MOD(c.computer_id,48),
            'GigabitEthernet0/'||TO_CHAR(MOD(c.computer_id,48)),
            MOD(v_spid,3)+1, 'ACTIVE');
    INSERT INTO CYT_PORT_LINKS (port_src, port_dst) VALUES (v_pid, v_spid);
    IF MOD(v_pid,200)=0 THEN COMMIT; END IF;
  END LOOP;
  COMMIT;
END;
/

-- IPs Pau
BEGIN
  FOR c IN (SELECT computer_id, entity_id FROM CYT_COMPUTERS WHERE ROWNUM<=2000) LOOP
    INSERT INTO CYT_IPADDRESSES (entity_id, items_id, item_type, ip_address)
    VALUES (c.entity_id, c.computer_id, 'COMPUTER',
            '192.168.'||TO_CHAR(110+MOD(c.computer_id,10))||'.'
            ||TO_CHAR(MOD(c.computer_id,253)+1));
    IF MOD(c.computer_id,300)=0 THEN COMMIT; END IF;
  END LOOP;
  COMMIT;
END;
/

SELECT 'CYT_COMPUTERS' t, COUNT(*) n FROM CYT_COMPUTERS UNION ALL
SELECT 'CYT_USERS',    COUNT(*) FROM CYT_USERS          UNION ALL
SELECT 'CYT_NETWORKPORTS', COUNT(*) FROM CYT_NETWORKPORTS;