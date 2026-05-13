-- =============================================================================
-- FICHIER  : pau/01_tablespaces.sql
-- INSTANCE : oracle_pau (gvenzl/oracle-free)
-- =============================================================================
SET SERVEROUTPUT ON;

DECLARE
  v_dir VARCHAR2(500);

  PROCEDURE make_ts(p_name VARCHAR2, p_file VARCHAR2,
                    p_size VARCHAR2, p_max VARCHAR2) IS
  BEGIN
    EXECUTE IMMEDIATE
      'CREATE TABLESPACE ' || p_name
      || ' DATAFILE ''' || v_dir || p_file || ''''
      || ' SIZE ' || p_size
      || ' AUTOEXTEND ON NEXT ' || p_size
      || ' MAXSIZE ' || p_max
      || ' EXTENT MANAGEMENT LOCAL SEGMENT SPACE MANAGEMENT AUTO';
    DBMS_OUTPUT.PUT_LINE('OK : ' || p_name);
  EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('SKIP ' || p_name || ' : ' || SQLERRM);
  END;

BEGIN
  SELECT REGEXP_SUBSTR(file_name, '^(.+/)', 1, 1, NULL, 1)
  INTO   v_dir
  FROM   dba_data_files
  WHERE  tablespace_name IN ('SYSTEM','SYSAUX')
  AND    ROWNUM = 1;

  DBMS_OUTPUT.PUT_LINE('Repertoire detecte : ' || v_dir);

  make_ts('TS_PAU_DATA',  'ts_pau_data01.dbf',  '100M', '2G');
  make_ts('TS_PAU_IDX',   'ts_pau_idx01.dbf',   '50M',  '1G');
  make_ts('TS_PAU_COLD',  'ts_pau_cold01.dbf',  '50M',  '1G');
  make_ts('TS_PAU_AUDIT', 'ts_pau_audit01.dbf', '100M', '2G');
END;
/

SELECT tablespace_name, ROUND(bytes/1048576,1) AS size_mb, status
FROM   dba_data_files
WHERE  tablespace_name IN ('TS_PAU_DATA','TS_PAU_IDX',
                           'TS_PAU_COLD','TS_PAU_AUDIT')
ORDER BY tablespace_name;
