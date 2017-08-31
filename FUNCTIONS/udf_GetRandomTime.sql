USE master;
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
GO
-- Create Dependency if it doesn't exist.  This view provides use of the non-deterministic function (newID) to a function
-- http://stackoverflow.com/questions/772517/newid-inside-sql-server-function
declare @rename_tsql varchar(500), @tsql varchar(500), @objname nvarchar(150), @dep nvarchar(150);
set @objname = 'udf_GetRandomTime';
set @dep = 'uvw_getNewID';

-- This section handles the renaiming and creation of the dependency
set @tsql = 'create view uvw_getNewID as select [newid]=rand(cast(cast(NEWID() as binary(8)) as int));';
if OBJECT_ID(@dep) is not null
begin 
	print 'saving your previous copy of: [' + @dep + ']';
	set @rename_tsql = 'exec sp_rename ''' +@dep+''',''' + @dep + '_' + dbo.udf_timestamp (getdate()) + ''';';
	exec (@rename_tsql);
	print 'creating your new object: [' + @dep + ']';
	exec (@tsql);
end
else begin
	print 'creating your new object: [' + @dep + ']';
	exec (@tsql) 
end

-- This section handles the renaming operation of the object about to be re-created (if exists).
set @tsql = 'exec sp_rename ''' +@objname+''',''' + @objname + '_' + dbo.udf_timestamp (getdate()) + ''';';
if OBJECT_ID(@objname) is not null begin
	print 'creating your new object: [' + @dep + ']';
	exec (@tsql)
end	
GO
-- =======================================================================================================================================
-- Author:		Jose A. Ramirez
-- Create date: 2016-02-09
-- Description:	This function returns a random time.  Its intended use if for SQL Agent backup jobs
--				to assign random start times (to reduce IO contention at the SAN, or backup server)
-- Usage	  : select dbo.udf_GetRandomTime(@m_start, @m_end, #)		-- (maintenance start, maintenance end, estimated runtime in hours) 
--                                                                --  use 24 hr format and integer value for the runtime
--            select master.dbo.udf_GetRandomTime ('05:00:00 PM', '06:00:00 AM', 3);
-- Change History:	2016-02-24	Fixed issue with use of non-deterministic functions as described on:
--					-- http://stackoverflow.com/questions/772517/newid-inside-sql-server-function
--					Added: Creation of the view dependency: "uvw_getNewID" which conceals the use of non-deterministic functions
--						   and returns the randomized value.
--					2017-05-04	Added comments to share code on GitHub, added maintenance window and corresponding logic
-- =======================================================================================================================================
CREATE FUNCTION dbo.udf_GetRandomTime (	@m_start datetime, @m_end datetime, @est_run int )
RETURNS varchar(10)
AS
BEGIN
	DECLARE @datetime datetime, @time varchar(10), @hour int, @hour_s int, @hour_e int, @hour_c char(2), @min int, @min_c char(2), @sec int, @sec_c char(2);
	DECLARE @est_finish int, @cal_window int;

	SELECT @cal_window = abs(datediff(hh, @m_start, @m_end));
	SELECT @hour_s = DATEPART(hh,@m_start), @hour_e = DATEPART(hh,@m_end)

	-- make sure estimated runtime does not exceed maitenance window
	SET @est_run = case when abs(@est_run) > @cal_window then @cal_window
						else abs(@est_run)
					end
	
	-- Pull a random time... we will use this as our baseline
	SELECT @datetime=cast(cast(@m_start as int)-[newid] as datetime) from dbo.uvw_getNewID;	
	-- dissect the time	so we can work with the hour itself... we will reconstruct shortly
	SELECT @hour = DATEPART(hh,@datetime), @min = DATEPART(n, @datetime), @sec = DATEPART(s,@datetime);
	-- estimate the finish time based on the runtime that was entered
	SELECT @est_finish = @hour + @est_run;
	-- overnight maintenance window
	if  @hour_e < @hour_s SET @est_finish = case when @est_finish > 23 then (@est_finish - 24) else @est_finish end;

	SET @hour = case when @est_finish < @hour_e and @hour >= @hour_s then @hour
					 when @est_finish >= @hour_e and @hour >= @hour_s then @hour_e - (@est_run + 1)
					 when @hour < @hour_s then @hour_s
				 end

	-- NOTE: if you would like to only randomize the hour, set the mins and secs to a static value, just remember to use 2 digits
	-- 			Agent jobs use the 6 digit time format
	SET @hour_c = case when @hour <= 9 then '0' + convert(varchar, @hour) else convert(varchar, @hour) end;
	SET @min_c =  case when @min  <= 9 then '0' + convert(varchar, @min)  else convert(varchar, @min) end;
	SET @sec_c =  case when @sec  <= 9 then '0' + convert(varchar, @sec)  else convert(varchar, @sec) end;

	-- Re-construct the time
	SELECT @time=@hour_c + @min_c + @sec_c;

	-- Return the time
	RETURN @time

END
GO
