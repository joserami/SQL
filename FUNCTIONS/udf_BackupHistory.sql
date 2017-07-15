SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
SET NOCOUNT ON;

GO
-- ==================================================================================================================================================================================================
-- Script Name:	[dbo].[udf_BackupHistory]
-- Author:		Jose A. Ramirez
-- Create date:		2015-07-15
-- Description:		This Function provides Backup History for any specified DB
--						or all DBs when '%' is used.
-- Change History:	2015-07-15 - Original Scrip created
--					2015-07-20 - Added Start and End Dates
--					2016-02-25 - Added is_copy_only to indentify full backup copies 
--									that may be irrelevant to a point in time recovery process and or DR
-- Usage:	SELECT * FROM [dbo].[udf_BackupHistory] ('%', '%', 0, null, null) WHERE is_copy_only = 0;
--				SELECT * FROM [dbo].[udf_BackupHistory] ('DBName or Name Pattern', 'Backup type: D=Full,I=Differential,L=Log', include system dbs? 1=Yes 0=No, Search Start Date, Search End Date);

-- Disclaimer:	The script is provided as-is with no guarantees expressed nor implied.  Always test the code in a dev or sandbox environment.
-- ==================================================================================================================================================================================================

CREATE FUNCTION [dbo].[udf_BackupHistory]
(	
	@dbname varchar(150)='%', @baktype char(1)='%', @incsys bit=0, @sdate datetime=null, @edate datetime=null
)
RETURNS TABLE 
AS
RETURN 
(
    with backhist as (
    SELECT distinct
	   s.database_name,
	   m.physical_device_name,
	   CAST(CAST(s.backup_size / 1000000 AS INT) AS VARCHAR(14)) + ' ' + 'MB' AS bkSize,
	   CAST(DATEDIFF(second, s.backup_start_date,
	   s.backup_finish_date) AS VARCHAR(4)) + ' ' + 'Seconds' TimeTaken,
	   s.backup_start_date,
	   s.backup_finish_date,
	   CAST(s.first_lsn AS VARCHAR(50)) AS first_lsn,
	   CAST(s.last_lsn AS VARCHAR(50)) AS last_lsn,
	   CASE s.[type]
	   WHEN 'D' THEN 'Full'
	   WHEN 'I' THEN 'Differential'
	   WHEN 'L' THEN 'Transaction Log'
	   END AS BackupType,
	   s.server_name,
	   s.recovery_model,
	   s.is_copy_only 
    FROM msdb.dbo.backupset s
	   INNER JOIN msdb.dbo.backupmediafamily m ON s.media_set_id = m.media_set_id
    WHERE s.database_name like @dbname
      AND s.type like @baktype 
	  AND s.is_copy_only = 0
      AND s.backup_start_date  between isnull(@sdate,'1/1/1900') and isnull(@edate,GETDATE()))
	select b.database_name,b.physical_device_name,b.bkSize,b.TimeTaken,b.backup_start_date,b.backup_finish_date,b.first_lsn,b.last_lsn,b.BackupType,b.server_name,b.recovery_model,b.is_copy_only from backhist b 
		inner join master.sys.databases db on db.name = b.database_name
	where b.database_name not in ('master','msdb','model') and db.is_distributor = 0 
	UNION
	select b.database_name,b.physical_device_name,b.bkSize,b.TimeTaken,b.backup_start_date,b.backup_finish_date,b.first_lsn,b.last_lsn,b.BackupType,b.server_name,b.recovery_model,b.is_copy_only from backhist b 
		inner join master.sys.databases db on db.name = b.database_name
	where (database_name in ('master','msdb','model') or db.is_distributor = 1) and @incsys = 1

)

GO