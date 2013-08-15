
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


PROMPT 
PROMPT ... Creating functions

CREATE OR REPLACE FUNCTION BASH.GET_TS_ID return NUMBER is
  l_ts_id number;
begin
    select
          extract(day from (sys_extract_utc(systimestamp)- to_timestamp('2000-01-01', 'YYYY-MM-DD')))*24*60*60
    +     extract(day from sys_extract_utc(systimestamp))*24*60*60
    +     extract(hour from sys_extract_utc(systimestamp))*60*60
    +     extract(minute from sys_extract_utc(systimestamp))*60
    +     trunc(extract(second from sys_extract_utc(systimestamp))) into l_ts_id
    from   dual;
  return l_ts_id;
end;
/

PROMPT 
PROMPT ... Updating packages


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
        GET_TS_ID,
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
  l_sample_ID:=GET_TS_ID;
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
  l_rc      NUMBER;
BEGIN
  log('Flushing persistant entries');
  INSERT
  INTO bash.bash$session_hist_INTERNAL
    (SELECT *
      FROM bash.bash$session_internal
      WHERE mod(SAMPLE_id,s_persist_every)=0
      AND sample_id                     >g_last_snapshot_persisted
	  AND INST_ID=g_own_inst_id
    );
  l_rc:=SQL%RowCount;
  if l_rc>0 then
    select max(SAMPLE_id) into g_last_snapshot_persisted from bash.bash$session_internal where INST_ID=g_own_inst_id;
	end if;
  IF s_logging=1 then log('Done flushing '|| l_rc ||' persistant entries'); end if; 
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
	
     begin
	 select max(SAMPLE_id) into g_last_snapshot_persisted from bash.BASH$SESSION_HIST_INTERNAL where INST_ID=g_own_inst_id;
	 EXCEPTION
	  WHEN OTHERS THEN
		g_last_snapshot_persisted:=GET_TS_ID-1;
	  END;	
	  
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
PROMPT ... Recompiling BASH schema


begin
UTL_RECOMP.RECOMP_SERIAL (schema=>'BASH');
end;
/


UPDATE  BASH.BASH$SETTINGS set VERSION=7;
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
