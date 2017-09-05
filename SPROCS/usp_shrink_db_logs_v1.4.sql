use master;
GO

-- NOTE: This script also creates a job to schedule the execution of this procedure... 
--		@DBName parameter is set to NONE, so no database will be modified unless the parameter is changed on the job section.
--		remove the job section if necessary.

declare @update_sqljob bit;
set @update_sqljob = 1;

if object_id('tempdb..##resetjob') is not null drop table ##resetjob;
select [resetjob] = case when @update_sqljob = 1 then 1 else 0 end into ##resetjob;

if object_id('dbo.usp_shrink_db_logs') is not null drop procedure dbo.usp_shrink_db_logs;
go

-- ============================================================================================================
-- Script Name:	usp_shrink_db_logs
-- Author:		Jose A. Ramirez
-- Create date:	2016-02-15
-- Description:	This stored procedure can work in two specific ways:
		--			1- debug mode: provides a list of all databases and corresponding files 
		--				that meet the specified criteria... useful if you want to check what 
		--				is aobut to be changed before it changes.
		--			   debug mode: can also be used as a report.
		--
		--			2- running mode: will make changes based on the parameters.

--	NOTE:	***	This procedure was originally intended to shink only logs, but later modified to also include 
--					data files by means of identifying them through their groupid.
--				Stored Procedure defaults are set to look for log files.

-- WARNING -------------
--				This procedure was designed with the intent to free up a transaction log
--					that is growing out of control, hence the setting to also change the database
--					recovery model.
--				If you decide to change the recovery model, please note you will lose your log-chain.
--					To restore your log-chain, you will need to:
--					1- switch back to full recovery
--					2- perform a full backup

-- *** Procedure is provided as-is, with no warranties expressed nor implied.  Please always test on a DEV or SANDBOX environment first. 

/* Usage:		
				exec [dbo].[usp_shrink_db_logs] @db_name 			= '%', 			-- varchar(200)
												@search_db_recovery = '%', 			-- varchar(25)
												@set_db_recovery 	= 'SIMPLE', 	-- varchar(25)
												@switch_recovery 	= 0,			-- bit
												@search_logsize_s 	= 1000.0, 		-- decimal(16,2)  == > search size (start)
												@search_logsize_e 	= 999999999.0, 	-- decimal(16,2)  == > search size (end)
												@set_logsize 		= 0, 			-- int
												@growth_size 		= '100MB',		-- varchar(50)
												@groupid 			= 0,			-- smallint
												@debug 				= 0;			-- bit

========================================================================================= */

/* 
   Change History:  2016-02-15  Created script
					2017-05-17	Added @groupid ==>> data file groupid:  0 = logs, 1 = data (primary), >1 = user defined file group, -1 = "ALL"
*/

-- ============================================================================================================

create procedure dbo.usp_shrink_db_logs (@db_name varchar(200) = '%', @search_db_recovery varchar(25) = '%', @set_db_recovery varchar(25) = 'SIMPLE', @switch_recovery bit = 0, @search_logsize_s decimal(16,2) = 1000.0, @search_logsize_e decimal(16,2) = 999999999.0, @set_logsize int = 0, @growth_size varchar(50) = '100MB', @groupid smallint = 0, @debug bit = 0) with encryption
as

-- //////////////////////////   Set Autogrowth to 100MB for all DB Files   //////////////////////////   --
SET NOCOUNT ON;
declare @DBName varchar(200), @tsql nvarchar(4000), @tsql_dbrec nvarchar(max), @tsql_shrink nvarchar(max), @db_recovery varchar(150);

declare dbcur cursor fast_forward for   
	select db.name from master.sys.databases db where (db.name like @db_name and db.database_id > 4 and db.is_distributor = 0
																			and DATABASEPROPERTYEX (db.name,'Updateability')='READ_WRITE'
																			and DATABASEPROPERTYEX(db.name, 'UserAccess') = 'MULTI_USER'
																			and DATABASEPROPERTYEX(db.name, 'Status') = 'ONLINE')
																			or (db.name = @db_name and @db_name = 'tempdb') 
																order by name;

if object_id('tempdb..#filegwth') is not null drop table #filegwth
create table #filegwth (DBName varchar(200), ctsql nvarchar(4000))

if object_id('tempdb..#shrinkfile') is not null drop table #shrinkfile
create table #shrinkfile (DBName varchar(200), ctsql nvarchar(4000))

if OBJECT_ID('tempdb..#logspace') is not null drop table #logspace;
create table #logspace
	(DBName				sysname
	,[LogSize(MB)]		decimal(20,8)
	,[LoSpaceUsed(%)]	decimal(20,8)
	,[Status]			int)

insert into #logspace (DBName, [LogSize(MB)], [LoSpaceUsed(%)], [Status])
EXEC('DBCC SQLPERF(logspace);');

if @debug = 1 
begin
	select DBName, [LogSize(MB)], [LoSpaceUsed(%)], [Status] from #logspace;
	select db.name, [Updateability] = DATABASEPROPERTYEX (db.name,'Updateability'), [RECOVERY] = DATABASEPROPERTYEX (db.name,'RECOVERY') from master..sysdatabases db where DATABASEPROPERTYEX (db.name,'Updateability')='READ_WRITE' order by name;
end

open dbcur
fetch next from dbcur into @DBName

while @@fetch_status = 0 
begin
	set @tsql = 'USE [' + @DBName + ']; select [DBName]='''+ @DBName+''', [TSQL]=''ALTER DATABASE [' + @DBName + '] MODIFY FILE ( NAME = N'''''' + name + '''''', FILEGROWTH = ' + @growth_size + ' )'' from sysfiles where growth < 128000'
	
	set @db_recovery = convert(varchar(150), DATABASEPROPERTYEX(@DBName, 'Recovery'))	
	if @DBName not in ('master','model','msdb')
	begin
		if @db_recovery like @search_db_recovery and @db_recovery <> @set_db_recovery and @switch_recovery = 1
		begin
			set @tsql_dbrec = 'ALTER DATABASE [' + @DBName + '] SET RECOVERY ' + @set_db_recovery + ' WITH NO_WAIT;';
			print case when @debug = 1 then '[DEBUG]::: ' else '' end + 'EXECUTING: [[ ' + @tsql_dbrec + ' ]]';
			if @debug = 0 exec(@tsql_dbrec);
		end

		if exists (select * from #logspace where DBName = @DBName and [LogSize(MB)] between @search_logsize_s and @search_logsize_e)
		begin
			set @tsql_shrink = 'USE [' + @DBName + ']; select [DBName]='''+ @DBName+''', [TSQL]=''USE [' + @DBName + ']; CHECKPOINT; DBCC SHRINKFILE (N'''''' + name + '''''', ' + convert(varchar, @set_logsize) + ')'' from sysfiles ' + case when @groupid = -1 then '' 
																																																												when @groupid >= 0 then 'where groupid = ''' + convert(varchar, @groupid) + ''''
																																																												else 'where groupid = 0'
																																																											end
		
			insert into #shrinkfile (DBName, ctsql) -- values (@DBName, @tsql)
			exec(@tsql_shrink)
			print case when @debug = 1 then '[DEBUG]::: ' else '' end + 'EXECUTING: [[ ' + @tsql_shrink + ' ]]';

			insert into #filegwth (DBName, ctsql) -- values (@DBName, @tsql)
			exec(@tsql)
			print case when @debug = 1 then '[DEBUG]::: ' else '' end + 'EXECUTING: [[ ' + @tsql + ' ]]';
		end
		else set @tsql_shrink = ''

	end

	if @debug = 1 print @tsql 
	fetch next from dbcur into @DBName
end

-- reset variables
select @DBName='', @tsql='', @tsql_shrink = '', @tsql_dbrec = '';

declare filegwthcur cursor fast_forward for 
	select DBName, ctsql from #filegwth;

open filegwthcur  
fetch next from filegwthcur into @DBName, @tsql

while @@fetch_status = 0
begin
	print 'Processing Database: [[ ' + @DBName + ' ]] --> Setting File Growth';
	
	if @debug = 1 print @tsql else exec(@tsql);

	fetch next from filegwthcur into @DBName, @tsql;
end

-- SHRINK LOG FILES 
declare shrinkfiles cursor fast_forward for select s.DBName, s.ctsql from #shrinkfile s inner join #logspace l on l.DBName = s.DBName where l.[LogSize(MB)] between @search_logsize_s and @search_logsize_e;

open shrinkfiles  
fetch next from shrinkfiles into @DBName, @tsql

while @@fetch_status = 0
begin
	print 'Shrinking files for Database: ' + @DBName;
	
	if @debug = 1 print @tsql else exec(@tsql);

	fetch next from shrinkfiles into @DBName, @tsql;
end

cleanup:
close dbcur;
close filegwthcur; 
close shrinkfiles;
deallocate dbcur;
deallocate filegwthcur;
deallocate shrinkfiles;

if object_id('tempdb..#filegwth') is not null drop table #filegwth;
if object_id('tempdb..#shrinkfile') is not null drop table #shrinkfile;
if OBJECT_ID('tempdb..#logspace') is not null drop table #logspace;
GO

/******************************************************************************************************************************************************************
-- ****************************************************  CREATE SQL Agent Job: "DBA: Shrink DB Log Files" ****************************************************** --
******************************************************************************************************************************************************************/
if exists (select * from ##resetjob where [resetjob] = 1)
begin
	USE [msdb]
	print 'resetting the sql agent job... deleting the job now... [DBA: Shrink DB Log Files]';
	if exists (select * from msdb..sysjobs where name = 'DBA: Shrink DB Log Files')
	begin
		exec sp_delete_job @job_name = 'DBA: Shrink DB Log Files', @delete_history = 0, @delete_unused_schedule = 1;
		print 'deleted the job... [DBA: Shrink DB Log Files]';
	end
	print 're-creating the sql agent job now... [DBA: Shrink DB Log Files]';
	DECLARE @jobId BINARY(16)
	EXEC  msdb.dbo.sp_add_job @job_name=N'DBA: Shrink DB Log Files', 
			@enabled=1, 
			@notify_level_eventlog=0, 
			@notify_level_email=2, 
			@notify_level_netsend=2, 
			@notify_level_page=2, 
			@delete_level=0, 
			@category_name=N'[Uncategorized (Local)]', 
			@owner_login_name=N'sa', @job_id = @jobId OUTPUT
	select @jobId
	EXEC msdb.dbo.sp_add_jobserver @job_name=N'DBA: Shrink DB Log Files'	
	EXEC msdb.dbo.sp_add_jobstep @job_name=N'DBA: Shrink DB Log Files', @step_name=N'Shrink DB Log Files', 
			@step_id=1, 
			@cmdexec_success_code=0, 
			@on_success_action=1, 
			@on_fail_action=2, 
			@retry_attempts=0, 
			@retry_interval=0, 
			@os_run_priority=0, @subsystem=N'TSQL', 
			@command=N'exec dbo.usp_shrink_db_logs @db_name = ''NONE'', @search_db_recovery = ''%'', @set_db_recovery = ''SIMPLE'', @switch_recovery = 0, @search_logsize_s = 2000.0, @search_logsize_e = 999999999.0, @set_logsize = 1000, @growth_size = ''1000MB'', @debug = 0;', 
			@database_name=N'master', 
			@flags=0
	EXEC msdb.dbo.sp_update_job @job_name=N'DBA: Shrink DB Log Files', 
			@enabled=1, 
			@start_step_id=1, 
			@notify_level_eventlog=0, 
			@notify_level_email=2, 
			@notify_level_netsend=2, 
			@notify_level_page=2, 
			@delete_level=0, 
			@description=N'', 
			@category_name=N'[Uncategorized (Local)]', 
			@owner_login_name=N'sa', 
			@notify_email_operator_name=N'', 
			@notify_netsend_operator_name=N'', 
			@notify_page_operator_name=N''
	DECLARE @schedule_id int
	EXEC msdb.dbo.sp_add_jobschedule @job_name=N'DBA: Shrink DB Log Files', @name=N'Shrink DB Log File ', 
			@enabled=1, 
			@freq_type=4, 
			@freq_interval=1, 
			@freq_subday_type=8, 
			@freq_subday_interval=6, 
			@freq_relative_interval=0, 
			@freq_recurrence_factor=1, 
			@active_start_date=20170316, 
			@active_end_date=99991231, 
			@active_start_time=0, 
			@active_end_time=235959, @schedule_id = @schedule_id OUTPUT
	select @schedule_id
end
else print 'we are not resetting or re-creating the sql agent job: DBA: "Shrink DB Log Files"'
GO

if object_id('tempdb..##resetjob') is not null drop table ##resetjob;