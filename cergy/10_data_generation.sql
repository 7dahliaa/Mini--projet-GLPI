-- =============================================================================
-- FICHIER  : cergy/10_data_generation.sql
-- VOLUMES  : 3000 PC, 1000 users, ports reseau, liaisons
-- =============================================================================
SET SERVEROUTPUT ON SIZE 1000000;

-- Nettoyage complet
DELETE FROM CYT_AUDIT_LOG;
DELETE FROM CYT_ASSET_TRANSFER;
DELETE FROM CYT_INFOCOMS;
DELETE FROM CYT_IPADDRESSES;
DELETE FROM CYT_COMPUTERS_DETAIL;
DELETE FROM CYT_PORT_LINKS;
DELETE FROM CYT_NETWORKPORTS;
DELETE FROM CYT_COMPUTERS;
COMMIT;

-- BLOC 4 : PC Cergy (3000)
DECLARE
  v_cid   NUMBER;
  TYPE t_ids IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
  v_locs  t_ids;
  v_users t_ids;
  v_nloc  NUMBER := 0;
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

  FOR i IN 1..3000 LOOP
    INSERT INTO CYT_COMPUTERS (
      serial, computer_name, entity_id, location_id,
      type_id, model_id, manufacturer_id, user_id,
      status, date_purchase, date_created
    ) VALUES (
      'SN-CY-' || TO_CHAR(i, 'FM00000'),
      'PC-CERGY-' || TO_CHAR(i, 'FM00000'),
      1,
      v_locs(MOD(i-1, v_nloc) + 1),
      MOD(i, 4) + 1, MOD(i, 4) + 1, MOD(i, 4) + 1,
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

-- BLOC 5 : Ports reseau + liaisons
-- MAC unique : basee sur port_id (toujours unique via sequence)
-- Format : aa:bb:cc:dd:ee:ff avec 6 octets distincts
DECLARE
  v_pid    NUMBER;
  v_spid   NUMBER;
  v_sw     NUMBER;
  v_b1     VARCHAR2(2); v_b2 VARCHAR2(2);
  v_b3     VARCHAR2(2); v_b4 VARCHAR2(2);
  v_b5     VARCHAR2(2); v_b6 VARCHAR2(2);
BEGIN
  SELECT COUNT(*) INTO v_sw FROM CYT_NETEQUIP;

  FOR c IN (SELECT computer_id FROM CYT_COMPUTERS
            WHERE is_deleted = 0 AND ROWNUM <= 3000) LOOP
    v_pid := SEQ_NETWORKPORT_ID.NEXTVAL;

    -- MAC unique basee sur v_pid (6 octets independants)
    v_b1 := TO_CHAR(MOD(TRUNC(v_pid/1),256),'FM0X');
    v_b2 := TO_CHAR(MOD(TRUNC(v_pid/256),256),'FM0X');
    v_b3 := TO_CHAR(MOD(TRUNC(v_pid/65536),256),'FM0X');
    v_b4 := TO_CHAR(MOD(c.computer_id,256),'FM0X');
    v_b5 := TO_CHAR(MOD(TRUNC(c.computer_id/256),256),'FM0X');
    v_b6 := '02';  -- bit admin local = unique

    INSERT INTO CYT_NETWORKPORTS (
      port_id, items_id, item_type, entity_id,
      logical_number, port_name, mac_address, network_id, port_status
    ) VALUES (
      v_pid, c.computer_id, 'COMPUTER', 1, 0, 'eth0',
      v_b1||':'||v_b2||':'||v_b3||':'||v_b4||':'||v_b5||':'||v_b6,
      MOD(v_pid,3)+1, 'ACTIVE'
    );

    v_spid := SEQ_NETWORKPORT_ID.NEXTVAL;
    INSERT INTO CYT_NETWORKPORTS (
      port_id, items_id, item_type, entity_id,
      logical_number, port_name, network_id, port_status
    ) VALUES (
      v_spid, MOD(c.computer_id,v_sw)+1, 'NETEQUIP', 1,
      MOD(c.computer_id,48),
      'GigabitEthernet0/'||TO_CHAR(MOD(c.computer_id,48)),
      MOD(v_spid,3)+1, 'ACTIVE'
    );

    INSERT INTO CYT_PORT_LINKS (port_src, port_dst)
    VALUES (v_pid, v_spid);

    IF MOD(v_pid,200)=0 THEN COMMIT; END IF;
  END LOOP;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('Ports et liaisons inseres');
END;
/

-- BLOC 6 : Adresses IP uniques
-- Format : 10.x.y.z avec x,y,z bases sur computer_id pour garantir unicite
DECLARE
  v_octet2 NUMBER;
  v_octet3 NUMBER;
  v_octet4 NUMBER;
BEGIN
  FOR c IN (SELECT computer_id, entity_id FROM CYT_COMPUTERS
            WHERE is_deleted = 0 AND ROWNUM <= 3000) LOOP
    -- computer_id unique -> IP unique
    v_octet2 := TRUNC((c.computer_id - 1) / 65025);
    v_octet3 := TRUNC(MOD((c.computer_id - 1), 65025) / 255);
    v_octet4 := MOD((c.computer_id - 1), 255) + 1;

    INSERT INTO CYT_IPADDRESSES (entity_id, items_id, item_type, ip_address)
    VALUES (c.entity_id, c.computer_id, 'COMPUTER',
            '10.' || TO_CHAR(v_octet2) || '.'
                  || TO_CHAR(v_octet3) || '.'
                  || TO_CHAR(v_octet4));

    IF MOD(c.computer_id,300)=0 THEN COMMIT; END IF;
  END LOOP;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('IPs inserees');
END;
/

-- Resume final
SELECT 'CYT_COMPUTERS'    AS t, COUNT(*) n FROM CYT_COMPUTERS    UNION ALL
SELECT 'CYT_USERS',            COUNT(*) FROM CYT_USERS            UNION ALL
SELECT 'CYT_NETWORKPORTS',     COUNT(*) FROM CYT_NETWORKPORTS     UNION ALL
SELECT 'CYT_PORT_LINKS',       COUNT(*) FROM CYT_PORT_LINKS       UNION ALL
SELECT 'CYT_IPADDRESSES',      COUNT(*) FROM CYT_IPADDRESSES      UNION ALL
SELECT 'CYT_NETEQUIP',         COUNT(*) FROM CYT_NETEQUIP         UNION ALL
SELECT 'CYT_AUDIT_LOG',        COUNT(*) FROM CYT_AUDIT_LOG;