USE [DBA_MAINTENANCE]
GO
/****** Object:  StoredProcedure [dbo].[usp_Generate_IO_Agent]    Script Date: 8/20/2017 3:39:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER procedure [dbo].[usp_Generate_IO_Agent] (@dbname varchar(200) = 'dba_test', @agent_num int = null, @nameval varchar(100) = 'Jose Ramirez the ', @description varchar(200) = 'This is an IO Test', 
											   @clsbuff bit = 0, @buffint int = 200, @rec_cnt bigint = 10500000, @interval int = 1, @sel bit = 1, @writeint int = 3, 
											   @ins bit =0, @delint int = 3, @del bit = 0, @debug bit = 1, @retry int = 5, @thottle varchar(50) = '00:00:00.500')
as

declare @tsql varchar(8000), @err nvarchar(4000);
--declare @agent_num int, @nameval varchar(100), @description varchar(200), @debug bit, @retry int;
--set @debug = 0;
--set @agent_num = 1;
--set @retry = 5;
--set @nameval = 'Jose Ramirez the ';
--set @description = 'This is an IO Test';
set @debug = isnull(@debug, 1);

set @err = '*** !!! ERROR !!! *** Database: [[ ' + @dbname + ' ]] does not exist... Please create the database first and then try your statement again';
if db_id(@dbname) is null
	raiserror(@err, 20, -1) with log

if (@agent_num > 0) or (@agent_num is null)
begin
	set @tsql = '
	use [' + @dbname + '];
	if ' + convert(varchar, @clsbuff) + ' = 1 begin
		CHECKPOINT;
		DBCC DROPCLEANBUFFERS;
	end
	set nocount on;

	if object_id(''[' + @dbname + '].[dbo].[utl_testtable' + convert(varchar, isnull(@agent_num,'')) + ']'') is null
	begin
		print ''crating table [' + @dbname + '].[dbo].[utl_testtable' +  convert(varchar, isnull(@agent_num,'')) + ']'';
		CREATE TABLE [' + @dbname + '].[dbo].[utl_testtable' +  convert(varchar, isnull(@agent_num,'')) + '](
			[test_id] [bigint] IDENTITY(1,1) NOT NULL,
			[name] [varchar](100) NULL,
			[description] [varchar](200) NOT NULL,
			[timestamp] [datetime] NULL DEFAULT (getdate())
		) ON [PRIMARY]
	end


	declare @name varchar(100), @description varchar(200), @cnt bigint, @minnum bigint, @maxnum bigint, @rec_cnt int, @scnt int, @dcnt int, @randomint bigint
	declare @interval int, @findrec bigint, @recsSelected varchar(200), @recfound varchar(1000), @delrecs int, @retry int, @retrycnt int;
	declare @ins bit, @sel bit, @del bit, @buffint int, @delint int, @writeint int, @writecnt int, @currRecCnt bigint, @prevRecCnt bigint, @deltaRecCnt int;

	set @rec_cnt = ' + convert(varchar, @rec_cnt) + ';
	set @interval = ' + convert(varchar, @interval) + ';
	set @retry = ' + convert(varchar, @retry) + ';
	set @ins = ' + convert(varchar, @ins) + ';
	set @sel = ' + convert(varchar, @sel) + ';
	set @del = ' + convert(varchar, @del) + ';
	set @buffint = ' + convert(varchar, @buffint) + ';
	set @writeint = ' + convert(varchar, @writeint) + ';
	set @delint = ' + convert(varchar, @delint) + ';
	set @retrycnt = 0;
	set @writecnt = 0;
	set @prevRecCnt = 0;
	set @deltaRecCnt = 0;

	select @minnum=min([test_id]) from [' + @dbname + '].[dbo].[utl_testtable' +  convert(varchar, isnull(@agent_num,'')) + '];
	set @minnum = isnull(@minnum,1);
	set @delrecs = @interval * .1;

	set @delrecs = case when @delrecs = 0 then 1
						when @delrecs > 10 then 10
						else @delrecs
					end

	select @cnt=isnull(@minnum, 1), @maxnum=isnull(@minnum,1)+@rec_cnt, @scnt=1, @dcnt=1;


	while @cnt between @minnum and @maxnum
	begin
		-- select @randomint = [RandomInt] from [master].dbo.uvw_getRandomInt;
		-- select [@randomint]=@randomint;
		-- CHECKPOINT

		set @name = ''' + @nameval + ' --- test number ['' + convert(varchar, @cnt) + '']nth'';
		set @description = ''' + @description + ' --- test number ['' + convert(varchar, @cnt) + '']nth'';

		select @currRecCnt = count(*), @deltaRecCnt = (count(*) - @prevRecCnt)  from [' + @dbname + '].[dbo].[utl_testtable' +  convert(varchar, isnull(@agent_num,'')) + '];
		print ''Current Record Count is: ['' + convert(varchar, @currRecCnt) + '']... that is a delta of: ['' + convert(varchar,@deltaRecCnt) + '']'';
		set @prevRecCnt = @currRecCnt;

		if ((@ins = 1) and (@writecnt = @writeint))
		begin
			INSERT INTO [' + @dbname + '].[dbo].[utl_testtable' +  convert(varchar, isnull(@agent_num,'')) + '] ([name],[description])
				VALUES (@name, @description);
			set @writecnt = 0;
		end

		if (' + convert(varchar, @clsbuff) + ' = 1) and ((@cnt % @buffint) = 0) begin
			CHECKPOINT;
			DBCC DROPCLEANBUFFERS;
		end
		set nocount on;

		doselect:
		EXECUTE @randomint = [master].dbo.usp_getRandomInt; 
		if (((@scnt = @interval) and (@retrycnt <= @retry)) and @sel = 1)
		begin
			set @findrec = abs(@minnum - @randomint);
			if exists (select * from [' + @dbname + '].[dbo].[utl_testtable' +  convert(varchar, isnull(@agent_num,'')) + '] where [test_id] = @findrec)
			begin
				print ''select record found with [test_id] = '' + convert(varchar(50), @findrec);
				select @recfound = description from [' + @dbname + '].[dbo].[utl_testtable' +  convert(varchar, isnull(@agent_num,'')) + '] where [test_id] = @findrec;
				if object_id(''tempdb..#tmptbl'') is not null drop table #tmptbl;
					select * into #tmptbl from [' + @dbname + '].[dbo].[utl_testtable' +  convert(varchar, isnull(@agent_num,'')) + '] where [test_id] between 0 and @findrec;
				select @recsSelected=''records selected : ['' + convert(varchar(50), count(*)) + '']'' from #tmptbl;
				print @recfound;
				print @recsSelected;
				if object_id(''tempdb..#tmptbl'') is not null drop table #tmptbl;
			end
			else
			begin
				print ''retrying doselect...'';
				set @retrycnt +=1;
				goto doselect;
			end
			set @retrycnt = 0;
			set @scnt = 0;
		end

		dodelete:
		EXECUTE @randomint = [master].dbo.usp_getRandomInt; 
		set @findrec = abs(@minnum - @randomint);
		if (((@dcnt = @delint) and (@retrycnt <= @retry)) and @del = 1)
		begin
			if exists (select * from [' + @dbname + '].[dbo].[utl_testtable' +  convert(varchar, isnull(@agent_num,'')) + '] where [test_id] = @findrec)
			begin
				print ''deleting '' + convert(varchar, @delrecs) + '' record(s) with [test_id] <= '' + convert(varchar(50), @findrec);
				delete top (@delrecs) from [' + @dbname + '].[dbo].[utl_testtable' +  convert(varchar, isnull(@agent_num,'')) + '] where [test_id] <= @findrec;
			end
			else
			begin
				print ''retrying dodelete...'';
				set @retrycnt +=1;
				goto dodelete;
			end
			set @dcnt = 0
			set @retrycnt = 0;
		end

		-- print @name + '' -----'' + @description;
		set @cnt +=1;
		set @scnt +=1;
		set @dcnt +=1;
		set @writecnt +=1;
		WAITFOR DELAY ''' + @thottle + '''
	end





	--SELECT top 1 [test_id]
	--      ,[name]
	--      ,[description]
	--  FROM [' + @dbname + '].[dbo].[utl_testtable' +  convert(varchar, isnull(@agent_num,'')) + ']''';



end
if @debug = 1 begin
	print @tsql;
	select [@tsql_len]=len(@tsql);
end
else exec (@tsql);
-- else exec sp_executesql @statement = @tsql;

