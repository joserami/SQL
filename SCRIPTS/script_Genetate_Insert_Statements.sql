-- ==========================================================================================================================================
-- Script Name: script_generate_insert_statements.sql
-- Author:		Jose A. Ramirez
-- Create date: JUN-01-2017
-- Description:	This script will read the definition of a specified table and generate insert statements for you.
--		NOTE: There are inherit limitations in the way the script is built, so depending on how wide the table is, only a limited number
--				of rows may be returned, hence the set @rowlimit.

-- Disclaimer:	The script is provided as-is with no guarantees expressed nor implied.  Always test the code in a dev or sandbox environment.
-- ==========================================================================================================================================

set nocount on;
declare @schema_name varchar(max), @table_name varchar(max), @column_name varchar(max), @column_type varchar(max), @column_length int, @tsql_ins varchar(max), @tsql_s varchar(max), @tsql_v varchar(max), @tsql_exec varchar(max), @tsql2_exec varchar(max), @cnt int;
declare @tsql2_fetch varchar(max), @tsql2_replace varchar(max), @debug bit;
declare @tsql_ifnotexist varchar(max), @use_ifnotexist bit, @rowcnt int, @row_limit int;
declare @newDB nvarchar(500), @currDB nvarchar(500);

set @schema_name = 'dbo';
set @table_name = 'source_table';	
set @cnt = 0;
set @rowcnt = 0;
set @row_limit = 50;
set @use_ifnotexist = 0;
set @debug = 0;
set @newDB = null;		-- 'TARGET_DB_NAME'

set @currDB = '[' + convert(nvarchar(500), db_name()) + ']'
if @debug = 1 print 'Current DB is: ' + @currDB;

declare cols cursor fast_forward read_only for
	select COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH from INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = @table_name and COLUMN_NAME not in ('insp_id','install_date') ORDER BY ORDINAL_POSITION

open cols;
fetch next from cols into @column_name,@column_type,@column_length;

set @tsql_ifnotexist = 'if not exists (select * from [' + db_name() + '].[' + @schema_name + '].[' + @table_name + '] where ''''<< REPLACE >>'''' = ''''<< CONDITION >>'''')' + CHAR(13);
set @tsql_s = 'select ';
set @tsql_ins = case when @use_ifnotexist = 1 then @tsql_ifnotexist else '' end + 'insert into [' + db_name() + '].[' + @schema_name + '].[' + @table_name + '] (';
set @tsql_v = '    values (';
set @tsql2_exec = 'declare @vtsql varchar(max),@vtsql_exe varchar(max), @rowcnt int,';
set @tsql2_fetch = 'set @rowcnt = @rowcnt + 1; ' + char(13) + 'print @vtsql_exe;' + char(13) + 'set @vtsql_exe = '''';' + char(13) +'fetch next from tbl_vals into '
set @tsql2_replace = ''

while @@fetch_status = 0
begin
	set @cnt = @cnt + 1;

	set @tsql_ins = @tsql_ins + case when @cnt = 1 then '' else ',' end + '[' + @column_name + ']';
	set @tsql_s = @tsql_s + case when @cnt = 1 then '' else ',' end + '[' + @column_name + ']';
	set @tsql_v = @tsql_v + case when @cnt = 1 then '' else ',' end
						  + case when @column_type in ('char','varchar','nvarchar','sysname','date','datetime') then '''''<<' + @column_name + '>>''''' 
								 else '<<' + @column_name + '>>' end;
	
	if @cnt = 1
	set @tsql2_replace = 'replace(@vtsql,' + '''<<' + @column_name + '>>''' + ',' 
						+ case when @column_type in ('char','varchar','nvarchar','sysname') then 'isnull(@' + replace(replace(@column_name,'(','_'),')','') + ', ''null'')' 
							   when @column_type in ('bit','int','bigint','smallint','tinyint','decimal','money','numeric','float','real') then 'isnull(@' + replace(replace(@column_name,'(','_'),')','') + ', ''null'')'
							   when @column_type in ('date','datetime') then 'convert(varchar(50),isnull(@' + replace(replace(@column_name,'(','_'),')','') + ', ''1950-01-01'')120)'
							   else 'convert(varchar(max),isnull(@' + replace(replace(@column_name,'(','_'),')','') + ',''null''))' end + ')';
	else 
	set @tsql2_replace = 'replace(' + @tsql2_replace + ',' + '''<<' + @column_name + '>>''' + ',' 
						+ case when @column_type in ('char','varchar','nvarchar','sysname') then 'isnull(@' + replace(replace(@column_name,'(','_'),')','')  + ', ''null'')' 
							   when @column_type in ('bit','int','bigint','smallint','tinyint','decimal','money','numeric','float','real') then 'isnull(@' + replace(replace(@column_name,'(','_'),')','')  + ', 0)' 
							   when @column_type in ('date','datetime') then 'convert(varchar(50),isnull(@' + replace(replace(@column_name,'(','_'),')','') + ', ''1950-01-01''),120)'
							   else 'convert(varchar(max),isnull(@' + replace(replace(@column_name,'(','_'),')','') + ',''null''))' end + ')';
					
	
	set @tsql2_exec = @tsql2_exec + case when @cnt = 1 then '' else ',' end + '@' + replace(replace(@column_name,'(','_'),')','') + ' ' + @column_type + case when @column_type <> 'decimal' and @column_length is null then '' 
																																							  when @column_type = 'decimal' then '(18,2)' 
																																							  when @column_type in ('varchar','nvarchar') and @column_length = -1 then '(max)'
																																							  else '(' + convert(varchar(max), @column_length) + ')' 
																																						  end;
	set @tsql2_fetch = @tsql2_fetch + case when @cnt = 1 then '' else ',' end + '@' + replace(replace(@column_name,'(','_'),')','');
	
	fetch next from cols into @column_name,@column_type,@column_length;
end
set @tsql_ins = @tsql_ins + ')';
set @tsql_s = @tsql_s + ' from [' + db_name() + '].[' + @schema_name + '].[' + @table_name + ']';
set @tsql_v = char(13) + @tsql_v + ');' + case when @use_ifnotexist = 1 then char(13) else '' end;
set @tsql_exec = @tsql_ins + char(13) + char(13) + @tsql_s;
set @tsql2_replace = 'set @vtsql = ' + @tsql2_replace;

set @tsql2_exec = @tsql2_exec + ';' + char(13) + 'set @vtsql_exe = '''';' + char(13) + 'declare tbl_vals cursor fast_forward read_only for ' + char(13) + '      ' + @tsql_s + ';' + char(13) + 'open tbl_vals;' + char(13) + @tsql2_fetch
set @tsql2_exec = @tsql2_exec + char(13) + 'set @rowcnt = 0; ' + char(13) + 'while @@fetch_status = 0 and @rowcnt <= ' + convert(varchar(max), @row_limit) + char(13) + 'begin' + char(13) + '     set @vtsql = ''' + @tsql_ins + '''' + char(13) 
							  + '                + ''' + @tsql_v + '''' + char(13) + '     ' + @tsql2_replace 
							  + char(13) + '     set @vtsql_exe = @vtsql_exe + char(13) + @vtsql;' + char(13) + '     ' + char(13) + '     ' + @tsql2_fetch + char(13) + 'end;' + char(13) + char(13);


set @tsql2_exec = @tsql2_exec + char(13) + 'close tbl_vals;' + char(13) + 'deallocate tbl_vals;';

if @newDB is not null
begin
	set @tsql2_exec = replace(@tsql2_exec, 'insert into ' + @currDB, 'insert into ' + @newDB);
	set @tsql2_exec = 'PRINT ''SET IDENTITY_INSERT ' + @newDB + '.[' + @schema_name + '].[' + @table_name + '] ON;''' + char(13) + @tsql2_exec + char(13) +
					  'PRINT ''SET IDENTITY_INSERT ' + @newDB + '.[' + @schema_name + '].[' + @table_name + '] OFF;''';
end
else 
begin
	set @tsql2_exec = 'PRINT ''SET IDENTITY_INSERT ' + @currDB + '.[' + @schema_name + '].[' + @table_name + '] ON;''' + char(13) + @tsql2_exec + char(13) +
					  'PRINT ''SET IDENTITY_INSERT ' + @currDB + '.[' + @schema_name + '].[' + @table_name + '] OFF;''';
end

if @debug = 1 begin select len(@tsql2_exec); print @tsql2_exec end;
else execute(@tsql2_exec);

cleanup:
close cols;
deallocate cols;