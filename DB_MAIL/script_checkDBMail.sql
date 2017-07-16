-- ==================================================================================================================================================================================================
-- Script Name:	script_checkDBMail.sql
-- Author:		Jose A. Ramirez
-- Create date:		JAN-30-2017
-- Description:		This script allows you to check DBMail status, start or reset if necessary.
--
-- Change History:	JAN-30-2017 - Original Scrip created
--					

-- Disclaimer:	The script is provided as-is with no guarantees expressed nor implied.  Always test the code in a dev or sandbox environment.
-- Resource: -- https://technet.microsoft.com/en-us/library/ms187540(v=sql.105).aspx
-- ==================================================================================================================================================================================================

declare @reset bit, @start bit, @mail_status nvarchar(50);
set @reset = 0;
set @start = 0;

exec sp_configure 'show advanced options', 1;
RECONFIGURE with override;
exec sp_configure 'Database Mail XPs'

EXEC msdb.sys.sp_helprolemember 'DatabaseMailUserRole';
EXEC msdb.sys.sp_helprolemember 'db_owner';

EXEC msdb.dbo.sysmail_help_principalprofile_sp;
-- select * from msdb..sysmail_help_queue_sp @queue_type = 'Mail' ;

-- Only perform one task (reset or start)
if @reset = 1 set @start = 0;

-- To confirm that the Database Mail is started
if object_id('tempdb..#mail_status') is not null drop table #mail_status;
create table #mail_status ([status] nvarchar(50))

insert into #mail_status
	EXEC msdb.dbo.sysmail_help_status_sp;

select [Message]='DBMail Status is: ' + status from #mail_status;

if @start = 1 and not exists (select * from #mail_status where [status]='STARTED')
	EXEC msdb.dbo.sysmail_start_sp;


-- to reset 
if @reset = 1
begin
	EXEC msdb.dbo.sysmail_stop_sp; 
	waitfor delay '00:00:05';
	EXEC msdb.dbo.sysmail_start_sp;
end

EXEC msdb.dbo.sysmail_help_queue_sp @queue_type = 'mail';

-- To determine if problems with Database Mail affect all accounts in a profile or only some accounts
SELECT send_request_user, sent_date, sent_status, send_request_date, recipients, [subject], body FROM msdb.dbo.sysmail_sentitems order by sent_date desc;
SELECT * FROM msdb.dbo.sysmail_event_log order by log_date desc;

if object_id('tempdb..#mail_status') is not null drop table #mail_status;
