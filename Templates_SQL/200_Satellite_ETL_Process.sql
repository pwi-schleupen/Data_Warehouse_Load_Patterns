USE [Sandbox];


-- Parameters
DECLARE @targetDatabase						VARCHAR(100) = '[200_Integration_Layer]';
DECLARE @targetSchema						VARCHAR(100) = '[dbo]';
DECLARE @sourceDatabase						VARCHAR(100) = '[100_Staging_Area]';
DECLARE @sourceSchema						VARCHAR(100) = '[dbo]';
DECLARE @loadDateTimeAttribute				VARCHAR(100) = '[LOAD_DATETIME]';
DECLARE @etlProcessIdAttribute				VARCHAR(100) = '[ETL_INSERT_RUN_ID]';
DECLARE @etlProcessIdUpdateAttribute		VARCHAR(100) = '[ETL_UPDATE_RUN_ID]';
DECLARE @recordSourceAttribute				VARCHAR(100) = '[RECORD_SOURCE]';
DECLARE @loadEndDateTimeAttribute			VARCHAR(100) = '[LOAD_END_DATETIME]';
DECLARE @currentRecordIndicatorAttribute	VARCHAR(100) = '[CURRENT_RECORD_INDICATOR]';
DECLARE @eventDateTimeAttribute				VARCHAR(100) = '[EVENT_DATETIME]';
DECLARE @checksumAttribute					VARCHAR(100) = '[HASH_FULL_RECORD]';
DECLARE @cdcAttribute						VARCHAR(100) = '[CDC_OPERATION]';
DECLARE @sourceRowIdAttribute				VARCHAR(100) = '[SOURCE_ROW_ID]';

-- Variables input / metadata (from the metadata database)
DECLARE @targetTable						VARCHAR(100);	-- The Satellite (target) table name
DECLARE @sourceTable						VARCHAR(100);	-- The source table name
DECLARE @sourceBusinessKey					VARCHAR(MAX);
DECLARE @sourceAttributeName				VARCHAR(MAX);	-- A local variable for use in the attribute cursor
DECLARE @targetAttributeName				VARCHAR(MAX);	-- A local variable for use in the attribute cursor

-- Variabels local / helper
DECLARE @pattern							VARCHAR(MAX);	-- The complete selection / generated output 
DECLARE @targetHashKeyName					VARCHAR(100);	-- The derived name of the Hash Key
DECLARE @hubHashKeySelectPart				VARCHAR(MAX);   -- The selection inside the hashbytes function (to define the Hash Key)
DECLARE @keyPartSource						VARCHAR(100);	-- The key component (source name), in case of composite or concatenated keys
DECLARE @keyPartTarget						VARCHAR(100);	-- The key component (target name), in case of composite or concatenated keys
DECLARE @keyPartConvertPart					VARCHAR(100);	-- The key component block that needs to be VARCHAR for lead/lag purposes in the row condensing
DECLARE @attributeSelectPartSource			VARCHAR(MAX);	-- The listing of all in-scope attributes for the SELECT statement (inserted as a block)
DECLARE @attributeSelectPartTarget			VARCHAR(MAX);	-- The listing of all in-scope attributes for the SELECT statement (inserted as a block)
DECLARE @attributeSelectPartSourceAsTarget	VARCHAR(MAX);	-- The listing of all in-scope attributes for the SELECT statement (inserted as a block)
DECLARE @attributesBasePart					VARCHAR(MAX);	-- The listing of attributes without the business key for change evaluation (combined value)
DECLARE @attributeChecksumPart				VARCHAR(MAX);	-- The constructed hashbytes for all attributes (inserted as a block)
DECLARE @keyPartSelectPart					VARCHAR(MAX);	-- The listing of all business key (part) attributes for the SELECT statement (inserted as a block)


-- The cursor is designed to 'pull' into the target Satellite, as opposed to 'push' from the source. This provides better control of which metadata gets used.
-- This cursor is the main / 'outer' cursor which cycles through the tables and creates the source-to-staging pattern
DECLARE sat_cursor CURSOR FOR   
  SELECT [SOURCE_NAME], [TARGET_NAME], [SOURCE_BUSINESS_KEY_DEFINITION], [SURROGATE_KEY]
  FROM [interface].[INTERFACE_SOURCE_SATELLITE_XREF]
  WHERE [TARGET_TYPE] = 'Normal'-- AND [TARGET_NAME]='SAT_MEMBERSHIP_PLAN_VALUATION'

OPEN sat_cursor  

FETCH NEXT FROM sat_cursor   
INTO @sourceTable, @targetTable, @sourceBusinessKey, @targetHashKeyName

WHILE @@FETCH_STATUS = 0  
BEGIN

	--Clear out local variables where required for each new iteration
	SET @attributeSelectPartSource='';
	SET @attributeSelectPartTarget='';
	SET @attributeSelectPartSourceAsTarget='';
	SET @attributesBasePart='';
	SET @attributeChecksumPart='';
	SET @hubHashKeySelectPart='';
	SET @keyPartConvertPart='';
	SET @keyPartSelectPart='';

	--1st inner Cursor: retrieve the attributes (from the target table)
	DECLARE attribute_cursor CURSOR FOR
		SELECT [SOURCE_ATTRIBUTE_NAME], [TARGET_ATTRIBUTE_NAME]
		FROM [interface].[INTERFACE_SOURCE_SATELLITE_ATTRIBUTE_XREF]
		WHERE [TARGET_NAME] = ''+@targetTable+''
		AND [SOURCE_NAME] = ''+@sourceTable+''

	OPEN attribute_cursor
	  
	FETCH NEXT FROM attribute_cursor INTO @sourceAttributeName, @targetAttributeName

	WHILE @@FETCH_STATUS = 0  
	BEGIN  

	    -- Construct the block of attributes for use in SELECT statements
		SET @attributeSelectPartSource = @attributeSelectPartSource+'    ['+@sourceAttributeName+'],'+CHAR(13);
		SET @attributesBasePart = @attributesBasePart+'    ['+@sourceAttributeName+'],'+CHAR(13);
		SET @attributeSelectPartTarget = @attributeSelectPartTarget+'  ['+@targetAttributeName+'],'+CHAR(13);

		-- Construct the checksum across all attributes
		SET @attributeChecksumPart = @attributeChecksumPart+'       ISNULL(RTRIM(CONVERT(NVARCHAR(100),['+ @sourceAttributeName +'])),''NA'')+''|'' +'+CHAR(13);

		-- Create the aliases
		SET @attributeSelectPartSourceAsTarget = @attributeSelectPartSourceAsTarget+'  ['+@sourceAttributeName+'] AS ['+@targetAttributeName+'],'+CHAR(13);

		FETCH NEXT FROM attribute_cursor INTO @sourceAttributeName, @targetAttributeName
	END  

	CLOSE attribute_cursor;  
	DEALLOCATE attribute_cursor;  
	--End of attribute cursor

	-- 2nd inner cursor - understand the key configuration
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
	  FROM interface.[INTERFACE_SOURCE_SATELLITE_XREF]
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
	  SOURCEKEYPARTS.BUSINESS_KEY_PART AS SOURCE_BUSINESS_KEY_PART
	 ,TARGETKEYPARTS.BUSINESS_KEY_PART AS TARGET_BUSINESS_KEY_PART
	FROM SOURCEKEYPARTS
	JOIN TARGETKEYPARTS ON SOURCEKEYPARTS.[TARGET_NAME]=TARGETKEYPARTS.[TARGET_NAME] AND SOURCEKEYPARTS.[SOURCE_NAME] = TARGETKEYPARTS.[SOURCE_NAME]
	WHERE SOURCEKEYPARTS.ROW_NR = TARGETKEYPARTS.ROW_NR

	OPEN keypart_cursor
	  
	FETCH NEXT FROM keypart_cursor INTO @keyPartSource, @keyPartTarget
	
	WHILE @@FETCH_STATUS = 0  
	BEGIN  

		SET @hubHashKeySelectPart = @hubHashKeySelectPart+'    ISNULL(RTRIM(CONVERT(NVARCHAR(100),['+ @keyPartTarget +'])),''NA'')+''|'' +'+CHAR(13);

		SET @keyPartConvertPart = @keyPartConvertPart + '    CAST('+@keyPartSource+' AS NVARCHAR(100)) AS '+@keyPartTarget+','+CHAR(13);

		SET @keyPartSelectPart = @keyPartSelectPart + '     [' + @keyPartTarget+'],'+CHAR(13);

	    -- Remove the business key from the attribute base array
		SET @attributesBasePart = REPLACE(@attributesBasePart,@keyPartSource,''); --Remove the business key from the base attribute list

		FETCH NEXT FROM keypart_cursor   
		INTO  @keyPartSource, @keyPartTarget
	END  

	CLOSE keypart_cursor;  
	DEALLOCATE keypart_cursor;  
	--End of key part cursor

	-- Remove trailing commas and delimiters	
	--SET @attributeSelectPartSource = LEFT(@attributeSelectPartSource,DATALENGTH(@attributeSelectPartSource)-2)+CHAR(13);
	SET @attributeSelectPartTarget = LEFT(@attributeSelectPartTarget,DATALENGTH(@attributeSelectPartTarget)-2)+CHAR(13);
	SET @attributeSelectPartSourceAsTarget = LEFT(@attributeSelectPartSourceAsTarget,DATALENGTH(@attributeSelectPartSourceAsTarget)-2)+CHAR(13);
	SET @hubHashKeySelectPart = LEFT(@hubHashKeySelectPart,DATALENGTH(@hubHashKeySelectPart)-2)+CHAR(13);
	SET @attributeChecksumPart = LEFT(@attributeChecksumPart,DATALENGTH(@attributeChecksumPart)-2)+CHAR(13);
	SET @keyPartSelectPart = LEFT(@keyPartSelectPart,DATALENGTH(@keyPartSelectPart)-2)+CHAR(13);

	-- Source to Staging Full Outer Join Pattern
 	SET @pattern = '-- Working on mapping to ' +  @targetTable + ' from source table ' + @sourceTable+CHAR(13)+CHAR(13);
	SET @pattern = @pattern+'USE '+@targetDatabase+';'+CHAR(13)+CHAR(13);
	SET @pattern = @pattern+'INSERT INTO '+@targetDatabase+'.'+@targetSchema+'.['+@targetTable+']'+CHAR(13);
	SET @pattern = @pattern+'('+CHAR(13)
	SET @pattern = @pattern+'  ['+@targetHashKeyName+'],'+CHAR(13);	
	SET @pattern = @pattern+'  '+@checksumAttribute+','+CHAR(13);
	SET @pattern = @pattern+'  '+@loadDateTimeAttribute+','+CHAR(13);
	SET @pattern = @pattern+'  '+@loadEndDateTimeAttribute+','+CHAR(13);
	SET @pattern = @pattern+'  '+@currentRecordIndicatorAttribute+','+CHAR(13);
	SET @pattern = @pattern+'  '+@etlProcessIdAttribute+','+CHAR(13);
	SET @pattern = @pattern+'  '+@etlProcessIdUpdateAttribute+','+CHAR(13);
	SET @pattern = @pattern+'  '+@recordSourceAttribute+','+CHAR(13);
	SET @pattern = @pattern+'  '+@cdcAttribute+','+CHAR(13);
	SET @pattern = @pattern+'  '+@sourceRowIdAttribute+','+CHAR(13);
	SET @pattern = @pattern+''+@attributeSelectPartTarget;-- Add the attribtes to insert into the target table
	SET @pattern = @pattern+')'+CHAR(13); 

	-- Outer selection
	SET @pattern = @pattern+'SELECT main.* FROM ('+CHAR(13);

	-- Start of the SELECT statement
	SET @pattern = @pattern+'SELECT'+CHAR(13);
	SET @pattern = @pattern+'  HASHBYTES(''MD5'','+CHAR(13);
	SET @pattern = @pattern+''+@hubHashKeySelectPart;
	SET @pattern = @pattern+'  ) AS ['+@targetHashKeyName+'],'+CHAR(13);
	SET @pattern = @pattern+'  HASHBYTES(''MD5'','+CHAR(13);
	SET @pattern = @pattern+'    ISNULL(RTRIM(CONVERT(NVARCHAR(100),'+@cdcAttribute+')),''NA'')+''|''+'+CHAR(13);
	SET @pattern = @pattern+@attributeChecksumPart;
	SET @pattern = @pattern+'  ) AS '+@checksumAttribute+','+CHAR(13);
	SET @pattern = @pattern+'  DATEADD(mcs,'+@sourceRowIdAttribute+','+@loadDateTimeAttribute+') AS '+@loadDateTimeAttribute+','+CHAR(13); 
	SET @pattern = @pattern+' '+' ''9999-12-31'''+@loadEndDateTimeAttribute+','+CHAR(13);
	SET @pattern = @pattern+' '+' ''Y'''+@currentRecordIndicatorAttribute+','+CHAR(13);
	SET @pattern = @pattern+'  -1 AS '+@etlProcessIdAttribute+','+CHAR(13);
	SET @pattern = @pattern+'  -1 AS '+@etlProcessIdUpdateAttribute+','+CHAR(13);
	SET @pattern = @pattern+'  '+@recordSourceAttribute+','+CHAR(13);
	SET @pattern = @pattern+'  '+@cdcAttribute+','+CHAR(13);
	SET @pattern = @pattern+'  '+@sourceRowIdAttribute+','+CHAR(13);
	SET @pattern = @pattern+''+@attributeSelectPartSourceAsTarget;
    SET @pattern = @pattern+'FROM'+CHAR(13);
	-- Start of the first sub query
	SET @pattern = @pattern+'('+CHAR(13);
	SET @pattern = @pattern+' SELECT '+CHAR(13);
	SET @pattern = @pattern+'    '+@loadDateTimeAttribute+','+CHAR(13);
	SET @pattern = @pattern+'    '+@recordSourceAttribute+','+CHAR(13);
	SET @pattern = @pattern+'    '+@cdcAttribute+','+CHAR(13);
	SET @pattern = @pattern+'    '+@sourceRowIdAttribute+','+CHAR(13);
	SET @pattern = @pattern+'    '+@eventDateTimeAttribute+','+CHAR(13);
	SET @pattern = @pattern+'    [COMBINED_VALUE],'+CHAR(13);
	SET @pattern = @pattern+@keyPartSelectPart+',';
	SET @pattern = @pattern+@attributeSelectPartSource;
	SET @pattern = @pattern+'    CASE '+CHAR(13);
	SET @pattern = @pattern+'      WHEN LAG([COMBINED_VALUE],1,''N/A'') OVER (PARTITION BY '+CHAR(13);
	SET @pattern = @pattern+@keyPartSelectPart;
	SET @pattern = @pattern+'       ORDER BY '+@loadDateTimeAttribute+' ASC, '+@eventDateTimeAttribute+' ASC, '+@cdcAttribute+' DESC) = [COMBINED_VALUE]' +CHAR(13);
	SET @pattern = @pattern+'      THEN ''Same'' ELSE ''Different'''+CHAR(13);
	SET @pattern = @pattern+'    END AS [VALUE_CHANGE_INDICATOR],'+CHAR(13);
	SET @pattern = @pattern+'    CASE WHEN LAG('+@cdcAttribute+',1,'''') OVER (PARTITION BY'+CHAR(13);
	SET @pattern = @pattern+@keyPartSelectPart;	
	SET @pattern = @pattern+'     ORDER BY '+@loadDateTimeAttribute+' ASC, '+@eventDateTimeAttribute+' ASC, '+@cdcAttribute+' ASC) = '+@cdcAttribute+''+CHAR(13);
	SET @pattern = @pattern+'      THEN ''Same'' ELSE ''Different'''+CHAR(13);
	SET @pattern = @pattern+'      END AS [CDC_CHANGE_INDICATOR],'+CHAR(13);
	SET @pattern = @pattern+'    CASE WHEN LEAD('+@loadDateTimeAttribute+',1,''9999-12-31'') OVER (PARTITION BY '+CHAR(13);
	SET @pattern = @pattern+@keyPartSelectPart;
	SET @pattern = @pattern+'       ORDER BY '+@loadDateTimeAttribute+' ASC, '+@eventDateTimeAttribute+' ASC, '+@cdcAttribute+' ASC)= '+@loadDateTimeAttribute+''+CHAR(13);
	SET @pattern = @pattern+'      THEN ''Same'' ELSE ''Different'''+CHAR(13);
	SET @pattern = @pattern+'    END AS [TIME_CHANGE_INDICATOR]'+CHAR(13);
	SET @pattern = @pattern+'FROM ('+CHAR(13);
	SET @pattern = @pattern+'SELECT'+CHAR(13);
	SET @pattern = @pattern+'    '+@loadDateTimeAttribute+','+CHAR(13);
	SET @pattern = @pattern+'    '+@eventDateTimeAttribute+','+CHAR(13);
	SET @pattern = @pattern+'    '+@recordSourceAttribute+','+CHAR(13);
	SET @pattern = @pattern+'    '+@sourceRowIdAttribute+','+CHAR(13);
	SET @pattern = @pattern+'    '+@cdcAttribute+','+CHAR(13);
	SET @pattern = @pattern+@keyPartConvertPart;
	SET @pattern = @pattern+''+@attributeSelectPartSource;
	SET @pattern = @pattern+'    CONVERT(CHAR(32),HASHBYTES(''MD5'','+CHAR(13);
	SET @pattern = @pattern+@attributeChecksumPart;
	SET @pattern = @pattern+'    ),2) AS COMBINED_VALUE'+CHAR(13);
	SET @pattern = @pattern+'  FROM '+@sourceDatabase+'.'+@sourceSchema+'.['+@sourceTable+']'+CHAR(13);
	SET @pattern = @pattern+'  ) sub'+CHAR(13);
	SET @pattern = @pattern+') combined_value'+CHAR(13);
	SET @pattern = @pattern+'WHERE ([VALUE_CHANGE_INDICATOR] =''Different'' AND '+@cdcAttribute+' IN (''Insert'', ''Change''))' +CHAR(13);
	SET @pattern = @pattern+'OR ([CDC_CHANGE_INDICATOR] = ''Different'' AND [TIME_CHANGE_INDICATOR] = ''Different'')'

	SET @pattern = @pattern+') main'+CHAR(13);

	-- Prevent reprocessing
	SET @pattern = @pattern+'LEFT OUTER JOIN '+@targetDatabase+'.'+@targetSchema+'.['+@targetTable+'] sat'+CHAR(13);
	SET @pattern = @pattern+' ON sat.['+@targetHashKeyName+'] = main.['+@targetHashKeyName+']'+CHAR(13);
	SET @pattern = @pattern+'AND sat.'+@loadDateTimeAttribute+' = main.'+@loadDateTimeAttribute+''+CHAR(13);
	SET @pattern = @pattern+'WHERE sat.['+@targetHashKeyName+'] IS NULL'+CHAR(13);
			  
	-- Spool the pattern to the console
   	PRINT @pattern+CHAR(13);     
		 
    FETCH NEXT FROM sat_cursor   
	INTO @sourceTable, @targetTable, @sourceBusinessKey, @targetHashKeyName
END  
 
CLOSE sat_cursor;  
DEALLOCATE sat_cursor;  