-- =============================================================================
-- FICHIER  : cergy/08_triggers.sql
-- INSTANCE : cergy_db (Lead)
-- NOTION   : Triggers PL/SQL
-- =============================================================================

-- =============================================================================
-- TRIGGER 1 — TRG_AUDIT_COMPUTERS
-- UC08 : audit automatique de toutes les modifications sur CYT_COMPUTERS
-- Type : AFTER INSERT OR UPDATE OR DELETE FOR EACH ROW
-- Action : INSERT dans CYT_AUDIT_LOG avec old_value / new_value
-- =============================================================================
CREATE OR REPLACE TRIGGER TRG_AUDIT_COMPUTERS
  AFTER INSERT OR UPDATE OR DELETE ON CYT_COMPUTERS
  FOR EACH ROW
DECLARE
  v_op        VARCHAR2(10);
  v_old_val   VARCHAR2(500);
  v_new_val   VARCHAR2(500);
  v_item_id   NUMBER;
  v_entity_id NUMBER;
BEGIN
  IF INSERTING THEN
    v_op        := 'INSERT';
    v_old_val   := NULL;
    v_new_val   := 'serial='  || :NEW.serial
                || ',name='   || :NEW.computer_name
                || ',status=' || :NEW.status
                || ',entity=' || TO_CHAR(:NEW.entity_id);
    v_item_id   := :NEW.computer_id;
    v_entity_id := :NEW.entity_id;

  ELSIF UPDATING THEN
    v_op        := 'UPDATE';
    v_old_val   := 'status='   || :OLD.status
                || ',location='|| TO_CHAR(:OLD.location_id)
                || ',user='    || TO_CHAR(:OLD.user_id);
    v_new_val   := 'status='   || :NEW.status
                || ',location='|| TO_CHAR(:NEW.location_id)
                || ',user='    || TO_CHAR(:NEW.user_id);
    v_item_id   := :NEW.computer_id;
    v_entity_id := :NEW.entity_id;

  ELSE
    v_op        := 'DELETE';
    v_old_val   := 'serial='  || :OLD.serial
                || ',name='   || :OLD.computer_name
                || ',status=' || :OLD.status;
    v_new_val   := NULL;
    v_item_id   := :OLD.computer_id;
    v_entity_id := :OLD.entity_id;
  END IF;

  INSERT INTO CYT_AUDIT_LOG (
    table_name, item_id, entity_id,
    operation, user_db,
    old_value, new_value, log_date
  ) VALUES (
    'CYT_COMPUTERS', v_item_id, v_entity_id,
    v_op, USER,
    v_old_val, v_new_val, SYSDATE
  );

EXCEPTION
  WHEN OTHERS THEN NULL;  -- ne jamais bloquer la transaction principale
END TRG_AUDIT_COMPUTERS;
/


-- =============================================================================
-- TRIGGER 2 — TRG_AUDIT_USERS
-- UC08 : audit des créations et modifications d'utilisateurs
-- =============================================================================
CREATE OR REPLACE TRIGGER TRG_AUDIT_USERS
  AFTER INSERT OR UPDATE OR DELETE ON CYT_USERS
  FOR EACH ROW
DECLARE
  v_op      VARCHAR2(10);
  v_old_val VARCHAR2(500);
  v_new_val VARCHAR2(500);
BEGIN
  IF INSERTING THEN
    v_op    := 'INSERT';
    v_new_val := 'login=' || :NEW.login || ',active=' || TO_CHAR(:NEW.is_active);
  ELSIF UPDATING THEN
    v_op    := 'UPDATE';
    v_old_val := 'active=' || TO_CHAR(:OLD.is_active)
              || ',profile='|| TO_CHAR(:OLD.profile_id);
    v_new_val := 'active=' || TO_CHAR(:NEW.is_active)
              || ',profile='|| TO_CHAR(:NEW.profile_id);
  ELSE
    v_op    := 'DELETE';
    v_old_val := 'login=' || :OLD.login;
  END IF;

  INSERT INTO CYT_AUDIT_LOG (
    table_name, item_id, entity_id,
    operation, user_db, old_value, new_value, log_date
  ) VALUES (
    'CYT_USERS',
    NVL(:NEW.user_id, :OLD.user_id),
    NVL(:NEW.entity_id, :OLD.entity_id),
    v_op, USER, v_old_val, v_new_val, SYSDATE
  );
EXCEPTION
  WHEN OTHERS THEN NULL;
END TRG_AUDIT_USERS;
/


-- =============================================================================
-- TRIGGER 3 — TRG_SYNC_USER_PAU
-- UC06 : quand un utilisateur est créé/modifié sur Cergy,
--        le répliquer automatiquement sur Pau pour l'itinérance
-- PRAGMA AUTONOMOUS_TRANSACTION : si Pau est indisponible,
--   la transaction Cergy n'est PAS annulée
-- =============================================================================
CREATE OR REPLACE TRIGGER TRG_SYNC_USER_PAU
  AFTER INSERT OR UPDATE ON CYT_USERS
  FOR EACH ROW
DECLARE
  PRAGMA AUTONOMOUS_TRANSACTION;
  v_count NUMBER;
BEGIN
  -- Vérifier si l'user existe déjà sur Pau
  SELECT COUNT(*) INTO v_count
  FROM   CYT_USERS@DBLINK_PAU
  WHERE  login = :NEW.login;

  IF INSERTING THEN
    IF v_count = 0 THEN
      -- Créer l'utilisateur sur Pau
      INSERT INTO CYT_USERS@DBLINK_PAU (
        login, password_hash, realname, firstname,
        entity_id, profile_id, is_active, date_created
      ) VALUES (
        :NEW.login, :NEW.password_hash,
        :NEW.realname, :NEW.firstname,
        1,              -- entity_id local Pau
        1,              -- profil Technicien par défaut sur Pau
        :NEW.is_active,
        SYSDATE
      );
    END IF;

  ELSIF UPDATING THEN
    IF v_count > 0 THEN
      -- Synchroniser mot de passe et statut uniquement
      UPDATE CYT_USERS@DBLINK_PAU
      SET    is_active     = :NEW.is_active,
             password_hash = :NEW.password_hash,
             date_mod      = SYSDATE
      WHERE  login = :NEW.login;
    END IF;
  END IF;

  COMMIT;

EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    -- Logger l'échec de sync sans bloquer Cergy
    INSERT INTO CYT_AUDIT_LOG (
      table_name, item_id, entity_id,
      operation, user_db, new_value, log_date
    ) VALUES (
      'SYNC_PAU_FAILED', :NEW.user_id, :NEW.entity_id,
      'INSERT', USER,
      'Echec sync Pau : ' || SQLERRM,
      SYSDATE
    );
    COMMIT;
END TRG_SYNC_USER_PAU;
/


-- =============================================================================
-- TRIGGER 4 — TRG_STATUS_TRANSFER
-- UC07 : quand un transfert est enregistré dans CYT_ASSET_TRANSFER,
--        mettre automatiquement le PC en statut 'TRANSFERT'
-- Type : BEFORE INSERT (pour agir avant l'insertion du transfert)
-- =============================================================================
CREATE OR REPLACE TRIGGER TRG_STATUS_TRANSFER
  BEFORE INSERT ON CYT_ASSET_TRANSFER
  FOR EACH ROW
BEGIN
  -- Mettre le PC en statut TRANSFERT automatiquement
  UPDATE CYT_COMPUTERS
  SET    status   = 'TRANSFERT',
         date_mod = SYSDATE
  WHERE  computer_id = :NEW.computer_id
  AND    status NOT IN ('TRANSFERT','RETIRE');

  IF SQL%ROWCOUNT = 0 THEN
    RAISE_APPLICATION_ERROR(-20010,
      'PC introuvable ou déjà en transfert : id=' || :NEW.computer_id);
  END IF;
END TRG_STATUS_TRANSFER;
/

-- Vérification
SELECT trigger_name, table_name, trigger_type, status
FROM   user_triggers
WHERE  table_name LIKE 'CYT_%'
ORDER BY table_name;
