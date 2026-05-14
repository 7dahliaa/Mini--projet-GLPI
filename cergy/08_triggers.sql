-- =============================================================================
-- FICHIER  : cergy/08_triggers.sql
-- =============================================================================
SET SERVEROUTPUT ON;

-- TRIGGER 1 — TRG_AUDIT_COMPUTERS
CREATE OR REPLACE TRIGGER TRG_AUDIT_COMPUTERS
  AFTER INSERT OR UPDATE OR DELETE ON CYT_COMPUTERS
  FOR EACH ROW
DECLARE
  v_op   VARCHAR2(10);
  v_old  VARCHAR2(500);
  v_new  VARCHAR2(500);
  v_id   NUMBER;
  v_eid  NUMBER;
  v_now  DATE := SYSDATE;
BEGIN
  IF INSERTING THEN
    v_op  := 'INSERT';
    v_id  := :NEW.computer_id;
    v_eid := :NEW.entity_id;
    v_new := 'serial=' || :NEW.serial || ' status=' || :NEW.status;
    v_old := NULL;
  ELSIF UPDATING THEN
    v_op  := 'UPDATE';
    v_id  := :NEW.computer_id;
    v_eid := :NEW.entity_id;
    v_old := 'status=' || :OLD.status;
    v_new := 'status=' || :NEW.status;
  ELSE
    v_op  := 'DELETE';
    v_id  := :OLD.computer_id;
    v_eid := :OLD.entity_id;
    v_old := 'serial=' || :OLD.serial;
    v_new := NULL;
  END IF;

  INSERT INTO CYT_AUDIT_LOG (
    table_name, item_id, entity_id,
    operation, user_db, old_value, new_value, log_date
  ) VALUES (
    'CYT_COMPUTERS', v_id, v_eid,
    v_op, USER, v_old, v_new, v_now
  );
EXCEPTION
  WHEN OTHERS THEN NULL;
END TRG_AUDIT_COMPUTERS;
/

-- TRIGGER 2 — TRG_AUDIT_USERS
CREATE OR REPLACE TRIGGER TRG_AUDIT_USERS
  AFTER INSERT OR UPDATE OR DELETE ON CYT_USERS
  FOR EACH ROW
DECLARE
  v_op   VARCHAR2(10);
  v_old  VARCHAR2(500);
  v_new  VARCHAR2(500);
  v_id   NUMBER;
  v_eid  NUMBER;
  v_now  DATE := SYSDATE;
BEGIN
  IF INSERTING THEN
    v_op  := 'INSERT';
    v_id  := :NEW.user_id;
    v_eid := :NEW.entity_id;
    v_new := 'login=' || :NEW.login;
    v_old := NULL;
  ELSIF UPDATING THEN
    v_op  := 'UPDATE';
    v_id  := :NEW.user_id;
    v_eid := :NEW.entity_id;
    v_old := 'is_active=' || :OLD.is_active;
    v_new := 'is_active=' || :NEW.is_active;
  ELSE
    v_op  := 'DELETE';
    v_id  := :OLD.user_id;
    v_eid := :OLD.entity_id;
    v_old := 'login=' || :OLD.login;
    v_new := NULL;
  END IF;

  INSERT INTO CYT_AUDIT_LOG (
    table_name, item_id, entity_id,
    operation, user_db, old_value, new_value, log_date
  ) VALUES (
    'CYT_USERS', v_id, v_eid,
    v_op, USER, v_old, v_new, v_now
  );
EXCEPTION
  WHEN OTHERS THEN NULL;
END TRG_AUDIT_USERS;
/

-- TRIGGER 3 — TRG_SYNC_USER_PAU
-- UC06 : repliquer les users Cergy vers Pau pour l itinerance
-- PRAGMA AUTONOMOUS_TRANSACTION : si Pau est indisponible,
--   la transaction Cergy n est PAS annulee
CREATE OR REPLACE TRIGGER TRG_SYNC_USER_PAU
  AFTER INSERT OR UPDATE ON CYT_USERS
  FOR EACH ROW
DECLARE
  PRAGMA AUTONOMOUS_TRANSACTION;
  v_count  NUMBER;
  v_login  VARCHAR2(100) := :NEW.login;
  v_uid    NUMBER        := :NEW.user_id;
  v_eid    NUMBER        := :NEW.entity_id;
  v_active NUMBER        := :NEW.is_active;
  v_hash   VARCHAR2(255) := :NEW.password_hash;
  v_real   VARCHAR2(100) := :NEW.realname;
  v_first  VARCHAR2(100) := :NEW.firstname;
  v_err    VARCHAR2(500);
BEGIN
  -- Copier toutes les valeurs :NEW en variables locales avant le DBLink
  SELECT COUNT(*) INTO v_count
  FROM   CYT_USERS@DBLINK_PAU
  WHERE  login = v_login;

  IF INSERTING AND v_count = 0 THEN
    -- Pas de DATE dans le INSERT via DBLink (ORA-00984 sur Oracle 23ai)
    INSERT INTO CYT_USERS@DBLINK_PAU (
      login, password_hash, realname, firstname,
      entity_id, profile_id, is_active
    ) VALUES (
      v_login, v_hash, v_real, v_first, 1, 1, v_active
    );
  ELSIF UPDATING AND v_count > 0 THEN
    UPDATE CYT_USERS@DBLINK_PAU
    SET    is_active     = v_active,
           password_hash = v_hash
    WHERE  login = v_login;
  END IF;
  COMMIT;

EXCEPTION
  WHEN OTHERS THEN
    -- Stocker SQLERRM en variable avant le ROLLBACK
    v_err := SUBSTR('Echec sync Pau : ' || SQLERRM, 1, 500);
    BEGIN
      ROLLBACK;
      INSERT INTO CYT_AUDIT_LOG (
        table_name, item_id, entity_id,
        operation, user_db, new_value, log_date
      ) VALUES (
        'SYNC_PAU_FAILED', v_uid, v_eid,
        'INSERT', USER, v_err, SYSDATE
      );
      COMMIT;
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
END TRG_SYNC_USER_PAU;
/

-- TRIGGER 4 — TRG_STATUS_TRANSFER
CREATE OR REPLACE TRIGGER TRG_STATUS_TRANSFER
  AFTER INSERT ON CYT_ASSET_TRANSFER
  FOR EACH ROW
BEGIN
  UPDATE CYT_COMPUTERS
  SET    status = 'TRANSFERT'
  WHERE  computer_id = :NEW.computer_id;
EXCEPTION
  WHEN OTHERS THEN NULL;
END TRG_STATUS_TRANSFER;
/

-- Verification
SELECT trigger_name, status FROM user_triggers ORDER BY trigger_name;
SHOW ERRORS TRIGGER TRG_AUDIT_COMPUTERS;
SHOW ERRORS TRIGGER TRG_AUDIT_USERS;
SHOW ERRORS TRIGGER TRG_SYNC_USER_PAU;