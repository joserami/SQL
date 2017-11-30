/*
	Script Name:	ReadErrorLog.sql
	Author:			Jose A. Ramirez
	Create Date:	2016-02-19
	Change History:	2016-02-19	Original script created
					2017-NOV-29	Modified the temp table creation to check and drop the temptable (if exists)
									and added a final check at the end to drop only if the table exists.
									This eliminates any errrors if the table for some reason did not get created.
								Added commented section to build as a stored procedure with some basic default values as examples.
								
	References:		-- https://www.mssqltips.com/sqlservertip/1476/reading-the-sql-server-log-files-using-tsql/

*/

-- create procedure dbo.usp_readErrorLog (@search1 nvarchar(500) = '', 
--										 @search2 nvarchar(500)  = '', 
--										 @searchdt datetime		 = '2017-01-01 00:00:01', 
--										 @search_edt datetime	 = getdate(), 
--										 @ProcessInfo nvarchar(500)	= '%')
-- as
declare @search1 nvarchar(500), @search2 nvarchar(500), @searchdt datetime, @search_edt datetime, @ProcessInfo nvarchar(500);
set @search1 = '\LOG\';					-- enter some text (no need for wild cards here) or blank for all
set @search2 = '';						-- enter some text (no need for wild cards here) or blank for all
set @searchdt = '2016-02-24 12:55:00'	-- This is the search start date.  
set @search_edt = getdate();			-- Change this to a specific value if you wish to narrow down to a specific timeframe
set @ProcessInfo = '%';					-- A process name, if you want the results to be filtered by a specific process or (in this case) use a wild card.

if object_id('tempdb..#sqlerrlog') is not null drop table #sqlerrlog;
	create table #sqlerrlog (LogDate datetime, ProcessInfo nvarchar(500), TextInfo	nvarchar(4000))

insert into #sqlerrlog (LogDate, ProcessInfo, TextInfo)
exec sp_readerrorlog 0,1,@search1,@search2;						-- first set of filters are applied here with @search1 and @search2

select LogDate, ProcessInfo, TextInfo 
  from #sqlerrlog 
 where LogDate between @searchdt and @search_edt
   and ProcessInfo like @ProcessInfo;


if object_id('tempdb..#sqlerrlog') is not null drop table #sqlerrlog;   
GO