USE [master]
GO
/****** Object:  StoredProcedure [dbo].[usp_getRandomInt]    Script Date: 8/21/2017 7:30:53 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


ALTER procedure [dbo].[usp_getRandomInt] 
as
	-- https://stackoverflow.com/questions/4492205/convert-varchar-to-ascii
	declare @RandomVal varchar(5), @RandomInt bigint;
	-- SELECT @RandomInt=CONVERT(bigint, REPLACE(REPLACE(substring(CONVERT(varchar(12), RAND(CAST(CAST(NEWID() AS varbinary(8)) AS int))), 1,12), '0', ''), '.', ''));
	SELECT @RandomVal=REPLACE(REPLACE(substring(CONVERT(varchar(12), RAND(CAST(CAST(NEWID() AS varbinary(8)) AS int))), 1,5), '0', ''), '.', '');
	DECLARE @count INT, @ascii VARCHAR(MAX);

	set @count = 1;
	set @ascii = '';

	WHILE @count <= DATALENGTH(@RandomVal)
	BEGIN
		SELECT @ascii = @ascii + convert(varchar(200), ASCII(SUBSTRING(@RandomVal, @count, 1)));
		SET @count += 1
	END

	SET @RandomInt = CONVERT(BIGINT, @ascii);

	--;WITH AllNumbers AS
	--(
	--	SELECT 1 AS Number
	--	UNION ALL
	--	SELECT Number+1
	--		FROM AllNumbers
	--		WHERE Number<LEN(@RandomVal)
	--)
	--SELECT @RandomInt = 
	--	   (SELECT
	--			ASCII(SUBSTRING(@RandomVal,Number,1))
	--			FROM AllNumbers
	--			ORDER BY Number
	--			FOR XML PATH(''), TYPE
	--	   ).value('.','varchar(max)')

	RETURN @RandomInt

