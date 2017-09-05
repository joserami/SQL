-- ============================================================================================================
-- Script Name:	script_check_fileUsage_logWaits.sql
-- Author:		Jose A. Ramirez
-- Create date:	2013-08-15
-- Description:	This script analyzes which files are currently in use by database, and provides log usage information.
--					Log usage information incldues: 
--						1- Log file size (MB)
--						2- LoSpaceUsed(%)
--						3- log_reuse_wait_desc

-- *** Script is provided as-is, with no warranties expressed nor implied.  Please always test on a DEV or SANDBOX environment first. 

/* Usage:		
				There are only two variables here:
				1- @DBName
				2- @sortby		-- 1 = DBName, 2 = Log Size

========================================================================================= */

/* 
   Change History:  22013-08-15  Created script
					
*/
-- ============================================================================================================


declare @dbname varchar(124), @sortby int
set @dbname = '%'	-- whole name or partial, or 'All'
set @sortby = 2;	-- 1 = DBName, 2 = Log Size

if OBJECT_ID('tempdb..#logspace') is not null
	drop table #logspace
	
create table #logspace
	(DBName				sysname
	,[LogSize(MB)]		decimal(20,8)
	,[LoSpaceUsed(%)]	decimal(20,8)
	,[Status]			int)

insert into #logspace (DBName, [LogSize(MB)], [LoSpaceUsed(%)], [Status])
EXEC('DBCC SQLPERF(logspace);');

if OBJECT_ID('tempdb..#pendingIOs') is not null
	drop table #pendingIOs

SELECT
	COUNT (*) AS [Pending_IOs],
	DB_NAME ([vfs].[database_id]) AS [DBName],
	[mf].[name] AS [FileName],
	[mf].[type_desc] AS [FileType],
	SUM ([pior].[io_pending_ms_ticks]) AS [TotalStall]
INTO #pendingIOs
FROM sys.dm_io_pending_io_requests AS [pior]
JOIN sys.dm_io_virtual_file_stats (NULL, NULL) AS [vfs]
	ON [vfs].[file_handle] = [pior].[io_handle]
JOIN sys.master_files AS [mf]
	ON [mf].[database_id] = [vfs].[database_id]
	AND [mf].[file_id] = [vfs].[file_id]
WHERE
   [pior].[io_pending] = 1
GROUP BY [vfs].[database_id], [mf].[name], [mf].[type_desc]
ORDER BY [vfs].[database_id], [mf].[name];

if OBJECT_ID('tempdb..#log_reuse_waits') is not null
	drop table #log_reuse_waits

SELECT name, [log_reuse_wait_desc]
  INTO #log_reuse_waits
  FROM sys.databases
 WHERE (name like @dbname)	

if @sortby = 1 
select 
	 l.DBName
	,[Recovery]=CONVERT(varchar(20),DatabasePropertyEx(l.DBName,'Recovery'))
	,[FileName] = isnull(pios.[FileName],'')
	,[FileType] = isnull(pios.FileType,'')
	,[Pending_IOs] = isnull(pios.Pending_IOs,'')
	,[TotalStall] = isnull(pios.TotalStall,'')
	,l.[LogSize(MB)]
	,[LogSpaceUsed(MB)]=CONVERT(decimal(20,2),(l.[LogSize(MB)] * l.[LoSpaceUsed(%)])/100)
	,l.[LoSpaceUsed(%)]
	,l.[Status]
	,[log_reuse_wait_desc] = isnull(w.log_reuse_wait_desc,'')
  from #logspace l 
	left join #pendingIOs pios on l.DBName = pios.DBName
	left join #log_reuse_waits w on w.name = l.DBName
 order by DBName asc

 if @sortby = 2 
select 
	 l.DBName
	,[Recovery]=CONVERT(varchar(20),DatabasePropertyEx(l.DBName,'Recovery'))
	,[FileName] = isnull(pios.[FileName],'')
	,[FileType] = isnull(pios.FileType,'')
	,[Pending_IOs] = isnull(pios.Pending_IOs,'')
	,[TotalStall] = isnull(pios.TotalStall,'')
	,l.[LogSize(MB)]
	,[LogSpaceUsed(MB)]=CONVERT(decimal(20,2),(l.[LogSize(MB)] * l.[LoSpaceUsed(%)])/100)
	,l.[LoSpaceUsed(%)]
	,l.[Status]
	,[log_reuse_wait_desc] = isnull(w.log_reuse_wait_desc,'')
  from #logspace l 
	left join #pendingIOs pios on l.DBName = pios.DBName
	left join #log_reuse_waits w on w.name = l.DBName
 order by l.[LogSize(MB)] DESC;
 
drop table #logspace
drop table #pendingIOs
drop table #log_reuse_waits