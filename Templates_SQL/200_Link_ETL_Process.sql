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
DECLARE @hubTable				VARCHAR(100);
DECLARE @sourceBusinessKey		VARCHAR(MAX);

-- Variabels local / helper
DECLARE @pattern				VARCHAR(MAX);  -- The complete selection / generated output 
DECLARE @targetHashKey			VARCHAR(MAX);  -- The derived name of the Hash Key
DECLARE @keyPartSource			VARCHAR(MAX);  -- The key component (source name), in case of composite or concatenated keys
DECLARE @keyPartTarget			VARCHAR(MAX);  -- The key component (target name), in case of composite or concatenated keys
DECLARE @selectOuterPart		VARCHAR(MAX);  -- The outer query selection, created from the Link Key and Hub Key names
DECLARE @groupByOuterPart		VARCHAR(MAX); -- The Group By statement build up from the Link and Hub Hash Key attributes
DECLARE @selectInnerPart		VARCHAR(MAX);  -- The inner query selection, which includes the Hub Hash key results
DECLARE @joinPart				VARCHAR(MAX);
DECLARE @wherePart				VARCHAR(MAX);
DECLARE @aliasPart				VARCHAR(MAX);
DECLARE @groupByPart			VARCHAR(4000);
DECLARE @hubHashKeysPart		VARCHAR(MAX);  -- The list containing the names of the Hub Hash Keys for use in the INSERT INTO and outer SELECT statement
DECLARE @lnkHashKey				VARCHAR(MAX);  -- The derived name of the Link Key
DECLARE @lnkHashKeyFunction		VARCHAR(MAX);  -- The hash calculation for the Link Key, which includes all Hub business key attributes
DECLARE @selectPart				VARCHAR(MAX); -- Used to build up individual Hub select statements
DECLARE @keyOrder				INT;

/*
Requires the following tables / views (TEAM metadata)
  - interface.INTERFACE_SOURCE_LINK_XREF, for the individual mappings
  - interface.INTERFACE_HUB_LINK_XREF, for the relationships between Hubs and Links
*/

DECLARE link_outer_cursor CURSOR FOR
SELECT 
   [SOURCE_NAME] -- The source table (i.e. STG or PSA)
  ,[TARGET_NAME] -- The link target table
  ,[SURROGATE_KEY] -- The link surrogate key attribute name
  ,[SOURCE_BUSINESS_KEY_DEFINITION] -- The business key as it is defined using source attributes
FROM interface.[INTERFACE_SOURCE_LINK_XREF]

OPEN link_outer_cursor

FETCH NEXT FROM link_outer_cursor   
INTO @sourceTable, @targetTable, @targetHashKey, @sourceBusinessKey

WHILE @@FETCH_STATUS = 0  
BEGIN  
	--Clear or set local variables for iteration across Link generation output
	SET @lnkHashKey = '';
	SET @selectOuterPart = '';
	SET @groupByOuterPart = '';
	SET @selectInnerPart = '';
	SET @joinPart = '';
	SET @wherePart = '';
	SET @lnkHashKey = '';
	SET @lnkHashKeyFunction='';
	SET @hubHashKeysPart ='';

	--Commence defining the outer query select statement by adding the Link Hash Key attribute name
	SET @selectOuterPart = @selectOuterPart + '  sub.'+@lnkHashKey+','+CHAR(13);

	--Commence defining the outer Group By statement by adding the Link Hash Key attribute name
	SET @groupByOuterPart = @groupByOuterPart+'  sub.'+@lnkHashKey+','+CHAR(13);

	--Commence defining the hash function for the Link Key
	SET @lnkHashKeyFunction = @lnkHashKeyFunction+'    HASHBYTES(''MD5'','+CHAR(13);


	--Get a record for each Hub contributing to the Link 
	DECLARE link_hub_cursor CURSOR FOR   
	SELECT [HUB_NAME], [BUSINESS_KEY_DEFINITION]
	FROM interface.INTERFACE_HUB_LINK_XREF
	WHERE [LINK_NAME] = @targetTable AND
		  [SOURCE_NAME] = @sourceTable
	ORDER BY [LINK_NAME], [HUB_ORDER]

	OPEN link_hub_cursor  

	FETCH NEXT FROM link_hub_cursor   
	INTO @hubTable, @sourceBusinessKey

	WHILE @@FETCH_STATUS = 0  
	BEGIN  

	 
		FETCH NEXT FROM link_hub_cursor   
		INTO @hubTable, @sourceBusinessKey
	END  
 
	CLOSE link_hub_cursor;  
	DEALLOCATE link_hub_cursor;  
	--End of inner cursor

	--Complete the outer query selection statement
	SET @selectOuterPart = @selectOuterPart+'  sub.'+@recordSourceAttribute+','+CHAR(13);
	SET @selectOuterPart = @selectOuterPart+'  sub.'+@etlProcessIdAttribute+','+CHAR(13);
	SET @selectOuterPart = @selectOuterPart+'  MIN(sub.'+@loadDateTimeAttribute+') AS '+@loadDateTimeAttribute+CHAR(13);

	--Complete the outer Group By statement
    SET @groupByOuterPart = @groupByOuterPart+'  sub.'+@recordSourceAttribute+','+CHAR(13);
    SET @groupByOuterPart = @groupByOuterPart+'  sub.'+@etlProcessIdAttribute+CHAR(13);

	--Complete the inner query selection statement
	SET @selectInnerPart = @selectInnerPart+'    stg.'+@loadDateTimeAttribute+','+CHAR(13);
	SET @selectInnerPart = @selectInnerPart+'    stg.'+@recordSourceAttribute+','+CHAR(13);
	SET @selectInnerPart = @selectInnerPart+'    -1 AS '+@etlProcessIdAttribute+CHAR(13);


	SET @joinPart = @joinPart+'LEFT OUTER JOIN '+@targetDatabase+'.dbo.'+@targetTable+' lnk '+CHAR(13);
	SET @joinPart = @joinPart+'  ON sub.'+@lnkHashKey+' = '+'lnk.'+@lnkHashKey+CHAR(13);

	SET @wherePart = @wherePart+'WHERE lnk.'+@lnkHashKey+' IS NULL AND sub.'+@lnkHashKey+' IS NOT NULL'+CHAR(13);

	--Complete the definition of the Link key
	SET @lnkHashKeyFunction = LEFT(@lnkHashKeyFunction,DATALENGTH(@lnkHashKeyFunction)-2)+CHAR(13)
	SET @lnkHashKeyFunction = @lnkHashKeyFunction+'    ) AS '+@lnkHashKey+','+CHAR(13);

	--Spool output to disk
 	SET @pattern = '-- Working on mapping to ' +  @targetTable + ' from source table ' + @sourceTable+CHAR(13)+CHAR(13);
	SET @pattern = @pattern+'USE '+@sourceDatabase+CHAR(13)+CHAR(13);
	SET @pattern = @pattern+'INSERT INTO '+@targetDatabase+'.'+@targetSchema+'.'+@targetTable+CHAR(13);
	SET @pattern = @pattern+'('+@targetHashKey+','+@lnkHashKey+', '+@hubHashKeysPart + @recordSourceAttribute+', '+@etlProcessIdAttribute+', '+@loadDateTimeAttribute+')'+CHAR(13);
	SET @pattern = @pattern+'SELECT'+CHAR(13);
	SET @pattern = @pattern+@selectOuterPart;
	SET @pattern = @pattern+'FROM ('+CHAR(13);
	SET @pattern = @pattern+'  SELECT'+CHAR(13);
	SET @pattern = @pattern+@lnkHashKeyFunction;	-- Add the Link Hash Key 
	SET @pattern = @pattern+@selectInnerPart;		-- Add the individual Hub Hash Keys (2 or more)
	SET @pattern = @pattern+'  FROM '+@sourceTable+' stg'+CHAR(13);
	SET @pattern = @pattern+') sub'+CHAR(13);
	SET @pattern = @pattern+@joinPart;				-- Add the JOIN condition 
	SET @pattern = @pattern+@wherePart;				-- Add the WHERE predicate
	SET @pattern = @pattern+'GROUP BY'+CHAR(13);	
	SET @pattern = @pattern+@groupByOuterPart;		-- Add the GROUP BY statement

   	PRINT @pattern+CHAR(13);

FETCH NEXT FROM link_outer_cursor   
INTO @sourceTable, @targetTable, @targetHashKey, @sourceBusinessKey

END

CLOSE link_outer_cursor;
DEALLOCATE link_outer_cursor; 