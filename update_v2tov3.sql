
set echo off verify off showmode off feedback off;
whenever sqlerror exit sql.sqlcode

PROMPT 
PROMPT ... Stopping collector

begin
bash.bash.stop();
end;
/

PROMPT 
PROMPT ... Installing view BASH$VSOURCE

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
 (SELECT 500+ord ord,NVL2(c.column_name,'s.'||c.column_name||', ','NULL, ') FROM cols c, cols_Wanted cw where c.column_name(+)=cw.column_name)
 union  

 select 900 ord, 
 't.xid,
 sq.plan_hash_value,
 sq.FORCE_MATCHING_SIGNATURE,
 serv.name_hash,
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
 WHEN 65
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
 WHEN 95' 
       from dual where 1=1
 union  
 select 901 ord, 
 ' THEN ''ALTER PACKAGE''
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
 WHEN 162
 THEN ''DROP JAVA''
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
 END sql_opname,
 en.event_id
 FROM gv$session s,
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
execute immediate sq ;   
end;
/


PROMPT 
PROMPT ... Updating package body BASH


CREATE OR REPLACE PACKAGE BODY      BASH.BASH
AS
  -- Constants
  C_BASH_JOB_ID             CONSTANT NUMBER:=2874615647;
  C_LOCK_ID_COLLECTOR       CONSTANT NUMBER := 1237820;

  -- Settings
  s_sample_every            NUMBER := 100; --centiseconds
  s_persist_every           NUMBER := 10;  --# of samples
  s_cleanup_every           NUMBER := 100; --# of memory samples
  s_cleanup_log_every       NUMBER := 100; --# of persisted samples (100*10 seconds=1000 seconds)
  s_max_entries_kept        NUMBER :=30000;
  s_logging                 NUMBER :=0;
  s_keep_log_entries        NUMBER :=1; --# of days

  -- Variables
  g_last_snapshot_persisted NUMBER;
  g_last_snapshot_flushed   NUMBER;
  g_own_sid                 NUMBER;


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
        bash_log_seq.nextval,
        systimestamp,
        p_line
      );
    COMMIT;
  END IF;
END;

procedure read_setting
is
l_updated NUMBER;
begin
SELECT UPDATED into l_updated FROM bash.bash$settings;
if l_updated<>0 then
log('Reloading settings...');
SELECT 
   sample_every_n_centiseconds,
    persist_every_n_samples,
    cleanup_every_n_samples,
    max_entries_kept,
    logging_enabled,
    keep_log_entries_n_days
    into 
    s_sample_every,s_persist_every,s_cleanup_every,s_max_entries_kept,s_logging,s_keep_log_entries 
FROM bash.bash$settings;
UPDATE bash.bash$settings set UPDATED=0;
COMMIT;
log('Reloading settings done.');
end if;
end;


PROCEDURE collector
IS
  l_sample_id   NUMBER;
  l_sample_time TIMESTAMP(3);
BEGIN
  select bash_seq.nextval into l_sample_id from dual;
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

PROCEDURE do_FLUSH_PERSISTANT
IS
  l_currval NUMBER;
BEGIN
  log('Flushing persistant entries');
  select bash_seq.currval into l_currval from dual;
  INSERT
  INTO bash.bash$session_hist_INTERNAL
    (SELECT *
      FROM bash.bash$session_internal
      WHERE mod(SAMPLE_id,s_persist_every)=0
      AND sample_id                     >g_last_snapshot_persisted
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


PROCEDURE purge (days_to_keep NUMBER)
IS
  l_del_sample_time TIMESTAMP(3);
BEGIN
  l_del_sample_time:=systimestamp-days_to_keep;
  log('Purging entries from Session History table older than '||l_del_sample_time);
  DELETE FROM BASH.BASH$SESSION_HIST_INTERNAL WHERE SAMPLE_TIME<l_del_sample_time;
  COMMIT;
END;


PROCEDURE STOP
IS
BEGIN
  BEGIN
    DBMS_SCHEDULER.disable (name => 'BASH_COLLECTOR_SCHEDULER_JOB');
    COMMIT;
  EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE = -27476 THEN -- Job doesn't exist
      dbms_scheduler.create_job( job_name=>'BASH_COLLECTOR_SCHEDULER_JOB', job_type=>'PLSQL_BLOCK', job_action => 'BASH.runner();', repeat_interval => 'FREQ=MINUTELY', enabled=>FALSE, comments=>'Starts the endless collector package procedure BASH.BASH.RUNNER that samples V$SESSION');
      COMMIT;
    END IF;
  END;
  BEGIN
    DBMS_SCHEDULER.stop_job(job_name => 'BASH_COLLECTOR_SCHEDULER_JOB');
    COMMIT;
  EXCEPTION
  WHEN OTHERS THEN
    NULL;
  END;
  BEGIN
    DBMS_SCHEDULER.disable (name => 'BASH_COLLECTOR_SCHEDULER_JOB');
    COMMIT;
  EXCEPTION
  WHEN OTHERS THEN
    NULL;
  END;
END;


PROCEDURE run
IS
BEGIN
  STOP;
  DBMS_SCHEDULER.enable (name => 'BASH_COLLECTOR_SCHEDULER_JOB');
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
    dbms_application_info.set_module('BASH collector','');
    l_result   :=DBMS_LOCK.REQUEST(C_LOCK_ID_COLLECTOR,DBMS_LOCK.X_MODE,0);
    IF l_result<>0 THEN
      raise_application_error( -20900, 'Could not start BASH collection, since it is already running in another session.' );
    END IF;
    l_counter:=0;
	select bash_seq.nextval-1 into g_last_snapshot_persisted from dual;
    g_last_snapshot_flushed  :=g_last_snapshot_persisted;
    SELECT sys_context('USERENV','SID') INTO g_own_sid FROM dual;
    l_start_time:=dbms_utility.get_time();
    LOOP
      collector;
      IF mod(l_counter,s_persist_every)=s_persist_every-1 THEN
        do_FLUSH_PERSISTANT;
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

UPDATE  BASH.BASH$SETTINGS set VERSION=3;
COMMIT;


PROMPT 
PROMPT ... Recompiling BASH schema


begin
UTL_RECOMP.RECOMP_SERIAL (schema=>'BASH');
end;
/

PROMPT 
PROMPT ... Starting collector

begin
bash.bash.run();
end;
/

PROMPT 
PROMPT ... Done.

