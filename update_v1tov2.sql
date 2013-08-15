
begin
bash.bash.stop();
end;

ALTER TABLE 
   "BASH"."BASH$SESSION_INTERNAL" 
MODIFY 
   ( 
   "SAMPLE_ID" NUMBER not null, 
   "SAMPLE_TIME" TIMESTAMP (3) not null
   )
;


ALTER TABLE 
   "BASH"."BASH$SESSION_HIST_INTERNAL" 
MODIFY 
   ( 
   "SAMPLE_ID" NUMBER not null, 
   "SAMPLE_TIME" TIMESTAMP (3) not null
   )
;

ALTER TABLE  "BASH"."BASH$LOG_INTERNAL"
modify 
   ( 
	"LOG_DATE" TIMESTAMP (3) not null, 
	"LOG_ID" NUMBER(38,0) not null
  );


begin
UTL_RECOMP.RECOMP_SERIAL (schema=>'BASH');
end;

begin
bash.bash.run();
end;
