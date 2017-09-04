/*
	Script Name:	script_get_missingIndexes
	Author:			Jose A. Ramirez
	Create Date:	2016-02-15
	Change History:	2016-02-15	Oroginal script created
                    2016-08-28  Formated script for legibility, and added technet ref.
	References:		https://technet.microsoft.com/en-us/library/ms345405(v=sql.105).aspx

*/
with idx_comp as (
SELECT 
	  [DBName]=db_name(database_id)
	, [TableName]=replace(reverse(substring(reverse(statement), 0, charindex('[.]', reverse(statement)))), ']','')
	, [FQ_TableName]=[statement]
	, [equality_columns]
	, [inequality_columns]
	, [included_columns]
	, [IX_Name]='IX_' + replace(replace(reverse(substring(reverse(statement), 0, charindex('[.]', reverse(statement)))), ']',''),' ','') 
					  + case when equality_columns is null then '' else '_' + replace(replace(replace(replace(equality_columns,'[',''),']',''),',','_'),' ','') end
					  + case when inequality_columns is null then '' else '_' + replace(replace(replace(replace(inequality_columns,'[',''),']',''),',','_'),' ','') end
	, [Idx_columns] =' (' + case when equality_columns is null then '' else replace(replace(replace(equality_columns,'[',''),']',''), ' ', '') end
						  + case when equality_columns is not null and inequality_columns is not null then ',' else '' end
						  + case when inequality_columns is null then '' else replace(replace(replace(inequality_columns,'[',''),']',''), ' ', '') end + ')'
						  -- + case when equality_columns is not null or inequality_columns is not null then ' INCLUDE (' else '' end 
						  + case when included_columns is null then ''
								 else ' INCLUDE (' + replace(replace(replace(included_columns,'[',''),']',''),' ','')  + ');'
							 end

  FROM sys.dm_db_missing_index_details)
  select distinct 
		 [DBName]
		,[TableName]
		,[SQL_Statement]='USE ' + [DBName] + '; if exists (select 1 from sysindexes where name = ''' + [IX_Name] + '''); DROP INDEX [' + [IX_Name] + '] ON [' + [TableName] + ']; '
								+ 'CREATE INDEX [' + [IX_Name] + '] ON [' + [TableName] + '] ' + [Idx_columns]
	from idx_comp i 
   where DBName not in ('master','msdb','distribution')
   order by [TableName] ASC;