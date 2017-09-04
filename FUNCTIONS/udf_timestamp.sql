SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
GO
-- =======================================================================================================================================
-- Script Name:	udf_timestamp
-- Author:		Jose A. Ramirez
-- Create date:	2012-01-15
-- Description:	Return Date and Time Stamp in the form of YYYYMMDDTHHMMSSmmm ==> YYYY + MM + DD + "T" + HH + MM + SS + (milliseconds)
--				Pass any datetime value and the function will convert it to a varchar datetime stamp.
--				Used for stamping export files, renaming objects, backups, etc.

/* Usage:		declare @date datetime,  @vch_timstamp varcahr(30)
				set @date = getdate();		-- this is my own habit, assign the value at the top of the code and re-use the same value 
											-- instead of invoking the function multiple times.  This is NOT mandatory.
				set @vch_timstamp = [dbo].[udf_timestamp] (@date);
				select [@vch_timstamp]=@vch_timstamp;

-- Renaming objects example:
				declare @tsql varchar(200), @objname nvarchar(150);
				set @objname = 'object_name';

				set @tsql = 'exec sp_rename ''' +@objname+''',''' + @objname + '_' + [DBA_MAINTENANCE].dbo.udf_timestamp (getdate()) + ''';';
				if OBJECT_ID(@objname) is not null exec (@tsql);
========================================================================================= */

/* 
   Change History:  2011-01-15  Created script
*/
-- =======================================================================================================================================
create function [dbo].[udf_timestamp] (@datetime datetime)
	returns varchar(30)
as
begin
	return  REPLACE(REPLACE(REPLACE(REPLACE(LEFT(CONVERT(VARCHAR, @datetime, 126), 50),'-',''),':',''),' ',''),'.','')
end

GO