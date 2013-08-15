
set echo off verify off showmode off feedback off;
whenever sqlerror exit sql.sqlcode

PROMPT 
PROMPT ... Stopping collector

begin
	begin
	bash.bash.stop();
    EXCEPTION  WHEN OTHERS THEN NULL;
    END;
end;
/

prompt
prompt
prompt ... Granting new privileges 

GRANT SELECT on V_$INSTANCE to BASH;
GRANT SELECT on GV_$INSTANCE to BASH;
GRANT EXECUTE ON DBMS_UTILITY TO BASH;
GRANT SELECT on V_$ACTIVE_INSTANCES to BASH;


prompt
prompt
prompt ... Adding public synonyms

CREATE OR REPLACE PUBLIC SYNONYM "BASHG$ACTIVE_SESSION_HISTORY" FOR "BASH"."GVTABSESSIONS";
CREATE OR REPLACE PUBLIC SYNONYM "BASHG$HIST_ACTIVE_SESS_HISTORY" FOR "BASH"."GVTABSESSIONSHIST";


prompt
prompt
prompt ... Updating tables

DROP TRIGGER "BASH"."TRG_SETTINGS_AFTER_UPD";

ALTER TABLE "BASH"."BASH$SETTINGS" DROP COLUMN UPDATED;  
ALTER TABLE "BASH"."BASH$SETTINGS" ADD updated_ts TIMESTAMP;     
ALTER TABLE "BASH"."BASH$SETTINGS" ADD checkfnewinst_every_n_samples NUMBER;     

UPDATE  BASH.BASH$SETTINGS set updated_ts=systimestamp; 
UPDATE  BASH.BASH$SETTINGS set checkfnewinst_every_n_samples=60; 
COMMIT;

CREATE OR REPLACE TRIGGER "BASH"."TRG_SETTINGS_AFTER_UPD" 
   AFTER UPDATE
   of 
    sample_every_n_centiseconds,
    persist_every_n_samples,
    cleanup_every_n_samples,
	checkfnewinst_every_n_samples,
    max_entries_kept,
    logging_enabled,
    keep_log_entries_n_days  
   ON BASH.BASH$SETTINGS
BEGIN
update BASH.BASH$SETTINGS set UPDATED_TS=systimestamp; 
END TRG_SETTINGS_AFTER_UPD; 
/   


prompt
prompt
prompt ... Updating views

CREATE OR REPLACE FORCE VIEW "BASH"."VTABSESSIONSHIST" ("SAMPLE_ID", "SAMPLE_TIME", "INST_ID", "SESSION_ID", "SESSION_SERIAL#", "USER_ID", "USERNAME", "SQL_OPCODE", "SQL_OPNAME", "OSUSER", "MACHINE", "PORT", "TERMINAL", "PROGRAM", "SESSION_TYPE", "SQL_ID", "SQL_CHILD_NUMBER", "SQL_EXEC_START", "SQL_EXEC_ID", "PLSQL_ENTRY_OBJECT_ID", "PLSQL_ENTRY_SUBPROGRAM_ID", "PLSQL_OBJECT_ID", "PLSQL_SUBPROGRAM_ID", "MODULE", "ACTION", "CURRENT_OBJ#", "CURRENT_FILE#", "CURRENT_BLOCK#", "TOP_LEVEL_CALL#", "CLIENT_ID", "BLOCKING_SESSION_STATUS", "BLOCKING_SESSION", "SEQ#", "EVENT#", "EVENT", "P1TEXT", "P1", "P2TEXT", "P2", "P3TEXT", "P3", "WAIT_CLASS_ID", "WAIT_CLASS", "WAIT_TIME", "TIME_WAITED", "SESSION_STATE", "ECID", "SQL_PLAN_HASH_VALUE", "FORCE_MATCHING_SIGNATURE", "SERVICE_HASH", "QC_SESSION_ID", "QC_INSTANCE_ID", "BLOCKING_SESSION_SERIAL#", "EVENT_ID", "XID", "FLAGS", "BLOCKING_HANGCHAIN_INFO", "BLOCKING_INST_ID", "CAPTURE_OVERHEAD", "CONSUMER_GROUP_ID", "CURRENT_ROW#", "DBREPLAY_CALL_COUNTER", "DBREPLAY_FILE_ID", "DELTA_INTERCONNECT_IO_BYTES", "DELTA_READ_IO_BYTES", "DELTA_READ_IO_REQUESTS", "DELTA_TIME", "DELTA_WRITE_IO_BYTES", "DELTA_WRITE_IO_REQUESTS", "IN_BIND", "IN_CONNECTION_MGMT", "IN_CURSOR_CLOSE", "IN_HARD_PARSE", "IN_JAVA_EXECUTION", "IN_PARSE", "IN_PLSQL_COMPILATION", "IN_PLSQL_EXECUTION", "IN_PLSQL_RPC", "IN_SEQUENCE_LOAD", "IN_SQL_EXECUTION", "IS_AWR_SAMPLE", "IS_CAPTURED", "IS_REPLAYED", "IS_SQLID_CURRENT", "PGA_ALLOCATED", "PX_FLAGS", "QC_SESSION_SERIAL#", "REMOTE_INSTANCE#", "REPLAY_OVERHEAD", "SQL_PLAN_LINE_ID", "SQL_PLAN_OPERATION", "SQL_PLAN_OPTIONS", "TEMP_SPACE_ALLOCATED", "TIME_MODEL", "TM_DELTA_CPU_TIME", "TM_DELTA_DB_TIME", "TM_DELTA_TIME", "TOP_LEVEL_CALL_NAME", "TOP_LEVEL_SQL_ID", "TOP_LEVEL_SQL_OPCODE") AS 
  SELECT "SAMPLE_ID",
    "SAMPLE_TIME",
	"INST_ID",
    "SID" SESSION_ID,
    "SERIAL#" SESSION_SERIAL#,
    TO_NUMBER("USER#") user_id,
    "USERNAME",
    "COMMAND" sql_opcode,
    "SQL_OPNAME" sql_opname,
    "OSUSER",
    "MACHINE",
    "PORT",
    "TERMINAL",
    "PROGRAM" PROGRAM,
    "TYPE" session_type,
    "SQL_ID" sql_id,
    "SQL_CHILD_NUMBER" sql_child_number,
    "SQL_EXEC_START",
    "SQL_EXEC_ID",
    "PLSQL_ENTRY_OBJECT_ID" PLSQL_ENTRY_OBJECT_ID,
    "PLSQL_ENTRY_SUBPROGRAM_ID" plsql_entry_subprogram_id,
    "PLSQL_OBJECT_ID" plsql_object_id,
    "PLSQL_SUBPROGRAM_ID" plsql_subprogram_id,
    "MODULE" MODULE,
    "ACTION" ACTION,
    "ROW_WAIT_OBJ#" current_obj#,
    "ROW_WAIT_FILE#" current_file#,
    "ROW_WAIT_BLOCK#" current_block#,
    "TOP_LEVEL_CALL#",
    "CLIENT_IDENTIFIER" CLIENT_ID,
    "BLOCKING_SESSION_STATUS" BLOCKING_SESSION_STATUS,
    "BLOCKING_SESSION" BLOCKING_SESSION,
    "SEQ#" SEQ#,
    "EVENT#" EVENT#,
    "EVENT" EVENT,
    "P1TEXT" P1TEXT,
    "P1" P1,
    "P2TEXT" P2TEXT,
    "P2" P2,
    "P3TEXT" P3TEXT,
    "P3" P3,
    "WAIT_CLASS_ID" WAIT_CLASS_ID,
    "WAIT_CLASS" WAIT_CLASS,
    "WAIT_TIME" WAIT_TIME,
    "SECONDS_IN_WAIT" time_waited,
    "STATE" session_state,
    "ECID",
    sql_plan_hash_value sql_plan_hash_value,
    force_matching_signature force_matching_signature,
    "SERVICE_HASH" service_hash,
    --COLUMNS in 10.2, but not supported in BASH:
    0 qc_session_id,
    0 qc_instance_id,
    TO_NUMBER(NULL) blocking_session_serial#,
    EVENT_ID EVENT_ID,
    XID XID,
    0 flags,
    --COLUMNS in 11.2, but not supported in BASH:
    TO_CHAR(NULL) BLOCKING_HANGCHAIN_INFO,
    to_number(NULL) BLOCKING_INST_ID,
    TO_CHAR(NULL) CAPTURE_OVERHEAD,
    to_number(NULL) CONSUMER_GROUP_ID,
    to_number(NULL) CURRENT_ROW#,
    to_number(NULL) DBREPLAY_CALL_COUNTER,
    to_number(NULL) DBREPLAY_FILE_ID,
    to_number(NULL) DELTA_INTERCONNECT_IO_BYTES,
    to_number(NULL) DELTA_READ_IO_BYTES,
    to_number(NULL) DELTA_READ_IO_REQUESTS,
    to_number(NULL) DELTA_TIME,
    to_number(NULL) DELTA_WRITE_IO_BYTES,
    to_number(NULL) DELTA_WRITE_IO_REQUESTS,
    TO_CHAR(NULL) IN_BIND,
    TO_CHAR(NULL) IN_CONNECTION_MGMT,
    TO_CHAR(NULL) IN_CURSOR_CLOSE,
    TO_CHAR(NULL) IN_HARD_PARSE,
    TO_CHAR(NULL) IN_JAVA_EXECUTION,
    TO_CHAR(NULL) IN_PARSE,
    TO_CHAR(NULL) IN_PLSQL_COMPILATION,
    TO_CHAR(NULL) IN_PLSQL_EXECUTION,
    TO_CHAR(NULL) IN_PLSQL_RPC,
    TO_CHAR(NULL) IN_SEQUENCE_LOAD,
    TO_CHAR(NULL) IN_SQL_EXECUTION,
    TO_CHAR(NULL) IS_AWR_SAMPLE,
    TO_CHAR(NULL) IS_CAPTURED,
    TO_CHAR(NULL) IS_REPLAYED,
    TO_CHAR(NULL) IS_SQLID_CURRENT,
    to_number(NULL) PGA_ALLOCATED,
    to_number(NULL) PX_FLAGS,
    to_number(NULL) QC_SESSION_SERIAL#,
    to_number(NULL) REMOTE_INSTANCE#,
    TO_CHAR(NULL) REPLAY_OVERHEAD,
    to_number(NULL) SQL_PLAN_LINE_ID,
    TO_CHAR(NULL) SQL_PLAN_OPERATION,
    TO_CHAR(NULL) SQL_PLAN_OPTIONS,
    to_number(NULL) TEMP_SPACE_ALLOCATED,
    to_number(NULL) TIME_MODEL,
    to_number(NULL) TM_DELTA_CPU_TIME,
    to_number(NULL) TM_DELTA_DB_TIME,
    to_number(NULL) TM_DELTA_TIME,
    TO_CHAR(NULL) TOP_LEVEL_CALL_NAME,
    TO_CHAR(NULL) TOP_LEVEL_SQL_ID,
    to_number(NULL) TOP_LEVEL_SQL_OPCODE
  FROM "BASH"."BASH$SESSION_HIST_INTERNAL"
  WHERE inst_id = USERENV('Instance');

CREATE OR REPLACE FORCE VIEW "BASH"."GVTABSESSIONSHIST" ("SAMPLE_ID", "SAMPLE_TIME", "INST_ID", "SESSION_ID", "SESSION_SERIAL#", "USER_ID", "USERNAME", "SQL_OPCODE", "SQL_OPNAME", "OSUSER", "MACHINE", "PORT", "TERMINAL", "PROGRAM", "SESSION_TYPE", "SQL_ID", "SQL_CHILD_NUMBER", "SQL_EXEC_START", "SQL_EXEC_ID", "PLSQL_ENTRY_OBJECT_ID", "PLSQL_ENTRY_SUBPROGRAM_ID", "PLSQL_OBJECT_ID", "PLSQL_SUBPROGRAM_ID", "MODULE", "ACTION", "CURRENT_OBJ#", "CURRENT_FILE#", "CURRENT_BLOCK#", "TOP_LEVEL_CALL#", "CLIENT_ID", "BLOCKING_SESSION_STATUS", "BLOCKING_SESSION", "SEQ#", "EVENT#", "EVENT", "P1TEXT", "P1", "P2TEXT", "P2", "P3TEXT", "P3", "WAIT_CLASS_ID", "WAIT_CLASS", "WAIT_TIME", "TIME_WAITED", "SESSION_STATE", "ECID", "SQL_PLAN_HASH_VALUE", "FORCE_MATCHING_SIGNATURE", "SERVICE_HASH", "QC_SESSION_ID", "QC_INSTANCE_ID", "BLOCKING_SESSION_SERIAL#", "EVENT_ID", "XID", "FLAGS", "BLOCKING_HANGCHAIN_INFO", "BLOCKING_INST_ID", "CAPTURE_OVERHEAD", "CONSUMER_GROUP_ID", "CURRENT_ROW#", "DBREPLAY_CALL_COUNTER", "DBREPLAY_FILE_ID", "DELTA_INTERCONNECT_IO_BYTES", "DELTA_READ_IO_BYTES", "DELTA_READ_IO_REQUESTS", "DELTA_TIME", "DELTA_WRITE_IO_BYTES", "DELTA_WRITE_IO_REQUESTS", "IN_BIND", "IN_CONNECTION_MGMT", "IN_CURSOR_CLOSE", "IN_HARD_PARSE", "IN_JAVA_EXECUTION", "IN_PARSE", "IN_PLSQL_COMPILATION", "IN_PLSQL_EXECUTION", "IN_PLSQL_RPC", "IN_SEQUENCE_LOAD", "IN_SQL_EXECUTION", "IS_AWR_SAMPLE", "IS_CAPTURED", "IS_REPLAYED", "IS_SQLID_CURRENT", "PGA_ALLOCATED", "PX_FLAGS", "QC_SESSION_SERIAL#", "REMOTE_INSTANCE#", "REPLAY_OVERHEAD", "SQL_PLAN_LINE_ID", "SQL_PLAN_OPERATION", "SQL_PLAN_OPTIONS", "TEMP_SPACE_ALLOCATED", "TIME_MODEL", "TM_DELTA_CPU_TIME", "TM_DELTA_DB_TIME", "TM_DELTA_TIME", "TOP_LEVEL_CALL_NAME", "TOP_LEVEL_SQL_ID", "TOP_LEVEL_SQL_OPCODE") AS 
  SELECT "SAMPLE_ID",
    "SAMPLE_TIME",
	"INST_ID",
    "SID" SESSION_ID,
    "SERIAL#" SESSION_SERIAL#,
    TO_NUMBER("USER#") user_id,
    "USERNAME",
    "COMMAND" sql_opcode,
    "SQL_OPNAME" sql_opname,
    "OSUSER",
    "MACHINE",
    "PORT",
    "TERMINAL",
    "PROGRAM" PROGRAM,
    "TYPE" session_type,
    "SQL_ID" sql_id,
    "SQL_CHILD_NUMBER" sql_child_number,
    "SQL_EXEC_START",
    "SQL_EXEC_ID",
    "PLSQL_ENTRY_OBJECT_ID" PLSQL_ENTRY_OBJECT_ID,
    "PLSQL_ENTRY_SUBPROGRAM_ID" plsql_entry_subprogram_id,
    "PLSQL_OBJECT_ID" plsql_object_id,
    "PLSQL_SUBPROGRAM_ID" plsql_subprogram_id,
    "MODULE" MODULE,
    "ACTION" ACTION,
    "ROW_WAIT_OBJ#" current_obj#,
    "ROW_WAIT_FILE#" current_file#,
    "ROW_WAIT_BLOCK#" current_block#,
    "TOP_LEVEL_CALL#",
    "CLIENT_IDENTIFIER" CLIENT_ID,
    "BLOCKING_SESSION_STATUS" BLOCKING_SESSION_STATUS,
    "BLOCKING_SESSION" BLOCKING_SESSION,
    "SEQ#" SEQ#,
    "EVENT#" EVENT#,
    "EVENT" EVENT,
    "P1TEXT" P1TEXT,
    "P1" P1,
    "P2TEXT" P2TEXT,
    "P2" P2,
    "P3TEXT" P3TEXT,
    "P3" P3,
    "WAIT_CLASS_ID" WAIT_CLASS_ID,
    "WAIT_CLASS" WAIT_CLASS,
    "WAIT_TIME" WAIT_TIME,
    "SECONDS_IN_WAIT" time_waited,
    "STATE" session_state,
    "ECID",
    sql_plan_hash_value sql_plan_hash_value,
    force_matching_signature force_matching_signature,
    "SERVICE_HASH" service_hash,
    --COLUMNS in 10.2, but not supported in BASH:
    0 qc_session_id,
    0 qc_instance_id,
    TO_NUMBER(NULL) blocking_session_serial#,
    EVENT_ID EVENT_ID,
    XID XID,
    0 flags,
    --COLUMNS in 11.2, but not supported in BASH:
    TO_CHAR(NULL) BLOCKING_HANGCHAIN_INFO,
    to_number(NULL) BLOCKING_INST_ID,
    TO_CHAR(NULL) CAPTURE_OVERHEAD,
    to_number(NULL) CONSUMER_GROUP_ID,
    to_number(NULL) CURRENT_ROW#,
    to_number(NULL) DBREPLAY_CALL_COUNTER,
    to_number(NULL) DBREPLAY_FILE_ID,
    to_number(NULL) DELTA_INTERCONNECT_IO_BYTES,
    to_number(NULL) DELTA_READ_IO_BYTES,
    to_number(NULL) DELTA_READ_IO_REQUESTS,
    to_number(NULL) DELTA_TIME,
    to_number(NULL) DELTA_WRITE_IO_BYTES,
    to_number(NULL) DELTA_WRITE_IO_REQUESTS,
    TO_CHAR(NULL) IN_BIND,
    TO_CHAR(NULL) IN_CONNECTION_MGMT,
    TO_CHAR(NULL) IN_CURSOR_CLOSE,
    TO_CHAR(NULL) IN_HARD_PARSE,
    TO_CHAR(NULL) IN_JAVA_EXECUTION,
    TO_CHAR(NULL) IN_PARSE,
    TO_CHAR(NULL) IN_PLSQL_COMPILATION,
    TO_CHAR(NULL) IN_PLSQL_EXECUTION,
    TO_CHAR(NULL) IN_PLSQL_RPC,
    TO_CHAR(NULL) IN_SEQUENCE_LOAD,
    TO_CHAR(NULL) IN_SQL_EXECUTION,
    TO_CHAR(NULL) IS_AWR_SAMPLE,
    TO_CHAR(NULL) IS_CAPTURED,
    TO_CHAR(NULL) IS_REPLAYED,
    TO_CHAR(NULL) IS_SQLID_CURRENT,
    to_number(NULL) PGA_ALLOCATED,
    to_number(NULL) PX_FLAGS,
    to_number(NULL) QC_SESSION_SERIAL#,
    to_number(NULL) REMOTE_INSTANCE#,
    TO_CHAR(NULL) REPLAY_OVERHEAD,
    to_number(NULL) SQL_PLAN_LINE_ID,
    TO_CHAR(NULL) SQL_PLAN_OPERATION,
    TO_CHAR(NULL) SQL_PLAN_OPTIONS,
    to_number(NULL) TEMP_SPACE_ALLOCATED,
    to_number(NULL) TIME_MODEL,
    to_number(NULL) TM_DELTA_CPU_TIME,
    to_number(NULL) TM_DELTA_DB_TIME,
    to_number(NULL) TM_DELTA_TIME,
    TO_CHAR(NULL) TOP_LEVEL_CALL_NAME,
    TO_CHAR(NULL) TOP_LEVEL_SQL_ID,
    to_number(NULL) TOP_LEVEL_SQL_OPCODE
  FROM "BASH"."BASH$SESSION_HIST_INTERNAL";  
  
  
  
declare
cursor c is
with cols as 
(SELECT column_name FROM DBA_TAB_COLS where table_name='GV_$SESSION')
, cols_wanted as
(
SELECT 1 ord,'INST_ID' column_name from dual
UNION SELECT 2 ord,'SID' from dual
UNION SELECT 3 ord,'SERIAL#' from dual
UNION SELECT 4 ord,'USER#' from dual
UNION SELECT 5 ord,'USERNAME' from dual
UNION SELECT 6 ord,'COMMAND' from dual
UNION SELECT 7 ord,'OSUSER' from dual
UNION SELECT 8 ord,'MACHINE' from dual
UNION SELECT 9 ord,'PORT' from dual
UNION SELECT 10 ord,'TERMINAL' from dual
UNION SELECT 11 ord,'PROGRAM' from dual
UNION SELECT 12 ord,'TYPE' from dual
UNION SELECT 13 ord,'SQL_ID' from dual
UNION SELECT 14 ord,'SQL_CHILD_NUMBER' from dual
UNION SELECT 15 ord,'SQL_EXEC_START' from dual
UNION SELECT 16 ord,'SQL_EXEC_ID' from dual
UNION SELECT 17 ord,'PLSQL_ENTRY_OBJECT_ID' from dual
UNION SELECT 18 ord,'PLSQL_ENTRY_SUBPROGRAM_ID' from dual
UNION SELECT 19 ord,'PLSQL_OBJECT_ID' from dual
UNION SELECT 20 ord,'PLSQL_SUBPROGRAM_ID' from dual
UNION SELECT 21 ord,'MODULE' from dual
UNION SELECT 22 ord,'ACTION' from dual
UNION SELECT 23 ord,'ROW_WAIT_OBJ#' from dual
UNION SELECT 24 ord,'ROW_WAIT_FILE#' from dual
UNION SELECT 25 ord,'ROW_WAIT_BLOCK#' from dual
UNION SELECT 26 ord,'TOP_LEVEL_CALL#' from dual
UNION SELECT 27 ord,'CLIENT_IDENTIFIER' from dual
UNION SELECT 28 ord,'BLOCKING_SESSION_STATUS' from dual
UNION SELECT 29 ord,'BLOCKING_SESSION' from dual
UNION SELECT 30 ord,'SEQ#' from dual
UNION SELECT 31 ord,'EVENT#' from dual
UNION SELECT 32 ord,'EVENT' from dual
UNION SELECT 33 ord,'P1TEXT' from dual
UNION SELECT 34 ord,'P1' from dual
UNION SELECT 35 ord,'P2TEXT' from dual
UNION SELECT 36 ord,'P2' from dual
UNION SELECT 37 ord,'P3TEXT' from dual
UNION SELECT 38 ord,'P3' from dual
UNION SELECT 39 ord,'WAIT_CLASS_ID' from dual
UNION SELECT 40 ord,'WAIT_CLASS' from dual
UNION SELECT 41 ord,'WAIT_TIME' from dual
UNION SELECT 42 ord,'SECONDS_IN_WAIT' from dual
UNION SELECT 43 ord,'STATE' from dual
UNION SELECT 44 ord,'ECID' from dual
)
select txt from 
(
select 10 ord,
'CREATE OR REPLACE FORCE VIEW "BASH"."BASH$VSOURCE"  (' txt
 from dual where 1=1
 union
 (SELECT 100+ord ord,column_name||', ' FROM cols_Wanted)
 union 
select 300,
      ' xid,
      sql_plan_hash_value,
      FORCE_MATCHING_SIGNATURE,
      SERVICE_HASH,
      sql_opname,
      EVENT_ID 
) as
( select 
'
 from dual where 1=1
 union
 select 499, ' (SELECT INSTANCE_number FROM V$INSTANCE), ' from dual where 1=1
 union
 (SELECT 500+ord ord,NVL2(c.column_name,'s.'||c.column_name||', ','NULL, ') FROM cols c, cols_Wanted cw where c.column_name(+)=cw.column_name and c.column_name<>'INST_ID')
 union  
 select 900 ord, 
 ' t.xid,
 sq.plan_hash_value,
 sq.FORCE_MATCHING_SIGNATURE,
 serv.name_hash,
 case when s.command<88 then
 CASE S.COMMAND
 WHEN 0
 THEN ''UNKNOWN''
 WHEN 1
 THEN ''CREATE TABLE''
 WHEN 2
 THEN ''INSERT''
 WHEN 3
 THEN ''SELECT''
 WHEN 4
 THEN ''CREATE CLUSTER''
 WHEN 5
 THEN ''ALTER CLUSTER''
 WHEN 6
 THEN ''UPDATE''
 WHEN 7
 THEN ''DELETE''
 WHEN 8
 THEN ''DROP CLUSTER''
 WHEN 9
 THEN ''CREATE INDEX''
 WHEN 10
 THEN ''DROP INDEX''
 WHEN 11
 THEN ''ALTER INDEX''
 WHEN 12
 THEN ''DROP TABLE''
 WHEN 13
 THEN ''CREATE SEQUENCE''
 WHEN 14
 THEN ''ALTER SEQUENCE''
 WHEN 15
 THEN ''ALTER TABLE''
 WHEN 16
 THEN ''DROP SEQUENCE''
 WHEN 17
 THEN ''GRANT OBJECT''
 WHEN 18
 THEN ''REVOKE OBJECT''
 WHEN 19
 THEN ''CREATE SYNONYM''
 WHEN 20
 THEN ''DROP SYNONYM''
 WHEN 21
 THEN ''CREATE VIEW''
 WHEN 22
 THEN ''DROP VIEW''
 WHEN 23
 THEN ''VALIDATE INDEX''
 WHEN 24
 THEN ''CREATE PROCEDURE''
 WHEN 25
 THEN ''ALTER PROCEDURE''
 WHEN 26
 THEN ''LOCK''
 WHEN 27
 THEN ''NO-OP''
 WHEN 28
 THEN ''RENAME''
 WHEN 29
 THEN ''COMMENT''
 WHEN 30
 THEN ''AUDIT OBJECT''
 WHEN 31
 THEN ''NOAUDIT OBJECT''
 WHEN 32
 THEN ''CREATE DATABASE LINK''
 WHEN 33
 THEN ''DROP DATABASE LINK''
 WHEN 34
 THEN ''CREATE DATABASE''
 WHEN 35
 THEN ''ALTER DATABASE''
 WHEN 36
 THEN ''CREATE ROLLBACK SEG''
 WHEN 37
 THEN ''ALTER ROLLBACK SEG''
 WHEN 38
 THEN ''DROP ROLLBACK SEG''
 WHEN 39
 THEN ''CREATE TABLESPACE''
 WHEN 40
 THEN ''ALTER TABLESPACE''
 WHEN 41
 THEN ''DROP TABLESPACE''
 WHEN 42
 THEN ''ALTER SESSION''
 WHEN 43
 THEN ''ALTER USER''
 WHEN 44
 THEN ''COMMIT''
 WHEN 45
 THEN ''ROLLBACK''
 WHEN 46
 THEN ''SAVEPOINT''
 WHEN 47
 THEN ''PL/SQL EXECUTE''
 WHEN 48
 THEN ''SET TRANSACTION''
 WHEN 49
 THEN ''ALTER SYSTEM''
 WHEN 50
 THEN ''EXPLAIN''
 WHEN 51
 THEN ''CREATE USER''
 WHEN 52
 THEN ''CREATE ROLE''
 WHEN 53
 THEN ''DROP USER''
 WHEN 54
 THEN ''DROP ROLE''
 WHEN 55
 THEN ''SET ROLE''
 WHEN 56
 THEN ''CREATE SCHEMA''
 WHEN 57
 THEN ''CREATE CONTROL FILE''
 WHEN 59
 THEN ''CREATE TRIGGER''
 WHEN 60
 THEN ''ALTER TRIGGER''
 WHEN 61
 THEN ''DROP TRIGGER''
 WHEN 62
 THEN ''ANALYZE TABLE''
 WHEN 63
 THEN ''ANALYZE INDEX''
 WHEN 64
 THEN ''ANALYZE CLUSTER''
 ' 
 from dual where 1=1
union  
 select 901 ord, 
 ' WHEN 65
 THEN ''CREATE PROFILE''
 WHEN 66
 THEN ''DROP PROFILE''
 WHEN 67
 THEN ''ALTER PROFILE''
 WHEN 68
 THEN ''DROP PROCEDURE''
 WHEN 70
 THEN ''ALTER RESOURCE COST''
 WHEN 71
 THEN ''CREATE MATERIALIZED VIEW LOG''
 WHEN 72
 THEN ''ALTER MATERIALIZED VIEW LOG''
 WHEN 73
 THEN ''DROP MATERIALIZED VIEW LOG''
 WHEN 74
 THEN ''CREATE MATERIALIZED VIEW''
 WHEN 75
 THEN ''ALTER MATERIALIZED VIEW''
 WHEN 76
 THEN ''DROP MATERIALIZED VIEW''
 WHEN 77
 THEN ''CREATE TYPE''
 WHEN 78
 THEN ''DROP TYPE''
 WHEN 79
 THEN ''ALTER ROLE''
 WHEN 80
 THEN ''ALTER TYPE''
 WHEN 81
 THEN ''CREATE TYPE BODY''
 WHEN 82
 THEN ''ALTER TYPE BODY''
 WHEN 83
 THEN ''DROP TYPE BODY''
 WHEN 84
 THEN ''DROP LIBRARY''
 WHEN 85
 THEN ''TRUNCATE TABLE''
 WHEN 86
 THEN ''TRUNCATE CLUSTER''
 ELSE ''UNKNOWN''
 end
 else
 CASE S.COMMAND
 WHEN 88
 THEN ''ALTER VIEW''
 WHEN 91
 THEN ''CREATE FUNCTION''
 WHEN 92
 THEN ''ALTER FUNCTION''
 WHEN 93
 THEN ''DROP FUNCTION''
 WHEN 94
 THEN ''CREATE PACKAGE''
 WHEN 95
 THEN ''ALTER PACKAGE''
 WHEN 96
 THEN ''DROP PACKAGE''
 WHEN 97
 THEN ''CREATE PACKAGE BODY''
 WHEN 98
 THEN ''ALTER PACKAGE BODY''
 WHEN 99
 THEN ''DROP PACKAGE BODY''
 WHEN 100
 THEN ''LOGON''
 WHEN 101
 THEN ''LOGOFF''
 WHEN 102
 THEN ''LOGOFF BY CLEANUP''
 WHEN 103
 THEN ''SESSION REC''
 WHEN 104
 THEN ''SYSTEM AUDIT''
 WHEN 105
 THEN ''SYSTEM NOAUDIT''
 WHEN 106
 THEN ''AUDIT DEFAULT''
 WHEN 107
 THEN ''NOAUDIT DEFAULT''
 WHEN 108
 THEN ''SYSTEM GRANT''
 WHEN 109
 THEN ''SYSTEM REVOKE''
 WHEN 110
 THEN ''CREATE PUBLIC SYNONYM''
 WHEN 111
 THEN ''DROP PUBLIC SYNONYM''
 WHEN 112
 THEN ''CREATE PUBLIC DATABASE LINK''
 WHEN 113
 THEN ''DROP PUBLIC DATABASE LINK''
 WHEN 114
 THEN ''GRANT ROLE''
 WHEN 115
 THEN ''REVOKE ROLE''
 WHEN 116
 THEN ''EXECUTE PROCEDURE''
 WHEN 117
 THEN ''USER COMMENT''
 WHEN 118
 THEN ''ENABLE TRIGGER''
 WHEN 119
 THEN ''DISABLE TRIGGER''
 WHEN 120
 THEN ''ENABLE ALL TRIGGERS''
 WHEN 121
 THEN ''DISABLE ALL TRIGGERS''
 WHEN 122
 THEN ''NETWORK ERROR''
 WHEN 123
 THEN ''EXECUTE TYPE''
 WHEN 128
 THEN ''FLASHBACK''
 WHEN 129
 THEN ''CREATE SESSION''
 WHEN 130
 THEN ''ALTER MINING MODEL''
 WHEN 131
 THEN ''SELECT MINING MODEL''
 WHEN 133
 THEN ''CREATE MINING MODEL''
 WHEN 134
 THEN ''ALTER PUBLIC SYNONYM''
 WHEN 135
 THEN ''DIRECTORY EXECUTE''
 WHEN 136
 THEN ''SQL*LOADER DIRECT PATH LOAD''
 WHEN 137
 THEN ''DATAPUMP DIRECT PATH UNLOAD''
 WHEN 157
 THEN ''CREATE DIRECTORY''
 WHEN 158
 THEN ''DROP DIRECTORY''
 WHEN 159
 THEN ''CREATE LIBRARY''
 WHEN 160
 THEN ''CREATE JAVA''
 WHEN 161
 THEN ''ALTER JAVA''
 WHEN 162 ' 
       from dual where 1=1
union  
 select 902 ord, 
 ' THEN ''DROP JAVA''
 WHEN 163
 THEN ''CREATE OPERATOR''
 WHEN 164
 THEN ''CREATE INDEXTYPE''
 WHEN 165
 THEN ''DROP INDEXTYPE''
 WHEN 166
 THEN ''ALTER INDEXTYPE''
 WHEN 167
 THEN ''DROP OPERATOR''
 WHEN 168
 THEN ''ASSOCIATE STATISTICS''
 WHEN 169
 THEN ''DISASSOCIATE STATISTICS''
 WHEN 170
 THEN ''CALL METHOD''
 WHEN 171
 THEN ''CREATE SUMMARY''
 WHEN 172
 THEN ''ALTER SUMMARY''
 WHEN 173
 THEN ''DROP SUMMARY''
 WHEN 174
 THEN ''CREATE DIMENSION''
 WHEN 175
 THEN ''ALTER DIMENSION''
 WHEN 176
 THEN ''DROP DIMENSION''
 WHEN 177
 THEN ''CREATE CONTEXT''
 WHEN 178
 THEN ''DROP CONTEXT''
 WHEN 179
 THEN ''ALTER OUTLINE''
 WHEN 180
 THEN ''CREATE OUTLINE''
 WHEN 181
 THEN ''DROP OUTLINE''
 WHEN 182
 THEN ''UPDATE INDEXES''
 WHEN 183
 THEN ''ALTER OPERATOR''
 WHEN 192
 THEN ''ALTER SYNONYM''
 WHEN 197
 THEN ''PURGE USER_RECYCLEBIN''
 WHEN 198
 THEN ''PURGE DBA_RECYCLEBIN''
 WHEN 199
 THEN ''PURGE TABLESPACE''
 WHEN 200
 THEN ''PURGE TABLE''
 WHEN 201
 THEN ''PURGE INDEX''
 WHEN 202
 THEN ''UNDROP OBJECT''
 WHEN 204
 THEN ''FLASHBACK DATABASE''
 WHEN 205
 THEN ''FLASHBACK TABLE''
 WHEN 206
 THEN ''CREATE RESTORE POINT''
 WHEN 207
 THEN ''DROP RESTORE POINT''
 WHEN 208
 THEN ''PROXY AUTHENTICATION ONLY''
 WHEN 209
 THEN ''DECLARE REWRITE EQUIVALENCE''
 WHEN 210
 THEN ''ALTER REWRITE EQUIVALENCE''
 WHEN 211
 THEN ''DROP REWRITE EQUIVALENCE''
 WHEN 212
 THEN ''CREATE EDITION''
 WHEN 213
 THEN ''ALTER EDITION''
 WHEN 214
 THEN ''DROP EDITION''
 WHEN 215
 THEN ''DROP ASSEMBLY''
 WHEN 216
 THEN ''CREATE ASSEMBLY''
 WHEN 217
 THEN ''ALTER ASSEMBLY''
 WHEN 218
 THEN ''CREATE FLASHBACK ARCHIVE''
 WHEN 219
 THEN ''ALTER FLASHBACK ARCHIVE''
 WHEN 220
 THEN ''DROP FLASHBACK ARCHIVE''
 WHEN 225
 THEN ''ALTER DATABASE LINK''
 WHEN 305
 THEN ''ALTER PUBLIC DATABASE LINK''
 ELSE ''UNKNOWN''
 END 
 end sql_opname,
 en.event_id
 FROM v$session s,
 V$TRANSACTION t,
 V$SQL sq,
 V$ACTIVE_SERVICES serv,
 v$event_name en
 WHERE ((s.status =''ACTIVE''
 AND s.state != ''WAITING'')
 OR (s.status = ''ACTIVE''
 AND s.state = ''WAITING''
 AND s.wait_class != ''Idle''))
 AND t.ses_addr(+) = s.saddr
 AND sq.sql_id(+) =s.sql_id
 AND sq.child_number(+)=s.sql_child_number
 AND serv.name(+) =s.service_name
 AND en.EVENT#(+) =s.EVENT#
 )' 
       from dual where 1=1
) order by ord ;
sq varchar2(32000);      
begin
  FOR rec in c
   LOOP
      sq := sq ||' ' || rec.txt;
   END LOOP;
--dbms_output.put_line(sq);   
execute immediate sq ;   
end;
/
         


prompt
prompt
prompt ... Updating packages   
   
CREATE OR REPLACE PACKAGE BASH.BASH AS
  procedure run;
  procedure stop;
  procedure purge (days_to_keep NUMBER default NULL);
  procedure runner;  
END BASH;
/

CREATE OR REPLACE PACKAGE BODY BASH.BASH
AS

  -- Settings
  s_sample_every            NUMBER := 100; --centiseconds
  s_persist_every           NUMBER := 10;  --# of samples
  s_checkinst_every         NUMBER := 60;  --# of samples
  s_cleanup_every           NUMBER := 100; --# of memory samples
  s_cleanup_log_every       NUMBER := 100; --# of persisted samples (100*10 seconds=1000 seconds)
  s_max_entries_kept        NUMBER :=30000;
  s_logging                 NUMBER :=0;
  s_keep_log_entries        NUMBER :=1; --# of days

  -- Variables
  g_last_snapshot_persisted NUMBER;
  g_last_snapshot_flushed   NUMBER;
  g_own_sid                 NUMBER;
  g_own_inst_id             NUMBER :=-1 ;
  C_LOCK_ID_COLLECTOR       NUMBER;
  g_settings_updated_ts		TIMESTAMP;


PROCEDURE log(
    p_line VARCHAR2)
IS
BEGIN
  IF s_logging                                         =1 THEN
    IF mod(g_last_snapshot_persisted,s_cleanup_log_every)=0 THEN
      DELETE FROM bash$log_INTERNAL WHERE log_date< sysdate-s_keep_log_entries;
    END IF;
    INSERT
    INTO bash$log_INTERNAL
      (
        LOG_ID,
        LOG_DATE,
        LOG_MESSAGE
      )
      VALUES
      (
        extract(day from(systimestamp - to_timestamp('2000-01-01', 'YYYY-MM-DD'))) * 86400 + trunc(to_number(to_char(sys_extract_utc(systimestamp), 'SSSSSFF3'))/1000),
        systimestamp,
        p_line || ' (Instance ID: '|| to_char(g_own_inst_id) || ')'
      );
    COMMIT;
  END IF;
END;

procedure read_setting
is
l_updated_ts timestamp;
begin  
SELECT UPDATED_TS into l_updated_ts FROM bash.bash$settings;
if (g_settings_updated_ts is null) or (l_updated_ts>g_settings_updated_ts) then
log('Reloading settings...');
g_settings_updated_ts:=l_updated_ts;
SELECT 
   sample_every_n_centiseconds,
    persist_every_n_samples,
    cleanup_every_n_samples,
    max_entries_kept,
    logging_enabled,
    keep_log_entries_n_days,
	checkfnewinst_every_n_samples
    into 
    s_sample_every,s_persist_every,s_cleanup_every,s_max_entries_kept,s_logging,s_keep_log_entries,s_checkinst_every 
FROM bash.bash$settings;
log('Reloading settings done.'); 
end if;
end;


PROCEDURE collector
IS
  l_sample_id   NUMBER;
  l_sample_time TIMESTAMP(3);
BEGIN
  select extract(day from(systimestamp - to_timestamp('2000-01-01', 'YYYY-MM-DD'))) * 86400 + trunc(to_number(to_char(sys_extract_utc(systimestamp), 'SSSSSFF3'))/1000) into l_sample_id from dual;
  l_sample_time:=systimestamp;
  INSERT
  INTO bash.bash$session_INTERNAL
    (
      SAMPLE_ID,
      SAMPLE_TIME,
      INST_ID,
      SID,
      SERIAL#,
      USER#,
      USERNAME,
      COMMAND,
      OSUSER,
      MACHINE,
      PORT,
      TERMINAL,
      PROGRAM,
      TYPE,
      SQL_ID,
      SQL_CHILD_NUMBER,
      SQL_EXEC_START,
      SQL_EXEC_ID,
      PLSQL_ENTRY_OBJECT_ID,
      PLSQL_ENTRY_SUBPROGRAM_ID,
      PLSQL_OBJECT_ID,
      PLSQL_SUBPROGRAM_ID,
      MODULE,
      ACTION,
      ROW_WAIT_OBJ#,
      ROW_WAIT_FILE#,
      ROW_WAIT_BLOCK#,
      TOP_LEVEL_CALL#,
      CLIENT_IDENTIFIER,
      BLOCKING_SESSION_STATUS,
      BLOCKING_SESSION,
      SEQ#,
      EVENT#,
      EVENT,
      P1TEXT,
      P1,
      P2TEXT,
      P2,
      P3TEXT,
      P3,
      WAIT_CLASS_ID,
      WAIT_CLASS,
      WAIT_TIME,
      SECONDS_IN_WAIT,
      STATE,
      ECID,
      xid,
      sql_plan_hash_value,
      FORCE_MATCHING_SIGNATURE,
      SERVICE_HASH,
      sql_opname,
      EVENT_ID
    )
    (SELECT
      l_sample_id,
      l_sample_time,
      INST_ID,
      SID,
      SERIAL#,
      USER#,
      USERNAME,
      COMMAND,
      OSUSER,
      MACHINE,
      PORT,
      TERMINAL,
      PROGRAM,
      TYPE,
      SQL_ID,
      SQL_CHILD_NUMBER,
      SQL_EXEC_START,
      SQL_EXEC_ID,
      PLSQL_ENTRY_OBJECT_ID,
      PLSQL_ENTRY_SUBPROGRAM_ID,
      PLSQL_OBJECT_ID,
      PLSQL_SUBPROGRAM_ID,
      MODULE,
      ACTION,
      ROW_WAIT_OBJ#,
      ROW_WAIT_FILE#,
      ROW_WAIT_BLOCK#,
      TOP_LEVEL_CALL#,
      CLIENT_IDENTIFIER,
      BLOCKING_SESSION_STATUS,
      BLOCKING_SESSION,
      SEQ#,
      EVENT#,
      EVENT,
      P1TEXT,
      P1,
      P2TEXT,
      P2,
      P3TEXT,
      P3,
      WAIT_CLASS_ID,
      WAIT_CLASS,
      WAIT_TIME,
      SECONDS_IN_WAIT,
      STATE,
      ECID,
      xid,
      sql_plan_hash_value,
      FORCE_MATCHING_SIGNATURE,
      SERVICE_HASH,
      sql_opname,
      EVENT_ID
     FROM BASH$VSOURCE WHERE sid <>g_own_sid
    ) ;
    IF s_logging=1 then log('Done sampling '|| SQL%RowCount ||' rows at '||TO_CHAR(l_sample_time)||' Sample_id: '|| TO_CHAR(l_sample_id)); end if; 
  COMMIT;
END;


PROCEDURE DROP_JOBS
IS
BEGIN
FOR job_rec in (SELECT JOB_NAME FROM USER_SCHEDULER_JOBS where JOB_NAME like 'BASH_COLLECTOR_SCHEDULER_JOB%')
   LOOP
    
    BEGIN
    DBMS_SCHEDULER.disable (name => job_rec.JOB_NAME);
    COMMIT;
    EXCEPTION  WHEN OTHERS THEN NULL;
    END;
    BEGIN
    DBMS_SCHEDULER.stop_job (job_name => job_rec.JOB_NAME);
    COMMIT;
    EXCEPTION  WHEN OTHERS THEN NULL;
    END;
    BEGIN
    DBMS_SCHEDULER.disable (name => job_rec.JOB_NAME);
    COMMIT;
    EXCEPTION  WHEN OTHERS THEN NULL;
    END;

    DBMS_SCHEDULER.DROP_JOB (job_name => job_rec.JOB_NAME);
   
   END LOOP;  
END;

PROCEDURE CREATE_JOBS
IS
BEGIN
FOR instance_rec in (SELECT INST_NUMBER INST_ID FROM V$ACTIVE_INSTANCES UNION SELECT instance_number INST_ID FROM V$INSTANCE)
   LOOP
     dbms_scheduler.create_job( job_name=>'BASH_COLLECTOR_SCHEDULER_JOB'||instance_rec.INST_ID, job_type=>'PLSQL_BLOCK', job_action => 'BASH.runner();', repeat_interval => 'FREQ=MINUTELY', enabled=>FALSE, comments=>'Starts the endless collector package procedure BASH.BASH.RUNNER that samples V$SESSION on instance '||to_char(instance_rec.INST_ID));
     IF dbms_utility.is_cluster_database THEN
     BEGIN
	    -- In a RAC we need to make sure that we have one collector job on each instance.
		-- Setting INSTANCE_ID on a scheduelr job only works on Oracle >=11.1.
		dbms_scheduler.set_attribute('BASH_COLLECTOR_SCHEDULER_JOB'||instance_rec.INST_ID,'INSTANCE_ID',instance_rec.INST_ID);
	 END;
     END IF;
   END LOOP;  
END;


PROCEDURE START_JOBS
IS
BEGIN
FOR instance_rec in (SELECT INST_NUMBER INST_ID FROM V$ACTIVE_INSTANCES UNION SELECT instance_number INST_ID FROM V$INSTANCE)
   LOOP
     DBMS_SCHEDULER.enable( name=>'BASH_COLLECTOR_SCHEDULER_JOB'||instance_rec.INST_ID);
   END LOOP;  
END;

PROCEDURE CREATE_JOBS_FOR_NEW_INSTANCES
IS
BEGIN
FOR instance_rec in (SELECT to_char(INST_NUMBER) INST_ID FROM V$ACTIVE_INSTANCES UNION SELECT to_char(instance_number) INST_ID FROM V$INSTANCE minus SELECT substr(JOB_NAME,29,1) INST_ID FROM USER_SCHEDULER_JOBS where JOB_NAME like 'BASH_COLLECTOR_SCHEDULER_JOB%')
   LOOP
     log('Creating collector job for newly discovered instance '||instance_rec.INST_ID);
	 begin
	   dbms_scheduler.create_job( job_name=>'BASH_COLLECTOR_SCHEDULER_JOB'||instance_rec.INST_ID, job_type=>'PLSQL_BLOCK', job_action => 'BASH.runner();', repeat_interval => 'FREQ=MINUTELY', enabled=>FALSE, comments=>'Starts the endless collector package procedure BASH.BASH.RUNNER that samples V$SESSION on instance '||to_char(instance_rec.INST_ID));
       IF dbms_utility.is_cluster_database THEN
	      -- In a RAC we need to make sure that we have one collector job on each instance.
          -- Setting INSTANCE_ID on a scheduler job only works on Oracle >=11.1.
          dbms_scheduler.set_attribute('BASH_COLLECTOR_SCHEDULER_JOB'||instance_rec.INST_ID,'INSTANCE_ID',instance_rec.INST_ID);
       END IF;
	   DBMS_SCHEDULER.enable( name=>'BASH_COLLECTOR_SCHEDULER_JOB'||instance_rec.INST_ID);
	 EXCEPTION
     WHEN OTHERS THEN log('FAILED: Creating collector job for newly discovered instance '||instance_rec.INST_ID);	 
     END;	 
   END LOOP;  
END;


PROCEDURE do_FLUSH_PERSISTANT  
IS
  l_currval NUMBER;
BEGIN
  log('Flushing persistant entries');
  select (extract(day from(systimestamp - to_timestamp('2000-01-01', 'YYYY-MM-DD'))) * 86400 + trunc(to_number(to_char(sys_extract_utc(systimestamp), 'SSSSSFF3'))/1000))-1 into l_currval from dual;
  INSERT
  INTO bash.bash$session_hist_INTERNAL
    (SELECT *
      FROM bash.bash$session_internal
      WHERE mod(SAMPLE_id,s_persist_every)=0
      AND sample_id                     >g_last_snapshot_persisted
	  AND INST_ID=g_own_inst_id
    );
  g_last_snapshot_persisted:=l_currval;
   IF s_logging=1 then log('Done flushing '|| SQL%RowCount ||' persistant entries'); end if; 
  COMMIT;
  read_setting;
END;


PROCEDURE do_cleanup
IS
  l_count        NUMBER;
  l_entries_kept NUMBER;
BEGIN
  log('Doing cleanup');
  l_entries_kept:=s_max_entries_kept;
  SELECT COUNT(*) INTO l_count FROM bash.bash$session_INTERNAL;
  log(l_count||' entries in bash$session_internal before delete - Keep count is '||l_entries_kept); 
  l_count  :=l_count-l_entries_kept;
  IF l_count>0 THEN
    DELETE
    FROM bash.bash$session_internal
    WHERE sample_id IN
      (SELECT        *
      FROM
        (SELECT sample_id FROM bash.bash$session_internal ORDER BY sample_id
        )
      WHERE rownum<=l_count
      );
    COMMIT;
  END IF;
  SELECT COUNT(*) INTO l_count FROM bash.bash$session_internal;
  log(l_count||' entries in bash$session_internal after delete - Keep count is '||l_entries_kept); 
  log('Done Cleanup'); 
END;


PROCEDURE purge (days_to_keep NUMBER DEFAULT NULL)
IS
  l_del_sample_time TIMESTAMP(3);
  l_days_to_keep NUMBER;
BEGIN
  l_days_to_keep := days_to_keep;
  if l_days_to_keep is null then
     SELECT HIST_DAYS_TO_KEEP into l_days_to_keep FROM BASH.BASH$SETTINGS;
  end if;
  l_del_sample_time:=systimestamp-l_days_to_keep;
  log('Purging entries from Session History table older than '||l_del_sample_time);
  DELETE FROM BASH.BASH$SESSION_HIST_INTERNAL WHERE SAMPLE_TIME<l_del_sample_time;
  COMMIT;
END;



PROCEDURE STOP
IS
BEGIN
  DROP_JOBS;
END;


PROCEDURE run
IS
BEGIN
  STOP;
  CREATE_JOBS;
  START_JOBS;
END;


PROCEDURE runner
IS
  l_start_time NUMBER;
  l_this_time  NUMBER;
  l_counter    NUMBER;
  l_result     INTEGER;
  l_sleep_time NUMBER;
BEGIN
  BEGIN
    read_setting;
	SELECT INSTANCE_number into g_own_inst_id FROM V$INSTANCE;
    dbms_application_info.set_module('BASH collector instance '||to_char(g_own_inst_id),''); 
	C_LOCK_ID_COLLECTOR:=1237820+g_own_inst_id; -- each instance gets its own LOCK_ID
    l_result   :=DBMS_LOCK.REQUEST(C_LOCK_ID_COLLECTOR,DBMS_LOCK.X_MODE,0);
    IF l_result<>0 THEN
      raise_application_error( -20900, 'Could not start BASH collection, since it is already running in another session in this instance.' );
    END IF;
    l_counter:=0;
	select (extract(day from(systimestamp - to_timestamp('2000-01-01', 'YYYY-MM-DD'))) * 86400 + trunc(to_number(to_char(sys_extract_utc(systimestamp), 'SSSSSFF3'))/1000))-1 into g_last_snapshot_persisted from dual;
    g_last_snapshot_flushed  :=g_last_snapshot_persisted;
    SELECT sys_context('USERENV','SID') INTO g_own_sid FROM dual;

    l_start_time:=dbms_utility.get_time();
    LOOP
      collector;
      IF mod(l_counter,s_persist_every)=s_persist_every-1 THEN
        do_FLUSH_PERSISTANT;
		IF mod(l_counter,s_checkinst_every)=s_checkinst_every-1 THEN
		  IF dbms_utility.is_cluster_database THEN CREATE_JOBS_FOR_NEW_INSTANCES;
	    END IF;
	  END IF;

      END IF;
      IF mod(l_counter,s_cleanup_every)=s_cleanup_every-1 THEN
        do_CLEANUP;
      END IF;
      l_counter     :=l_counter+1;
      l_this_time   :=dbms_utility.get_time();
      l_sleep_time  :=(s_sample_every-(l_this_time-l_start_time -((l_counter)*s_sample_every)))/100;
      IF l_sleep_time>0 THEN
        dbms_lock.sleep(l_sleep_time);
      END IF;
    END LOOP;
  EXCEPTION
  WHEN OTHERS THEN
    log('Exception in runner...');
    log( SQLERRM );
    log( DBMS_UTILITY.FORMAT_ERROR_BACKTRACE );
    l_result :=DBMS_LOCK.RELEASE(C_LOCK_ID_COLLECTOR);
    RAISE;
  END;
  l_result :=DBMS_LOCK.RELEASE(C_LOCK_ID_COLLECTOR);
END;
END BASH;
/


PROMPT 
PROMPT ... Dropping sequence

DROP SEQUENCE  "BASH"."BASH_SEQ";
DROP SEQUENCE  "BASH"."BASH_LOG_SEQ";


PROMPT 
PROMPT ... Recompiling BASH schema


begin
UTL_RECOMP.RECOMP_SERIAL (schema=>'BASH');
end;
/


UPDATE  BASH.BASH$SETTINGS set VERSION=6;
COMMIT;

PROMPT 
PROMPT ... Starting collector

prompt
prompt Would you like to start the BASH data collector? Enter N if you don't want to start it now.
prompt


set heading off

col start_bash_collector new_value start_bash_collector noprint
select 'Starting BASH collector: '||
       decode(upper(nvl('&&start_bash_collector','Y')),'N','No','Yes')
     , upper(nvl('&&start_bash_collector','Y')) start_bash_collector
	 from dual;
set heading on


BEGIN
  IF '&start_bash_collector' <> 'N' THEN
    BASH.BASH.RUN;
  END IF;
END;
/

PROMPT 
PROMPT ... Done.

exit

