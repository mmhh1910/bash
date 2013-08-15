------------------------------------------------------------------------------------
--
-- Name:          bashdrop.sql - BASH Deinstallation script. Must be run as user sys.
--
-- Author:        Marcus Monnig
-- Copyright:     (c) 2012, 2013 Marcus Monnig - All rights reserved.
--
-- Check http://marcusmonnig.wordpress.com/bash/ for new versions.
--
-- Disclaimer:    No guarantees. Use at your own risk. 
--
------------------------------------------------------------------------------------


set echo off verify off showmode off feedback off;
whenever sqlerror exit sql.sqlcode


prompt
prompt This script drops the BASH schema and all public synonyms pointing to BASH objects.
prompt ------------------------------------  

prompt Are you sure you want to drop the BASH schema? [Y,N]
prompt
prompt &&answer

begin
  if ('&&answer'<>'Y') or ('&&answer' is null) then
    raise_application_error(-20101, 'Uninstall terminated');
  end if;
end;
/

BEGIN
BASH.BASH.STOP;
DBMS_LOCK.SLEEP (5);
END;
/

drop user bash cascade;
drop public synonym BASH$ACTIVE_SESSION_HISTORY;
drop public synonym BASH$HIST_ACTIVE_SESS_HISTORY;
drop public synonym BASH$LOG;
drop PUBLIC SYNONYM "BASHG$ACTIVE_SESSION_HISTORY";
drop PUBLIC SYNONYM "BASHG$HIST_ACTIVE_SESS_HISTORY";


prompt
prompt
prompt *** Successfully uninstalled BASH. ****
prompt
prompt

exit
