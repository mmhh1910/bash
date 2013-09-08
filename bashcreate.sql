------------------------------------------------------------------------------------
--
-- Name:          bashcreate.sql - BASH Installation script for Oracle 10.2 to 12.1
--
-- Author:        Marcus Monnig
-- Copyright:     (c) 2012, 2013 Marcus Monnig - All rights reserved.
--
-- Check http://marcusmonnig.wordpress.com/bash/ for new versions.
--
-- Disclaimer:    No guarantees. Use at your own risk. 
--
-- Changelog:     v1: 2012-12-28 First public release 
--                v2: 2013-01-15 Added not null constraints to tables	 	
--                v3: 2013-02-07 Rewrote the install script so that it dynamically checks for 
--                               columns available in V$SESSION and generates an appropiate view. 
--                               This should make it compatible at least to all Oracle 
--                               versions >= 10.2.0.1.
--                v4: 2013-02-08 Fixed a problem on <10.2.0.5 with more than 255 arguments in case statement
--                v5: 2013-06-15 Added a nightly purge job for historic data (defaults to 93 "days to keep")
--                                 (if you already created one yourself and use the update_v4tov5.sql update
--                                  script you'll end up with two)
--                               Changed the TERMINAL column from VARCHAR2(16) to VARCHAR2(32)
--                v6: 2013-06-27 Made sure BASH works on Oracle 12c
--                               BASH is now compatible with RAC on Oracle 11.1 and higher. Each instance 
--                                 runs its own collector through a separate scheduler job.
--                                 
--                                 Scheduler jobs are created and deleted when starting and stopping the 
--                                 collector through EXEC BASH.BASH.RUN;. The collector detects new 
--                                 instances when running and create collector jobs for them.
--                                 
--                                 The following public synonyms to select the collected data now exist:
--                                 
--                                 BASH$ACTIVE_SESSION_HISTORY        ASH data from the current instance
--                                 BASH$HIST_ACTIVE_SESS_HISTORY      Historic ASH data from the current instance
--                                 BASHG$ACTIVE_SESSION_HISTORY       ASH data from all instances
--                                 BASHG$HIST_ACTIVE_SESS_HISTORY     Historic ASH data from all instancess
--                v7: 2013-07-13 Fixed a UTC-conversion bug around midnight, resulting in too many entries in 
--                                 BASH$HIST_ACTIVE_SESS_HISTORY (Thanks to Robert Ortel)
--                               Fixed a bug leading to duplicate rows in BASH$HIST_ACTIVE_SESS_HISTORY after
--                                 10 seconds with no active sessions sampled (Thanks to Robert Ortel)
--                v8: 2013-08-01 Fixed another UTC-conversion resulting in no entries in BASH$HIST_ACTIVE_SESS_HISTORY
--                               Added missing trigger on BASH.BASH$SETTINGS
--                               Renamed INST_ID to INSTANCE_NUMBER in views accessed through public synonyms
--                               Fixed a bug causing no data flushed to BASH$HIST_ACTIVE_SESS_HISTORY
--                v9: 2013-09-09 Now including INST_ID column in indexes on SAMPLE_TIME and SAMPLE_ID columns 
--                               ASH compatibility fix: Just like in Oracle ASH, SESSION_STATE columns now show "ON CPU" 
--                                 values instead of "WAITED KNOW/UNKNOWN/SHORT TIME". This should make a lot of 3rd 
--                                 party scripts/queries compatible with BASH.
--
--
-- Purpose:       It's ASH for the rest of us (no EE or no diagnostic pack license).
--
-- Requirements:  * Single instance Oracle 10.2 to 12.1 database or RAC database Oracle 11.1 or higher
--                * SE1, SE or EE - Diagnostic Pack NOT needed
--                * Parameter job_queue_processes > 0 
--                   (since the bash data collector permanently runs as a scheduler 
--                    job, you might want to consider raising the job_queue_processes 
--                    parameter by one)
--                * RAC databases are only supported for Oracle version 11.2 or higher
--
-- Installation:  1.) Create a new tablespace for the BASH schema (optional, but recommended).
--                2.) Run: sqlplus sys/<sys_password>@<TNS_ALIAS> as sysdba @bashcreate.sql
--                3.) When asked, enter the password for the BASH user to be created and the 
--                    names for the permanent and temporary tablespace for the BASH user.
--                4.) When asked, enter "N" if you don't want to start the data 
--                    collector job right away. 
--
-- Uninstall:     sqlplus sys/<sys_password>@<TNS_ALIAS> as sysdba @bashdrop.sql
--
--
-- Usage:         *** CONTROLLING THE DATA COLLECTION *** 
--
--                The package BASH.BASH has the following procedures that let you
--                control the data gathering:
--
--                procedure run;
--                    Creates and start the bash data collector scheduler job.
--
--                procedure stop;
--                    Stops the bash data collector scheduler job.
--
--                procedure purge (days_to_keep NUMBER);
--                    Purges the data in BASH$HIST_ACTIVE_SESS_HISTORY
--
--                procedure runner;  
--                    Blocking procedure that collects the bash data. Called by the 
--                    data collector scheduler job, but might be usefull to call manually 
--                    e.g. when scheduler jobs are not available and the data collector 
--                    can not be run from a job session.
--
--
--                *** SETTINGS ***
--
--                The table BASH.BASH$SETTINGS has the following columns that let
--                you control how the BASH data is gathered:
--
--                 sample_every_n_centiseconds NUMBER (Default: 100 = 1 second)
--                     Number of centiseconds V$SESSION is sampled.
--
--                 max_entries_kept NUMBER (Default: 30000)
--                     How many entries are kept in BASH$ACTIVE_SESSION_HISTORY.
--
--                 cleanup_every_n_samples NUMBER (Default: 100)
--                     How often the data in BASH$ACTIVE_SESSION_HISTORY is purged.
--
--                 checkfnewinst_every_n_samples NUMBER (Default: 60)
--                     How often the collector checks for new instances in a clustered database
--                     to create a collector job for the new instance.
--
--                 persist_every_n_samples NUMBER (Default: 10 )
--                     How many of the samples are persisted to BASH$HIST_ACTIVE_SESS_HISTORY.
--
--                 logging_enabled NUMBER (Default: 0)
--                     If logging to BASH$LOG is enabled .
--
--                 keep_log_entries_n_days NUMBER (Default: 1)
--                     How many days log entries in BASH$LOG are kept.
--
--                 hist_days_to_keep NUMBER 
--                     The number of days for that historic data is kept in BASH$HIST_ACTIVE_SESS_HISTORY
--                     when the BASH.BASH.PURGE is called wthout arguments. This setting is also used by
--                     the purge job that is installed with BASH and runs every night.
--
--                 updated_ts TIMESTAMP 
--                     An internally used column that tracks changes in the settings table
--                     through a trigger.
--
--                 version NUMBER 
--                     The version number of BASH. Might be used with future update scripts.
--                     Do not change.
--
--                If you change a setting in the BASH.BASH$SETTINGS table and commit,
--                the updated setting will be used by the data collector the next time
--                it persists data to DBA_HIST_ACTIVE_SESS_HISTORY (default: every 10 seconds) 
--
--                The default values for sample_every_n_centiseconds and 
--                persist_every_n_samples replicate the ASH behaviour. 
--                
--
--                *** QUERYING THE COLLECTED BASH DATA *** 
--
--                BASH$ACTIVE_SESSION_HISTORY
--                  ASH data from the current instance. Replaces V$ACTIVE_SESSION_HISTORY (1-second samples)
--
--                BASH$HIST_ACTIVE_SESS_HISTORY
--                  Historic ASH data from the current instance. Replaces DBA_HIST_ACTIVE_SESS_HISTORY (10-second samples)
--
--                BASHG$ACTIVE_SESSION_HISTORY
--                  ASH data from all instances. ASH data from the current instance. Replaces V$ACTIVE_SESSION_HISTORY 
--                  (1-second samples)
--
--                BASHG$HIST_ACTIVE_SESS_HISTORY
--                  Historic ASH data from all instancess. Historic ASH data from the current instance. 
--                  Replaces DBA_HIST_ACTIVE_SESS_HISTORY (10-second samples)
--
--                BASH$LOG
--                  Logging table (logging is off by default)
--
--                                 BASH$ACTIVE_SESSION_HISTORY        ASH data from the current instance
--                                 BASH$HIST_ACTIVE_SESS_HISTORY      Historic ASH data from the current instance
--                                 BASHG$ACTIVE_SESSION_HISTORY       ASH data from all instances
--                                 BASHG$HIST_ACTIVE_SESS_HISTORY     Historic ASH data from all instancess
--                
--                
--                Compatibilty with 3rd party products:
--
--                If want to use scripts or tools (e.g. "Mumbai" or "ASH Viewer") that 
--                select from V/GV$ACTIVE_SESSION_HISTORY or DBA_HIST_ACTIVE_SESS_HISTORY,
--                you might want to replace the following default Oracle public synonyms with 
--                synonyms pointing to BASH$ACTIVE_SESSION_HISTORY and 
--                BASH$HIST_ACTIVE_SESS_HISTORY:
--                
--                  CREATE OR REPLACE PUBLIC SYNONYM "V$ACTIVE_SESSION_HISTORY" 
--                      FOR BASH$ACTIVE_SESSION_HISTORY;
--
--                  CREATE OR REPLACE PUBLIC SYNONYM "GV$ACTIVE_SESSION_HISTORY" 
--                      FOR BASHG$ACTIVE_SESSION_HISTORY;
--
--                  CREATE OR REPLACE PUBLIC SYNONYM "DBA_HIST_ACTIVE_SESS_HISTORY" 
--                      FOR BASHG$HIST_ACTIVE_SESS_HISTORY;
--                
--                Note that these synonyms will not work for user SYS, so selecting from 
--                V$ACTIVE_SESSION_HISTORY as user sys will still return the Oracle ASH data,
--                not BASH data.
--                
--                Also note that you are still not allowed to use Oracle Enterprise Manager,
--                Oracle Database Console or the Oracle supplied ASH scripts in RDBMS/ADMIN
--                against BASH data without a valid Diagnostic Pack license.
--
--
--                *** CLEANUP AND PURGING *** 
--
--                The data collected for BASH$ACTIVE_SESSION_HISTORY is automatically purged,
--                based on the max_entries_kept setting.
--
--                The data collected for BASH$HIST_ACTIVE_SESS_HISTORY is purged by a nightly
--                scheduler job based on the settings in the column HIST_DAYS_TO_KEEP in the
--                table BASH.BASH$SETTINGS.
--
-- Background:    *** Performance impact of the BASH data collector ***
--
--                Oracle's own ASH uses a circular buffer in the SGA, which is something
--                a user process like the BASH data collector can not. After trying a few 
--                setups (global temporary tables, communications though DBMS_PIPE, etc.), I
--                decided to implement BASH as simple as possible using standard heap tables.
--                (The buffer cache is probably the closest thing to a separate memory area 
--                that can be used from a user session.)
--
--                I tested BASH on ten productive databases with quite different loads, both
--                on the OLTP and OLAP side. Since the load from BASH is not recorded by BASH 
--                (when sampling the sampler has to be ignored) I used Tanel Poder's snapper 
--                and latchprof scripts to check for load and excessive latch gets by the bash
--                data collector. The load was usually 0,01 AAS (usually on CPU), on some 
--                database with a large number of active session it sometimes was 0,02 AAS. 
--                The latchprof script showed only very low numbers of latch gets from the 
--                bash data collector.
--                
--                While the ASH setup with a circular buffer in the SGA and its latch-free 
--                access is definetly the superior architecture, I can not see any serious
--                side-effects with the down-to-earth BASH architecture.
--                
--                If you worry about the additonal 1-2% AAS load, you probably need BASH 
--                badly, to fix a few performance problems... ;-)
--                
--                
--                *** Columns in BASH$ACTIVE_SESSION_HISTORY ***
--                
--                For compatibilty reasons with 3rd party tools that select from 
--                V$ACTIVE_SESSION_HISTORY (but actually BASH$ACTIVE_SESSION_HISTORY if
--                you decide to replace the V$ACTIVE_SESSION_HISTORY public synonym), I made
--                all columns from V$ACTIVE_SESSION_HISTORY available in 
--                BASH$ACTIVE_SESSION_HISTORY, however some columns are not really filled
--                with data and always NULL: qc_session_id, qc_instance_id
--                and blocking_session_serial# from the 10.2 version of 
--                V$ACTIVE_SESSION_HISTORY and a whole series of columns from the 11.2
--                version of V$ACTIVE_SESSION_HISTORY (see comments in PL/SQL code).
--                
--                On the other hand, there are three columns in BASH$ACTIVE_SESSION_HISTORY
--                orginating from V$SESSION that are not available in V$ACTIVE_SESSION_HISTORY, 
--                because I think they are useful: OSUSER, TERMINAL, USERNAME
--                
------------------------------------------------------------------------------------


set echo off verify off showmode off feedback off;
whenever sqlerror exit sql.sqlcode


with mod_banner as (
    select
        replace(banner,'9.','09.') banner
    from
        v$version
    where rownum = 1
)
select
    decode(substr(banner, instr(banner, 'Release ')+8,1), '1',  '',  '--')  bash_ora10higher,
    decode(substr(banner, instr(banner, 'Release ')+8,2), '11', '',  '--')  bash_ora11higher,
    decode(substr(banner, instr(banner, 'Release ')+8,2), '11', '--',  '')  bash_ora11lower
from
    mod_banner
/

prompt
prompt Choose the BASH user's password
prompt ------------------------------------  

prompt Not specifying a password will result in the installation FAILING
prompt
prompt &&bash_password

spool bashcreate.log

begin
  if '&&bash_password' is null then
    raise_application_error(-20101, 'Install failed - No password specified for bash user');
  end if;
end;
/


prompt
prompt
prompt Choose the Default tablespace for the bash user
prompt ----------------------------------------------------

prompt Below is the list of online tablespaces in this database which can
prompt store user data.  Specifying the SYSTEM tablespace for the user's 
prompt default tablespace will result in the installation FAILING, as 
prompt using SYSTEM for performance data is not supported.
prompt
prompt Choose the bash users's default tablespace.  This is the tablespace
prompt in which the BASH objects will be created.

column db_default format a28 heading 'BASH DEFAULT TABLESPACE'
select tablespace_name, contents
     , decode(tablespace_name,'SYSAUX','*') db_default
  from sys.dba_tablespaces 
 where tablespace_name <> 'SYSTEM'
   and contents = 'PERMANENT'
   and status = 'ONLINE'
 order by tablespace_name;

prompt
prompt Pressing <return> will result in BASH's recommended default
prompt tablespace (identified by *) being used.
prompt

set heading off
col default_tablespace new_value default_tablespace noprint
select 'Using tablespace '||
       upper(nvl('&&default_tablespace','SYSAUX'))||
       ' as bash default tablespace.'
     , nvl('&default_tablespace','SYSAUX') default_tablespace
  from sys.dual;
set heading on

begin
  if upper('&&default_tablespace') = 'SYSTEM' then
    raise_application_error(-20101, 'Install failed - SYSTEM tablespace specified for DEFAULT tablespace');
  end if;
end;
/


prompt
prompt
prompt Choose the Temporary tablespace for the bash user
prompt ------------------------------------------------------

prompt Below is the list of online tablespaces in this database which can
prompt store temporary data (e.g. for sort workareas).  Specifying the SYSTEM 
prompt tablespace for the user's temporary tablespace will result in the 
prompt installation FAILING, as using SYSTEM for workareas is not supported.

prompt
prompt Choose the bash user's Temporary tablespace.

column db_default format a26 heading 'DB DEFAULT TEMP TABLESPACE'
select t.tablespace_name, t.contents
     , decode(dp.property_name,'DEFAULT_TEMP_TABLESPACE','*') db_default
  from sys.dba_tablespaces t
     , sys.database_properties dp
 where t.contents           = 'TEMPORARY'
   and t.status             = 'ONLINE'
   and dp.property_name(+)  = 'DEFAULT_TEMP_TABLESPACE'
   and dp.property_value(+) = t.tablespace_name
 order by tablespace_name;

prompt
prompt Pressing <return> will result in the database's default Temporary 
prompt tablespace (identified by *) being used.
prompt

set heading off
col temporary_tablespace new_value temporary_tablespace noprint
select 'Using tablespace '||
       nvl('&&temporary_tablespace',property_value)||
       ' as bash temporary tablespace.'
     , nvl('&&temporary_tablespace',property_value) temporary_tablespace
  from database_properties
 where property_name='DEFAULT_TEMP_TABLESPACE';
set heading on

begin
  if upper('&&temporary_tablespace') = 'SYSTEM' then
    raise_application_error(-20101, 'Install failed - SYSTEM tablespace specified for TEMPORARY tablespace');
  end if;
end;
/


prompt
prompt
prompt ... Creating bash user

CREATE USER "BASH" IDENTIFIED BY &&bash_password
      DEFAULT TABLESPACE &&default_tablespace
      TEMPORARY TABLESPACE &&temporary_tablespace;

prompt
prompt
prompt ... Granting priviliges to bash user
	  
ALTER USER BASH QUOTA UNLIMITED ON &&default_tablespace;
GRANT CREATE JOB TO "BASH";
GRANT CREATE PUBLIC SYNONYM TO "BASH";
GRANT CREATE SESSION TO "BASH";
GRANT ALTER SESSION TO "BASH";
GRANT CREATE PROCEDURE TO "BASH";
GRANT CREATE SEQUENCE TO "BASH";
GRANT CREATE SYNONYM TO "BASH";
GRANT CREATE TABLE TO "BASH";
GRANT CREATE TRIGGER TO "BASH";
GRANT CREATE VIEW TO "BASH";

ALTER USER "BASH" DEFAULT ROLE ALL;

GRANT SELECT on GV_$SESSION TO BASH;
GRANT SELECT on V_$ACTIVE_SERVICES TO BASH;
GRANT SELECT on V_$EVENT_NAME TO BASH;
GRANT SELECT on V_$PROCESS TO BASH;
GRANT SELECT on V_$SESSION TO BASH;
GRANT SELECT on V_$SQL TO BASH;
GRANT SELECT on V_$TRANSACTION TO BASH;
GRANT SELECT on V_$INSTANCE to BASH;
GRANT SELECT on GV_$INSTANCE to BASH;
GRANT SELECT on V_$ACTIVE_INSTANCES to BASH;

GRANT EXECUTE ON DBMS_LOCK TO BASH;
GRANT EXECUTE ON DBMS_UTILITY TO BASH;


 
prompt
prompt
prompt ... Installing tables

CREATE TABLE "BASH"."BASH$SESSION_INTERNAL" 
   (	"SAMPLE_ID" NUMBER NOT NULL, 
	"SAMPLE_TIME" TIMESTAMP (3) NOT NULL, 
	"SID" NUMBER, 
	"SERIAL#" NUMBER, 
	"USER#" NUMBER, 
	"USERNAME" VARCHAR2(30 BYTE), 
	"COMMAND" NUMBER, 
	"OSUSER" VARCHAR2(30 BYTE), 
	"MACHINE" VARCHAR2(64 BYTE), 
	"PORT" NUMBER, 
	"TERMINAL" VARCHAR2(30 BYTE), 
	"PROGRAM" VARCHAR2(64 BYTE), 
	"TYPE" VARCHAR2(10 BYTE), 
	"SQL_ID" VARCHAR2(13 BYTE), 
	"SQL_CHILD_NUMBER" NUMBER, 
	"SQL_EXEC_START" DATE, 
	"SQL_EXEC_ID" NUMBER, 
	"PLSQL_ENTRY_OBJECT_ID" NUMBER, 
	"PLSQL_ENTRY_SUBPROGRAM_ID" NUMBER, 
	"PLSQL_OBJECT_ID" NUMBER, 
	"PLSQL_SUBPROGRAM_ID" NUMBER, 
	"MODULE" VARCHAR2(64 BYTE), 
	"ACTION" VARCHAR2(64 BYTE), 
	"ROW_WAIT_OBJ#" NUMBER, 
	"ROW_WAIT_FILE#" NUMBER, 
	"ROW_WAIT_BLOCK#" NUMBER, 
	"TOP_LEVEL_CALL#" NUMBER, 
	"CLIENT_IDENTIFIER" VARCHAR2(64 BYTE), 
	"BLOCKING_SESSION_STATUS" VARCHAR2(11 BYTE), 
	"BLOCKING_SESSION" NUMBER, 
	"SEQ#" NUMBER, 
	"EVENT#" NUMBER, 
	"EVENT" VARCHAR2(64 BYTE), 
	"P1TEXT" VARCHAR2(64 BYTE), 
	"P1" NUMBER, 
	"P2TEXT" VARCHAR2(64 BYTE), 
	"P2" NUMBER, 
	"P3TEXT" VARCHAR2(64 BYTE), 
	"P3" NUMBER, 
	"WAIT_CLASS_ID" NUMBER, 
	"WAIT_CLASS" VARCHAR2(64 BYTE), 
	"WAIT_TIME" NUMBER, 
	"SECONDS_IN_WAIT" NUMBER, 
	"STATE" VARCHAR2(19 BYTE), 
	"ECID" VARCHAR2(64 BYTE), 
	"XID" RAW(8), 
	"SQL_PLAN_HASH_VALUE" NUMBER, 
	"FORCE_MATCHING_SIGNATURE" NUMBER, 
	"SERVICE_HASH" NUMBER, 
	"EVENT_ID" NUMBER, 
	"SQL_OPNAME" VARCHAR2(64 BYTE), 
	"INST_ID" NUMBER
   ) 
  TABLESPACE &&default_tablespace ;

CREATE TABLE "BASH"."BASH$SESSION_HIST_INTERNAL" 
   (	"SAMPLE_ID" NUMBER NOT NULL, 
	"SAMPLE_TIME" TIMESTAMP (3) NOT NULL, 
	"SID" NUMBER, 
	"SERIAL#" NUMBER, 
	"USER#" NUMBER, 
	"USERNAME" VARCHAR2(30 BYTE), 
	"COMMAND" NUMBER, 
	"OSUSER" VARCHAR2(30 BYTE), 
	"MACHINE" VARCHAR2(64 BYTE), 
	"PORT" NUMBER, 
	"TERMINAL" VARCHAR2(30 BYTE), 
	"PROGRAM" VARCHAR2(64 BYTE), 
	"TYPE" VARCHAR2(10 BYTE), 
	"SQL_ID" VARCHAR2(13 BYTE), 
	"SQL_CHILD_NUMBER" NUMBER, 
	"SQL_EXEC_START" DATE, 
	"SQL_EXEC_ID" NUMBER, 
	"PLSQL_ENTRY_OBJECT_ID" NUMBER, 
	"PLSQL_ENTRY_SUBPROGRAM_ID" NUMBER, 
	"PLSQL_OBJECT_ID" NUMBER, 
	"PLSQL_SUBPROGRAM_ID" NUMBER, 
	"MODULE" VARCHAR2(64 BYTE), 
	"ACTION" VARCHAR2(64 BYTE), 
	"ROW_WAIT_OBJ#" NUMBER, 
	"ROW_WAIT_FILE#" NUMBER, 
	"ROW_WAIT_BLOCK#" NUMBER, 
	"TOP_LEVEL_CALL#" NUMBER, 
	"CLIENT_IDENTIFIER" VARCHAR2(64 BYTE), 
	"BLOCKING_SESSION_STATUS" VARCHAR2(11 BYTE), 
	"BLOCKING_SESSION" NUMBER, 
	"SEQ#" NUMBER, 
	"EVENT#" NUMBER, 
	"EVENT" VARCHAR2(64 BYTE), 
	"P1TEXT" VARCHAR2(64 BYTE), 
	"P1" NUMBER, 
	"P2TEXT" VARCHAR2(64 BYTE), 
	"P2" NUMBER, 
	"P3TEXT" VARCHAR2(64 BYTE), 
	"P3" NUMBER, 
	"WAIT_CLASS_ID" NUMBER, 
	"WAIT_CLASS" VARCHAR2(64 BYTE), 
	"WAIT_TIME" NUMBER, 
	"SECONDS_IN_WAIT" NUMBER, 
	"STATE" VARCHAR2(19 BYTE), 
	"ECID" VARCHAR2(64 BYTE), 
	"XID" RAW(8), 
	"SQL_PLAN_HASH_VALUE" NUMBER, 
	"FORCE_MATCHING_SIGNATURE" NUMBER, 
	"SERVICE_HASH" NUMBER, 
	"EVENT_ID" NUMBER, 
	"SQL_OPNAME" VARCHAR2(64 BYTE), 
	"INST_ID" NUMBER
   ) TABLESPACE &&default_tablespace ;

CREATE TABLE "BASH"."BASH$LOG_INTERNAL" 
   (	"LOG_MESSAGE" VARCHAR2(2000 BYTE), 
	"LOG_DATE" TIMESTAMP (3) NOT NULL, 
	"LOG_ID" NUMBER(38,0) NOT NULL
   )   TABLESPACE &&default_tablespace ;


CREATE TABLE "BASH"."BASH$SETTINGS" 
   (	
    updated_ts                            TIMESTAMP,
    version                               NUMBER,
    sample_every_n_centiseconds           NUMBER,
    persist_every_n_samples               NUMBER,
    cleanup_every_n_samples               NUMBER,
	checkfnewinst_every_n_samples         NUMBER,
    max_entries_kept                      NUMBER,
    logging_enabled                       NUMBER,
    keep_log_entries_n_days               NUMBER,
	HIST_DAYS_TO_KEEP                     NUMBER
    ) 
  TABLESPACE &&default_tablespace;
  
INSERT INTO "BASH"."BASH$SETTINGS"   
   (	
    updated_ts,
	version,
	sample_every_n_centiseconds,
    persist_every_n_samples,
    cleanup_every_n_samples,
	checkfnewinst_every_n_samples,
    max_entries_kept,
    logging_enabled,
    keep_log_entries_n_days,
	HIST_DAYS_TO_KEEP
    ) 
    VALUES
    (
    systimestamp,
	9,
	100,
    10,
    100,
	60,
    30000,
    0,
    1,
	93
    );
    
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
prompt ... Installing indexes
   

CREATE INDEX "BASH"."IDX_BSI_SAMPLE_TIME_INSTID" ON "BASH"."BASH$SESSION_INTERNAL" ("SAMPLE_TIME", "INST_ID")  TABLESPACE &&default_tablespace;
CREATE INDEX "BASH"."IDX_BSI_SAMPLE_ID_INSTID"   ON "BASH"."BASH$SESSION_INTERNAL" ("SAMPLE_ID", "INST_ID") TABLESPACE &&default_tablespace;

CREATE INDEX "BASH"."IDX_SHI_SAMPLE_TIME_INSTID" ON "BASH"."BASH$SESSION_HIST_INTERNAL" ("SAMPLE_TIME", "INST_ID") TABLESPACE &&default_tablespace;
CREATE INDEX "BASH"."IDX_SHI_SAMPLE_ID_INSTID"   ON "BASH"."BASH$SESSION_HIST_INTERNAL" ("SAMPLE_ID", "INST_ID")  TABLESPACE &&default_tablespace;

CREATE INDEX "BASH"."IDX_LOG_LOG_DATE" ON "BASH"."BASH$LOG_INTERNAL" ("LOG_DATE") TABLESPACE &&default_tablespace;
CREATE INDEX "BASH"."IDX_LOG_LOG_ID"   ON "BASH"."BASH$LOG_INTERNAL" ("LOG_ID") TABLESPACE &&default_tablespace;



prompt
prompt
prompt ... Installing views

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
         


CREATE  FORCE VIEW "BASH"."VTABSESSIONS" ("SAMPLE_ID", "SAMPLE_TIME", "INSTANCE_NUMBER", "SESSION_ID", "SESSION_SERIAL#", "USER_ID", "USERNAME", "SQL_OPCODE", "SQL_OPNAME", "OSUSER", "MACHINE", "PORT", "TERMINAL", "PROGRAM", "SESSION_TYPE", "SQL_ID", "SQL_CHILD_NUMBER", "SQL_EXEC_START", "SQL_EXEC_ID", "PLSQL_ENTRY_OBJECT_ID", "PLSQL_ENTRY_SUBPROGRAM_ID", "PLSQL_OBJECT_ID", "PLSQL_SUBPROGRAM_ID", "MODULE", "ACTION", "CURRENT_OBJ#", "CURRENT_FILE#", "CURRENT_BLOCK#", "TOP_LEVEL_CALL#", "CLIENT_ID", "BLOCKING_SESSION_STATUS", "BLOCKING_SESSION", "SEQ#", "EVENT#", "EVENT", "P1TEXT", "P1", "P2TEXT", "P2", "P3TEXT", "P3", "WAIT_CLASS_ID", "WAIT_CLASS", "WAIT_TIME", "TIME_WAITED", "SESSION_STATE", "ECID", "SQL_PLAN_HASH_VALUE", "FORCE_MATCHING_SIGNATURE", "SERVICE_HASH", "QC_SESSION_ID", "QC_INSTANCE_ID", "BLOCKING_SESSION_SERIAL#", "EVENT_ID", "XID", "FLAGS", "BLOCKING_HANGCHAIN_INFO", "BLOCKING_INST_ID", "CAPTURE_OVERHEAD", "CONSUMER_GROUP_ID", "CURRENT_ROW#", "DBREPLAY_CALL_COUNTER", "DBREPLAY_FILE_ID", "DELTA_INTERCONNECT_IO_BYTES", "DELTA_READ_IO_BYTES", "DELTA_READ_IO_REQUESTS", "DELTA_TIME", "DELTA_WRITE_IO_BYTES", "DELTA_WRITE_IO_REQUESTS", "IN_BIND", "IN_CONNECTION_MGMT", "IN_CURSOR_CLOSE", "IN_HARD_PARSE", "IN_JAVA_EXECUTION", "IN_PARSE", "IN_PLSQL_COMPILATION", "IN_PLSQL_EXECUTION", "IN_PLSQL_RPC", "IN_SEQUENCE_LOAD", "IN_SQL_EXECUTION", "IS_AWR_SAMPLE", "IS_CAPTURED", "IS_REPLAYED", "IS_SQLID_CURRENT", "PGA_ALLOCATED", "PX_FLAGS", "QC_SESSION_SERIAL#", "REMOTE_INSTANCE#", "REPLAY_OVERHEAD", "SQL_PLAN_LINE_ID", "SQL_PLAN_OPERATION", "SQL_PLAN_OPTIONS", "TEMP_SPACE_ALLOCATED", "TIME_MODEL", "TM_DELTA_CPU_TIME", "TM_DELTA_DB_TIME", "TM_DELTA_TIME", "TOP_LEVEL_CALL_NAME", "TOP_LEVEL_SQL_ID", "TOP_LEVEL_SQL_OPCODE") AS 
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
    decode(STATE,'WAITING','WAITING','ON CPU') session_state,
    "ECID",
    sql_plan_hash_value sql_plan_hash_value,
    force_matching_signature force_matching_signature,
    "SERVICE_HASH" service_hash,
    to_number(NULL) qc_session_id,            --10.2 ASH Column not supported in BASH
    to_number(0) qc_instance_id,              --10.2 ASH Column not supported in BASH
    TO_NUMBER(NULL) blocking_session_serial#, --10.2 ASH Column not supported in BASH
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
  FROM BASH$SESSION_INTERNAL
  WHERE inst_id = USERENV('Instance');
  
  
CREATE  FORCE VIEW "BASH"."VTABSESSIONSHIST" ("SAMPLE_ID", "SAMPLE_TIME", "INSTANCE_NUMBER", "SESSION_ID", "SESSION_SERIAL#", "USER_ID", "USERNAME", "SQL_OPCODE", "SQL_OPNAME", "OSUSER", "MACHINE", "PORT", "TERMINAL", "PROGRAM", "SESSION_TYPE", "SQL_ID", "SQL_CHILD_NUMBER", "SQL_EXEC_START", "SQL_EXEC_ID", "PLSQL_ENTRY_OBJECT_ID", "PLSQL_ENTRY_SUBPROGRAM_ID", "PLSQL_OBJECT_ID", "PLSQL_SUBPROGRAM_ID", "MODULE", "ACTION", "CURRENT_OBJ#", "CURRENT_FILE#", "CURRENT_BLOCK#", "TOP_LEVEL_CALL#", "CLIENT_ID", "BLOCKING_SESSION_STATUS", "BLOCKING_SESSION", "SEQ#", "EVENT#", "EVENT", "P1TEXT", "P1", "P2TEXT", "P2", "P3TEXT", "P3", "WAIT_CLASS_ID", "WAIT_CLASS", "WAIT_TIME", "TIME_WAITED", "SESSION_STATE", "ECID", "SQL_PLAN_HASH_VALUE", "FORCE_MATCHING_SIGNATURE", "SERVICE_HASH", "QC_SESSION_ID", "QC_INSTANCE_ID", "BLOCKING_SESSION_SERIAL#", "EVENT_ID", "XID", "FLAGS", "BLOCKING_HANGCHAIN_INFO", "BLOCKING_INST_ID", "CAPTURE_OVERHEAD", "CONSUMER_GROUP_ID", "CURRENT_ROW#", "DBREPLAY_CALL_COUNTER", "DBREPLAY_FILE_ID", "DELTA_INTERCONNECT_IO_BYTES", "DELTA_READ_IO_BYTES", "DELTA_READ_IO_REQUESTS", "DELTA_TIME", "DELTA_WRITE_IO_BYTES", "DELTA_WRITE_IO_REQUESTS", "IN_BIND", "IN_CONNECTION_MGMT", "IN_CURSOR_CLOSE", "IN_HARD_PARSE", "IN_JAVA_EXECUTION", "IN_PARSE", "IN_PLSQL_COMPILATION", "IN_PLSQL_EXECUTION", "IN_PLSQL_RPC", "IN_SEQUENCE_LOAD", "IN_SQL_EXECUTION", "IS_AWR_SAMPLE", "IS_CAPTURED", "IS_REPLAYED", "IS_SQLID_CURRENT", "PGA_ALLOCATED", "PX_FLAGS", "QC_SESSION_SERIAL#", "REMOTE_INSTANCE#", "REPLAY_OVERHEAD", "SQL_PLAN_LINE_ID", "SQL_PLAN_OPERATION", "SQL_PLAN_OPTIONS", "TEMP_SPACE_ALLOCATED", "TIME_MODEL", "TM_DELTA_CPU_TIME", "TM_DELTA_DB_TIME", "TM_DELTA_TIME", "TOP_LEVEL_CALL_NAME", "TOP_LEVEL_SQL_ID", "TOP_LEVEL_SQL_OPCODE") AS 
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
    decode(STATE,'WAITING','WAITING','ON CPU') session_state,
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
  
CREATE  FORCE VIEW "BASH"."GVTABSESSIONSHIST" ("SAMPLE_ID", "SAMPLE_TIME", "INSTANCE_NUMBER", "SESSION_ID", "SESSION_SERIAL#", "USER_ID", "USERNAME", "SQL_OPCODE", "SQL_OPNAME", "OSUSER", "MACHINE", "PORT", "TERMINAL", "PROGRAM", "SESSION_TYPE", "SQL_ID", "SQL_CHILD_NUMBER", "SQL_EXEC_START", "SQL_EXEC_ID", "PLSQL_ENTRY_OBJECT_ID", "PLSQL_ENTRY_SUBPROGRAM_ID", "PLSQL_OBJECT_ID", "PLSQL_SUBPROGRAM_ID", "MODULE", "ACTION", "CURRENT_OBJ#", "CURRENT_FILE#", "CURRENT_BLOCK#", "TOP_LEVEL_CALL#", "CLIENT_ID", "BLOCKING_SESSION_STATUS", "BLOCKING_SESSION", "SEQ#", "EVENT#", "EVENT", "P1TEXT", "P1", "P2TEXT", "P2", "P3TEXT", "P3", "WAIT_CLASS_ID", "WAIT_CLASS", "WAIT_TIME", "TIME_WAITED", "SESSION_STATE", "ECID", "SQL_PLAN_HASH_VALUE", "FORCE_MATCHING_SIGNATURE", "SERVICE_HASH", "QC_SESSION_ID", "QC_INSTANCE_ID", "BLOCKING_SESSION_SERIAL#", "EVENT_ID", "XID", "FLAGS", "BLOCKING_HANGCHAIN_INFO", "BLOCKING_INST_ID", "CAPTURE_OVERHEAD", "CONSUMER_GROUP_ID", "CURRENT_ROW#", "DBREPLAY_CALL_COUNTER", "DBREPLAY_FILE_ID", "DELTA_INTERCONNECT_IO_BYTES", "DELTA_READ_IO_BYTES", "DELTA_READ_IO_REQUESTS", "DELTA_TIME", "DELTA_WRITE_IO_BYTES", "DELTA_WRITE_IO_REQUESTS", "IN_BIND", "IN_CONNECTION_MGMT", "IN_CURSOR_CLOSE", "IN_HARD_PARSE", "IN_JAVA_EXECUTION", "IN_PARSE", "IN_PLSQL_COMPILATION", "IN_PLSQL_EXECUTION", "IN_PLSQL_RPC", "IN_SEQUENCE_LOAD", "IN_SQL_EXECUTION", "IS_AWR_SAMPLE", "IS_CAPTURED", "IS_REPLAYED", "IS_SQLID_CURRENT", "PGA_ALLOCATED", "PX_FLAGS", "QC_SESSION_SERIAL#", "REMOTE_INSTANCE#", "REPLAY_OVERHEAD", "SQL_PLAN_LINE_ID", "SQL_PLAN_OPERATION", "SQL_PLAN_OPTIONS", "TEMP_SPACE_ALLOCATED", "TIME_MODEL", "TM_DELTA_CPU_TIME", "TM_DELTA_DB_TIME", "TM_DELTA_TIME", "TOP_LEVEL_CALL_NAME", "TOP_LEVEL_SQL_ID", "TOP_LEVEL_SQL_OPCODE") AS 
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
  
CREATE  FORCE VIEW "BASH"."GVTABSESSIONS" ("SAMPLE_ID", "SAMPLE_TIME", "INST_ID", "SESSION_ID", "SESSION_SERIAL#", "USER_ID", "USERNAME", "SQL_OPCODE", "SQL_OPNAME", "OSUSER", "MACHINE", "PORT", "TERMINAL", "PROGRAM", "SESSION_TYPE", "SQL_ID", "SQL_CHILD_NUMBER", "SQL_EXEC_START", "SQL_EXEC_ID", "PLSQL_ENTRY_OBJECT_ID", "PLSQL_ENTRY_SUBPROGRAM_ID", "PLSQL_OBJECT_ID", "PLSQL_SUBPROGRAM_ID", "MODULE", "ACTION", "CURRENT_OBJ#", "CURRENT_FILE#", "CURRENT_BLOCK#", "TOP_LEVEL_CALL#", "CLIENT_ID", "BLOCKING_SESSION_STATUS", "BLOCKING_SESSION", "SEQ#", "EVENT#", "EVENT", "P1TEXT", "P1", "P2TEXT", "P2", "P3TEXT", "P3", "WAIT_CLASS_ID", "WAIT_CLASS", "WAIT_TIME", "TIME_WAITED", "SESSION_STATE", "ECID", "SQL_PLAN_HASH_VALUE", "FORCE_MATCHING_SIGNATURE", "SERVICE_HASH", "QC_SESSION_ID", "QC_INSTANCE_ID", "BLOCKING_SESSION_SERIAL#", "EVENT_ID", "XID", "FLAGS", "BLOCKING_HANGCHAIN_INFO", "BLOCKING_INST_ID", "CAPTURE_OVERHEAD", "CONSUMER_GROUP_ID", "CURRENT_ROW#", "DBREPLAY_CALL_COUNTER", "DBREPLAY_FILE_ID", "DELTA_INTERCONNECT_IO_BYTES", "DELTA_READ_IO_BYTES", "DELTA_READ_IO_REQUESTS", "DELTA_TIME", "DELTA_WRITE_IO_BYTES", "DELTA_WRITE_IO_REQUESTS", "IN_BIND", "IN_CONNECTION_MGMT", "IN_CURSOR_CLOSE", "IN_HARD_PARSE", "IN_JAVA_EXECUTION", "IN_PARSE", "IN_PLSQL_COMPILATION", "IN_PLSQL_EXECUTION", "IN_PLSQL_RPC", "IN_SEQUENCE_LOAD", "IN_SQL_EXECUTION", "IS_AWR_SAMPLE", "IS_CAPTURED", "IS_REPLAYED", "IS_SQLID_CURRENT", "PGA_ALLOCATED", "PX_FLAGS", "QC_SESSION_SERIAL#", "REMOTE_INSTANCE#", "REPLAY_OVERHEAD", "SQL_PLAN_LINE_ID", "SQL_PLAN_OPERATION", "SQL_PLAN_OPTIONS", "TEMP_SPACE_ALLOCATED", "TIME_MODEL", "TM_DELTA_CPU_TIME", "TM_DELTA_DB_TIME", "TM_DELTA_TIME", "TOP_LEVEL_CALL_NAME", "TOP_LEVEL_SQL_ID", "TOP_LEVEL_SQL_OPCODE") AS 
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
    decode(STATE,'WAITING','WAITING','ON CPU') session_state,
    "ECID",
    sql_plan_hash_value sql_plan_hash_value,
    force_matching_signature force_matching_signature,
    "SERVICE_HASH" service_hash,
    to_number(NULL) qc_session_id,            --10.2 ASH Column not supported in BASH
    to_number(0) qc_instance_id,              --10.2 ASH Column not supported in BASH
    TO_NUMBER(NULL) blocking_session_serial#, --10.2 ASH Column not supported in BASH
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
  FROM BASH$SESSION_INTERNAL;

  
PROMPT 
PROMPT ... Creating functions

CREATE OR REPLACE FUNCTION "BASH"."GET_TS_ID" return NUMBER is
  l_ts_id number;
begin
  SELECT ( (to_date(to_char(systimestamp AT TIME ZONE 'UTC','DD-MM-YYYY HH24:MI:SS'),'DD-MM-YYYY HH24:MI:SS')) - TO_DATE('01-01-1999 00:00:00', 'DD-MM-YYYY HH24:MI:SS')) *24 * 60 * 60 into l_ts_id FROM DUAL;
  return l_ts_id;
end;
/
 
  
prompt
prompt
prompt ... Installing packages   
   
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
    select NVL(max(SAMPLE_id),GET_TS_ID-1) into g_last_snapshot_persisted from bash.bash$session_internal where INST_ID=g_own_inst_id;
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
	 select NVL(max(SAMPLE_id),GET_TS_ID-1) into g_last_snapshot_persisted from bash.BASH$SESSION_HIST_INTERNAL where INST_ID=g_own_inst_id;	 
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


prompt
prompt
prompt ... Installing public synonyms

CREATE OR REPLACE PUBLIC SYNONYM "BASH$LOG" FOR "BASH"."BASH$LOG_INTERNAL";
CREATE OR REPLACE PUBLIC SYNONYM "BASH$ACTIVE_SESSION_HISTORY" FOR "BASH"."VTABSESSIONS";
CREATE OR REPLACE PUBLIC SYNONYM "BASH$HIST_ACTIVE_SESS_HISTORY" FOR "BASH"."VTABSESSIONSHIST";
CREATE OR REPLACE PUBLIC SYNONYM "BASHG$ACTIVE_SESSION_HISTORY" FOR "BASH"."GVTABSESSIONS";
CREATE OR REPLACE PUBLIC SYNONYM "BASHG$HIST_ACTIVE_SESS_HISTORY" FOR "BASH"."GVTABSESSIONSHIST";



PROMPT 
PROMPT ... Recompiling BASH schema


begin
UTL_RECOMP.RECOMP_SERIAL (schema=>'BASH');
end;
/


UPDATE  BASH.BASH$SETTINGS set VERSION=9;
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



prompt
prompt ... Creating nightly purge job for historic data
prompt

begin
dbms_scheduler.create_job( job_name=>'BASH.BASH_PURGE_SCHEDULER_JOB', job_type=>'PLSQL_BLOCK', job_action => 'BASH.PURGE();', repeat_interval => 'FREQ=DAILY; BYHOUR=3; BYMINUTE=33', enabled=>TRUE, comments=>'Purges the historic BASH data');
end;
/

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


prompt
prompt
prompt *** Successfully installed BASH. ****
prompt
prompt

exit
