-- Audit des ordinateurs côté Pau
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
    v_op      := 'INSERT';
    v_new_val := 'serial=' || :NEW.serial || ',status=' || :NEW.status;
    v_item_id := :NEW.computer_id; v_entity_id := :NEW.entity_id;
  ELSIF UPDATING THEN
    v_op      := 'UPDATE';
    v_old_val := 'status=' || :OLD.status;
    v_new_val := 'status=' || :NEW.status;
    v_item_id := :NEW.computer_id; v_entity_id := :NEW.entity_id;
  ELSE
    v_op      := 'DELETE';
    v_old_val := 'serial=' || :OLD.serial;
    v_item_id := :OLD.computer_id; v_entity_id := :OLD.entity_id;
  END IF;

  INSERT INTO CYT_AUDIT_LOG (
    table_name, item_id, entity_id, operation, user_db,
    old_value, new_value, log_date
  ) VALUES (
    'CYT_COMPUTERS', v_item_id, v_entity_id, v_op, USER,
    v_old_val, v_new_val, SYSDATE
  );
EXCEPTION WHEN OTHERS THEN NULL;
END TRG_AUDIT_COMPUTERS;
/

-- Audit des utilisateurs côté Pau
CREATE OR REPLACE TRIGGER TRG_AUDIT_USERS
  AFTER INSERT OR UPDATE OR DELETE ON CYT_USERS
  FOR EACH ROW
DECLARE
  v_op VARCHAR2(10);
BEGIN
  IF INSERTING THEN v_op := 'INSERT';
  ELSIF UPDATING THEN v_op := 'UPDATE';
  ELSE v_op := 'DELETE'; END IF;

  INSERT INTO CYT_AUDIT_LOG (
    table_name, item_id, entity_id, operation, user_db, log_date
  ) VALUES (
    'CYT_USERS',
    NVL(:NEW.user_id, :OLD.user_id),
    NVL(:NEW.entity_id, :OLD.entity_id),
    v_op, USER, SYSDATE
  );
EXCEPTION WHEN OTHERS THEN NULL;
END TRG_AUDIT_USERS;
/
-- Vérification des triggers créés
SELECT trigger_name, table_name, status
FROM   user_triggers WHERE table_name LIKE 'CYT_%';
