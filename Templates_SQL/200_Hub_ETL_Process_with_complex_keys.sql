USE [Sandbox];

-- Parameters
DECLARE @targetDatabase			VARCHAR(100) = '[200_Integration_Layer]';
DECLARE @targetSchema			VARCHAR(100) = 'dbo'
DECLARE @sourceDatabase			VARCHAR(100) = '[100_Staging_Area]';
DECLARE @sourceSchema			VARCHAR(100) = 'dbo'
DECLARE @loadDateTimeAttribute	VARCHAR(100) = 'LOAD_DATETIME'
DECLARE @etlProcessIdAttribute	VARCHAR(100) = 'ETL_INSERT_RUN_ID'
DECLARE @recordSourceAttribute	VARCHAR(100) = 'RECORD_SOURCE'

-- Variables / metadata (from the metadata database)
DECLARE @targetTable			VARCHAR(100);
DECLARE @sourceTable			VARCHAR(100);
DECLARE @targetBusinessKey		VARCHAR(MAX);
DECLARE @sourceBusinessKey		VARCHAR(MAX);

-- Variables / local
DECLARE @pattern				VARCHAR(MAX); -- The complete selection / generated output 
DECLARE @targetHashKeyName		VARCHAR(100); -- The derived name of the Hash Key

DECLARE @keyPartSource			VARCHAR(100); -- The key component (source name), in case of composite or concatenated keys
DECLARE @keyPartTarget			VARCHAR(100); -- The key component (target name), in case of composite or concatenated keys
DECLARE @selectPart				VARCHAR(4000);
DECLARE @groupByPart			VARCHAR(4000);
DECLARE @aliasPart				VARCHAR(4000);
DECLARE @joinPart				VARCHAR(4000);
DECLARE @wherePart				VARCHAR(4000);


DECLARE hub_cursor CURSOR FOR   
  SELECT [TARGET_NAME],[TARGET_BUSINESS_KEY_DEFINITION],[SOURCE_NAME],[SOURCE_BUSINESS_KEY_DEFINITION] 
  FROM interface.[INTERFACE_SOURCE_HUB_XREF]
  -- WHERE [TARGET_NAME] IN ('HUB_MEMBERSHIP_PLAN', 'HUB_SEGMENT') -- The complex examples, but simple ones are support also


OPEN hub_cursor  

FETCH NEXT FROM hub_cursor   
INTO @targetTable, @targetBusinessKey, @sourceTable, @sourceBusinessKey

WHILE @@FETCH_STATUS = 0  
BEGIN  
	--Clear local variables before each iteration
	SET @selectPart = '';
	SET @groupByPart = '';
	SET @aliasPart = '';
	SET @joinPart = '';
	SET @wherePart = '';

	--Create JOIN and WHERE conditions
	DECLARE keypart_cursor CURSOR FOR
	WITH [MAINQUERY] AS
	(
	SELECT
		[TARGET_NAME],
		[SOURCE_NAME],
		[BUSINESS_KEY_COMPOSITION],
		CASE
			WHEN [BUSINESS_KEY_COMPOSITION]='Concatenate' THEN REPLACE(SOURCE_BUSINESS_KEY_DEFINITION,',','+')
			ELSE [SOURCE_BUSINESS_KEY_DEFINITION]
		END AS [SOURCE_BUSINESS_KEY_DEFINITION],
		[TARGET_BUSINESS_KEY_DEFINITION]
	FROM 
	(
	  SELECT 
	    [TARGET_NAME],
	    [SOURCE_NAME],
	    CASE 
	  	WHEN CHARINDEX('COMPOSITE(',[SOURCE_BUSINESS_KEY_DEFINITION], 1) > 0 THEN 'Composite' 
	  	WHEN CHARINDEX('CONCATENATE(',[SOURCE_BUSINESS_KEY_DEFINITION], 1) > 0 THEN 'Concatenate' 
	  	ELSE 'Regular'
	    END AS [BUSINESS_KEY_COMPOSITION],
	    REPLACE(
	  	REPLACE(
	  		REPLACE(
	  			REPLACE([SOURCE_BUSINESS_KEY_DEFINITION],'COMPOSITE(','')
	  		,'CONCATENATE(','')
	  	,')','')
	    ,';',',') AS [SOURCE_BUSINESS_KEY_DEFINITION], -- Strip out any metadata information i.e. classification, commas and brackets
	    [TARGET_BUSINESS_KEY_DEFINITION]
	  FROM interface.[INTERFACE_SOURCE_HUB_XREF]
	  WHERE [TARGET_NAME] = ''+@targetTable+'' AND [SOURCE_NAME] = ''+@sourceTable+'' AND [SOURCE_BUSINESS_KEY_DEFINITION] = ''+@sourceBusinessKey+''
	) sub
	-- Define the source business key as XML
	), [SOURCEKEY] AS
	(   
	SELECT 
	  [TARGET_NAME],
	  [SOURCE_NAME],
	  [BUSINESS_KEY_COMPOSITION],
	  [SOURCE_BUSINESS_KEY_DEFINITION], 
	  CAST ('<M>' + REPLACE([SOURCE_BUSINESS_KEY_DEFINITION], ',', '</M><M>') + '</M>' AS XML) AS [BUSINESS_KEY_SOURCE_XML]
	FROM [MAINQUERY] 
	-- Define the target business key as XML
	), [TARGETKEY] AS
	(     
	SELECT 
	  [TARGET_NAME],
	  [SOURCE_NAME],
	  [BUSINESS_KEY_COMPOSITION],
	  [TARGET_BUSINESS_KEY_DEFINITION],
	  CAST ('<M>' + REPLACE([TARGET_BUSINESS_KEY_DEFINITION], ',', '</M><M>') + '</M>' AS XML) AS [BUSINESS_KEY_TARGET_XML]
	FROM [MAINQUERY] 
	-- Break up the source business key in parts to support composite keys
	), [SOURCEKEYPARTS] AS
	( 
	SELECT 
	  [TARGET_NAME],
	  [SOURCE_NAME],
	  [BUSINESS_KEY_COMPOSITION],
	  LTRIM(Split.a.value('.', 'VARCHAR(100)')) AS [BUSINESS_KEY_PART],
	  ROW_NUMBER() OVER (PARTITION BY [TARGET_NAME], [SOURCE_NAME] ORDER BY (SELECT 100)) AS [ROW_NR]
	FROM [SOURCEKEY]
	CROSS APPLY [SOURCEKEY].[BUSINESS_KEY_SOURCE_XML].nodes ('/M') AS Split(a)
	-- Break up the target business key to match the composite keys on ordinal position
	), [TARGETKEYPARTS] AS
	( 
	SELECT
	  [TARGET_NAME],
	  [SOURCE_NAME],
	  [BUSINESS_KEY_COMPOSITION],
	  LTRIM(Split.a.value('.', 'VARCHAR(100)')) AS [BUSINESS_KEY_PART],
	  ROW_NUMBER() OVER (PARTITION BY [TARGET_NAME], [SOURCE_NAME] ORDER BY (SELECT 100)) AS [ROW_NR]
	FROM [TARGETKEY]
	CROSS APPLY [TARGETKEY].[BUSINESS_KEY_TARGET_XML].nodes ('/M') AS Split(a)
	)
	SELECT
	  SOURCEKEYPARTS.BUSINESS_KEY_PART AS SOURCE_BUSINESS_KEY_PART,
	  TARGETKEYPARTS.BUSINESS_KEY_PART AS TARGET_BUSINESS_KEY_PART
	FROM SOURCEKEYPARTS
	JOIN TARGETKEYPARTS ON SOURCEKEYPARTS.[TARGET_NAME]=TARGETKEYPARTS.[TARGET_NAME] AND SOURCEKEYPARTS.[SOURCE_NAME] = TARGETKEYPARTS.[SOURCE_NAME]
	WHERE SOURCEKEYPARTS.ROW_NR = TARGETKEYPARTS.ROW_NR

	OPEN keypart_cursor
	  
	FETCH NEXT FROM keypart_cursor INTO @keyPartSource, @keyPartTarget
	
	WHILE @@FETCH_STATUS = 0  
	BEGIN  

		-- Also support concatenate keys
		SELECT @keyPartSource = REPLACE(@keyPartSource,'+',' + ')

		-- Evaluate the various pattern snippets, also taking hard-coded values in consideration
		IF CHARINDEX('''',@keyPartSource)>0 AND CHARINDEX('+',@keyPartSource)=0
		BEGIN			
			SET @selectPart = @selectPart+'    ISNULL(RTRIM(CONVERT(NVARCHAR(100), '+ @keyPartSource +')),''NA'')+''|'' +'+CHAR(13);
			SET @aliasPart = @aliasPart + '  '+@keyPartSource+' AS '+@keyPartTarget+','+CHAR(13);
			SET @joinPart = @joinPart + '  '+@keyPartSource+' = hub.'+@keyPartTarget+' AND'+CHAR(13);
			SET @wherePart = @wherePart + '  '+@keyPartSource+' IS NOT NULL AND hub.'+@keyPartTarget+' IS NULL AND'+CHAR(13);
		END
		ELSE
		BEGIN
			SET @selectPart = @selectPart+'    ISNULL(RTRIM(CONVERT(NVARCHAR(100), stg.'+ @keyPartSource +')),''NA'')+''|'' +'+CHAR(13);
			SET @groupByPart = @groupByPart+'  stg.'+@keyPartSource+','+CHAR(13);
			SET @aliasPart = @aliasPart + '  stg.'+@keyPartSource+' AS '+@keyPartTarget+','+CHAR(13);
			SET @joinPart = @joinPart + '  stg.'+@keyPartSource+' = hub.'+@keyPartTarget+' AND'+CHAR(13);
			SET @wherePart = @wherePart + '  stg.'+@keyPartSource+' IS NOT NULL AND hub.'+@keyPartTarget+' IS NULL AND'+CHAR(13);
		END

		FETCH NEXT FROM keypart_cursor   
		INTO  @keyPartSource, @keyPartTarget
	END  

	CLOSE keypart_cursor;  
	DEALLOCATE keypart_cursor;  
	--End of key part cursor

	--Remove trailing parts from key parts
	SET @selectPart		= LEFT(@selectPart,DATALENGTH(@selectPart)-2)
	SET @groupByPart	= LEFT(@groupByPart,DATALENGTH(@groupByPart)-2)
	SET @aliasPart		= LEFT(@aliasPart,DATALENGTH(@aliasPart)-1)
	SET @joinPart		= LEFT(@joinPart,DATALENGTH(@joinPart)-4)
	SET @wherePart		= LEFT(@wherePart,DATALENGTH(@wherePart)-4)
					
	--Derive the hash key column name
	SET @targetHashKeyName = REPLACE(@targetTable,'HUB_','') +'_HSH';

	--Insert into pattern
 	SET @pattern = '-- Working on mapping to ' +  @targetTable + ' from source table ' + @sourceTable+CHAR(13)+CHAR(13);
	SET @pattern = @pattern+'USE '+@targetDatabase+CHAR(13)+CHAR(13);

	SET @pattern = @pattern+'INSERT INTO '+@targetDatabase+'.'+@targetSchema+'.'+@targetTable+CHAR(13);
	SET @pattern = @pattern+'('+@targetHashKeyName+', '+@targetBusinessKey+', '+@loadDateTimeAttribute+', '+@etlProcessIdAttribute+', '+@recordSourceAttribute+')'+CHAR(13);
	SET @pattern = @pattern+'SELECT'+CHAR(13);
	SET @pattern = @pattern+'  HASHBYTES(''MD5'','+CHAR(13);
	SET @pattern = @pattern+''+@selectPart+CHAR(13);
	SET @pattern = @pattern+'  ) AS '+@targetHashKeyName+','+CHAR(13);
	SET @pattern = @pattern+''+@aliasPart+CHAR(13);
	SET @pattern = @pattern+'  MIN(stg.'+@loadDateTimeAttribute+') AS '+@loadDateTimeAttribute+','+CHAR(13);
	SET @pattern = @pattern+'  -1 AS '+@etlProcessIdAttribute+','+CHAR(13);
	SET @pattern = @pattern+'  stg.'+@recordSourceAttribute+''+CHAR(13);
	SET @pattern = @pattern+'FROM '+@sourceDatabase+'.dbo.'+@sourceTable+' stg'+CHAR(13);
	SET @pattern = @pattern+'LEFT OUTER JOIN '+@targetDatabase+'.dbo.'+@targetTable+' hub ON '+CHAR(13);
	SET @pattern = @pattern+''+@joinPart+CHAR(13);
	SET @pattern = @pattern+'WHERE '+CHAR(13);
	SET @pattern = @pattern+''+@wherePart+CHAR(13);
	SET @pattern = @pattern+'GROUP BY'+CHAR(13);
	SET @pattern = @pattern+'  HASHBYTES(''MD5'','+CHAR(13);
	SET @pattern = @pattern+''+@selectPart+CHAR(13);
	SET @pattern = @pattern+'  ),'+CHAR(13);
	SET @pattern = @pattern+'  stg.'+@recordSourceAttribute+','+CHAR(13);;   
	SET @pattern = @pattern+@groupByPart

   	PRINT @pattern+CHAR(13);     
		 
    FETCH NEXT FROM hub_cursor   
	INTO @targetTable, @targetBusinessKey, @sourceTable, @sourceBusinessKey
END  
 
CLOSE hub_cursor;  
DEALLOCATE hub_cursor;  