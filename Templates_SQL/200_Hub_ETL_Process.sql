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


DECLARE hub_cursor CURSOR FOR   
  SELECT [TARGET_NAME],[TARGET_BUSINESS_KEY_DEFINITION],[SOURCE_NAME],[SOURCE_BUSINESS_KEY_DEFINITION] 
  FROM interface.[INTERFACE_SOURCE_HUB_XREF]
  WHERE [TARGET_NAME] IN ('HUB_CUSTOMER', 'HUB_INCENTIVE_OFFER') -- The simplest examples (i.e. no complex keys)

OPEN hub_cursor  

FETCH NEXT FROM hub_cursor   
INTO @targetTable, @targetBusinessKey, @sourceTable, @sourceBusinessKey

WHILE @@FETCH_STATUS = 0  
BEGIN  
	SET @targetHashKeyName = REPLACE(@targetTable,'HUB_','') +'_HSH';

 	SET @pattern = '-- Working on mapping to ' +  @targetTable + ' from source table ' + @sourceTable+CHAR(13)+CHAR(13);
	SET @pattern = @pattern+'USE '+@sourceDatabase+CHAR(13)+CHAR(13);

	SET @pattern = @pattern+'INSERT INTO '+@targetDatabase+'.'+@targetSchema+'.'+@targetTable+CHAR(13);
	SET @pattern = @pattern+'('+@targetHashKeyName+', '+@targetBusinessKey+', '+@loadDateTimeAttribute+', '+@etlProcessIdAttribute+', '+@recordSourceAttribute+')'+CHAR(13);
	SET @pattern = @pattern+'SELECT'+CHAR(13);
	SET @pattern = @pattern+'  HASHBYTES(''MD5'','+CHAR(13);
	SET @pattern = @pattern+'    ISNULL(RTRIM(CONVERT(NVARCHAR(100), stg.'+@sourceBusinessKey+')),''NA'')+''|'''+CHAR(13);
	SET @pattern = @pattern+'  ) AS '+@targetHashKeyName+','+CHAR(13);
	SET @pattern = @pattern+'  stg.'+@sourceBusinessKey+' AS '+@targetBusinessKey+','+CHAR(13);
	SET @pattern = @pattern+'  MIN(stg.'+@loadDateTimeAttribute+') AS '+@loadDateTimeAttribute+','+CHAR(13);
	SET @pattern = @pattern+'  -1 AS '+@etlProcessIdAttribute+','+CHAR(13);
	SET @pattern = @pattern+'  stg.'+@recordSourceAttribute+''+CHAR(13);
	SET @pattern = @pattern+'FROM '+@sourceTable+' stg'+CHAR(13);
	SET @pattern = @pattern+'LEFT OUTER JOIN '+@targetDatabase+'.dbo.'+@targetTable+' hub ON stg.'+@sourceBusinessKey+' = '+@targetBusinessKey+CHAR(13);
	SET @pattern = @pattern+'WHERE stg.'+@sourceBusinessKey+ ' IS NOT NULL'+CHAR(13);
	SET @pattern = @pattern+'  AND hub.'+@targetBusinessKey+' IS NULL'+CHAR(13);
	SET @pattern = @pattern+'GROUP BY'+CHAR(13);
	SET @pattern = @pattern+'  HASHBYTES(''MD5'','+CHAR(13);
	SET @pattern = @pattern+'    ISNULL(RTRIM(CONVERT(NVARCHAR(100),stg.'+@sourceBusinessKey+')),''NA'')+''|'''+CHAR(13);
	SET @pattern = @pattern+'  ),'+CHAR(13);
	SET @pattern = @pattern+'  stg.'+@sourceBusinessKey+','+CHAR(13);   
	SET @pattern = @pattern+'  stg.'+@recordSourceAttribute+'';   

   	PRINT @pattern+CHAR(13);     
		 
    FETCH NEXT FROM hub_cursor   
	INTO @targetTable, @targetBusinessKey, @sourceTable, @sourceBusinessKey
END  
 
CLOSE hub_cursor;  
DEALLOCATE hub_cursor;  