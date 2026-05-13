-- =============================================================================
-- FICHIER  : pau/04_index.sql
-- INSTANCE : pau_db (Spoke) — mêmes index que Cergy, tablespaces Pau
-- =============================================================================

CREATE INDEX IDX_COMP_ENTITY        ON CYT_COMPUTERS(entity_id)              TABLESPACE TS_PAU_IDX;
CREATE INDEX IDX_COMP_STATUS_ENTITY ON CYT_COMPUTERS(entity_id, status)      TABLESPACE TS_PAU_IDX;
CREATE INDEX IDX_COMP_SERIAL_FBI    ON CYT_COMPUTERS(UPPER(serial))           TABLESPACE TS_PAU_IDX;
CREATE INDEX IDX_COMP_TECH          ON CYT_COMPUTERS(tech_user_id)            TABLESPACE TS_PAU_IDX;
CREATE INDEX IDX_USER_ENTITY        ON CYT_USERS(entity_id)                  TABLESPACE TS_PAU_IDX;
CREATE INDEX IDX_USER_LOGIN_ACTIVE  ON CYT_USERS(login, is_active)            TABLESPACE TS_PAU_IDX;
CREATE INDEX IDX_NETPORT_ITEMS      ON CYT_NETWORKPORTS(items_id, item_type)  TABLESPACE TS_PAU_IDX;
CREATE INDEX IDX_NETPORT_NETWORK    ON CYT_NETWORKPORTS(network_id)           TABLESPACE TS_PAU_IDX;
CREATE INDEX IDX_IP_ENTITY          ON CYT_IPADDRESSES(entity_id)             TABLESPACE TS_PAU_IDX;
CREATE INDEX IDX_IP_ITEMS           ON CYT_IPADDRESSES(items_id, item_type)   TABLESPACE TS_PAU_IDX;
CREATE INDEX IDX_AUDIT_DATE         ON CYT_AUDIT_LOG(log_date, entity_id)     TABLESPACE TS_PAU_AUDIT;
CREATE INDEX IDX_AUDIT_TABLE_OP     ON CYT_AUDIT_LOG(table_name, operation)   TABLESPACE TS_PAU_AUDIT;
CREATE INDEX IDX_GU_USER            ON CYT_GROUPS_USERS(user_id)              TABLESPACE TS_PAU_IDX;

SELECT index_name, table_name, index_type, uniqueness, tablespace_name
FROM   user_indexes
WHERE  table_name LIKE 'CYT_%'
ORDER BY table_name, index_name;
