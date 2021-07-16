USE DBA
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[IndexOptimize_Modified]') AND type in (N'P', N'PC'))
BEGIN
	EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[IndexOptimize_Modified] AS'
END
GO

ALTER PROCEDURE [dbo].[IndexOptimize_Modified]	@Databases nvarchar(max) = NULL,
												@FragmentationLow nvarchar(max) = NULL,
												@FragmentationMedium nvarchar(max) = 'INDEX_REORGANIZE,INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE',
												@FragmentationHigh nvarchar(max) = 'INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE',
												@FragmentationLevel1 int = 50,
												@FragmentationLevel2 int = 80,
												@MinNumberOfPages int = 1000,
												@MaxNumberOfPages int = NULL,
												@SortInTempdb nvarchar(max) = 'N',
												@MaxDOP int = NULL,
												@FillFactor int = NULL,
												@PadIndex nvarchar(max) = NULL,
												@LOBCompaction nvarchar(max) = 'Y',
												@UpdateStatistics nvarchar(max) = NULL,
												@OnlyModifiedStatistics nvarchar(max) = 'N',
												@StatisticsModificationLevel int = NULL,
												@StatisticsSample int = NULL,
												@StatisticsResample nvarchar(max) = 'N',
												@PartitionLevel nvarchar(max) = 'Y',
												@MSShippedObjects nvarchar(max) = 'N',
												@Indexes nvarchar(max) = NULL,
												@TimeLimit int = NULL,
												@Delay int = NULL,
												@WaitAtLowPriorityMaxDuration int = NULL,
												@WaitAtLowPriorityAbortAfterWait nvarchar(max) = NULL,
												@Resumable nvarchar(max) = 'N',
												@AvailabilityGroups nvarchar(max) = NULL,
												@LockTimeout int = NULL,
												@LockMessageSeverity int = 16,
												@DatabaseOrder nvarchar(max) = NULL,
												@DatabasesInParallel nvarchar(max) = 'N',
												@LogToTable nvarchar(max) = 'N',
												@Execute nvarchar(max) = 'Y',
												@Help bit = 0,
												@forceReInitiate bit = 0
AS
BEGIN
	SET NOCOUNT ON;

	/*	Created By:			Ajay Dwivedi
		Version:			1.0
		Modifications:		May 20, 20019 - Created for 1st time
	*/

	DECLARE @_isFreshStart bit = ISNULL(@forceReInitiate,0);
	DECLARE @c_ID BIGINT;
	DECLARE @c_DbName VARCHAR(125);
	DECLARE @c_ParameterValue VARCHAR(500);
	DECLARE @c_TotalPages BIGINT;
	DECLARE @_TotalPages_PreviousIndex BIGINT;
	DECLARE @_EndTime_PreviousIndex datetime;
	DECLARE @c_DbName_PreviousIndex VARCHAR(125);
	DECLARE @_IndexDuration_Seconds BIGINT;
	DECLARE @_DelaySeconds bigint = 0;
	DECLARE @_DelayLength char(8)= '00:00:00'
	DECLARE @c_IndexParameterValue VARCHAR(500);
	DECLARE @_SQLString NVARCHAR(MAX);
	DECLARE @tbl_Databases TABLE (ID INT IDENTITY(1,1), DBName VARCHAR(200));
	DECLARE @_IndexingStartTime datetime = GETDATE();
	DECLARE @_CountReplIndexes INT;
	DECLARE @_CountNonReplIndexes INT;
	DECLARE @_CountMin INT;
	IF OBJECT_ID('dbo.IndexProcessing_IndexOptimize') IS NULL
	BEGIN
		--DROP TABLE dbo.IndexProcessing_IndexOptimize
		CREATE TABLE dbo.IndexProcessing_IndexOptimize
			(ID BIGINT IDENTITY(1,1) PRIMARY KEY, DbName varchar(125) NOT NULL, SchemaName varchar(125) NOT NULL, TableName varchar(125) NOT NULL, IndexName varchar(125) NOT NULL, TotalPages BIGINT NOT NULL, UsedPages BIGINT NOT NULL, ParameterValue AS (QUOTENAME(DbName)+'.'+QUOTENAME(SchemaName)+'.'+QUOTENAME(TableName)+'.'+QUOTENAME(IndexName)), EntryTime datetime default getdate(), IsProcessed bit default 0);
	END
	
	-- If no remaining index is there to process, repopulate table
	IF NOT EXISTS (SELECT * FROM dbo.IndexProcessing_IndexOptimize WHERE IsProcessed = 0) OR @_isFreshStart = 1
	BEGIN
		SET @_isFreshStart = 1;
		TRUNCATE TABLE dbo.IndexProcessing_IndexOptimize;
	END
	
	-- Check is specific databases have been mentioned
	IF @Databases IS NOT NULL AND @_isFreshStart = 1
	BEGIN
		WITH t1(DBName,DBs) AS 
		(
			SELECT	CAST(LEFT(@Databases, CHARINDEX(',',@Databases+',')-1) AS VARCHAR(500)) as DBName,
					STUFF(@Databases, 1, CHARINDEX(',',@Databases+','), '') as DBs
			--
			UNION ALL
			--
			SELECT	CAST(LEFT(DBs, CHARINDEX(',',DBs+',')-1) AS VARChAR(500)) AS DBName,
					STUFF(DBs, 1, CHARINDEX(',',DBs+','), '')  as DBs
			FROM t1
			WHERE DBs > ''	
		)
		INSERT @tbl_Databases
		SELECT LTRIM(RTRIM(DBName)) FROM t1
		OPTION (MAXRECURSION 32000);
	END

	IF @_isFreshStart = 1
	BEGIN
		DECLARE cursor_Databases CURSOR LOCAL FORWARD_ONLY FAST_FORWARD READ_ONLY FOR
							SELECT DBName FROM @tbl_Databases ORDER BY DBName;

		OPEN cursor_Databases;

		FETCH NEXT FROM cursor_Databases INTO @c_DbName;
		WHILE @@FETCH_STATUS = 0
		BEGIN  
			SET @_SQLString = '
			USE '+QUOTENAME(@c_DbName)+';

			SELECT DB_NAME() as DbName, s.name as SchemaName, o.name as TableName, i.name as IndexName, SUM(a.total_pages) AS TotalPages, SUM(a.used_pages) AS UsedPages
			FROM sys.indexes AS i inner join sys.objects as o on o.object_id = i.object_id join sys.schemas as s on s.schema_id = o.schema_id
			inner join sys.partitions as p on p.object_id = i.object_id and p.index_id = i.index_id
			inner join sys.allocation_units as a on p.partition_id = a.container_id
			WHERE o.type in (''U'',''V'') AND i.name IS NOT NULL
				AND o.is_ms_shipped = 0 AND i.is_hypothetical = 0
			GROUP BY s.name, o.name, i.name
			ORDER BY TotalPages DESC
			';

			--PRINT @_SQLString;

			INSERT dbo.IndexProcessing_IndexOptimize
			(DbName, SchemaName, TableName, IndexName, TotalPages, UsedPages)
			EXEC(@_SQLString);

			FETCH NEXT FROM cursor_Databases INTO @c_DbName;
		END
	END

	SET @_CountReplIndexes = (SELECT COUNT(*) FROM dbo.IndexProcessing_IndexOptimize WHERE IsProcessed = 0 AND DbName IN (SELECT d.name FROM sys.databases as d WHERE d.is_published = 1 OR d.is_subscribed = 1 OR d.is_distributor = 1));

	SET @_CountNonReplIndexes = (SELECT COUNT(*) FROM dbo.IndexProcessing_IndexOptimize WHERE IsProcessed = 0 AND DbName NOT IN (SELECT d.name FROM sys.databases as d WHERE d.is_published = 1 OR d.is_subscribed = 1 OR d.is_distributor = 1));

	IF @_CountReplIndexes <= @_CountNonReplIndexes
		SET @_CountMin = @_CountReplIndexes;
	ELSE
		SET @_CountMin = @_CountNonReplIndexes;

	IF @_CountMin = 0
		SET @_CountMin = 50;

	DECLARE cursor_Indexes CURSOR LOCAL FORWARD_ONLY FAST_FORWARD READ_ONLY FOR
						SELECT	ID, DBName, ParameterValue, TotalPages --,RowRank = NTILE(@_CountMin)OVER(PARTITION BY IsReplIndex ORDER BY OrderID), OrderID
						FROM (
						SELECT ID, DBName, ParameterValue, TotalPages, IsReplIndex = 1, OrderID = ROW_NUMBER()OVER(ORDER BY TotalPages DESC)
						FROM dbo.IndexProcessing_IndexOptimize -- REPL databases
						WHERE IsProcessed = 0 AND DbName IN (SELECT d.name FROM sys.databases as d WHERE d.is_published = 1 OR d.is_subscribed = 1 OR d.is_distributor = 1)
						--
						UNION ALL
						--
						SELECT ID, DBName, ParameterValue, TotalPages, IsReplIndex = 0, OrderID = ROW_NUMBER()OVER(ORDER BY TotalPages DESC)
						FROM dbo.IndexProcessing_IndexOptimize -- Not REPL databases
						WHERE IsProcessed = 0 AND DbName NOT IN (SELECT d.name FROM sys.databases as d WHERE d.is_published = 1 OR d.is_subscribed = 1 OR d.is_distributor = 1)
							) AS R
						ORDER BY NTILE(@_CountMin)OVER(PARTITION BY IsReplIndex ORDER BY OrderID), OrderID;

	OPEN cursor_Indexes;

	FETCH NEXT FROM cursor_Indexes INTO @c_ID, @c_DbName,@c_IndexParameterValue, @c_TotalPages;
	WHILE @@FETCH_STATUS = 0 AND (@TimeLimit IS NULL OR (DATEDIFF(second,@_IndexingStartTime,GETDATE()) < @TimeLimit))
	BEGIN
		
		-- If Trying to Rebuild/ReOrg continsouly for Repl involved database, then Delay for 5 Minutes
		IF @c_DbName_PreviousIndex IS NOT NULL AND @_CountReplIndexes > 0 AND EXISTS (SELECT 1 FROM sys.databases as d WHERE d.name = @c_DbName AND d.is_published = 1 OR d.is_subscribed = 1 OR d.is_distributor = 1)
		BEGIN
			SELECT @_EndTime_PreviousIndex = cl.EndTime, @_TotalPages_PreviousIndex = ExtendedInfo.value('(/ExtendedInfo/PageCount)[1]','bigint')
			FROM DBA..CommandLog cl WHERE cl.CommandType = 'ALTER_INDEX' AND cl.DatabaseName = @c_DbName
			AND cl.ID = (SELECT max(ID) FROM DBA..CommandLog as i WHERE i.CommandType = 'ALTER_INDEX' AND i.DatabaseName = @c_DbName);

			SET @_DelaySeconds = 20 + (@_TotalPages_PreviousIndex/10000)*0.56;

			IF @_DelaySeconds <= DATEDIFF(SECOND,@_EndTime_PreviousIndex,GETDATE())
				SET @_DelaySeconds = 10;
			ELSE
				SET @_DelaySeconds = @_DelaySeconds - DATEDIFF(SECOND,@_EndTime_PreviousIndex,GETDATE());

			IF @_DelaySeconds IS NULL
				SET @_DelaySeconds = 20;


			SELECT @_DelayLength = 
						(CASE WHEN @_DelaySeconds < 60 
							THEN '00:00:'+REPLICATE('0',2-LEN(@_DelaySeconds))+CAST(@_DelaySeconds AS VARCHAR(20))-- Less than a Minute
							WHEN (@_DelaySeconds/60) < 60
							THEN '00:'+REPLICATE('0',2-LEN(@_DelaySeconds/60))+CAST(@_DelaySeconds/60 AS VARCHAR(2))+':'+REPLICATE('0',2-LEN(@_DelaySeconds%60))+CAST(@_DelaySeconds%60 AS VARCHAR(20)) -- Less than an Hour
							ELSE REPLICATE('0',2-LEN(@_DelaySeconds/3600))+CAST(@_DelaySeconds/3600 AS VARCHAR(20))+':'+REPLICATE('0',2-LEN((@_DelaySeconds%3600)/60))+CAST((@_DelaySeconds%3600)/60 AS VARCHAR(20))+':'+REPLICATE('0',2-LEN(@_DelaySeconds%60))+CAST(@_DelaySeconds%60 AS VARCHAR(20))
							END);

			IF @Execute = 'Y'
				WAITFOR DELAY @_DelayLength;
			ELSE
				PRINT CHAR(10)+CHAR(9)+'@_DelayLength = '''+@_DelayLength+''''+CHAR(10);
		END
		
		EXECUTE DBA.dbo.IndexOptimize
									@Databases = @c_DbName, -- Changed Value
									@FragmentationLow =  @FragmentationLow,
									@FragmentationMedium =  @FragmentationMedium,
									@FragmentationHigh =  @FragmentationHigh,
									@FragmentationLevel1 =  @FragmentationLevel1,
									@FragmentationLevel2 =  @FragmentationLevel2,
									@MinNumberOfPages =  @MinNumberOfPages,
									@MaxNumberOfPages =  @MaxNumberOfPages,
									@SortInTempdb =  @SortInTempdb,
									@MaxDOP =  @MaxDOP,
									@FillFactor =  @FillFactor,
									@PadIndex =  @PadIndex,
									@LOBCompaction =  @LOBCompaction,
									@UpdateStatistics =  @UpdateStatistics,
									@OnlyModifiedStatistics =  @OnlyModifiedStatistics,
									@StatisticsModificationLevel =  @StatisticsModificationLevel,
									@StatisticsSample =  @StatisticsSample,
									@StatisticsResample =  @StatisticsResample,
									@PartitionLevel =  @PartitionLevel,
									@MSShippedObjects =  @MSShippedObjects,
									@Indexes =  @c_IndexParameterValue, -- Changed Value
									@TimeLimit =  @TimeLimit,
									@Delay =  @Delay,
									@WaitAtLowPriorityMaxDuration =  @WaitAtLowPriorityMaxDuration,
									@WaitAtLowPriorityAbortAfterWait =  @WaitAtLowPriorityAbortAfterWait,
									@Resumable =  @Resumable,
									@AvailabilityGroups =  @AvailabilityGroups,
									@LockTimeout =  @LockTimeout,
									@LockMessageSeverity =  @LockMessageSeverity,
									@DatabaseOrder =  @DatabaseOrder,
									@DatabasesInParallel =  @DatabasesInParallel,
									@LogToTable =  @LogToTable,
									@Execute =  @Execute;
		
		IF @Execute = 'Y'
		BEGIN
			UPDATE dbo.IndexProcessing_IndexOptimize
			SET IsProcessed = 1
			WHERE ID = @c_ID;
		END

		SET @c_DbName_PreviousIndex = @c_DbName;
		FETCH NEXT FROM cursor_Indexes INTO @c_ID, @c_DbName,@c_IndexParameterValue, @c_TotalPages;
	END
END
GO
