
set echo off verify off showmode off feedback off;
whenever sqlerror exit sql.sqlcode

PROMPT 
PROMPT ... Stopping collector

begin
bash.bash.stop();
end;
/

PROMPT 
PROMPT ... Modifying table BASH.BASH$SETTINGS

alter table BASH.BASH$SETTINGS add HIST_DAYS_TO_KEEP number;
update BASH.BASH$SETTINGS set HIST_DAYS_TO_KEEP=93;
commit;


PROMPT 
PROMPT ... Modifying table BASH$SESSION_INTERNAL

alter table "BASH"."BASH$SESSION_INTERNAL" modify ("TERMINAL" VARCHAR2(30 BYTE));

PROMPT 
PROMPT ... Modifying table BASH$SESSION_HIST_INTERNAL

alter table "BASH"."BASH$SESSION_HIST_INTERNAL" modify ("TERMINAL" VARCHAR2(30 BYTE));

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

prompt
prompt ... Creating nightly purge job for historic data
prompt


begin
dbms_scheduler.create_job( job_name=>'BASH.BASH_PURGE_SCHEDULER_JOB', job_type=>'PLSQL_BLOCK', job_action => 'BASH.PURGE();', repeat_interval => 'FREQ=DAILY; BYHOUR=3; BYMINUTE=33', enabled=>TRUE, comments=>'Purges the historic BASH data');
end;
/

PROMPT 
PROMPT ... Recompiling BASH schema


begin
UTL_RECOMP.RECOMP_SERIAL (schema=>'BASH');
end;
/


UPDATE  BASH.BASH$SETTINGS set VERSION=5;
COMMIT;

PROMPT 
PROMPT ... Starting collector

begin
bash.bash.run();
end;
/

PROMPT 
PROMPT ... Done.

