-- =============================================================================
-- FICHIER  : cergy/09_procedures_fonctions.sql
-- INSTANCE : cergy_db (Lead)
-- NOTION   : Procédures, Fonctions, Curseurs, Package PL/SQL
-- =============================================================================

-- =============================================================================
-- FONCTION 1 — F_COUNT_ASSETS
-- UC10 : compter les équipements par site et statut
-- Utilisée dans les rapports et tests de performance
-- =============================================================================
CREATE OR REPLACE FUNCTION F_COUNT_ASSETS (
  p_site_code IN VARCHAR2,
  p_status    IN VARCHAR2 DEFAULT NULL
) RETURN NUMBER AS
  v_count    NUMBER;
  v_entity   NUMBER;
BEGIN
  SELECT entity_id INTO v_entity
  FROM   CYT_ENTITIES
  WHERE  site_code = UPPER(p_site_code);

  IF p_status IS NULL THEN
    SELECT COUNT(*) INTO v_count
    FROM   CYT_COMPUTERS
    WHERE  entity_id = v_entity AND is_deleted = 0;
  ELSE
    SELECT COUNT(*) INTO v_count
    FROM   CYT_COMPUTERS
    WHERE  entity_id = v_entity
    AND    status    = UPPER(p_status)
    AND    is_deleted = 0;
  END IF;

  RETURN v_count;
EXCEPTION
  WHEN NO_DATA_FOUND THEN RETURN -1;
  WHEN OTHERS        THEN RETURN -2;
END F_COUNT_ASSETS;
/


-- =============================================================================
-- FONCTION 2 — F_IP_AVAILABLE
-- UC04 : vérifier si une adresse IP est libre sur un site
-- =============================================================================
CREATE OR REPLACE FUNCTION F_IP_AVAILABLE (
  p_ip        IN VARCHAR2,
  p_site_code IN VARCHAR2
) RETURN VARCHAR2 AS   -- retourne 'OUI' ou 'NON'
  v_count   NUMBER;
  v_entity  NUMBER;
BEGIN
  SELECT entity_id INTO v_entity
  FROM   CYT_ENTITIES WHERE site_code = UPPER(p_site_code);

  SELECT COUNT(*) INTO v_count
  FROM   CYT_IPADDRESSES
  WHERE  ip_address = p_ip
  AND    entity_id  = v_entity
  AND    is_deleted = 0;

  RETURN CASE WHEN v_count = 0 THEN 'OUI' ELSE 'NON' END;
EXCEPTION
  WHEN OTHERS THEN RETURN 'ERREUR';
END F_IP_AVAILABLE;
/


-- =============================================================================
-- PROCÉDURE 1 — P_TRANSFER_ASSET
-- UC07 : transfert atomique d'un PC de Cergy vers Pau
-- Le trigger TRG_STATUS_TRANSFER gère le changement de statut automatiquement
-- =============================================================================
CREATE OR REPLACE PROCEDURE P_TRANSFER_ASSET (
  p_computer_id  IN NUMBER,
  p_reason       IN VARCHAR2 DEFAULT 'Transfert inter-sites',
  p_initiated_by IN NUMBER
) AS
  v_serial      VARCHAR2(100);
  v_name        VARCHAR2(100);
  v_entity_src  NUMBER;
  v_entity_dst  NUMBER;
  v_model_id    NUMBER;
  v_type_id     NUMBER;
  v_manuf_id    NUMBER;
BEGIN
  -- Récupérer les infos du PC
  SELECT entity_id, serial, computer_name, model_id, type_id, manufacturer_id
  INTO   v_entity_src, v_serial, v_name, v_model_id, v_type_id, v_manuf_id
  FROM   CYT_COMPUTERS
  WHERE  computer_id = p_computer_id AND is_deleted = 0;

  -- Vérifier que le PC est bien sur Cergy
  SELECT entity_id INTO v_entity_src
  FROM   CYT_ENTITIES WHERE site_code = 'CERGY';

  SELECT entity_id INTO v_entity_dst
  FROM   CYT_ENTITIES WHERE site_code = 'PAU';

  -- Enregistrer le transfert (TRG_STATUS_TRANSFER se déclenche automatiquement)
  INSERT INTO CYT_ASSET_TRANSFER (
    computer_id, entity_src, entity_dst,
    initiated_by, transfer_date, reason, status
  ) VALUES (
    p_computer_id, v_entity_src, v_entity_dst,
    p_initiated_by, SYSDATE, p_reason, 'EN_COURS'
  );

  -- Copier le PC sur Pau via DBLink
  INSERT INTO CYT_COMPUTERS@DBLINK_PAU (
    serial, computer_name, entity_id,
    model_id, type_id, manufacturer_id,
    status, date_purchase, date_created
  ) VALUES (
    v_serial, v_name, 1,
    v_model_id, v_type_id, v_manuf_id,
    'ACTIF', SYSDATE, SYSDATE
  );

  -- Marquer comme supprimé sur Cergy (transfert définitif)
  UPDATE CYT_COMPUTERS
  SET    is_deleted = 1, date_mod = SYSDATE
  WHERE  computer_id = p_computer_id;

  -- Marquer le transfert comme terminé
  UPDATE CYT_ASSET_TRANSFER
  SET    status = 'TERMINE'
  WHERE  computer_id = p_computer_id AND status = 'EN_COURS';

  -- Mettre à jour le timestamp de dernière sync dans CYT_ENTITIES
  UPDATE CYT_ENTITIES
  SET    pau_last_sync = SYSDATE
  WHERE  site_code = 'CERGY';

  COMMIT;
  DBMS_OUTPUT.PUT_LINE('OK : ' || v_name || ' (' || v_serial || ') transfere vers Pau');

EXCEPTION
  WHEN NO_DATA_FOUND THEN
    ROLLBACK;
    RAISE_APPLICATION_ERROR(-20001, 'PC introuvable : id=' || p_computer_id);
  WHEN OTHERS THEN
    ROLLBACK;
    RAISE_APPLICATION_ERROR(-20002, 'Erreur transfert : ' || SQLERRM);
END P_TRANSFER_ASSET;
/


-- =============================================================================
-- PROCÉDURE 2 — P_CREATE_USER
-- UC02 + UC06 : créer un utilisateur sur un ou les deux sites
-- p_site = 'CERGY', 'PAU' ou 'ALL' (itinérance)
-- =============================================================================
CREATE OR REPLACE PROCEDURE P_CREATE_USER (
  p_login     IN VARCHAR2,
  p_password  IN VARCHAR2,
  p_realname  IN VARCHAR2,
  p_firstname IN VARCHAR2,
  p_site      IN VARCHAR2,   -- 'CERGY', 'PAU' ou 'ALL'
  p_profile   IN NUMBER DEFAULT 2  -- 2 = Technicien
) AS
  v_entity_id NUMBER;
  v_user_id   NUMBER;
BEGIN
  IF UPPER(p_site) IN ('CERGY', 'ALL') THEN
    SELECT entity_id INTO v_entity_id
    FROM   CYT_ENTITIES WHERE site_code = 'CERGY';

    INSERT INTO CYT_USERS (
      login, password_hash, realname, firstname,
      entity_id, profile_id, is_active
    ) VALUES (
      p_login, p_password, p_realname, p_firstname,
      v_entity_id, p_profile, 1
    ) RETURNING user_id INTO v_user_id;

    -- Créer aussi la fiche détail
    INSERT INTO CYT_USERS_DETAIL (user_id, language)
    VALUES (v_user_id, 'fr_FR');
  END IF;

  IF UPPER(p_site) IN ('PAU', 'ALL') THEN
    -- Insérer directement sur Pau via DBLink
    INSERT INTO CYT_USERS@DBLINK_PAU (
      login, password_hash, realname, firstname,
      entity_id, profile_id, is_active, date_created
    ) VALUES (
      p_login, p_password, p_realname, p_firstname,
      1, 1, 1, SYSDATE
    );
  END IF;

  COMMIT;
  DBMS_OUTPUT.PUT_LINE('User ' || p_login || ' cree sur ' || UPPER(p_site));
EXCEPTION
  WHEN DUP_VAL_ON_INDEX THEN
    ROLLBACK;
    RAISE_APPLICATION_ERROR(-20003, 'Login deja existant : ' || p_login);
  WHEN OTHERS THEN
    ROLLBACK;
    RAISE_APPLICATION_ERROR(-20004, 'Erreur creation user : ' || SQLERRM);
END P_CREATE_USER;
/


-- =============================================================================
-- CURSEUR EXPLICITE — dans P_RAPPORT_INVENTAIRE_SALLE
-- UC01 : rapport d'inventaire d'une salle avec mapping réseau
-- Démontre : CURSOR paramétré, OPEN/FETCH/CLOSE, %ROWTYPE, %NOTFOUND, %ISOPEN
-- =============================================================================
CREATE OR REPLACE PROCEDURE P_RAPPORT_INVENTAIRE_SALLE (
  p_building IN VARCHAR2,
  p_room     IN VARCHAR2
) AS
  -- Curseur paramétré : liste les PC d'une salle avec leur réseau
  CURSOR cur_inventaire (v_building VARCHAR2, v_room VARCHAR2) IS
    SELECT c.computer_name,
           c.serial,
           c.status,
           np.mac_address,
           np.port_name       AS pc_port,
           sw.netequip_name   AS switch_name,
           np_sw.port_name    AS switch_port,
           n.vlan_id,
           n.subnet
    FROM   CYT_COMPUTERS c
    JOIN   CYT_LOCATIONS l
           ON l.location_id = c.location_id
    LEFT JOIN CYT_NETWORKPORTS np
           ON np.items_id  = c.computer_id
           AND np.item_type = 'COMPUTER'
           AND np.is_deleted = 0
    LEFT JOIN CYT_PORT_LINKS pl
           ON pl.port_src = np.port_id
    LEFT JOIN CYT_NETWORKPORTS np_sw
           ON np_sw.port_id = pl.port_dst
    LEFT JOIN CYT_NETEQUIP sw
           ON sw.netequip_id = np_sw.items_id
    LEFT JOIN CYT_NETWORKS n
           ON n.network_id = np.network_id
    WHERE  l.building   = v_building
    AND    l.room       = v_room
    AND    c.is_deleted = 0
    ORDER BY c.computer_name;

  v_rec      cur_inventaire%ROWTYPE;
  v_compteur NUMBER := 0;
BEGIN
  DBMS_OUTPUT.PUT_LINE('=== INVENTAIRE : ' || p_building || ' / ' || p_room || ' ===');
  DBMS_OUTPUT.PUT_LINE(
    RPAD('PC',      20) || RPAD('Serial', 12) || RPAD('Statut', 14) ||
    RPAD('Switch',  20) || RPAD('Port SW', 10) || 'VLAN'
  );
  DBMS_OUTPUT.PUT_LINE(RPAD('-', 80, '-'));

  -- Ouverture explicite du curseur
  OPEN cur_inventaire(p_building, p_room);

  LOOP
    FETCH cur_inventaire INTO v_rec;
    EXIT WHEN cur_inventaire%NOTFOUND;
    v_compteur := v_compteur + 1;
    DBMS_OUTPUT.PUT_LINE(
      RPAD(v_rec.computer_name,              20) ||
      RPAD(v_rec.serial,                     12) ||
      RPAD(v_rec.status,                     14) ||
      RPAD(NVL(v_rec.switch_name, 'Non connecte'), 20) ||
      RPAD(NVL(v_rec.switch_port, '-'),      10) ||
      NVL(TO_CHAR(v_rec.vlan_id), '-')
    );
  END LOOP;

  -- Fermeture explicite
  CLOSE cur_inventaire;

  DBMS_OUTPUT.PUT_LINE(RPAD('-', 80, '-'));
  DBMS_OUTPUT.PUT_LINE('Total : ' || v_compteur || ' PC');

EXCEPTION
  WHEN OTHERS THEN
    IF cur_inventaire%ISOPEN THEN CLOSE cur_inventaire; END IF;
    RAISE;
END P_RAPPORT_INVENTAIRE_SALLE;
/


-- =============================================================================
-- REF CURSOR — P_DYNAMIC_REPORT
-- Rapport dynamique pour le DSI — curseur ouvert sur une requête construite
-- =============================================================================
CREATE OR REPLACE PROCEDURE P_DYNAMIC_REPORT (
  p_site   IN  VARCHAR2,          -- 'CERGY', 'PAU' ou 'ALL'
  p_status IN  VARCHAR2 DEFAULT NULL,
  p_cursor OUT SYS_REFCURSOR
) AS
  v_sql VARCHAR2(1000);
BEGIN
  v_sql := 'SELECT computer_name, serial, status, date_created '
        || 'FROM CYT_COMPUTERS c '
        || 'JOIN CYT_ENTITIES e ON e.entity_id = c.entity_id '
        || 'WHERE c.is_deleted = 0 ';

  IF UPPER(p_site) != 'ALL' THEN
    v_sql := v_sql || 'AND e.site_code = ''' || UPPER(p_site) || ''' ';
  END IF;

  IF p_status IS NOT NULL THEN
    v_sql := v_sql || 'AND c.status = ''' || UPPER(p_status) || ''' ';
  END IF;

  v_sql := v_sql || 'ORDER BY c.computer_name';

  OPEN p_cursor FOR v_sql;
END P_DYNAMIC_REPORT;
/


-- =============================================================================
-- PACKAGE PKG_GLPI_CYTECH
-- Regroupe toutes les procédures et fonctions dans une unité cohérente
-- =============================================================================
CREATE OR REPLACE PACKAGE PKG_GLPI_CYTECH AS
  -- Fonctions
  FUNCTION  F_COUNT_ASSETS(p_site VARCHAR2, p_status VARCHAR2 DEFAULT NULL)
    RETURN NUMBER;
  FUNCTION  F_IP_AVAILABLE(p_ip VARCHAR2, p_site_code VARCHAR2)
    RETURN VARCHAR2;

  -- Procédures
  PROCEDURE P_TRANSFER_ASSET(p_computer_id NUMBER,
                              p_reason      VARCHAR2 DEFAULT 'Transfert',
                              p_initiated_by NUMBER);
  PROCEDURE P_CREATE_USER(p_login     VARCHAR2,
                          p_password  VARCHAR2,
                          p_realname  VARCHAR2,
                          p_firstname VARCHAR2,
                          p_site      VARCHAR2,
                          p_profile   NUMBER DEFAULT 2);
  PROCEDURE P_RAPPORT_INVENTAIRE_SALLE(p_building VARCHAR2, p_room VARCHAR2);
  PROCEDURE P_DYNAMIC_REPORT(p_site   VARCHAR2,
                              p_status VARCHAR2 DEFAULT NULL,
                              p_cursor OUT SYS_REFCURSOR);
END PKG_GLPI_CYTECH;
/

CREATE OR REPLACE PACKAGE BODY PKG_GLPI_CYTECH AS

  FUNCTION F_COUNT_ASSETS(p_site VARCHAR2, p_status VARCHAR2 DEFAULT NULL)
    RETURN NUMBER AS
  BEGIN RETURN F_COUNT_ASSETS(p_site, p_status); END;

  FUNCTION F_IP_AVAILABLE(p_ip VARCHAR2, p_site_code VARCHAR2)
    RETURN VARCHAR2 AS
  BEGIN RETURN F_IP_AVAILABLE(p_ip, p_site_code); END;

  PROCEDURE P_TRANSFER_ASSET(p_computer_id NUMBER,
                              p_reason VARCHAR2 DEFAULT 'Transfert',
                              p_initiated_by NUMBER) AS
  BEGIN P_TRANSFER_ASSET(p_computer_id, p_reason, p_initiated_by); END;

  PROCEDURE P_CREATE_USER(p_login VARCHAR2, p_password VARCHAR2,
                          p_realname VARCHAR2, p_firstname VARCHAR2,
                          p_site VARCHAR2, p_profile NUMBER DEFAULT 2) AS
  BEGIN P_CREATE_USER(p_login, p_password, p_realname,
                                         p_firstname, p_site, p_profile); END;

  PROCEDURE P_RAPPORT_INVENTAIRE_SALLE(p_building VARCHAR2, p_room VARCHAR2) AS
  BEGIN P_RAPPORT_INVENTAIRE_SALLE(p_building, p_room); END;

  PROCEDURE P_DYNAMIC_REPORT(p_site VARCHAR2, p_status VARCHAR2 DEFAULT NULL,
                              p_cursor OUT SYS_REFCURSOR) AS
  BEGIN P_DYNAMIC_REPORT(p_site, p_status, p_cursor); END;

END PKG_GLPI_CYTECH;
/

-- Vérification
SELECT object_name, object_type, status
FROM   user_objects
WHERE  object_type IN ('FUNCTION','PROCEDURE','PACKAGE','PACKAGE BODY','TRIGGER')
ORDER BY object_type, object_name;