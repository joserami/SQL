SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
GO

-- =======================================================================================================================================
-- Script Name:	udf_UserDBs
-- Author:		Jose A. Ramirez
-- Create date:	2015-07-15
-- Description:	Return a list of accessible user databases. (this is a table-value function) 
--				This function is normally used for batch processes such as maintenance tasks (Indexing, backups, etc)
--					where the database not only should be online, but in read-write and in multi-user mode.
--					This eliminates complex code need to figure out if your database is a secondary database 
--					or somehow in a restricted mode.

/* Usage:		declare @DBName varcahr(200)
				set @DBName = '%';			-- The function uses a like clause which can be used to perform pattern searches 
											-- Always keeping in mind the results are filtered to the extent that the database 
											-- must be accessible and in multi-user mode
				select * from [dbo].[udf_UserDBs] (@DBName);

========================================================================================= */

/* 
   Change History:  2015-07-15  Created script
					2015-09-28  Excluded distribution DB 
								-- this DB is part of the system DBs (Replication)
					2016-02-29	Fixed Distribution DB selection by looking into the is_distributor flag instead of searching by name.
								-- this fix is intended for distribution databases with names other than "distribution".
								-- Added if exists rename condition to backup prior version when applicable (for rollback purposes).
					2017-01-22	Jose Ramirez.  Added "db.name like @DBName"
					2017-03-15	Jose Ramirez.  Added DATABASEPROPERTYEX condition to endure only accessible DBs are returned.
*/
-- =======================================================================================================================================

Create FUNCTION [dbo].[udf_UserDBs]
(	
	-- Add the parameters for the function here
	@DBName varchar(150) = '%'
)
RETURNS TABLE 
AS
RETURN 
(
	SELECT db.name from master.sys.databases db where db.name like @DBName and db.database_id > 4 and db.is_distributor = 0		-- 2017-01-22
												  and DATABASEPROPERTYEX(db.name, 'UserAccess') = 'MULTI_USER'					-- 2017-03-15
												  and DATABASEPROPERTYEX(db.name, 'Status') = 'ONLINE'							
												  and DATABASEPROPERTYEX(db.name, 'Updateability') = 'READ_WRITE'	
)

GO