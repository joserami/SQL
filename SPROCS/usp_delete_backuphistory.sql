-- ============================================================================================================
-- Script Name:	usp_delete_backuphistory
-- Author:		Jose A. Ramirez
-- Create date:	2015-07-15
-- Description:	This stored procedure can work in one of three specific ways:
		--			1- debug mode: no actual deletion occurs. only summary information is returned.
		--			2- debug + verbose mode: no actual deletion occurs. detailed information is returned.
		--			3- running mode: will make changes based on the parameters.

-- WARNING -------------
--				Deleting data from msdb can cause blocking on the msdb (just like on any other database).
--					Always ensure your batch size is small enough to commit changes and flush the transaction log
--					

-- *** Procedure is provided as-is, with no warranties expressed nor implied.  Please always test on a DEV or SANDBOX environment first. 
-- 
-- The code below is based on these two mssqltips articles:
-- References:	https://www.mssqltips.com/sqlservertip/1727/purging-msdb-backup-and-restore-history-from-sql-server/
--				https://www.mssqltips.com/sqlservertip/1461/analyze-and-correct-a-large-sql-server-msdb-database/

/* Usage:		
				exec [dbo].[usp_delete_backuphistory] 	@oldest_date 					-- datetime
												 		@batch_size 	= 10000, 		-- int
												 		@debug  		= 1, 			-- bit
												 		@verbose  		= 1;			-- bit

========================================================================================= */

/* 
   Change History:  2015-07-15  Created script
					
*/
-- ============================================================================================================

CREATE PROCEDURE dbo.usp_delete_backuphistory (@oldest_date datetime, @batch_size int = 10000, @debug bit = 1, @verbose bit = 1)
AS



-- DECLARE @CUR_ROWCOUNT int
SET ROWCOUNT @batch_size;

BEGIN
  -- SET NOCOUNT ON
  DECLARE @backup_set_id TABLE      (backup_set_id INT)
  DECLARE @media_set_id TABLE       (media_set_id INT)
  DECLARE @restore_history_id TABLE (restore_history_id INT)


  INSERT INTO @backup_set_id (backup_set_id)
  SELECT DISTINCT backup_set_id
  FROM msdb.dbo.backupset
  WHERE backup_finish_date < @oldest_date

  INSERT INTO @media_set_id (media_set_id)
  SELECT DISTINCT media_set_id
  FROM msdb.dbo.backupset
  WHERE backup_finish_date < @oldest_date

  INSERT INTO @restore_history_id (restore_history_id)
  SELECT DISTINCT restore_history_id
  FROM msdb.dbo.restorehistory
  WHERE backup_set_id IN (SELECT backup_set_id
	                        FROM @backup_set_id)

	if @debug = 1
	begin
		select [@backup_set_id]=count(*) from @backup_set_id;
		select [@media_set_id]=count(*) from @media_set_id;
		select [@restore_history_id]=count(*) from @restore_history_id;
	end
  
  SET ROWCOUNT 0;
  IF @debug = 0
  BEGIN
	  BEGIN TRANSACTION
	  DELETE FROM msdb.dbo.backupfile
	  WHERE backup_set_id IN (SELECT backup_set_id
							  FROM @backup_set_id)
	  IF (@@error > 0) GOTO Quit

	  DELETE FROM msdb.dbo.backupfilegroup
	  WHERE backup_set_id IN (SELECT backup_set_id
							  FROM @backup_set_id)
	  IF (@@error > 0) GOTO Quit

	  DELETE FROM msdb.dbo.restorefile
	  WHERE restore_history_id IN (SELECT restore_history_id
								   FROM @restore_history_id)
	  IF (@@error > 0) GOTO Quit

	  DELETE FROM msdb.dbo.restorefilegroup
	  WHERE restore_history_id IN (SELECT restore_history_id
								   FROM @restore_history_id)
	  IF (@@error > 0) GOTO Quit

	  DELETE FROM msdb.dbo.restorehistory
	  WHERE restore_history_id IN (SELECT restore_history_id
								   FROM @restore_history_id)
	  IF (@@error > 0) GOTO Quit

	  DELETE FROM msdb.dbo.backupset
	  WHERE backup_set_id IN (SELECT backup_set_id
							  FROM @backup_set_id)
	  IF (@@error > 0) GOTO Quit



	  DELETE msdb.dbo.backupmediafamily
	  FROM msdb.dbo.backupmediafamily bmf
	  WHERE bmf.media_set_id IN (SELECT media_set_id
								 FROM @media_set_id)
		AND ((SELECT COUNT(*)
			  FROM msdb.dbo.backupset
			  WHERE media_set_id = bmf.media_set_id) = 0)
	  IF (@@error > 0) GOTO Quit

	  DELETE msdb.dbo.backupmediaset
	  FROM msdb.dbo.backupmediaset bms
	  WHERE bms.media_set_id IN (SELECT media_set_id
								 FROM @media_set_id)
	   AND ((SELECT COUNT(*)
			  FROM msdb.dbo.backupset
			  WHERE media_set_id = bms.media_set_id) = 0)
	  IF (@@error > 0) GOTO Quit

	  COMMIT TRANSACTION
	  RETURN

	  Quit:
	  ROLLBACK TRANSACTION
   END

   if @debug = 1 and @verbose = 1
   BEGIN
   	  SELECT * FROM msdb.dbo.backupfile
	  WHERE backup_set_id IN (SELECT backup_set_id
							  FROM @backup_set_id)

	  SELECT * FROM msdb.dbo.backupfilegroup
	  WHERE backup_set_id IN (SELECT backup_set_id
							  FROM @backup_set_id)

	  SELECT * FROM msdb.dbo.restorefile
	  WHERE restore_history_id IN (SELECT restore_history_id
								   FROM @restore_history_id)

	  SELECT * FROM msdb.dbo.restorefilegroup
	  WHERE restore_history_id IN (SELECT restore_history_id
								   FROM @restore_history_id)

	  SELECT * FROM msdb.dbo.restorehistory
	  WHERE restore_history_id IN (SELECT restore_history_id
								   FROM @restore_history_id)

	  SELECT * FROM msdb.dbo.backupset
	  WHERE backup_set_id IN (SELECT backup_set_id
							  FROM @backup_set_id)


	  SELECT * 
	  FROM msdb.dbo.backupmediafamily bmf
	  WHERE bmf.media_set_id IN (SELECT media_set_id
								 FROM @media_set_id)
		AND ((SELECT COUNT(*)
			  FROM msdb.dbo.backupset
			  WHERE media_set_id = bmf.media_set_id) = 0)

	  SELECT * 
	  FROM msdb.dbo.backupmediaset bms
	  WHERE bms.media_set_id IN (SELECT media_set_id
								 FROM @media_set_id)
	   AND ((SELECT COUNT(*)
			  FROM msdb.dbo.backupset
			  WHERE media_set_id = bms.media_set_id) = 0)
   END
END
