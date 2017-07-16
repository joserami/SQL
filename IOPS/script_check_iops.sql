-- ==================================================================================================================================================================================================
-- Script Name:	script_check_iops
-- Author:		Jose A. Ramirez
-- Create date:		MAY-16-2017
-- Description:		This script calculates IOPS (Reads and Writes) and their respective latencies 
--						the script accepts a DBName or may run against all DBs when '%' is used.
-- Change History:	2017-05-16 - Original Scrip created

-- Disclaimer:	The script is provided as-is with no guarantees expressed nor implied.  Always test the code in a dev or sandbox environment first.
-- ==================================================================================================================================================================================================


declare @dbname nvarchar(200), @fileid int, @filetype varchar(50);
set @dbname = '%';
set @fileid  = -1;
set @filetype = '%'

if object_id('tempdb..#iorequests') is not null
	drop table #iorequests
create table #iorequests 
	(ServerName				nvarchar(200)
	,SecondsRunning			bigint
	,DBName					nvarchar(200)
	,num_of_reads			bigint
	,num_of_writes			bigint
	,num_of_bytes_read		bigint
	,num_of_bytes_written	bigint
	,num_of_bytes_p_read	decimal(30,10)
	,num_of_bytes_p_write	decimal(30,10)
	,io_stall_read_ms		bigint
	,io_stall_write_ms		bigint
	,io_stall				bigint
	,[Read Latency]			decimal(30,10)
	,[Write Latency]		decimal(30,10)
	,[Overall Latency]		decimal(30,10)
	,IOReads_ps				decimal(30,10)
	,IOReads_bytes_ps		decimal(30,10)
	,IOWrites_ps			decimal(30,10)
	,IOWrites_bytes_ps		decimal(30,10)
	,Drive					char(2)
	,file_id				int
	,physical_name			nvarchar(500)
	,type_desc				nvarchar(50))

insert into #iorequests (ServerName
					   , SecondsRunning
					   , DBName
					   , num_of_reads
					   , num_of_writes
					   , num_of_bytes_read
					   , num_of_bytes_written
					   , num_of_bytes_p_read
					   , num_of_bytes_p_write
					   , io_stall_read_ms
					   , io_stall_write_ms
					   , io_stall
					   , [Read Latency]
					   , [Write Latency]
					   , [Overall Latency]
					   , IOReads_ps
					   , IOReads_bytes_ps
					   , IOWrites_ps
					   , IOWrites_bytes_ps
					   , Drive
					   , file_id
					   , physical_name
					   , type_desc)
select 
	  [ServerName]=@@SERVERNAME
	, [SecondsRunning]=abs(sample_ms/1000)
	, [DBName]=db_name(mf.database_id)
	, [vfs].num_of_reads
	, [vfs].num_of_writes
	, [vfs].num_of_bytes_read
	, [vfs].num_of_bytes_written
	, [num_of_bytes_p_read] = ([vfs].num_of_bytes_read / [vfs].num_of_reads)
	, [num_of_bytes_p_write] = ([vfs].num_of_bytes_written / [vfs].num_of_writes)
	, [vfs].io_stall_read_ms
	, [vfs].io_stall_write_ms
	, [vfs].io_stall
	, [Read Latency]=(([vfs].io_stall_read_ms * 1.000000)/([vfs].num_of_reads * 1.000000))
	, [Write Latency]=(([vfs].io_stall_write_ms * 1.000000)/([vfs].num_of_writes * 1.000000)) 
	, [Overall Latency]=(([vfs].io_stall * 1.000000)/(([vfs].num_of_reads + [vfs].num_of_writes) * 1.000000)) 
	, [IOReads_ps]=abs(convert(decimal(30,10),num_of_reads/(convert(decimal(30,10),sample_ms)/1000.00)))
	, [IOReads_Bytes_ps]=abs(convert(decimal(30,10),num_of_bytes_read/(convert(decimal(30,10),sample_ms)/1000.00)))
	, [IOWrites_ps]=abs(convert(decimal(30,10),num_of_writes/(convert(decimal(30,10),sample_ms)/1000.00)))
	, [IOWrites_Bytes_ps]=abs(convert(decimal(30,10),num_of_bytes_written/(convert(decimal(30,10),sample_ms)/1000.00)))
	, [Drive]=LEFT ([mf].[physical_name], 2) 
	, vfs.file_id
	, [mf].[physical_name]
	, [mf].type_desc
  from sys.dm_io_virtual_file_stats (NULL,NULL) AS [vfs]
	JOIN sys.master_files AS [mf] ON [vfs].[database_id] = [mf].[database_id] AND [vfs].[file_id] = [mf].[file_id]
 where db_name(mf.database_id) like @dbname
 order by IOWrites_Bytes_ps desc

select top 1 ServerName, [CURRENT_TIMESTAMP]=CURRENT_TIMESTAMP, SecondsRunning, DBName from #iorequests;
select IOReads_ps
	 , [IOReads_MBytes_ps]=(IOReads_bytes_ps/1048576.024)
	 , IOWrites_ps
	 , [IOWrites_MBytes_ps]=(IOWrites_bytes_ps/1048576.024)
	 , Drive
	 , physical_name
	 , type_desc
	 , [file_id]
	 , num_of_reads
	 , num_of_writes
	 , [num_of_kbytes_p_read]=(num_of_bytes_p_read/1024)
	 , [num_of_kbytes_p_write]=(num_of_bytes_p_write/1024)
	 , io_stall_read_ms
	 , io_stall_write_ms
	 , num_of_reads
	 , num_of_writes
	 , [Read Latency]
	 , [Write Latency]
	 , [Overall Latency]
  from #iorequests
 where type_desc like @filetype
 order by DBName desc, [file_id] asc OPTION (RECOMPILE);


select [IOReads_ps]=SUM(IOReads_ps), [IOReads_bytes_ps]=SUM(IOReads_bytes_ps), [IOReads_MBytes_ps]=(SUM(IOReads_bytes_ps)/1048576.024), [IOWrites_ps]=SUM(IOWrites_ps), [IOWrites_bytes_ps]=SUM(IOWrites_bytes_ps), [IOWrites_MBytes_ps]=(SUM(IOWrites_bytes_ps)/1048576.024)
  from #iorequests
 where (file_id = @fileid or @fileid = -1)
 order by IOWrites_bytes_ps desc

select [DBName], [IOReads_ps]=SUM(IOReads_ps), [IOReads_bytes_ps]=SUM(IOReads_bytes_ps), [IOReads_MBytes_ps]=(SUM(IOReads_bytes_ps)/1048576.024), [IOWrites_ps]=SUM(IOWrites_ps), [IOWrites_bytes_ps]=SUM(IOWrites_bytes_ps), [IOWrites_MBytes_ps]=(SUM(IOWrites_bytes_ps)/1048576.024)
  from #iorequests
 where DBName like @dbname and (file_id = @fileid or @fileid = -1)
 group by [DBName]
 order by IOWrites_bytes_ps desc

select ServerName, SecondsRunning, DBName, IOReads_ps, IOReads_bytes_ps, IOWrites_ps, IOWrites_bytes_ps, Drive, physical_name, type_desc
  from #iorequests
 where type_desc like @filetype
 order by IOWrites_bytes_ps desc

select [IOReads_ps]=SUM(IOReads_ps), [IOReads_bytes_ps]=SUM(IOReads_bytes_ps), [IOReads_MBytes_ps]=(SUM(IOReads_bytes_ps)/1048576.024), [IOWrites_ps]=SUM(IOWrites_ps), [IOWrites_bytes_ps]=SUM(IOWrites_bytes_ps), [IOWrites_MBytes_ps]=(SUM(IOWrites_bytes_ps)/1048576.024)
  from #iorequests
 where type_desc like @filetype
 order by IOWrites_bytes_ps desc

select [DBName], [IOReads_ps]=SUM(IOReads_ps), [IOReads_bytes_ps]=SUM(IOReads_bytes_ps), [IOReads_MBytes_ps]=(SUM(IOReads_bytes_ps)/1048576.024), [IOWrites_ps]=SUM(IOWrites_ps), [IOWrites_bytes_ps]=SUM(IOWrites_bytes_ps), [IOWrites_MBytes_ps]=(SUM(IOWrites_bytes_ps)/1048576.024)
  from #iorequests
 where DBName like @dbname and type_desc like @filetype
 group by [DBName]
 order by IOWrites_bytes_ps desc

drop table #iorequests