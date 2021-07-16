USE tempdb
GO
IF OBJECT_ID('dbo.usp_AnalyzeSpaceCapacity') IS NULL
  EXEC ('CREATE PROCEDURE dbo.usp_AnalyzeSpaceCapacity AS RETURN 0;')
GO
--	EXEC tempdb..[usp_AnalyzeSpaceCapacity] @getLogInfo = 1
--	EXEC tempdb..[usp_AnalyzeSpaceCapacity] @help = 1
--	EXEC [dbo].[usp_AnalyzeSpaceCapacity] @addDataFiles = 1 ,@newVolume = 'E:\Data1\' ,@oldVolume = 'E:\Data\' --,@forceExecute = 1
--	EXEC [dbo].[usp_AnalyzeSpaceCapacity] @generateCapacityException = 1, @oldVolume = 'E:\Data\'
--	EXEC tempdb..[usp_AnalyzeSpaceCapacity] @verbose = 1
--	EXEC [dbo].[usp_AnalyzeSpaceCapacity] @restrictDataFileGrowth = 1 ,@oldVolume = 'E:\Data\' --,@forceExecute = 1
--	EXEC tempdb..[usp_AnalyzeSpaceCapacity] @expandTempDBSize = 1 ,@output4IdealScenario = 1
--	DECLARE	@_errorOccurred BIT; EXEC @_errorOccurred = tempdb..[usp_AnalyzeSpaceCapacity] ; SELECT CASE WHEN @_errorOccurred = 1 THEN 'fail' ELSE 'pass' END AS [Pass/Fail];
ALTER PROCEDURE [dbo].[usp_AnalyzeSpaceCapacity]
	@getInfo TINYINT = 0, @getLogInfo TINYINT = 0, @help TINYINT = 0, @addDataFiles TINYINT = 0, @addLogFiles TINYINT = 0, @restrictDataFileGrowth TINYINT = 0, @restrictLogFileGrowth TINYINT = 0, @generateCapacityException TINYINT = 0, @unrestrictFileGrowth TINYINT = 0, @removeCapacityException TINYINT = 0, @UpdateMountPointSecurity TINYINT = 0, @restrictMountPointGrowth TINYINT = 0, @expandTempDBSize TINYINT = 0, @optimizeLogFiles TINYINT = 0,
	@newVolume VARCHAR(50) = NULL, @oldVolume VARCHAR(50) = NULL, @mountPointGrowthRestrictionPercent TINYINT = 79, @tempDBMountPointPercent TINYINT = 89, @DBs2Consider VARCHAR(1000) = NULL, @mountPointFreeSpaceThreshold_GB INT = 60
	,@verbose TINYINT = 0 ,@testAllOptions TINYINT = 0 ,@forceExecute TINYINT = 0 ,@allowMulYourOrglumeUnrestrictedFiles TINYINT = 0 ,@output4IdealScenario TINYINT = 0
AS
BEGIN
	/*
		Created By:		Ajay Dwivedi
		Updated on:		08-Aug-2017
		Current Ver:	3.3 - Add functionality to make modification only for specific databases using @DBs2Consider

		Purpose:		This procedure can be used to generate automatic TSQL code for working with ESCs like 'DBSEP2537- Data- Create and Restrict Database File Names' type.
						\\gdv01fil01\d101\dba\sqlserver\scripts\sql\Maintenance
	*/

	SET NOCOUNT ON;
	
	IF @verbose = 1
		PRINT	'Declaring Local Variables';

	--	Declare table for Error Handling
	IF OBJECT_ID('tempdb..#ErrorMessages') IS NOT NULL
		DROP TABLE #ErrorMessages;
	CREATE TABLE	#ErrorMessages
	(
		ErrorID INT IDENTITY(1,1),
		ErrorCategory VARCHAR(50), -- 'Compilation Error', 'Runtime Time', 'ALTER DATABASE Error'
		DBName SYSNAME NULL,
		[FileName] SYSNAME NULL,
		ErrorDetails TEXT NOT NULL,
		TSQLCode TEXT NULL
	);
	--	Declare variable to check if any error occurred
	DECLARE	@_errorOccurred BIT 
	SET @_errorOccurred = 0;

	DECLARE @_powershellCMD VARCHAR(400);
	DECLARE	@_addFileSQLText VARCHAR(MAX)
			,@_isServerPartOfMirroring TINYINT
			,@_mirroringPartner VARCHAR(50)
			,@_principalDatabaseCounts_Mirroring SMALLINT
			,@_mirrorDatabaseCounts_Mirroring SMALLINT
			,@_nonAccessibleDatabasesCounts SMALLINT
			,@_nonAccessibleDatabases VARCHAR(MAX)
			,@_mirrorDatabases VARCHAR(MAX)
			,@_principalDatabases VARCHAR(MAX)
			,@_nonAddedDataFilesDatabases VARCHAR(MAX)
			,@_nonAddedDataFilesDatabasesCounts SMALLINT
			,@_nonAddedLogFilesDatabases VARCHAR(MAX)
			,@_nonAddedLogFilesDatabasesCounts SMALLINT
			,@_databasesWithMultipleDataFiles VARCHAR(MAX)
			,@_databasesWithMultipleDataFilesCounts SMALLINT
			,@_totalSpace_OldVolume_GB DECIMAL(20,2)
			,@_freeSpace_OldVolume_Percent TINYINT
			,@_freeSpace_OldVolume_GB DECIMAL(20,2)
			,@_errorMSG VARCHAR(2000)
			,@_loopCounter SMALLINT
			,@_loopCounts SMALLINT
			,@_loopSQLText VARCHAR(MAX)
			,@_dbName SYSNAME
			,@_name SYSNAME
			,@_newName SYSNAME
			,@_capacityExceptionSQLText VARCHAR(MAX)
			,@_svrName VARCHAR(255)
			,@_sqlGetMountPointVolumes VARCHAR(400)
			,@_sqlGetInfo VARCHAR(4000)
			,@_commaSeparatedMountPointVolumes VARCHAR(2000)
			,@_LogOrData VARCHAR(5)
			,@_Total_Files_Size_MB DECIMAL(20,2)
			,@_Total_Files_SpaceUsed_MB DECIMAL(20,2)
			,@_Space_That_Can_Be_Freed_MB DECIMAL(20,2)
			,@_Weightage_Sum DECIMAL(20,2)
			,@_Space_To_Add_to_Files_MB DECIMAL(20,2)
			,@_productVersion VARCHAR(20)
			,@_SpaceToBeFreed_MB DECIMAL(20,2)
			,@_sqlText NVARCHAR(4000) -- Can be used for any dynamic queries

DECLARE		@_logicalCores TINYINT
			,@_fileCounts TINYINT
			,@_maxFileNO TINYINT
			,@_counts_of_Files_To_Be_Created TINYINT
			,@_jobTimeThreshold_in_Hrs INT;

	IF @verbose=1
		PRINT	'Initiating local variables';

	SET	@_addFileSQLText = ''
	SET	@_isServerPartOfMirroring = 1
	SET	@_principalDatabaseCounts_Mirroring = 0
	SET	@_mirrorDatabaseCounts_Mirroring = 0
	SET	@_nonAddedDataFilesDatabasesCounts = 0
	SET	@_nonAddedLogFilesDatabasesCounts = 0
	SET	@_databasesWithMultipleDataFilesCounts = 0
	SET	@_loopCounter = 0
	SET	@_loopCounts = 0
	SET	@_svrName = @@SERVERNAME
	SET	@_productVersion = (SELECT CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(20)) AS PVersion);
	SET @_counts_of_Files_To_Be_Created = 0;
	SET @_jobTimeThreshold_in_Hrs = NULL; -- Set threshold hours to 18 here

	IF @verbose=1 
		PRINT	'Declaring Table Variables';

	DECLARE @output TABLE (line varchar(255));
	DECLARE @T_Files_Final_Add TABLE (ID INT IDENTITY(1,1), TSQL_AddFile VARCHAR(2000),DBName SYSNAME, name SYSNAME, _name SYSNAME);
	DECLARE @T_LogFiles_Final_Add TABLE (ID INT IDENTITY(1,1), TSQL_AddFile VARCHAR(2000),DBName SYSNAME, name SYSNAME, _name SYSNAME);
	DECLARE @T_Files_Final_Restrict TABLE (ID INT IDENTITY(1,1), TSQL_RestrictFileGrowth VARCHAR(2000),DBName SYSNAME, name SYSNAME, _name SYSNAME);
	DECLARE @T_Files_Final_AddUnrestrict TABLE (ID INT IDENTITY(1,1), TSQL_AddFile VARCHAR(2000),DBName SYSNAME, name SYSNAME, _name SYSNAME NULL);
	DECLARE @T_Files_Final_AddUnrestrictLogFiles TABLE (ID INT IDENTITY(1,1), TSQL_AddFile VARCHAR(2000),DBName SYSNAME, name SYSNAME, _name SYSNAME NULL);
	DECLARE @T_Files_ReSizeTempDB TABLE (ID INT IDENTITY(1,1), TSQL_ResizeTempDB_Files VARCHAR(2000));
	DECLARE @T_Files_restrictMountPointGrowth TABLE (ID INT IDENTITY(1,1), TSQL_restrictMountPointGrowth VARCHAR(2000));
	DECLARE @T_Files_Remove TABLE (ID INT IDENTITY(1,1), TSQL_EmptyFile VARCHAR(2000), TSQL_RemoveFile VARCHAR(2000), name SYSNAME, Volume VARCHAR(255));


	DECLARE @mountPointVolumes TABLE ( Volume VARCHAR(200), [capacity(MB)] DECIMAL(20,2), [freespace(MB)] DECIMAL(20,2) ,VolumeName VARCHAR(50), [capacity(GB)]  DECIMAL(20,2), [freespace(GB)]  DECIMAL(20,2), [freespace(%)]  DECIMAL(20,2) );
	DECLARE @filegroups TABLE ([DBName] [sysname], [name] [sysname], [data_space_id] smallint, [type_desc] [varchar](100) );
	DECLARE @Databases TABLE (ID INT IDENTITY(1,1), DBName VARCHAR(200));
	DECLARE	@DatabasesBySize TABLE (DBName SYSNAME, database_id SMALLINT, [Size (GB)] DECIMAL(20,2));
	DECLARE	@T_DatabasesNotAccessible TABLE (database_id SMALLINT, DBName SYSNAME);
	DECLARE @filterDatabaseNames TABLE (DBName sysname);
	DECLARE @DBFiles TABLE
	(
		[DbName] [varchar](500),
		[FileName] [varchar](500),
		[data_space_id] int NULL, --FileGroup id
		[physical_name] varchar(1000),
		[CurrentSizeMB] [numeric](17, 6),
		[FreeSpaceMB] [numeric](18, 6),
		[SpaceUsed] [numeric] (20,0), -- File used space in MB
		[type_desc] [varchar](60),
		[growth] [int],
		[is_percent_growth] [bit],
		[% space used] [numeric] (18,2)
	);

	IF @verbose=1 
		PRINT	'Creating temp table #T_Files_Derived';
	IF OBJECT_ID('tempdb..#T_Files_Derived') IS NOT NULL
		DROP TABLE #T_Files_Derived;
	CREATE TABLE #T_Files_Derived
	(
		[dbName] [nvarchar](128) NULL,
		[database_id] [int] NULL,
		[file_id] [int] NULL,
		[type_desc] [nvarchar](60) NULL,
		[data_space_id] [int] NULL, -- filegroup id
		[name] [sysname] NULL,
		[physical_name] [nvarchar](260) NULL,
		[size] [int] NULL,	-- file size from sys.master_files
		[max_size] [int] NULL, -- max_size value from sys.master_files
		[growth] [int] NULL, --	growth value from sys.master_files
		[is_percent_growth] [bit] NULL,
		[fileGroup] [sysname] NULL,
		[FileIDRankPerFileGroup] [bigint] NULL,
		[isExistingOn_NewVolume] [int] NULL,
		[isExisting_UnrestrictedGrowth_on_OtherVolume] [int] NULL,
		--[Category] [varchar](10) NULL,
		[Size (GB)] [decimal](20, 2) NULL, -- database size from @DatabasesBySize
		[_name] [nvarchar](4000) NULL,
		[_physical_name] [nvarchar](4000) NULL,
		[TotalSize_All_DataFiles_MB]  [decimal](20, 2) NULL, -- sum total of used space for all data files of database
		[TotalSize_All_LogFiles_MB]  [decimal](20, 2) NULL, -- sum total of current size for all log files of database
		[_initialSize] [varchar](10) NULL, -- initial size of data/log file like 8000MB, 256MB
		[_autoGrowth] [varchar](10) NULL, -- auto growth size of data/log file to be created like 8000MB, 10%
		[maxfileSize_oldVolumes_MB] [decimal](20, 0) NULL, -- max size of data/log file for particular combination of Database & FileGroup
		[TSQL_AddFile] [varchar](2000) NULL,
		[TSQL_RestrictFileGrowth] [varchar](2000) NULL,
		[TSQL_UnRestrictFileGrowth] [varchar](2000) NULL
	);
	DECLARE @tempDBFiles TABLE
	(
		[fileNo] INT IDENTITY(1,1),
		[DBName] [sysname] NULL,
		[LogicalName] [sysname] NOT NULL,
		[physical_name] [nvarchar](260) NOT NULL,
		[FileSize_MB] [numeric](18, 6) NULL,
		[Volume] [varchar](200) NULL,
		[VolumeName] [varchar](20) NULL,
		[VolumeSize_MB] [decimal](20, 2) NULL
		,[isToBeDeleted] AS CASE WHEN [VolumeName] LIKE '%TempDB%' THEN 0 ELSE 1 END
	);


	IF OBJECT_ID('tempdb..#stage') IS NOT NULL
		DROP TABLE #stage;
	CREATE TABLE #stage([RecoveryUnitId] INT, [file_id] INT,[file_size] BIGINT,[start_offset] BIGINT,[f_seq_no] BIGINT,[status] BIGINT,[parity] BIGINT,[create_lsn] NUMERIC(38));
	IF OBJECT_ID('tempdb..#LogInfoByFile') IS NOT NULL
		DROP TABLE #LogInfoByFile;
	CREATE TABLE #LogInfoByFile (DBName VARCHAR(200), FileId INT, VLFCount INT);
	
	IF OBJECT_ID('tempdb..#runningAgentJobs') IS NOT NULL -- Used to find if any backup job is running.
		DROP TABLE #runningAgentJobs;

	BEGIN TRY	-- Try Catch for executable blocks that may throw error

		IF @help = 1
			GOTO HELP_GOTO_BOOKMARK;

		--	============================================================================
			--	Begin:	Validations 
		--	============================================================================
		IF @verbose=1 
			PRINT	'
/*	******************** BEGIN: Validations *****************************/';
		
		IF @verbose=1 
			PRINT	'	Evaluation value of @_LogOrData variable';
		IF (@addDataFiles=1 OR @restrictDataFileGrowth=1 OR @getInfo=1)
			SET @_LogOrData = 'Data';
		ELSE IF @oldVolume IS NOT NULL AND EXISTS (SELECT * FROM sys.master_files as mf WHERE mf.physical_name LIKE (@oldVolume+'%') AND type_desc = 'ROWS')
			SET @_LogOrData = 'Data';
		ELSE
			SET @_LogOrData = 'Log';

		IF	(@help=1 OR @addDataFiles=1 OR @addLogFiles=1 OR @restrictDataFileGrowth=1 OR @restrictLogFileGrowth=1 OR @generateCapacityException=1 OR @unrestrictFileGrowth=1 OR @removeCapacityException=1 OR @UpdateMountPointSecurity=1 OR @restrictMountPointGrowth=1 OR @expandTempDBSize=1 OR @optimizeLogFiles=1)
		BEGIN	
			SET	@getInfo = 0;
			SET @getLogInfo = 0;
		END
		ELSE 
		BEGIN
			IF (@getLogInfo=0)
				SET	@getInfo = 1;
		END

		IF (COALESCE(@getInfo,@help,@addDataFiles,@addLogFiles,@restrictDataFileGrowth,@restrictLogFileGrowth,@generateCapacityException,@unrestrictFileGrowth
		,@restrictMountPointGrowth,@expandTempDBSize,-999) = -999)
		BEGIN
			SET @_errorMSG = 'Procedure does not accept NULL for parameter values.';
			IF (select CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)),charindex('.',CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)))-1) AS INT)) >= 12
				EXEC sp_executesql N'THROW 50000,@_errorMSG,1',N'@_errorMSG VARCHAR(200)', @_errorMSG;
			ELSE
				EXEC sp_executesql N'RAISERROR (@_errorMSG, 16, 1)', N'@_errorMSG VARCHAR(200)', @_errorMSG;
		END

		IF (@help = 1 AND (@addDataFiles=1 OR @addLogFiles=1 OR @restrictDataFileGrowth=1 OR @restrictLogFileGrowth=1 OR @generateCapacityException=1 OR @unrestrictFileGrowth=1 OR @removeCapacityException=1 OR @expandTempDBSize=1 ))
		BEGIN
			SET @_errorMSG = '@help=1 is incompatible with any other parameters.';
			IF (select CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)),charindex('.',CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)))-1) AS INT)) >= 12
				EXEC sp_executesql N'THROW 50000,@_errorMSG,1',N'@_errorMSG VARCHAR(200)', @_errorMSG;
			ELSE
				EXEC sp_executesql N'RAISERROR (@_errorMSG, 16, 1)', N'@_errorMSG VARCHAR(200)', @_errorMSG;
		END

		IF (@generateCapacityException = 1 AND (@addDataFiles=1 OR @restrictDataFileGrowth=1 OR @unrestrictFileGrowth=1 OR @help=1 OR @removeCapacityException=1))
		BEGIN
			SET @_errorMSG = '@generateCapacityException=1 is incompatible with any other parameters.';
			IF (select CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)),charindex('.',CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)))-1) AS INT)) >= 12
				EXEC sp_executesql N'THROW 50000,@_errorMSG,1',N'@_errorMSG VARCHAR(200)', @_errorMSG;
			ELSE
				EXEC sp_executesql N'RAISERROR (@_errorMSG, 16, 1)', N'@_errorMSG VARCHAR(200)', @_errorMSG;
		END

		IF (@unrestrictFileGrowth = 1 AND (@addDataFiles=1 OR @restrictDataFileGrowth=1 OR @generateCapacityException=1 OR @help=1 OR @removeCapacityException=1))
		BEGIN
			SET @_errorMSG = '@unrestrictFileGrowth=1 is incompatible with any other parameters.';
			IF (select CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)),charindex('.',CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)))-1) AS INT)) >= 12
				EXEC sp_executesql N'THROW 50000,@_errorMSG,1',N'@_errorMSG VARCHAR(200)', @_errorMSG;
			ELSE
				EXEC sp_executesql N'RAISERROR (@_errorMSG, 16, 1)', N'@_errorMSG VARCHAR(200)', @_errorMSG;
		END

		IF (@removeCapacityException = 1 AND (@addDataFiles=1 OR @restrictDataFileGrowth=1 OR @generateCapacityException=1 OR @help=1 OR @unrestrictFileGrowth=1))
		BEGIN
			SET @_errorMSG = '@removeCapacityException=1 is incompatible with any other parameters.';
			IF (select CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)),charindex('.',CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)))-1) AS INT)) >= 12
				EXEC sp_executesql N'THROW 50000,@_errorMSG,1',N'@_errorMSG VARCHAR(200)', @_errorMSG;
			ELSE
				EXEC sp_executesql N'RAISERROR (@_errorMSG, 16, 1)', N'@_errorMSG VARCHAR(200)', @_errorMSG;
		END

		IF ( (@addDataFiles=1 OR @addLogFiles=1) AND (@newVolume IS NULL OR @oldVolume IS NULL))
		BEGIN
			SET @_errorMSG = '@oldVolume & @newVolume parameters must be specified with '+(CASE WHEN @addDataFiles=1 THEN '@addDataFiles' ELSE '@addLogFiles' END)+' = 1 parameter.';
			IF (select CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)),charindex('.',CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)))-1) AS INT)) >= 12
				EXEC sp_executesql N'THROW 50000,@_errorMSG,1',N'@_errorMSG VARCHAR(200)', @_errorMSG;
			ELSE
				EXEC sp_executesql N'RAISERROR (@_errorMSG, 16, 1)', N'@_errorMSG VARCHAR(200)', @_errorMSG;
		END

		IF ( (@restrictDataFileGrowth=1 OR @restrictLogFileGrowth=1 OR @restrictMountPointGrowth=1) AND (@oldVolume IS NULL))
		BEGIN
			SET @_errorMSG = '@oldVolume parameters must be specified with '+(CASE WHEN @restrictDataFileGrowth=1 THEN '@restrictDataFileGrowth' WHEN @restrictLogFileGrowth=1 THEN '@restrictLogFileGrowth' ELSE '@restrictMountPointGrowth' END)+' = 1 parameter.';
			IF (select CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)),charindex('.',CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)))-1) AS INT)) >= 12
				EXEC sp_executesql N'THROW 50000,@_errorMSG,1',N'@_errorMSG VARCHAR(200)', @_errorMSG;
			ELSE
				EXEC sp_executesql N'RAISERROR (@_errorMSG, 16, 1)', N'@_errorMSG VARCHAR(200)', @_errorMSG;
		END

		IF @verbose=1 
			PRINT	'/*	******************** END: Validations *****************************/
';
		--	============================================================================
			--	End:	Validations 
		--	============================================================================

		--	============================================================================
			--	Begin:	Common Code 
		--	----------------------------------------------------------------------------
			/*	Get data for below tables:-
			1) @mountPointVolumes - Get all volume details like total size, free space etc
			2) @filegroups - Get details of DatabaseName, filegroup name, and type_desc
			3) @DBFiles - Get data/log file usage details along with DbName, FileName, data_space_id
			4) @DatabasesBySize - Get Database size details
			*/
		BEGIN	-- Begin block of Common Code

			IF @verbose=1 
				PRINT	'
/*	******************** BEGIN: Common Code *****************************/';
		
			IF @verbose=1 
				PRINT	'	Adding Backslash at the end for @oldVolume & @newVolume';
			SELECT	@oldVolume = CASE WHEN RIGHT(RTRIM(LTRIM(@oldVolume)),1) <> '\' THEN @oldVolume+'\' ELSE @oldVolume END,
					@newVolume = CASE WHEN RIGHT(RTRIM(LTRIM(@newVolume)),1) <> '\' THEN @newVolume+'\' ELSE @newVolume END;

			-- Check is specific databases have been mentioned
			IF @DBs2Consider IS NOT NULL
			BEGIN
				IF @verbose = 1
					PRINT	'	Following databases are specified:- '+@DBs2Consider;
		
				WITH t1(DBName,DBs) AS 
				(
					SELECT	CAST(LEFT(@DBs2Consider, CHARINDEX(',',@DBs2Consider+',')-1) AS VARCHAR(500)) as DBName,
							STUFF(@DBs2Consider, 1, CHARINDEX(',',@DBs2Consider+','), '') as DBs
					--
					UNION ALL
					--
					SELECT	CAST(LEFT(DBs, CHARINDEX(',',DBs+',')-1) AS VARChAR(500)) AS DBName,
							STUFF(DBs, 1, CHARINDEX(',',DBs+','), '')  as DBs
					FROM t1
					WHERE DBs > ''	
				)
				INSERT @filterDatabaseNames
				SELECT LTRIM(RTRIM(DBName)) FROM t1;
			END

			--	Begin: Get Data & Log Mount Point Volumes
			SET @_powershellCMD =  'powershell.exe -c "Get-WmiObject -ComputerName ' + QUOTENAME(@@servername,'''') + ' -Class Win32_Volume -Filter ''DriveType = 3'' | select name,capacity,freespace | foreach{$_.name+''|''+$_.capacity/1048576+''%''+$_.freespace/1048576+''*''}"';

			-- Clear previous output
			DELETE @output;

			IF @verbose = 1
			BEGIN
				PRINT	'	Executing xp_cmdshell command:-
		'+@_powershellCMD;
			END

			--inserting disk name, total space and free space value in to temporary table
			INSERT @output
			EXEC xp_cmdshell @_powershellCMD;

			IF @verbose = 1
			BEGIN
				PRINT	'	SELECT * FROM @output';
				SELECT 'SELECT * FROM @output' AS RunningQuery,* FROM @output;
			END

			IF @verbose=1 
				PRINT	'	Executing code to find Data/Log Mount Point Volumes';
			;WITH T_Volumes AS
			(
				SELECT	RTRIM(LTRIM(SUBSTRING(line,1,CHARINDEX('|',line) -1))) as Volume
						,ROUND(CAST(RTRIM(LTRIM(SUBSTRING(line,CHARINDEX('|',line)+1,
						(CHARINDEX('%',line) -1)-CHARINDEX('|',line)) )) as Float),0) as 'capacity(MB)'
						,ROUND(CAST(RTRIM(LTRIM(SUBSTRING(line,CHARINDEX('%',line)+1,
						(CHARINDEX('*',line) -1)-CHARINDEX('%',line)) )) as Float),0) as 'freespace(MB)'
				FROM	@output
				WHERE line like '[A-Z][:]%'
			)
			INSERT INTO @mountPointVolumes
			(Volume, [capacity(MB)], [freespace(MB)] ,VolumeName, [capacity(GB)], [freespace(GB)], [freespace(%)])
			SELECT	Volume
					,[capacity(MB)]
					,[freespace(MB)]
					,REVERSE(SUBSTRING(REVERSE(v.Volume),2,CHARINDEX('\',REVERSE(v.Volume),2)-2)) as VolumeName
					,CAST(([capacity(MB)]/1024.0) AS DECIMAL(20,2)) AS [capacity(GB)]
					,CAST(([freespace(MB)]/1024.0) AS DECIMAL(20,2)) AS [freespace(GB)]
					,CAST(([freespace(MB)]*100.0)/[capacity(MB)] AS DECIMAL(20,2)) AS [freespace(%)]
			FROM	T_Volumes v
			WHERE	v.Volume LIKE '[A-Z]:\Data\'
				OR	v.Volume LIKE '[A-Z]:\Data[0-9]\'
				OR	v.Volume LIKE '[A-Z]:\Data[0-9][0-9]\'
				OR	v.Volume LIKE '[A-Z]:\Logs\'
				OR	v.Volume LIKE '[A-Z]:\Logs[0-9]\'
				OR	v.Volume LIKE '[A-Z]:\Logs[0-9][0-9]\'
				OR	v.Volume LIKE '[A-Z]:\tempdb\'
				OR	v.Volume LIKE '[A-Z]:\tempdb[0-9]\'
				OR	v.Volume LIKE '[A-Z]:\tempdb[0-9][0-9]\';
				--OR	EXISTS (SELECT * FROM sys.master_files as mf WHERE mf.physical_name LIKE (Volume+'%'));

			IF @verbose=1
			BEGIN
				PRINT	'	Values populated for @mountPointVolumes';
				PRINT	'	SELECT * FROM @mountPointVolumes;'
				SELECT 'SELECT * FROM @mountPointVolumes;' AS RunningQuery,* FROM @mountPointVolumes;
			END

			--	Check if some volume exists in @mountPointVolumes
			IF NOT EXISTS (SELECT * FROM @mountPointVolumes v ) 
			BEGIN
				SET @_errorMSG = 'Volume configuration is not per standard. Kindly perform the activity manually.';
			
				IF (select CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)),charindex('.',CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)))-1) AS INT)) >= 12
					EXEC sp_executesql N'THROW 50000,@_errorMSG,1',N'@_errorMSG VARCHAR(200)', @_errorMSG;
				ELSE
					EXEC sp_executesql N'RAISERROR (@_errorMSG, 16, 1)', N'@_errorMSG VARCHAR(200)', @_errorMSG;
			END

			--	Perform free space Validation based on table @mountPointVolumes
			IF NOT EXISTS (SELECT * FROM @mountPointVolumes v WHERE v.Volume = @newVolume AND v.[freespace(%)] >= 20) AND (@addDataFiles=1 OR @addLogFiles=1) 
			BEGIN
				IF NOT EXISTS (SELECT * FROM @mountPointVolumes v WHERE v.Volume = @newVolume)
					SET @_errorMSG = 'Kindly specify correct value for @newVolume as provided mount point volume '+QUOTENAME(@newVolume,'''')+' does not exist';
				ELSE
					SET @_errorMSG = 'Available free space on @newVolume='+QUOTENAME(@newVolume,'''')+' is less than 20 percent.';
			
				IF (select CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)),charindex('.',CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)))-1) AS INT)) >= 12
					EXEC sp_executesql N'THROW 50000,@_errorMSG,1',N'@_errorMSG VARCHAR(200)', @_errorMSG;
				ELSE
					EXEC sp_executesql N'RAISERROR (@_errorMSG, 16, 1)', N'@_errorMSG VARCHAR(200)', @_errorMSG;
			END

			--	Running jobs
			/*
			;WITH T_Last_Job_Status AS
			(
				SELECT	JobName, Status, RunDate, [Duration HH:MM]
					,ROW_NUMBER()OVER(PARTITION BY JobName, Status ORDER BY RunDate DESC, [Duration HH:MM] DESC) AS RowID
				FROM	(
							SELECT      [JobName]   = JOB.name,
										[Status]    = CASE WHEN HIST.run_status = 0 THEN 'Failed'
										WHEN HIST.run_status = 1 THEN 'Succeeded'
										WHEN HIST.run_status = 2 THEN 'Retry'
										WHEN HIST.run_status = 3 THEN 'Canceled'
										END,
										[RunDate]   = msdb.dbo.agent_datetime(run_date, run_time),
										[Duration HH:MM]  = CAST(((run_duration/10000*3600 + (run_duration/100)%100*60 + run_duration%100 + 31 ) / 60)/60 AS VARCHAR(2))
															+ ':' + CAST(((run_duration/10000*3600 + (run_duration/100)%100*60 + run_duration%100 + 31 ) / 60)%60 AS VARCHAR(2))
							FROM        msdb.dbo.sysjobs JOB
							INNER JOIN  msdb.dbo.sysjobhistory HIST ON HIST.job_id = JOB.job_id
							WHERE    JOB.name IN ('DBA - Backup All Databases')
								AND	 HIST.step_id = 0
						) as t
			)
			,T_Last_Job_Status_2 AS
			(
				SELECT	JobName, [Succeeded], [Canceled], [Failed], [Retry]
				FROM  (	
						SELECT JobName, Status, [Duration HH:MM] FROM T_Last_Job_Status WHERE RowID = 1
					  ) AS up
				PIVOT (MAX([Duration HH:MM]) FOR [Status] IN (Succeeded, Canceled, Failed, Retry)) AS pvt
			)
			SELECT	@@SERVERNAME as [InstanceName],
				--ja.job_id,
				j.name AS job_name,
				Js.step_name,
				ja.start_execution_date as StartTime, 
				CAST(DATEDIFF(HH,ja.start_execution_date,GETDATE()) AS VARCHAR(2))+':'+CAST((DATEDIFF(MINUTE,ja.start_execution_date,GETDATE())%60) AS VARCHAR(2)) AS [ElapsedTime(HH:MM)],    
				ISNULL(last_executed_step_id,0)+1 AS current_executed_step_id,
				COALESCE(cte.Succeeded, cte.Canceled, cte.Failed, cte.Retry) as [TimeTakenLastTime(HH:MM)]
				,BlockedSPID
				,bs.session_id as Blocking_Session_ID, bs.DBName, bs.status, bs.percent_complete, bs.running_time, bs.wait_type, bs.program_name, bs.host_name, bs.login_name, CONVERT(VARCHAR(1000), bs.sql_handle, 2) as [sql_handle]
			INTO	#runningAgentJobs
			FROM msdb.dbo.sysjobactivity ja 
			LEFT JOIN msdb.dbo.sysjobhistory jh 
				ON ja.job_history_id = jh.instance_id
			JOIN msdb.dbo.sysjobs j 
			ON ja.job_id = j.job_id
			JOIN msdb.dbo.sysjobsteps js
				ON ja.job_id = js.job_id
				AND ISNULL(ja.last_executed_step_id,0)+1 = js.step_id
			LEFT JOIN
				T_Last_Job_Status_2 AS cte
				ON cte.JobName = j.name
			LEFT JOIN
				(
					--	Query to find what's is running on server
					SELECT '"spid" :: ' +CAST(s2.session_id AS VARCHAR(3)) + ' | "DBName" :: '+ s2.DBName +' | "Status" :: '+ s2.status + ' | "% Completed" :: '+ CAST(S2.percent_complete AS VARCHAR(5)) +' | "RunningTime(HH:MM:SS)" :: '+ S2.running_time +' | "WaitType" :: ' + S2.wait_type + ' | "program_name" :: '+ S2.program_name + ' | "host_name" :: '+ S2.host_name + ' | "login_Name" :: '+ S2.login_name + ' | "sql_handle" :: ' + CONVERT(VARCHAR(1000), s2.sql_handle, 2) as BlockedSPID
							,s2.session_id, s2.DBName, s2.status, S2.percent_complete, S2.running_time, S2.wait_type, S2.program_name, S2.host_name, S2.login_name, CONVERT(VARCHAR(1000), s2.sql_handle, 2) as [sql_handle]
							,s.program_name as job_program_name
					FROM sys.dm_exec_sessions AS s
					INNER JOIN sys.dm_exec_requests AS r ON r.session_id = s.session_id
					INNER JOIN 
						(
							-- Fetch details of blocking session id
							SELECT	si.session_id
									,DB_NAME(COALESCE(ri.database_id,dbid)) as DBName
									,COALESCE(ri.STATUS,LTRIM(RTRIM(sp.status))) as [STATUS]
									,COALESCE(ri.percent_complete,'') AS percent_complete
									,COALESCE(CAST(((DATEDIFF(s,start_time,GetDate()))/3600) as varchar) + ':'
										+ CAST((DATEDIFF(s,start_time,GetDate())%3600)/60 as varchar) + ':'
										+ CAST((DATEDIFF(s,start_time,GetDate())%60) as varchar) + ':'
										,CAST(DATEDIFF(hh,last_batch,GETDATE()) AS VARCHAR) + ':' + CAST(DATEDIFF(mi,last_batch,GETDATE())%60 AS VARCHAR)+':' + CAST(DATEDIFF(ss,last_batch,GETDATE())%3600 AS VARCHAR))  as running_time
									,COALESCE(CAST((estimated_completion_time/3600000) as varchar) + ' hour(s), '
												  + CAST((estimated_completion_time %3600000)/60000  as varchar) + 'min, '
												  + CAST((estimated_completion_time %60000)/1000  as varchar) + ' sec','')  as est_time_to_go
									,dateadd(second,estimated_completion_time/1000, getdate())  as est_completion_time 
									,COALESCE(ri.blocking_session_id,sp.blocked) as 'blocked by'
									,COALESCE(ri.wait_type,LTRIM(RTRIM(sp.lastwaittype))) as wait_type
									,COALESCE(ri.sql_handle, sp.sql_handle) as [sql_handle]
									,si.login_name
									,si.host_name
									,si.program_name
								FROM sys.dm_exec_sessions AS si
								LEFT JOIN sys.dm_exec_requests AS ri ON ri.session_id = si.session_id
								LEFT JOIN sys.sysprocesses AS sp ON sp.spid = si.session_id
						) AS s2
						ON		s2.session_id = r.blocking_session_id
					-- Agent job session is represented by outer query.
				) AS bs
				ON	master.dbo.fn_varbintohexstr(convert(varbinary(16), j.job_id)) COLLATE Latin1_General_CI_AI = substring(replace(bs.job_program_name, 'SQLAgent - TSQL JobStep (Job ', ''), 1, 34)
			WHERE ja.session_id = (SELECT TOP 1 session_id FROM msdb.dbo.syssessions ORDER BY agent_start_date DESC)
			AND start_execution_date is not null
			AND stop_execution_date is null
			AND j.name IN ('DBA - Backup All Databases')
			AND	(	@_jobTimeThreshold_in_Hrs IS NULL
				OR	DATEDIFF(HH,ja.start_execution_date,GETDATE()) >= @_jobTimeThreshold_in_Hrs);

			IF @verbose = 1
			BEGIN
				SELECT	J.*, Q.*
				FROM	(	SELECT	'SELECT * FROM #runningAgentJobs;' AS RunningQuery	) AS Q
				CROSS JOIN
						#runningAgentJobs AS J;
			END

			IF @addLogFiles = 1 OR @addDataFiles = 1 -- If user want to run ALTER DATABASE scripts, then check for running backups
			BEGIN
				IF EXISTS (SELECT * FROM #runningAgentJobs)
				BEGIN
					SET @_errorMSG = 'Backup job is running. So kindly create/restrict files later.';
			
					IF (select CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)),charindex('.',CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)))-1) AS INT)) >= 12
						EXEC sp_executesql N'THROW 50000,@_errorMSG,1',N'@_errorMSG VARCHAR(200)', @_errorMSG;
					ELSE
						EXEC sp_executesql N'RAISERROR (@_errorMSG, 16, 1)', N'@_errorMSG VARCHAR(200)', @_errorMSG;
				END
			END
			*/

			IF @getLogInfo <> 1 AND @addLogFiles <> 1 AND @expandTempDBSize <> 1
			BEGIN
				IF @verbose=1 
					PRINT	'	Populate values into @filegroups temp table';
				INSERT @filegroups
				EXEC  sp_MSforeachdb  ' 
			USE [?];
			SELECT db_name(), name, data_space_id, type_desc FROM [sys].[filegroups];
			 ' ;
				IF @verbose = 1
				BEGIN
					PRINT	'	SELECT * FROM @filegroups';
					SELECT 'SELECT * FROM @filegroups' AS RunningQuery, * FROM @filegroups;
				END
			END

			--	Begin code to find out complete data/log file usage details
			IF (@addDataFiles=1 OR @addLogFiles=1 OR @unrestrictFileGrowth=1 OR @optimizeLogFiles=1 OR @getInfo=1 )
			BEGIN
				IF @verbose = 1
					PRINT	'	Populating data into @DBFiles.';

				INSERT @DBFiles
				EXEC sp_MSforeachdb '
				USE [?];
				SELECT	DB_NAME() AS DbName,
						name AS FileName,
						data_space_id,
						physical_name,
						size/128.0 AS CurrentSizeMB,
						size/128.0 -CAST(FILEPROPERTY(name,''SpaceUsed'') AS INT)/128.0 AS FreeSpaceMB,
						CAST(FILEPROPERTY(name,''SpaceUsed'') AS INT)/128.0 AS [SpaceUsed],
						type_desc,
						growth,
						is_percent_growth,
						CASE WHEN size = 0 THEN 0 ELSE (((FILEPROPERTY(name,''SpaceUsed'') * 8.0) * 100) / (size * 8.0)) END as [% space used]
						--((CAST(FILEPROPERTY(name,''SpaceUsed'') AS INT)/128.0) * 100.0) / (size/128.0) AS [% space used]
				FROM sys.database_files;
				';

				IF @verbose = 1
				BEGIN
					PRINT	'	SELECT * FROM @DBFiles ORDER BY DbName, FileName';
					SELECT 'SELECT * FROM @DBFiles ORDER BY DbName, FileName' AS RunningQuery, * FROM @DBFiles ORDER BY DbName, FileName;
				END
			END

			IF ( @getInfo <> 1 AND @getLogInfo <> 1) -- Don't execute common codes for @getInfo functionality
			BEGIN	-- Begin Block: Don't execute common codes for @getInfo functionality
				--	Get Database size details
				IF @verbose = 1
					PRINT	'	Populating data in @DatabasesBySize table';
				INSERT @DatabasesBySize
					SELECT	DBName, database_id, [Size (GB)] --, (CASE WHEN [Size (GB)] <= @smallDBSize THEN 'Small' ELSE 'Large' END) as Category
					FROM (	
							SELECT	db_name(database_id) as DBName, database_id, CONVERT(DECIMAL(20,2),((SUM(CONVERT(BIGINT,size))*8.0)/1024/1024)) AS [Size (GB)]
							FROM	master.sys.master_files as f
							GROUP BY db_name(database_id), database_id
						 ) AS d;
			
				SET @_mirroringPartner = (SELECT TOP 1 mirroring_partner_instance FROM sys.database_mirroring WHERE mirroring_state IS NOT NULL);

				IF @verbose=1 
					PRINT	'	Get All Databases with size information executed';
			
				--	Begin: Find Data/Log files on @oldVolume
				IF @verbose=1 
					PRINT	'	Starting Find Data/Log files on @oldVolume
					@_LogOrData = '+@_LogOrData;

				IF (@_LogOrData = 'Log') AND @expandTempDBSize <> 1
				BEGIN
					IF @verbose=1 
						PRINT	'	Begin Common Code: inside @_LogOrData = ''Log''';

					--	Find Log files on @oldVolume. [isLogExistingOn_NewVolume] column indicates if the same files exists on @newVolume.
					;WITH T_Files AS 
					(		
						--	Find Log files on @oldVolume
						SELECT	DB_NAME(database_id) as dbName, mf1.*, NULL as [fileGroup]
									-- Consider adding single file per filegroup for each database
								,[FileIDRankPerFileGroup] = row_number()over(partition by mf1.database_id order by mf1.file_id)
									-- Check if corresponding Data file for same FileGroup exists on @newVolume
								,[isExistingOn_NewVolume] = CASE WHEN NOT EXISTS (
																					SELECT	mf2.*, NULL as [fileGroup]
																					FROM	sys.master_files mf2
																					WHERE	mf2.type_desc = mf1.type_desc
																						AND	mf2.database_id = mf1.database_id
																						AND mf2.physical_name like (@newVolume+'%')
																				)
																THEN 0
																ELSE 1
																END
								,[isExisting_UnrestrictedGrowth_on_OtherVolume] = CASE WHEN NOT EXISTS (
																					SELECT	mf2.*, NULL as [fileGroup]
																					FROM	sys.master_files mf2
																					WHERE	mf2.type_desc = mf1.type_desc
																						AND	mf2.database_id = mf1.database_id
																						AND mf2.growth <> 0
																						AND LEFT(mf2.physical_name, CHARINDEX('\',mf2.physical_name,4)) IN (select V.Volume from @mountPointVolumes V WHERE V.Volume <> @oldVolume AND [freespace(%)] >= 20.0)
																				)
																THEN 0
																ELSE 1
																END
						FROM	sys.master_files mf1
						WHERE	mf1.type_desc = 'LOG'
							AND	mf1.physical_name LIKE (@oldVolume+'%')
					)
						INSERT #T_Files_Derived
						(	dbName, database_id, file_id, type_desc, data_space_id, name, physical_name, size, max_size, growth, is_percent_growth, fileGroup, 
							FileIDRankPerFileGroup, isExistingOn_NewVolume, isExisting_UnrestrictedGrowth_on_OtherVolume, [Size (GB)], _name, _physical_name, TotalSize_All_DataFiles_MB, TotalSize_All_LogFiles_MB, maxfileSize_oldVolumes_MB, TSQL_AddFile, TSQL_RestrictFileGrowth, TSQL_UnRestrictFileGrowth
						)
						SELECT	f.dbName, f.database_id, f.file_id, f.type_desc, f.data_space_id, f.name, f.physical_name, f.size, f.max_size, f.growth, f.is_percent_growth, f.fileGroup, 
								f.FileIDRankPerFileGroup, f.isExistingOn_NewVolume, f.isExisting_UnrestrictedGrowth_on_OtherVolume, d.[Size (GB)]
								,mf.[_name]
								,[_physical_name] = @newVolume+[_name]+'.ldf'
								,u2.Sum_DataFilesSize_MB AS TotalSize_All_DataFiles_MB
								,u2.Sum_LogsFilesSize_MB AS TotalSize_All_LogFiles_MB
								,u.maxfileSize_oldVolumes_MB
								,[TSQL_AddFile] = CAST(NULL AS VARCHAR(2000))
								,[TSQL_RestrictFileGrowth] = CAST(NULL AS VARCHAR(2000))
								,[TSQL_UnRestrictFileGrowth] = CAST(NULL AS VARCHAR(2000))
						FROM	T_Files as f
						LEFT JOIN
								@DatabasesBySize	AS d
							ON	d.database_id = f.database_id
						LEFT JOIN
								(	select u.DbName, u.data_space_id
											,(CASE WHEN u.data_space_id = 0 THEN MAX(CurrentSizeMB) ELSE MAX(u.SpaceUsed) END) -- if log file then CurrentSizeMB else SpaceUsed
												 AS maxfileSize_oldVolumes_MB 
									from @DBFiles AS u 
									group by u.DbName, u.data_space_id
								) AS u
							ON	f.database_id = DB_ID(u.DbName)
							AND	f.data_space_id = u.data_space_id
						LEFT JOIN
								(	SELECT	DbName,	Sum_DataFilesSize_MB, Sum_LogsFilesSize_MB
									FROM  (	select u.DbName, (CASE WHEN u.[type_desc] = 'ROWS' THEN 'Sum_DataFilesSize_MB' ELSE 'Sum_LogsFilesSize_MB' END) AS [type_desc]
													,(CASE WHEN u.[type_desc] = 'LOG' THEN SUM(CurrentSizeMB) ELSE SUM(u.SpaceUsed) END) -- if log file then SUM(CurrentSizeMB) else SUM(SpaceUsed)
														 AS Sum_fileSize_ByType_MB 
											from @DBFiles AS u 
											group by u.DbName, u.[type_desc]
										  ) AS u
									PIVOT ( MAX(Sum_fileSize_ByType_MB) FOR [type_desc] in (Sum_DataFilesSize_MB, Sum_LogsFilesSize_MB) ) AS pvt
								) AS u2
							ON	f.database_id = DB_ID(u2.DbName)
						LEFT JOIN
							(	SELECT	database_id, DBName, type_desc, name, _name = (CASE WHEN CHARINDEX(DBName,name) <> 0 THEN DBName ELSE '' END)+_Name_Without_DBName
								FROM	(
											SELECT	database_id, DBName, type_desc, name, FileNO_String, FileNO_Int, Name_Without_DBName, FileOrder, 
													[_Name_Without_DBName] = (CASE WHEN LEN( [_Name_Without_DBName]) > 0 THEN [_Name_Without_DBName] ELSE (CASE WHEN type_desc = 'ROWS' THEN '_Data01' ELSE '_Log01' END) END)
											FROM	(
														SELECT	*
																,ROW_NUMBER()OVER(PARTITION BY DBName, type_desc ORDER BY FileNO_Int DESC) as FileOrder
																,[_Name_Without_DBName] = CASE WHEN LEN(FileNO_String)<>0 THEN REPLACE(Name_Without_DBName,FileNO_String,(CASE WHEN LEN(FileNO_Int+1) = 1 THEN ('0'+CAST((FileNO_Int+1) AS VARCHAR(20))) ELSE CAST((FileNO_Int+1) AS VARCHAR(20)) END )) ELSE Name_Without_DBName + (CASE WHEN type_desc = 'LOG' THEN '01' ELSE '_data01' END) END
														FROM	(
																	SELECT mf.database_id, db_name(database_id) AS DBName, type_desc, name 
																			,FileNO_String = RIGHT(name,PATINDEX('%[a-zA-Z_ ]%',REVERSE(name))-1)
																			,FileNO_Int = CAST(RIGHT(name,PATINDEX('%[a-zA-Z_ ]%',REVERSE(name))-1) AS INT)
																			,Name_Without_DBName = REPLACE ( name, db_name(database_id), '')
																	FROM sys.master_files as mf
																) AS T_Files_01
													) AS T_Files_02
										) AS T_Files_03
								WHERE	FileOrder = 1
							)  AS mf
							ON	mf.database_id = f.database_id
							AND	mf.type_desc = f.type_desc;
				END
				--ELSE
				IF NOT (@_LogOrData = 'Log') AND @expandTempDBSize <> 1
				BEGIN
					IF @verbose=1 
						PRINT	'	Begin Common Code: inside else part of @_LogOrData = ''Log''';

					--	Find Data files on @oldVolume. [isExistingOn_NewVolume] column indicates if the same files exists on @newVolume.
					;WITH T_Files AS 
					(		
						--	Find Data files on @oldVolume
						SELECT	DB_NAME(database_id) as dbName, mf1.*, fg1.name as [fileGroup]
									-- Consider adding single file per filegroup for each database
								,[FileIDRankPerFileGroup] = row_number()over(partition by mf1.database_id, fg1.name order by mf1.file_id)
									-- Check if corresponding Data file for same FileGroup exists on @newVolume
								,[isExistingOn_NewVolume] = CASE WHEN NOT EXISTS (
																					SELECT	mf2.*, NULL as [fileGroup]
																					FROM	sys.master_files mf2
																					WHERE	mf2.type_desc = mf1.type_desc 
																						AND	mf2.database_id = mf1.database_id
																						AND mf2.data_space_id = mf1.data_space_id -- same filegroup
																						AND mf2.physical_name like (@newVolume+'%')
																				)
																THEN 0
																ELSE 1
																END
								,[isExisting_UnrestrictedGrowth_on_OtherVolume] = CASE WHEN EXISTS (
																					SELECT	mf2.*, NULL as [fileGroup]
																					FROM	sys.master_files mf2
																					WHERE	mf2.type_desc = mf1.type_desc
																						AND	mf2.database_id = mf1.database_id
																						AND mf2.data_space_id = mf1.data_space_id -- same filegroup
																						AND mf2.growth <> 0
																						AND LEFT(mf2.physical_name, CHARINDEX('\',mf2.physical_name,4)) IN (select Volume from @mountPointVolumes V WHERE V.Volume <> @oldVolume AND [freespace(%)] >= 20.0)
																				)
																THEN 1
																ELSE 0
																END
						--FROM	sys.master_files mf1 inner join sys.filegroups fg1 on fg1.data_space_id = mf1.data_space_id
						FROM	sys.master_files mf1 left join @filegroups fg1 on fg1.data_space_id = mf1.data_space_id
							AND	fg1.DBName = DB_NAME(mf1.database_id)
						WHERE	mf1.type_desc = 'rows'
							AND	mf1.physical_name LIKE (@oldVolume+'%')
					)	--select 'Testing',* from T_Files;
						INSERT #T_Files_Derived
						(	dbName, database_id, file_id, type_desc, data_space_id, name, physical_name, size, max_size, growth, is_percent_growth, fileGroup, 
							FileIDRankPerFileGroup, isExistingOn_NewVolume, isExisting_UnrestrictedGrowth_on_OtherVolume, [Size (GB)], _name, _physical_name, TotalSize_All_DataFiles_MB, TotalSize_All_LogFiles_MB, maxfileSize_oldVolumes_MB, TSQL_AddFile, TSQL_RestrictFileGrowth, TSQL_UnRestrictFileGrowth
						)
						SELECT	f.dbName, f.database_id, f.file_id, f.type_desc, f.data_space_id, f.name, f.physical_name, f.size, f.max_size, f.growth, f.is_percent_growth, f.fileGroup, 
								f.FileIDRankPerFileGroup, f.isExistingOn_NewVolume, f.isExisting_UnrestrictedGrowth_on_OtherVolume, d.[Size (GB)]
								,[_name]
								,[_physical_name] = @newVolume+[_name]+'.ndf'
								,u2.Sum_DataFilesSize_MB AS TotalSize_All_DataFiles_MB
								,u2.Sum_LogsFilesSize_MB AS TotalSize_All_LogFiles_MB
								,u.maxfileSize_oldVolumes_MB
								,[TSQL_AddFile] = CAST(NULL AS VARCHAR(2000))
								,[TSQL_RestrictFileGrowth] = CAST(NULL AS VARCHAR(2000))
								,[TSQL_UnRestrictFileGrowth] = CAST(NULL AS VARCHAR(2000))
						FROM	T_Files as f -- all data files on @oldVolume
						LEFT JOIN
								@DatabasesBySize	AS d
							ON	d.database_id = f.database_id
						LEFT JOIN
								(	select u.DbName, u.data_space_id
											,(CASE WHEN u.data_space_id = 0 THEN MAX(CurrentSizeMB) ELSE MAX(u.SpaceUsed) END) -- if log file then CurrentSizeMB else SpaceUsed
												 AS maxfileSize_oldVolumes_MB 
									from @DBFiles AS u 
									group by u.DbName, u.data_space_id
								) AS u
							ON	f.database_id = DB_ID(u.DbName)
							AND	f.data_space_id = u.data_space_id
						LEFT JOIN
								(	SELECT	DbName,	Sum_DataFilesSize_MB, Sum_LogsFilesSize_MB
									FROM  (	select u.DbName, (CASE WHEN u.[type_desc] = 'ROWS' THEN 'Sum_DataFilesSize_MB' ELSE 'Sum_LogsFilesSize_MB' END) AS [type_desc]
													,(CASE WHEN u.[type_desc] = 'LOG' THEN SUM(CurrentSizeMB) ELSE SUM(u.SpaceUsed) END) -- if log file then SUM(CurrentSizeMB) else SUM(SpaceUsed)
														 AS Sum_fileSize_ByType_MB 
											from @DBFiles AS u 
											group by u.DbName, u.[type_desc]
										  ) AS u
									PIVOT ( MAX(Sum_fileSize_ByType_MB) FOR [type_desc] in (Sum_DataFilesSize_MB, Sum_LogsFilesSize_MB) ) AS pvt
								) AS u2
							ON	f.database_id = DB_ID(u2.DbName)
						LEFT JOIN -- get new names per filegroup
							(	SELECT	database_id, DBName, type_desc, name, _name = (CASE WHEN CHARINDEX(DBName,name) <> 0 THEN DBName ELSE '' END)+_Name_Without_DBName
										,FileOrder ,data_space_id
								FROM	(
											SELECT	database_id, DBName, type_desc, name, FileNO_String, FileNO_Int, Name_Without_DBName, FileOrder, data_space_id,
													[_Name_Without_DBName] = (CASE WHEN LEN( [_Name_Without_DBName]) > 0 THEN [_Name_Without_DBName] ELSE (CASE WHEN type_desc = 'ROWS' THEN '_Data01' ELSE '_Log01' END) END)
											FROM	(
														SELECT	T_Files_01.*
																,FileOrder = ROW_NUMBER()OVER(PARTITION BY DBName, type_desc, data_space_id ORDER BY FileNO_Int DESC)
																,MaxFileNO = MAX(FileNO_Int)OVER(PARTITION BY DBName, type_desc)
																,[_Name_Without_DBName] = CASE	WHEN LEN(FileNO_String)<>0 -- if more than 1 files already exist, then just increment no by 1
																								THEN REPLACE(Name_Without_DBName,FileNO_String,(CASE WHEN LEN(FileNO_Int+data_space_id) = 1 THEN ('0'+CAST((FileNO_Int+data_space_id) AS VARCHAR(20))) ELSE CAST((FileNO_Int+data_space_id) AS VARCHAR(20)) END )) 
																								ELSE Name_Without_DBName + (CASE WHEN type_desc = 'LOG' THEN '01' ELSE '_data01' END) END
														FROM	(
											
																	SELECT mf.database_id, db_name(database_id) AS DBName, type_desc, name, data_space_id, growth
																			,FileNO_String = RIGHT(REPLACE(REPLACE(name,']',''),'[',''),PATINDEX('%[a-zA-Z_ ]%',REVERSE(REPLACE(REPLACE(name,']',''),'[','')))-1)
																			,FileNO_Int = CAST(RIGHT(REPLACE(REPLACE(name,']',''),'[',''),PATINDEX('%[a-zA-Z_ ]%',REVERSE(REPLACE(REPLACE(name,']',''),'[','')))-1) AS BIGINT)
																			,Name_Without_DBName = REPLACE ( name, db_name(database_id), '')
																	FROM sys.master_files as mf
																	WHERE mf.type_desc = 'ROWS'
											
																) AS T_Files_01
													) AS T_Files_02
										) AS T_Files_03
								WHERE	FileOrder = 1
							)  AS mf
							ON	mf.database_id = f.database_id
							AND	mf.type_desc = f.type_desc
							AND mf.data_space_id = f.data_space_id;
				END -- Ending of if else block 
			
				IF @verbose = 1 AND @expandTempDBSize <> 1
				BEGIN
					PRINT	'	Completed Data population in #T_Files_Derived';
					SELECT	Q.RunningQuery, d.*
					FROM  (	SELECT 'SELECT * FROM #T_Files_Derived ORDER BY dbName, file_id;' AS RunningQuery ) Q
					LEFT JOIN
							#T_Files_Derived AS d
					ON		1 = 1
					ORDER BY dbName, file_id;
				END

				/* By default, if another unrestricted file exists in any other volume, then don't create files for that db */
				IF @allowMulYourOrglumeUnrestrictedFiles = 1
				BEGIN
					IF	@_LogOrData = 'Log'
					BEGIN
						IF @verbose = 1
							PRINT	'	Updating #T_Files_Derived table for @allowMulYourOrglumeUnrestrictedFiles option.';
						UPDATE	fo
						SET		isExisting_UnrestrictedGrowth_on_OtherVolume = 0
						FROM	#T_Files_Derived AS fo
						WHERE	(	isExistingOn_NewVolume = 0 AND isExisting_UnrestrictedGrowth_on_OtherVolume = 1) --if file not exists on @newVolume
							OR	(	isExistingOn_NewVolume = 1 -- if file exists on @newVolume but with 0 growth
								AND NOT EXISTS (select * from sys.master_files as fi where fi.database_id = fo.database_id and fi.data_space_id = fo.data_space_id and fi.growth <> 0 AND fi.physical_name LIKE (@newVolume+'%'))
								);
					END
				END

				------------------------------------------------------------------------------------------------
				--	Begin: Get All Databases that are not accessible being Offline, ReadOnly or in Restoring Mode
				INSERT @T_DatabasesNotAccessible
				SELECT	*
				FROM  (
						--	Database in 'Restoring' mode
						SELECT	d.database_id, DB_NAME(d.database_id) AS DBName
						FROM	sys.databases as d
						WHERE	d.state_desc = 'Restoring'
							AND	d.database_id NOT IN (SELECT m.database_id FROM sys.database_mirroring as m WHERE m.mirroring_role_desc IS NOT NULL)
							AND	d.database_id IN (select f.database_id from #T_Files_Derived as f)
						--
						UNION 
						--	Database that are 'Offline' or 'Read Only'
						SELECT	d.database_id, DB_NAME(d.database_id) AS DBName
						FROM	sys.databases as d
						WHERE	(CASE WHEN d.is_read_only = 1 THEN 'Read_Only' ELSE DATABASEPROPERTYEX(DB_NAME(d.database_id), 'Status') END) <> 'ONLINE'
					  ) AS A
				ORDER BY A.DBName;

				IF @verbose=1 
					PRINT	'	Begin Common Code: End of Find Data/Log files on @oldVolume';
				--	------------------------------------------------------------------------
				--	End: Find Data/Log files on @oldVolume
				--	============================================================================================

				IF @verbose=1 
					PRINT	'	Initializing values for @_mirrorDatabases and @_principalDatabases';
				IF	@_mirroringPartner IS NOT NULL
				BEGIN
					--	Find all databases that are part of Mirroring plan, their data files are +nt on @oldVolume and playing 'MIRROR' role.
					SELECT	@_mirrorDatabases = COALESCE(@_mirrorDatabases+', '+DB_NAME(database_id),DB_NAME(database_id))
					FROM	sys.database_mirroring m
					WHERE	m.mirroring_state IS NOT NULL
						AND	m.mirroring_role_desc = 'MIRROR'
						AND	m.database_id IN (select f.database_id from #T_Files_Derived as f);
					SET @_mirrorDatabaseCounts_Mirroring = (LEN(@_mirrorDatabases)-LEN(REPLACE(@_mirrorDatabases,',',''))+1);
		
					--	Find all databases that are part of Mirroring plan, their data files are +nt on @oldVolume and playing 'PRINCIPAL' role.
					SELECT	@_principalDatabases = COALESCE(@_principalDatabases+', '+DB_NAME(database_id),DB_NAME(database_id))
					FROM	sys.database_mirroring m
					WHERE	m.mirroring_state IS NOT NULL
						AND	m.mirroring_role_desc = 'PRINCIPAL'
						AND	m.database_id IN (select f.database_id from #T_Files_Derived as f where (@addDataFiles = 0 OR (@addDataFiles = 1 AND f.isExistingOn_NewVolume = 0)) OR (@restrictDataFileGrowth = 0 OR (@restrictDataFileGrowth = 1 AND growth <> 0 AND f.isExistingOn_NewVolume = 1)) OR  (@unrestrictFileGrowth = 0 OR (@unrestrictFileGrowth = 1 AND growth = 0)));	
					SET @_principalDatabaseCounts_Mirroring = (LEN(@_principalDatabases)-LEN(REPLACE(@_principalDatabases,',',''))+1);
				END

				IF @verbose=1 
					PRINT	'	Initializing values for @_databasesWithMultipleDataFiles';
				--	Find all databases having multiple files per filegroup on @oldVolume.
				SELECT	@_databasesWithMultipleDataFiles = COALESCE(@_databasesWithMultipleDataFiles+', '+DB_NAME(database_id),DB_NAME(database_id))
				FROM  (	SELECT DISTINCT database_id FROM #T_Files_Derived AS m WHERE FileIDRankPerFileGroup <> 1 ) as f;
				SET @_databasesWithMultipleDataFilesCounts = (LEN(@_databasesWithMultipleDataFilesCounts)-LEN(REPLACE(@_databasesWithMultipleDataFilesCounts,',',''))+1);

				IF @verbose=1 
					PRINT	'	Initializing values for @_nonAccessibleDatabases';
				SELECT	@_nonAccessibleDatabases = COALESCE(@_nonAccessibleDatabases+', '+DB_NAME(database_id),DB_NAME(database_id))
				FROM  @T_DatabasesNotAccessible;
				SET @_nonAccessibleDatabasesCounts = (LEN(@_nonAccessibleDatabases)-LEN(REPLACE(@_nonAccessibleDatabases,',',''))+1);


				IF @verbose=1 AND @_nonAccessibleDatabases IS NOT NULL
					PRINT	'	Below are few non-accessible databases:-
			'+@_nonAccessibleDatabases;

				IF @verbose=1
					PRINT	'	Create #T_Files_Final from #T_Files_Derived table';

				--	Create temp table #T_Files_Final with Data files of @oldVolume that can be successfully processed for @addDataFiles & @restrictDataFileGrowth operations.
				IF OBJECT_ID('tempdb..#T_Files_Final') IS NOT NULL
					DROP TABLE #T_Files_Final;
				
				IF @verbose=1 AND EXISTS (SELECT * FROM @filterDatabaseNames)
				BEGIN
					PRINT	'	Filtering #T_Files_Final for databases based on @DBs2Consider';
					SELECT	'SELECT * FROM @filterDatabaseNames' AS RunningQuery, *
					FROM	@filterDatabaseNames;
				END

				SELECT	*
				INTO	#T_Files_Final
				FROM	#T_Files_Derived AS f
				WHERE	f.database_id NOT IN (SELECT m.database_id FROM	sys.database_mirroring m WHERE m.mirroring_state IS NOT NULL AND m.mirroring_role_desc = 'MIRROR')
					AND	f.database_id NOT IN (	SELECT d.database_id FROM @T_DatabasesNotAccessible as d)
					AND (	NOT EXISTS (SELECT * FROM @filterDatabaseNames)
						OR	f.database_id IN (SELECT DB_ID(d.DBName) FROM @filterDatabaseNames AS d)
						);
		
				IF (@_LogOrData='Log')
				BEGIN
					IF @verbose=1 
						PRINT	'	Populate #T_Files_Final for Log Files';

					IF @verbose = 1
						PRINT	'	Updating value in [maxfileSize_oldVolumes_MB] column for Log files in #T_Files_Final';
					UPDATE	#T_Files_Final
					SET	maxfileSize_oldVolumes_MB = CASE WHEN (TotalSize_All_DataFiles_MB / 4) < maxfileSize_oldVolumes_MB -- Check if Max Log size > 1/4th of data file 
														 THEN maxfileSize_oldVolumes_MB -- keep log size
														 WHEN ((TotalSize_All_DataFiles_MB / 4) - TotalSize_All_LogFiles_MB) <= maxfileSize_oldVolumes_MB -- Check if 1/4th Data file - Total Log size is less than maxfileSize_oldVolumes_MB
														 THEN maxfileSize_oldVolumes_MB
														 ELSE ((TotalSize_All_DataFiles_MB / 4) - TotalSize_All_LogFiles_MB) 
														 END 
					WHERE maxfileSize_oldVolumes_MB < 16000;

					/*	Say, 4 Data files with sum(UsedSpace) = TotalSize_All_DataFiles_MB
							2 Log Files with sum(CurrentSize) = TotalSize_All_LogFiles_MB

							Max_Log_Size_MB		TotalSize_All_DataFiles_MB		TotalSize_All_LogFiles_MB	New_Max_Log_Size_Threadhold		Initial_Size		Growth
							6000				120000							10000						30000							8000MB				8000MB
							13000				120000							20000						13000							4000MB				1000MB
							10000				80000							20000						10000							4000MB				1000MB
							2000				120000							3000						27000							8000MB				8000MB
							2000				12000							2000						2000							4000MB				500MB
							6000				16000							7000						6000							4000MB				500MB
							20000				120000							22000						20000							8000MB				8000MB
							20000				300000							30000						20000							8000MB				8000MB
							500					4000							500							500								500MB				500MB
							120 gb				500 gb							128 gb						120 gb							8 gb				8gb
							512 mb				500 gb							1 gb						31 gb							8 gb				8gb


					*/
							

					IF @verbose = 1
						PRINT	'	Updating value in [_initialSize] column for Log files in #T_Files_Final';
					--	https://www.sqlskills.com/blogs/paul/important-change-vlf-creation-algorithm-sql-server-2014/
					UPDATE	#T_Files_Final
					SET		[_initialSize] =	CASE	WHEN	maxfileSize_oldVolumes_MB < 256 
														THEN	'256MB'
														WHEN	maxfileSize_oldVolumes_MB < 1000
														THEN	CAST(maxfileSize_oldVolumes_MB AS VARCHAR(20))+'MB'
														WHEN	maxfileSize_oldVolumes_MB = 8192
														THEN	'4000MB'
														WHEN	maxfileSize_oldVolumes_MB < 16000
														THEN	CAST(CAST( (maxfileSize_oldVolumes_MB/2) AS NUMERIC(20,0)) AS VARCHAR(20))+'MB'
														ELSE	'8000MB'
														END

					IF @verbose = 1
						PRINT	'	Updating value in [_autoGrowth] column for Log files in #T_Files_Final';
					UPDATE	#T_Files_Final
					SET		[_autoGrowth] =	CASE	WHEN	maxfileSize_oldVolumes_MB < 8000 
													THEN	'500MB'
													WHEN	maxfileSize_oldVolumes_MB < 16000
													THEN	'1000MB'
													ELSE	'8000MB'
													END

					UPDATE	#T_Files_Final
							SET		TSQL_AddFile = '
		'+(CASE WHEN @forceExecute = 0 THEN 'PRINT	''Adding new file '+QUOTENAME(_name)+' for database ['+dbName+']'';' ELSE '' END)+ '
	ALTER DATABASE ['+dbName+'] ADD LOG FILE ( NAME = N'+QUOTENAME(_name,'''')+', FILENAME = '+QUOTENAME(_physical_name,'''')+' , SIZE = '+[_initialSize]+' , FILEGROWTH = '+[_autoGrowth]+');'
									,TSQL_RestrictFileGrowth = '
		'+(CASE WHEN @forceExecute = 0 THEN 'PRINT	''Restricting growth for file '+QUOTENAME(name)+' of database ['+dbName+']'';' ELSE '' END)+ '
	ALTER DATABASE ['+dbName+'] MODIFY FILE ( NAME = '+QUOTENAME(name,'''')+', FILEGROWTH = 0);'
									,TSQL_UnRestrictFileGrowth = '
		'+(CASE WHEN @forceExecute = 0 THEN 'PRINT	''Removing restriction for file '+QUOTENAME(name)+' of database ['+dbName+']'';' ELSE '' END) + '
	ALTER DATABASE ['+dbName+'] MODIFY FILE ( NAME = '+QUOTENAME(name,'''')+', FILEGROWTH = '+[_autoGrowth]+')';

												END
				ELSE
				BEGIN
					
					IF @verbose = 1
						PRINT	'	Updating value in [_initialSize] column for Data files in #T_Files_Final';
					UPDATE	#T_Files_Final
					SET		[_initialSize] =	CASE	WHEN	[Size (GB)] < 2
														THEN	'256MB'
														WHEN	[Size (GB)] BETWEEN 2 AND 10
														THEN	'512MB'
														WHEN	[Size (GB)] > 10 AND [maxfileSize_oldVolumes_MB] < (50*1024) -- less than 50 gb
														THEN	'1024MB'
														WHEN	[maxfileSize_oldVolumes_MB] BETWEEN (50*1024) AND (200*1024) -- b/w 50 gb and 200 gb
														THEN	'10240MB' -- 10 GB
														WHEN	[maxfileSize_oldVolumes_MB] > (200*1024) -- greator than 200 gb
														THEN	'51200MB' -- 50 GB
														ELSE	NULL
														END

					IF @verbose = 1
						PRINT	'	Updating value in [_autoGrowth] column for Data files in #T_Files_Final';
					UPDATE	#T_Files_Final
					SET		[_autoGrowth] =	CASE	WHEN	[Size (GB)] < 2
														THEN	'256MB'
														WHEN	[Size (GB)] BETWEEN 2 AND 10
														THEN	'512MB'
														WHEN	[Size (GB)] > 10 AND [maxfileSize_oldVolumes_MB] < (50*1024) -- less than 50 gb
														THEN	'1024MB'
														WHEN	[maxfileSize_oldVolumes_MB] BETWEEN (50*1024) AND (200*1024) -- b/w 50 gb and 200 gb
														THEN	'2048MB'
														WHEN	[maxfileSize_oldVolumes_MB] > (200*1024) -- greator than 200 gb
														THEN	'5120MB'
														ELSE	NULL
														END

					UPDATE	#T_Files_Final
								SET	TSQL_AddFile = '
		'+(CASE WHEN @forceExecute = 0 THEN 'PRINT	''Adding new file '+QUOTENAME(_name)+' for database ['+dbName+']'';' ELSE '' END) + '
	ALTER DATABASE ['+dbName+'] ADD FILE ( NAME = '+QUOTENAME(_name,'''')+', FILENAME = '+QUOTENAME(_physical_name,'''')+' , SIZE = '+[_initialSize]+' , FILEGROWTH = '+[_autoGrowth]+') TO FILEGROUP '+QUOTENAME(fileGroup)+';'
									,TSQL_RestrictFileGrowth = '		
		'+(CASE WHEN @forceExecute = 0 THEN 'PRINT	''Restricting growth for file '+QUOTENAME(name)+' of database ['+dbName+']'';' ELSE '' END) + '
	ALTER DATABASE ['+dbName+'] MODIFY FILE ( NAME = '+QUOTENAME(name,'''')+', FILEGROWTH = 0);'
									,TSQL_UnRestrictFileGrowth = '		
		'+(CASE WHEN @forceExecute = 0 THEN 'PRINT	''Removing restriction for file '+QUOTENAME(name,'''')+' of database ['+dbName+']'';' ELSE '' END) + '	
	ALTER DATABASE ['+dbName+'] MODIFY FILE ( NAME = '+QUOTENAME(name,'''')+', FILEGROWTH = '+[_autoGrowth]+');';
		
				END

				IF @verbose=1 AND @expandTempDBSize <> 1
				BEGIN
					PRINT	'	SELECT * FROM #T_Files_Final;';
					SELECT Q.RunningQuery , dt.*
					FROM (	SELECT 'SELECT * FROM #T_Files_Final;' AS RunningQuery) Q
					LEFT JOIN
							#T_Files_Final as dt
					ON 1 = 1;
				END
			
				IF @verbose=1 AND @expandTempDBSize <> 1
				BEGIN
					PRINT	'	Find the free space % on @oldVolume';
					PRINT	'	SELECT * FROM @mountPointVolumes AS v WHERE	v.Volume = @oldVolume;';
			
					SELECT RunningQuery, v.* 
					FROM (SELECT 'SELECT * FROM @mountPointVolumes AS v WHERE	v.Volume = @oldVolume' AS RunningQuery) Q
					LEFT JOIN @mountPointVolumes AS v 
					ON	1 = 1
					AND v.Volume = @oldVolume;
				END

				SELECT	@_freeSpace_OldVolume_GB = [freespace(GB)],
						@_totalSpace_OldVolume_GB = [capacity(GB)],
						@_freeSpace_OldVolume_Percent = [freespace(%)]
				FROM	@mountPointVolumes AS v 
				WHERE	v.Volume = @oldVolume;
			END	-- End Block: Don't execute common codes for @getInfo functionality

			IF @verbose=1 
				PRINT	'/*	******************** END: Common Code *****************************/

';
		END	-- End block of Common Code
		--	----------------------------------------------------------------------------
			--	End:	Common Code 
		--	============================================================================
	
		--	============================================================================
			--	Begin:	@getInfo = 1
		--	----------------------------------------------------------------------------	
		IF	@getInfo = 1
		BEGIN	-- Begin Block of @getInfo
			IF @verbose=1 
				PRINT	'
/*	******************** Begin:	@getInfo = 1 *****************************/';

			IF @verbose=1 
				PRINT	'	Creating temp table #FilesByFileGroup';

			IF OBJECT_ID('tempdb..#FilesByFileGroup') IS NOT NULL
				DROP TABLE #FilesByFileGroup;
			WITH T_FileGroup AS
			(	SELECT mf1.database_id, mf1.data_space_id, fg1.name as [FileGroup], CONVERT(DECIMAL(20,2),((SUM(CONVERT(BIGINT,size))*8.0)/1024/1024)) AS [TotalFilesSize(GB)]
				FROM sys.master_files AS mf1 LEFT JOIN @filegroups AS fg1 ON fg1.data_space_id = mf1.data_space_id AND fg1.DBName = DB_NAME(mf1.database_id)
				GROUP BY mf1.database_id, mf1.data_space_id, fg1.name
			)
			,T_Files_Filegroups AS
			(
				SELECT	mf.file_id, mf.database_id as [DB_ID], DB_NAME(mf.database_id) AS [DB_Name], fg.[TotalFilesSize(GB)], fg.[FileGroup]
						,growth 
						,(CASE WHEN growth = 0 THEN '0' WHEN is_percent_growth = 1 THEN CAST(growth AS VARCHAR(5))+'%' 
						ELSE CAST(CONVERT( DECIMAL(20,2),((65536*8.0)/1024.0)) AS VARCHAR(20))+'(MB)'
						END) AS [growth(GB)]
						,name as [FileName] ,LEFT(physical_name, CHARINDEX('\',physical_name,4))  as [Volume] 
				FROM	sys.master_files AS mf
				INNER JOIN
						T_FileGroup AS fg
					ON	mf.database_id = fg.database_id AND mf.data_space_id = fg.data_space_id
				WHERE	mf.type_desc = 'ROWS'
			)
			,T_Files_Usage AS
			(
				SELECT	DbName, [FileName], data_space_id, physical_name, CurrentSizeMB, FreeSpaceMB, SpaceUsed, type_desc, growth, is_percent_growth, [% space used]
						,size = CASE	WHEN CurrentSizeMB >= (1024.0 * 1024.0) -- size > 1 tb
										THEN CAST(CAST(CurrentSizeMB / (1024.0 * 1024.0) AS numeric(20,2)) AS VARCHAR(20))+' tb'
										WHEN CurrentSizeMB >= 1024 -- size < 1 tb but greater than 1024 mb
										THEN CAST(CAST(CurrentSizeMB / 1024 AS numeric(20,2)) AS VARCHAR(20))+ ' gb'
										ELSE CAST(CAST(CurrentSizeMB AS NUMERIC(20,2)) AS VARCHAR(20)) + ' mb'
										END
				FROM	@DBFiles AS f
			)
			,T_Volumes_Derived AS
			(
				SELECT	Volume
					   ,[capacity(MB)]
					   ,[freespace(MB)]
					   ,VolumeName
					   ,[capacity(GB)]
					   ,[freespace(GB)]
					   , [freespace(%)]
				FROM	@mountPointVolumes as v
				WHERE	v.Volume IN (SELECT DISTINCT [Volume] FROM T_Files_Filegroups)
					OR	v.Volume LIKE '[A-Z]:\Data[0-9]\'
					OR	v.Volume LIKE '[A-Z]:\Data[0-9][0-9]\'
			)
			,T_Files AS
			( 
				SELECT	DB_ID, DB_Name, [TotalFilesSize(GB)], [FileGroup], 
						--f.FileName+' (Growth by '+[growth(GB)]+')' AS FileSettings, 
						f.[FileName]+' (Size|% Used|AutoGrowth :: '+size+'|'+CAST([% space used] AS VARCHAR(50))+' %|'+[growth(GB)]+')' AS FileSettings, 
						v.VolumeName+' = '+CAST([freespace(GB)] AS VARCHAR(20))+'GB('+CAST([freespace(%)] AS VARCHAR(20))+'%) Free of '+CAST([capacity(GB)] AS VARCHAR(20))+' GB' as FileDrive
						,f.growth, f.[growth(GB)], f.[FileName], v.Volume, [capacity(MB)], [freespace(MB)], VolumeName, [capacity(GB)], [freespace(GB)], [freespace(%)]
						,ROW_NUMBER()OVER(PARTITION BY v.Volume, f.DB_Name, f.[FileGroup] ORDER BY f.[file_id])AS FileID
				FROM	T_Files_Filegroups AS f
				LEFT JOIN
						T_Files_Usage as u
					ON	u.DbName = f.[DB_Name]
					AND	u.[FileName] = f.[FileName]
				RIGHT OUTER JOIN
						T_Volumes_Derived AS v
					ON	v.Volume = f.[Volume]
			),T_Files_Derived AS
			(
				SELECT	DB_ID, DB_Name, CASE WHEN d.is_read_only = 1 THEN 'Read_Only' ELSE DATABASEPROPERTYEX(DB_Name, 'Status') END as DB_State, [TotalFilesSize(GB)], FileGroup, STUFF(
								(SELECT ', ' + f2.FileSettings
								 FROM T_Files as f2
								 WHERE f2.Volume = f.Volume AND f2.DB_Name = f.DB_Name AND f2.FileGroup = f.FileGroup
								 FOR XML PATH (''))
								  , 1, 1, ''
							) AS Files, FileDrive, growth, [growth(GB)], FileName, Volume, [capacity(MB)], [freespace(MB)], VolumeName, [capacity(GB)], [freespace(GB)], [freespace(%)], FileID
				FROM	T_Files as f LEFT OUTER JOIN sys.databases as d 
					ON	d.name = f.DB_Name
				WHERE	f.FileID = 1
			)
			SELECT	*
			INTO	#FilesByFileGroup
			FROM	T_Files_Derived;

			IF @verbose = 1
			BEGIN
				PRINT 'SELECT * FROM #FilesByFileGroup';
				SELECT 'SELECT * FROM #FilesByFileGroup' AS RunningQuery, * FROM #FilesByFileGroup;
			END

			IF @verbose = 1
			BEGIN
				SELECT  DISTINCT TOP 100 'SELECT DISTINCT TOP 100 FileDrive, LEFT(FileDrive,4) AS First4Char, CAST(SUBSTRING(Volume, PATINDEX(''%[0-9]%'', Volume), PATINDEX(''%[0-9][^0-9]%'', Volume + ''t'') - PATINDEX(''%[0-9]%'', 
							Volume) + 1) AS INT) AS Number, Volume
							,Vol_Order =	(CASE	WHEN	Volume LIKE ''%MSSQL%''
									THEN	1
									WHEN	Volume LIKE ''%TempDB%''
									THEN	2
									ELSE	3
									END)
					FROM #FilesByFileGroup 
					ORDER BY Vol_Order,First4Char,Number;'AS RunningQuery, FileDrive, LEFT(FileDrive,4) AS First4Char, CAST(SUBSTRING(Volume, PATINDEX('%[0-9]%', Volume), PATINDEX('%[0-9][^0-9]%', Volume + 't') - PATINDEX('%[0-9]%', 
							Volume) + 1) AS INT) AS Number, Volume
							,Vol_Order =	(CASE	WHEN	Volume LIKE '%MSSQL%'
									THEN	1
									WHEN	Volume LIKE '%TempDB%'
									THEN	2
									ELSE	3
									END)
					FROM #FilesByFileGroup 
					ORDER BY Vol_Order,First4Char,Number;
			END

			IF @verbose = 1
			BEGIN
				PRINT	'	Initiating value for @_commaSeparatedMountPointVolumes using COALESCE statement';
			END

			SELECT	@_commaSeparatedMountPointVolumes = COALESCE(@_commaSeparatedMountPointVolumes+', '+QUOTENAME(FileDrive), QUOTENAME(FileDrive))
			FROM (	SELECT DISTINCT TOP 100 FileDrive, LEFT(FileDrive,4) AS First4Char, CAST(SUBSTRING(Volume, PATINDEX('%[0-9]%', Volume), PATINDEX('%[0-9][^0-9]%', Volume + 't') - PATINDEX('%[0-9]%', Volume) + 1) AS INT) AS Number, Volume
							,Vol_Order =	(CASE	WHEN	Volume LIKE '%MSSQL%'
													THEN	1
													WHEN	Volume LIKE '%TempDB%'
													THEN	2
													ELSE	3
													END)
					FROM #FilesByFileGroup 
					ORDER BY Vol_Order,First4Char,Number
				) AS FD;

			IF @verbose = 1
			BEGIN
				PRINT	'	Value of @_commaSeparatedMountPointVolumes = ' + @_commaSeparatedMountPointVolumes;
			END

			--	Unfortunately table variables are out of scope of dynamic SQL, trying temp table method
			IF OBJECT_ID('tempdb..#filterDatabaseNames') IS NOT NULL
				DROP TABLE #filterDatabaseNames;
			SELECT * INTO #filterDatabaseNames FROM @filterDatabaseNames;

			SET @_sqlGetInfo = '
				SELECT	DB_ID, DB_Name, DB_State, [TotalFilesSize(GB)], FileGroup, '+@_commaSeparatedMountPointVolumes+'
				FROM  (
						SELECT	DB_ID, DB_Name, DB_State, [TotalFilesSize(GB)], FileGroup, Files, FileDrive
						FROM	#FilesByFileGroup
						WHERE	DB_Name IS NOT NULL
							AND	(	NOT EXISTS (SELECT * FROM #filterDatabaseNames) 
								OR	DB_Name IN (SELECT d.DBName FROM #filterDatabaseNames AS d)
								) 
					  ) up
				PIVOT	(MAX(Files) FOR FileDrive IN ('+@_commaSeparatedMountPointVolumes+')) AS pvt
				ORDER BY [DB_Name];';

			IF @verbose = 1
			BEGIN
				PRINT	'	Value of @_sqlText = ' + @_sqlGetInfo;
			END

			EXEC (@_sqlGetInfo)
			IF @verbose=1 
				PRINT	'/*	******************** End:	@getInfo = 1 *****************************/

';

		END	-- End Block of @getInfo
		
		--	----------------------------------------------------------------------------
			--	End:	@getInfo = 1
		--	============================================================================


		--	============================================================================
			--	Begin:	@getLogInfo = 1
		--	----------------------------------------------------------------------------
		IF	@getLogInfo = 1
		BEGIN
			IF @verbose=1 
				PRINT	'
/*	******************** Begin:	@getLogInfo = 1 *****************************/';

			IF @_productVersion LIKE '10.%' OR @_productVersion LIKE '9.%'
				ALTER TABLE #stage DROP COLUMN [RecoveryUnitId];

			INSERT @Databases -- Eliminate non-accessible DBs
			SELECT name FROM sys.databases d WHERE DATABASEPROPERTYEX(name, 'Status') = 'ONLINE';

			IF	@verbose = 1
			BEGIN
				PRINT	'	SELECT * FROM @Databases;';
				SELECT 'SELECT * FROM @Databases;' AS RunningQuery, * FROM @Databases;
			END
				
	
			SET	@_loopCounter = 1;
			SET	@_loopCounts = (SELECT COUNT(*) FROM @Databases);

			IF @verbose=1 
				PRINT	'	Start Loop, and find VLFs for each log file of every db';
			WHILE (@_loopCounter <= @_loopCounts)
			BEGIN
				SELECT @_dbName = DBName FROM @Databases WHERE ID = @_loopCounter ;
				SET @_loopSQLText = 'DBCC LOGINFO ('+QUOTENAME(@_dbName)+')
		WITH  NO_INFOMSGS;';

				INSERT #stage
				EXEC (@_loopSQLText);

				INSERT #LogInfoByFile
				SELECT	@_dbName AS DBName,
						file_id as FileId,
						COUNT(*) AS VLFCount
				FROM	#stage
				GROUP BY [file_id];

				SET @_loopCounter = @_loopCounter + 1;
			END
			
			IF	@verbose = 1
			BEGIN
				PRINT	'	Finished finding VLFs for each log file of every db
		SELECT * FROM #LogInfoByFile;';
				SELECT 'SELECT * FROM #LogInfoByFile;' AS RunningQuery, * FROM #LogInfoByFile;
			END

			IF	@verbose = 1
				PRINT	'	Creating table #LogFiles.';

			IF OBJECT_ID('tempdb..#LogFiles') IS NOT NULL
				DROP TABLE #LogFiles;
			;WITH T_Files_Size AS
			(
				SELECT mf.database_id, CONVERT(DECIMAL(20,2),((SUM(size)*8.0)/1024/1024)) AS [TotalFilesSize(GB)] FROM sys.master_files AS mf WHERE mf.type_desc = 'LOG' GROUP BY mf.database_id
			)
			,T_Files_Filegroups AS
			(
				SELECT	mf.database_id as [DB_ID], DB_NAME(mf.database_id) AS [DB_Name], CASE WHEN d.is_read_only = 1 THEN 'Read_Only' ELSE DATABASEPROPERTYEX(DB_NAME(mf.database_id), 'Status') END as DB_State
						,[TotalFilesSize(GB)]
						,(CASE WHEN growth = 0 THEN '0' WHEN is_percent_growth = 1 THEN CAST(growth AS VARCHAR(5))+'%' 
						ELSE CAST(CONVERT( DECIMAL(20,2),((65536*8.0)/1024.0)) AS VARCHAR(20))+' mb'
						END) AS [growth(GB)]
						,mf.name as [FileName] ,LEFT(physical_name, CHARINDEX('\',physical_name,4))  as [Volume]
						,mf.* 
						,d.recovery_model_desc
				FROM	sys.master_files AS mf
				INNER JOIN
						sys.databases as d
				ON		d.database_id = mf.database_id
				LEFT JOIN
						T_Files_Size AS l
					ON	l.database_id = mf.database_id
				WHERE	mf.type_desc = 'LOG'
			)
			,T_Volumes_Derived AS
			(
				SELECT	Volume
					   ,[capacity(MB)]
					   ,[freespace(MB)]
					   ,VolumeName
					   ,[capacity(GB)]
					   ,[freespace(GB)]
					   ,[freespace(%)]
				FROM	@mountPointVolumes as v
				WHERE	v.Volume IN (SELECT DISTINCT [Volume] FROM T_Files_Filegroups)
					OR	v.Volume LIKE '[A-Z]:\LOG[S][0-9]\'
					OR	v.Volume LIKE '[A-Z]:\LOG[S][0-9][0-9]\'
			)
			,T_Files AS
			(
				SELECT	DB_ID, DB_Name, [TotalFilesSize(GB)], DB_State,
						f.FileName+' (VLF_Count|Size|AutoGrowth :: '+CAST(l.VLFCount AS VARCHAR(20))+'|'+CAST(CONVERT(DECIMAL(20,2),((size*8.0)/1024/1024)) AS VARCHAR(20))+' gb|'+[growth(GB)]+')' AS FileSettings, 
						--f.FileName+' (Growth by '+[growth(GB)]+') with '+CAST(l.VLFCount AS VARCHAR(20))+' VLFs' AS FileSettings, 
						v.VolumeName+' = '+CAST([freespace(GB)] AS VARCHAR(20))+'GB('+CAST([freespace(%)] AS VARCHAR(20))+'%) Free of '+CAST([capacity(GB)] AS VARCHAR(20))+' GB' as FileDrive
						,growth, [growth(GB)], [FileName], l.VLFCount
						,v.Volume, [capacity(MB)], [freespace(MB)], VolumeName, [capacity(GB)], [freespace(GB)], [freespace(%)]
						,ROW_NUMBER()OVER(PARTITION BY v.Volume, f.DB_Name ORDER BY f.[file_id]) AS FileID
				FROM	T_Files_Filegroups AS f
				LEFT JOIN
						#LogInfoByFile AS l
					ON	l.DBName = DB_Name AND l.FileId = f.file_id
				RIGHT OUTER JOIN
						T_Volumes_Derived AS v
					ON	v.Volume = f.[Volume]
			)
			,T_Files_Derived AS
			(
				SELECT	DB_ID, DB_Name, DB_State, [TotalFilesSize(GB)], STUFF(
								(SELECT ', ' + f2.FileSettings
								 FROM T_Files as f2
								 WHERE f2.Volume = f.Volume AND f2.DB_Name = f.DB_Name
								 FOR XML PATH (''))
								  , 1, 1, ''
							) AS Files, FileDrive, growth, [growth(GB)], FileName, Volume, [capacity(MB)], [freespace(MB)], VolumeName, [capacity(GB)], [freespace(GB)], [freespace(%)], FileID
				FROM	T_Files as f
				WHERE	f.FileID = 1
			)
			SELECT	*
			INTO	#LogFiles
			FROM	T_Files_Derived;

			IF	@verbose = 1
			BEGIN
				PRINT	'	SELECT * FROM #LogFiles;';
				SELECT 'SELECT * FROM #LogFiles;' AS RunningQuery, * FROM #LogFiles;
			END

			IF @verbose = 1
			BEGIN
				PRINT	'	Finding and arranging the log files names for Pivoting';
				SELECT DISTINCT TOP 100 'Finding and arranging the log files names for Pivoting' AS RunningQuery, FileDrive 
							,LEFT(FileDrive,4) AS First4Char, CAST(SUBSTRING(Volume, PATINDEX('%[0-9]%', Volume), PATINDEX('%[0-9][^0-9]%', Volume + 't') - PATINDEX('%[0-9]%', 
							Volume) + 1) AS INT) AS Number, Volume
							,Vol_Order =	(CASE	WHEN	Volume LIKE '%MSSQL%'
									THEN	1
									WHEN	Volume LIKE '%TempDB%'
									THEN	2
									ELSE	3
									END)
					FROM #LogFiles
					order by Vol_Order,First4Char,Number;
			END
	
			SELECT	@_commaSeparatedMountPointVolumes = COALESCE(@_commaSeparatedMountPointVolumes+', '+QUOTENAME(FileDrive), QUOTENAME(FileDrive)) --DISTINCT FileDrive
			FROM	(SELECT DISTINCT TOP 100 FileDrive 
							,LEFT(FileDrive,4) AS First4Char, CAST(SUBSTRING(Volume, PATINDEX('%[0-9]%', Volume), PATINDEX('%[0-9][^0-9]%', Volume + 't') - PATINDEX('%[0-9]%', 
							Volume) + 1) AS INT) AS Number, Volume
							,Vol_Order =	(CASE	WHEN	Volume LIKE '%MSSQL%'
									THEN	1
									WHEN	Volume LIKE '%TempDB%'
									THEN	2
									ELSE	3
									END)
					FROM #LogFiles
					order by Vol_Order,First4Char,Number
			) AS FD;
			
			IF @verbose = 1
				PRINT	'	@_commaSeparatedMountPointVolumes = '+@_commaSeparatedMountPointVolumes;

			--	Unfortunately table variables are out of scope of dynamic SQL, trying temp table method
			IF OBJECT_ID('tempdb..#filterDatabaseNames_Logs') IS NOT NULL
				DROP TABLE #filterDatabaseNames_Logs;
			SELECT * INTO #filterDatabaseNames_Logs FROM @filterDatabaseNames;

			SET @_sqlGetInfo = '
			SELECT	DB_ID, DB_Name, DB_State, [TotalFilesSize(GB)] as [TotalLogFilesSize(GB)], '+@_commaSeparatedMountPointVolumes+'
			FROM  (
					SELECT	DB_ID, DB_Name, DB_State, [TotalFilesSize(GB)], Files, FileDrive
					FROM	#LogFiles
					WHERE	NOT EXISTS (SELECT * FROM #filterDatabaseNames_Logs) 
						OR	DB_Name IN (SELECT d.DBName FROM #filterDatabaseNames_Logs AS d)
				  ) up
			PIVOT	(MAX(Files) FOR FileDrive IN ('+@_commaSeparatedMountPointVolumes+')) AS pvt
			WHERE	DB_Name IS NOT NULL
			ORDER BY [DB_Name];
			';

			EXEC (@_sqlGetInfo);
	
			IF @verbose=1 
				PRINT	'/*	******************** End:	@getLogInfo = 1 *****************************/
';
		END
		--	----------------------------------------------------------------------------
			--	End:	@getLogInfo = 1
		--	============================================================================

	--	============================================================================
		--	Begin:	@help = 1
	--	----------------------------------------------------------------------------
	HELP_GOTO_BOOKMARK:
	IF	@help = 1
	BEGIN
		IF @verbose=1 
			PRINT	'
/*	******************** Begin:	@help = 1 *****************************/';

		-- VALUES constructor method does not work in SQL 2005. So using UNION ALL
		SELECT	[Parameter Name], [Data Type], [Default Value], [Parameter Description]
		FROM	(SELECT	'@help' as [Parameter Name],'TINYINT' as [Data Type],'0' as [Default Value],'Displays this help message.' as [Parameter Description]
					--
				UNION ALL
					--
				SELECT	'@getInfo','TINYINT','0','Displays distribution of Data Files across multiple data volumes. It presents file details like database name, its file groups, db status, logical name and autogrowth setting, and volume details like free space and total space.'
				--
				UNION ALL
					--
				SELECT	'@getLogInfo','TINYINT','0','Displays distribution of Log Files across multiple log volumes. It presents log file details like database name, db status, logical name, size, VLF counts and autogrowth setting, and volume details like free space and total space.'
				--
				UNION ALL
					--
				SELECT	'@addDataFiles','TINYINT','0','This generates TSQL code for adding data files on @newVolume for data files present on @oldVolume for each combination of database and filegroup.'
				--
				UNION ALL
					--
				SELECT	'@addLogFiles','TINYINT','0','This generates TSQL code for adding log files on @newVolume for log files present on @oldVolume for each database.'
				--
				UNION ALL
					--
				SELECT	'@restrictDataFileGrowth','TINYINT','0','This generates TSQL code for restricting growth of Data files on @oldVolume.'
				--
				UNION ALL
					--
				SELECT	'@restrictLogFileGrowth','TINYINT','0','This generates TSQL code for restricting growth of Log files on @oldVolume.'
				--
				UNION ALL
					--
				SELECT	'@generateCapacityException','TINYINT','0','This generates TSQL code for adding capacity exception on MNA alerting database server for @oldVolume.'
				--
				UNION ALL
					--
				SELECT	'@unrestrictFileGrowth','TINYINT','0','This generates TSQL code for removing the growth restrict for data/log files on @oldVolume.'
				--
				UNION ALL
					--
				SELECT	'@removeCapacityException','TINYINT','0','This generates TSQL code for removing the added capacity exception on MNA alerting database server for @oldVolume.'
				--
				UNION ALL
					--
				SELECT	'@UpdateMountPointSecurity','TINYINT','0','This prints directions on how to update access for sql service account on @newVolume.'
				--
				UNION ALL
					--
				SELECT	'@restrictMountPointGrowth','TINYINT','0','This generates TSQL code for expanding/shrinking files upto @mountPointGrowthRestrictionPercent % of total volume capacity.'
				--
				UNION ALL
					--
				SELECT	'@expandTempDBSize','TINYINT','0','This generates TSQL code for expanding tempdb data files upto @tempDBMountPointPercent % of total tempdb volume capacity.'
				--
				UNION ALL
					--
				SELECT	'@newVolume','VARCHAR(50)',NULL,'Name of the new Volume where data/log files are to be added.'
				--
				UNION ALL
					--
				SELECT	'@oldVolume','VARCHAR(50)',NULL,'Name of the old Volume where data/log files growth is to be restricted.'
				--
				UNION ALL
					--
				SELECT	'@mountPointGrowthRestrictionPercent','TINYINT','79','Threshold value in percentage for restricting data/log files on @oldVolume. It will either increase initial size, or shrink the files based on current space occupied.'
				--
				UNION ALL
					--
				SELECT	'@tempDBMountPointPercent','TINYINT','79','Threshold value in percentage for restricting tempdb data files on @oldVolume. This will be used with @expandTempDBSize parameter to re-size the tempdb files if space is added on volume.'
				--
				UNION ALL
					--
				SELECT	'@DBs2Consider','VARCHAR(1000)',NULL,'Comma (,) separated database names to filter the result set action'
				--
				UNION ALL
					--
				SELECT	'@mountPointFreeSpaceThreshold_GB','INT','60','Threshold value of free space in GB on @oldVolume after which new data/log files to be on @newVolume.'
				--
				UNION ALL
					--
				SELECT	'@verbose','TINYINT','0','Used for debugging procedure. It will display temp table results created in background for analyzing issues/logic.'
				--
				UNION ALL
					--
				SELECT	'@testAllOptions','TINYINT','0','Used for debugging procedure. It will test all parameter options for procedure.'
				--
				UNION ALL
					--
				SELECT	'@forceExecute','TINYINT','0','When set to 1, will execute the TSQL Code generated by main parameter options like @addDataFiles, @addLogFiles, @restrictDataFileGrowth, @restrictLogFileGrowth, @unrestrictFileGrowth, @restrictMountPointGrowth and @expandTempDBSize.'
				--
				UNION ALL
					--
				SELECT	'@allowMulYourOrglumeUnrestrictedFiles','TINYINT','0','All creation of multiple data/log files with unrestricted growth on multiple volumes.'
				--
				UNION ALL
					--
				SELECT	'@output4IdealScenario','TINYINT','0','When set to 1, will generate TSQL code to add/remove data files based on the number Logical cores on server upto 8, and delete extra data files created on non-tempdb volumes.'
				) AS Params; --([Parameter Name], [Data Type], [Default Value], [Parameter Description]);

		PRINT	'
	NAME
		[dbo].[usp_AnalyzeSpaceCapacity]

	SYNOPSIS
		Analyze the Data Volume mount points for free space, database files, growth restriction and capacity exception.

	SYNTAX
		EXEC [dbo].[usp_AnalyzeSpaceCapacity]	[ [@getInfo =] { 1 | 0 } ] [,@DBs2Consider = <comma separated database names>]
												|
												@getLogInfo = { 1 | 0 } [,@DBs2Consider = <comma separated database names>]
												|
												@help = { 1 | 0 }
												|
												@addDataFiles = { 1 | 0 } ,@newVolume = <drive_name>, @oldVolume = <drive_name> [,@DBs2Consider = <comma separated database names>] [,@forceExecute = 1] 
												|
												@addLogFiles = { 1 | 0 } ,@newVolume = <drive_name>, @oldVolume = <drive_name> [,@allowMulYourOrglumeUnrestrictedFiles = 1] [,@DBs2Consider = <comma separated database names>] [,@forceExecute = 1] 
												|
												@restrictDataFileGrowth = { 1 | 0 } ,@oldVolume = <drive_name> [,@DBs2Consider = <comma separated database names>] [,@forceExecute = 1]
												|
												@restrictLogFileGrowth = { 1 | 0 } ,@oldVolume = <drive_name> [,@DBs2Consider = <comma separated database names>] [,@forceExecute = 1]
												|
												@generateCapacityException = { 1 | 0 }, @oldVolume = <drive_name>
												|
												@unrestrictFileGrowth = { 1 | 0 }, @oldVolume = <drive_name> [,@DBs2Consider = <comma separated database names>] [,@forceExecute = 1]
												|
												@removeCapacityException = { 1 | 0 }, @oldVolume = <drive_name>
												|
												@UpdateMountPointSecurity = { 1 | 0 }
												|
												@restrictMountPointGrowth = { 1 | 0}, @oldVolume = <drive_name> [,@mountPointGrowthRestrictionPercent = <value> ] [,@DBs2Consider = <comma separated database names>] [,@forceExecute = 1]
												|
												@expandTempDBSize = { 1 | 0} [,@tempDBMountPointPercent = <value> ] [,@output4IdealScenario = 1] [,@forceExecute = 1]
											  } [;]

		<drive_name> :: { ''E:\Data\'' | ''E:\Data01'' | ''E:\Data2'' | ... }

		--------------------------------------- EXAMPLE 1 ----------------------------------------------
		EXEC [dbo].[usp_AnalyzeSpaceCapacity];
		EXEC [dbo].[usp_AnalyzeSpaceCapacity] ,@DBs2Consider = ''unet, Test1Db, MirrorTestDB'';

		This procedure returns general information like Data volumes, data files on those data volumes, Free space on data volumes, Growth settings of dbs etc.

		--------------------------------------- EXAMPLE 2 ----------------------------------------------
		EXEC [dbo].[usp_AnalyzeSpaceCapacity] @getLogInfo = 1
		EXEC [dbo].[usp_AnalyzeSpaceCapacity] @getLogInfo = 1 ,@DBs2Consider = ''unet, Test1Db, MirrorTestDB''

		This procedure returns general information like Log volumes, Log files on those log volumes, Free space on log volumes, Growth settings of dbs etc.
	
		--------------------------------------- EXAMPLE 3 ----------------------------------------------
		EXEC [dbo].[usp_AnalyzeSpaceCapacity] @help = 1

		This returns help for procedure usp_AnalyzeSpaceCapacity along with definitions for each parameter.

		--------------------------------------- EXAMPLE 4 ----------------------------------------------
		EXEC [dbo].[usp_AnalyzeSpaceCapacity] @addDataFiles = 1 ,@newVolume = ''E:\Data1\'' ,@oldVolume = ''E:\Data\'';
		EXEC [dbo].[usp_AnalyzeSpaceCapacity] @addDataFiles = 1 ,@newVolume = ''E:\Data1\'' ,@oldVolume = ''E:\Data\'' ,@DBs2Consider = ''unet, Test1Db, MirrorTestDB'';
		EXEC [dbo].[usp_AnalyzeSpaceCapacity] @addDataFiles = 1 ,@newVolume = ''E:\Data1\'' ,@oldVolume = ''E:\Data\'' ,@forceExecute = 1;

		This generates TSQL Code for add secondary data files on @newVolume for each file of @oldVolume per FileGroup.

		--------------------------------------- EXAMPLE 5 ----------------------------------------------
		EXEC [dbo].[usp_AnalyzeSpaceCapacity] @restrictDataFileGrowth = 1 ,@oldVolume = ''E:\Data\'';
		EXEC [dbo].[usp_AnalyzeSpaceCapacity] @restrictDataFileGrowth = 1 ,@oldVolume = ''E:\Data\'' ,@DBs2Consider = ''unet, Test1Db, MirrorTestDB'';
		EXEC [dbo].[usp_AnalyzeSpaceCapacity] @restrictDataFileGrowth = 1 ,@oldVolume = ''E:\Data\'' ,@forceExecute = 1

		This generates TSQL Code to restrict growth of secondary data files on @oldVolume if corresponding Data files exists on @newVolume.

		--------------------------------------- EXAMPLE 6 ----------------------------------------------
		EXEC [dbo].[usp_AnalyzeSpaceCapacity] @addLogFiles = 1 ,@newVolume = ''E:\Logs1\'' ,@oldVolume = ''E:\Logs\''
		EXEC [dbo].[usp_AnalyzeSpaceCapacity] @addLogFiles = 1 ,@newVolume = ''E:\Logs1\'' ,@oldVolume = ''E:\Logs\'' ,@DBs2Consider = ''unet, Test1Db, MirrorTestDB'';
		EXEC [dbo].[usp_AnalyzeSpaceCapacity] @addLogFiles = 1 ,@newVolume = ''E:\Logs1\'' ,@oldVolume = ''E:\Logs\'' ,@forceExecute = 1
		EXEC [dbo].[usp_AnalyzeSpaceCapacity] @addLogFiles = 1 ,@newVolume = ''E:\Logs1\'' ,@oldVolume = ''E:\Logs\'' ,@allowMulYourOrglumeUnrestrictedFiles = 1
		EXEC [dbo].[usp_AnalyzeSpaceCapacity] @addLogFiles = 1 ,@newVolume = ''E:\Logs1\'' ,@oldVolume = ''E:\Logs\'' ,@allowMulYourOrglumeUnrestrictedFiles = 1 ,@forceExecute = 1

		This generates TSQL Code for add log files on @newVolume for each database on @oldVolume.

		--------------------------------------- EXAMPLE 7 ----------------------------------------------
		EXEC [dbo].[usp_AnalyzeSpaceCapacity] @restrictLogFileGrowth = 1 ,@oldVolume = ''E:\Logs\''
		EXEC [dbo].[usp_AnalyzeSpaceCapacity] @restrictLogFileGrowth = 1 ,@oldVolume = ''E:\Logs\'' ,@DBs2Consider = ''unet, Test1Db, MirrorTestDB'';
		EXEC [dbo].[usp_AnalyzeSpaceCapacity] @restrictLogFileGrowth = 1 ,@oldVolume = ''E:\Logs\'',@forceExecute = 1

		This generates TSQL Code to restrict growth of log files on @oldVolume if corresponding log files exists on @newVolume.
	
		--------------------------------------- EXAMPLE 8 ----------------------------------------------
		EXEC [dbo].[usp_AnalyzeSpaceCapacity] @unrestrictFileGrowth = 1, @oldVolume = ''E:\Data\''
		EXEC [dbo].[usp_AnalyzeSpaceCapacity] @unrestrictFileGrowth = 1, @oldVolume = ''E:\Data\'' ,@DBs2Consider = ''unet, Test1Db, MirrorTestDB'';

		This generates TSQL Code for remove Data File growth Restriction for files on @oldVolume.

		--------------------------------------- EXAMPLE 9 ----------------------------------------------
		EXEC [dbo].[usp_AnalyzeSpaceCapacity] @generateCapacityException = 1, @oldVolume = ''E:\Data\''

		This generates TSQL Code for adding Space Capacity Exception for @oldVolume.

		--------------------------------------- EXAMPLE 10 ----------------------------------------------
		EXEC [dbo].[usp_AnalyzeSpaceCapacity] @UpdateMountPointSecurity = 1

		This will generate Powershell command to provide Full Access on @newVolume for SQL Server service accounts.

		--------------------------------------- EXAMPLE 11 ----------------------------------------------
		EXEC [dbo].[usp_AnalyzeSpaceCapacity] @restrictMountPointGrowth = 1, @oldVolume = ''E:\Data\''
		EXEC [dbo].[usp_AnalyzeSpaceCapacity] @restrictMountPointGrowth = 1, @oldVolume = ''E:\Data\'', @mountPointGrowthRestrictionPercent = 95
		EXEC [dbo].[usp_AnalyzeSpaceCapacity] @restrictMountPointGrowth = 1, @oldVolume = ''E:\Data\'', @mountPointGrowthRestrictionPercent = 95, @DBs2Consider = ''CHSDB_Audit,CHSDBArchive''
		EXEC [dbo].[usp_AnalyzeSpaceCapacity] @restrictMountPointGrowth = 1, @oldVolume = ''E:\Logs2\''
		EXEC [dbo].[usp_AnalyzeSpaceCapacity] @restrictMountPointGrowth = 1, @oldVolume = ''E:\Logs2\'', @mountPointGrowthRestrictionPercent = 70

		This will generate TSQL Code to restrict all the files on @oldVolume such that total files size consumes upto 79% of the mount point volume.

		--------------------------------------- EXAMPLE 12 ----------------------------------------------
		EXEC [dbo].[usp_AnalyzeSpaceCapacity] @expandTempDBSize = 1
		EXEC [dbo].[usp_AnalyzeSpaceCapacity] @expandTempDBSize = 1, @output4IdealScenario = 1
		EXEC [dbo].[usp_AnalyzeSpaceCapacity] @expandTempDBSize = 1, @tempDBMountPointPercent = 89

		This generates TSQL code for expanding tempdb data files upto @tempDBMountPointPercent % of total tempdb volume capacity.
		When @output4IdealScenario set to 1, will generate TSQL code to add/remove data files based on the number Logical cores on server upto 8, and delete extra data files created on non-tempdb volumes, and re-size TempdDB data files to occupy 89% of mount point volume.

		--------------------------------------- EXAMPLE 13 ----------------------------------------------
		EXEC [dbo].[usp_AnalyzeSpaceCapacity] @optimizeLogFiles = 1

		This generates TSQL code to re-size log files upto current size with objective to reduce high VLF Counts
	';
		IF @verbose=1 
			PRINT	'/*	******************** End:	@help = 1 *****************************/
';
	END
	--	----------------------------------------------------------------------------
		--	End:	@help = 1
	--	============================================================================

	--	============================================================================
		--	Begin:	@addDataFiles = 1
	--	----------------------------------------------------------------------------
	IF	@addDataFiles = 1
	BEGIN
		IF @verbose=1 
			PRINT	'
/*	******************** Begin:	@addDataFiles = 1 *****************************/';
		IF (SELECT COUNT(*) FROM @mountPointVolumes as V WHERE V.Volume IN (@newVolume,@oldVolume))<>2
		BEGIN -- Begin block for Validation of Data volumes
			SET @_errorMSG = '@newVolume and @oldVolume parameter values mandatory with @addDataFiles = 1 parameter. Verify if valid values are supplied.';
			IF (select CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)),charindex('.',CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)))-1) AS INT)) >= 12
				EXEC sp_executesql N'THROW 50000,@_errorMSG,1',N'@_errorMSG VARCHAR(200)', @_errorMSG;
			ELSE
				EXEC sp_executesql N'RAISERROR (@_errorMSG, 16, 1)', N'@_errorMSG VARCHAR(200)', @_errorMSG;
		END -- End block for Validation of Data volumes
		ELSE
		BEGIN -- Begin Else portion for Validation of Data volumes
			IF @verbose=1 
			BEGIN
				PRINT	'	Validations completed successfully.';
				PRINT	'	Printing @_mirrorDatabases, @_nonAccessibleDatabases, @_principalDatabases, @_databasesWithMultipleDataFiles';
			END

			IF	@_mirrorDatabases IS NOT NULL
			BEGIN
				SET @_errorMSG = '/*	NOTE: Following '+CAST(@_mirrorDatabaseCounts_Mirroring AS VARCHAR(5))+' database(s) '+(case when @_mirrorDatabaseCounts_Mirroring > 1 then 'are' else 'is' end) +' in role of ''Mirroring Partner''. So add secondary files on Partner server '''+@_mirroringPartner+''' for these dbs.
				'+@_mirrorDatabases+'
	*/';
				IF @forceExecute = 1
				BEGIN
					IF @_errorOccurred = 0
						SET @_errorOccurred = 1;

					INSERT #ErrorMessages
					SELECT	'Mirror Server' AS ErrorCategory
							,NULL AS DBName 
							,NULL AS [FileName] 
							,@_errorMSG AS ErrorDetails 
							,NULL AS TSQLCode;
				END
				ELSE
					PRINT @_errorMSG;
			END
	
			IF	@_nonAccessibleDatabases IS NOT NULL
			BEGIN
				SET @_errorMSG = '/*	NOTE: Following '+CAST(@_nonAccessibleDatabasesCounts AS VARCHAR(5))+' database(s) '+(case when @_nonAccessibleDatabasesCounts > 1 then 'are' else 'is' end) +' in non-accessible state. Either wait, or resolve the issue, and then create/restrict Data files.
				'+@_nonAccessibleDatabases+'
	*/';
				IF @forceExecute = 1
				BEGIN
					IF @_errorOccurred = 0
						SET @_errorOccurred = 1;

					INSERT #ErrorMessages
					SELECT	'Non-Accessible Databases' AS ErrorCategory
							,NULL AS DBName 
							,NULL AS [FileName] 
							,@_errorMSG AS ErrorDetails 
							,NULL AS TSQLCode;
				END
				ELSE
					PRINT @_errorMSG;
			END

			IF	@_principalDatabases IS NOT NULL
			BEGIN
				SET @_errorMSG = '/*	NOTE: Following '+CAST(@_principalDatabaseCounts_Mirroring AS VARCHAR(5))+' database(s) '+(case when @_principalDatabaseCounts_Mirroring > 1 then 'are' else 'is' end) +' in role of ''Mirroring Principal''. So generating code to add secondary files for these dbs. Kindly make sure that Same Data Volumes exists on DR server '''+@_mirroringPartner+''' as well. Otherwise this shall fail.
				'+@_principalDatabases+'
	*/';
				IF @forceExecute = 0 -- Ignore this message if @forceExecute = 1 since this is information only message
					PRINT @_errorMSG;
			END
				

			IF	@_databasesWithMultipleDataFiles IS NOT NULL
			BEGIN
				SET @_errorMSG = '/*	NOTE: Following '+CAST(@_databasesWithMultipleDataFilesCounts AS VARCHAR(5))+' database(s) exists that have multiple files per filegroup on @oldVolume '+QUOTENAME(@oldVolume,'''') + '. But, this script will add only single file per filegroup per database on @newVolume '+QUOTENAME(@newVolume,'''') + '.
				'+@_databasesWithMultipleDataFiles+'
	*/';
				IF @forceExecute = 0 -- Ignore this message if @forceExecute = 1 since this is information only message
					PRINT @_errorMSG;
			END

		
			IF @verbose = 1 
			BEGIN
					PRINT	'	Checking if new data files are to be added.';
					SELECT	'	SELECT	[Add New Files] = CASE WHEN isExistingOn_NewVolume = 0 AND isExisting_UnrestrictedGrowth_on_OtherVolume = 0 THEN ''Yes'' ELSE ''No'' END
		,* 
		FROM #T_Files_Final;' AS RunningQuery, [Add New Files] = CASE WHEN isExistingOn_NewVolume = 0 AND isExisting_UnrestrictedGrowth_on_OtherVolume = 0 THEN 'Yes' ELSE 'No' END
							,* 
					FROM #T_Files_Final;
			END

			--	Generate TSQL Code for adding data files when it does not exist
			IF EXISTS (SELECT * FROM #T_Files_Final WHERE isExistingOn_NewVolume = 0 AND isExisting_UnrestrictedGrowth_on_OtherVolume = 0 )
			BEGIN	-- Begin block for tsql code generation
				IF @verbose = 1 
				BEGIN
					PRINT	'	Generating TSQL Code for adding data files when it does not exist';
					PRINT	'	Populate @T_Files_Final_Add';
				END

				DELETE @T_Files_Final_Add;
				INSERT @T_Files_Final_Add (TSQL_AddFile,DBName,name,_name)
				SELECT TSQL_AddFile,DBName,name,_name FROM #T_Files_Final as f WHERE isExistingOn_NewVolume = 0 AND isExisting_UnrestrictedGrowth_on_OtherVolume = 0 AND [FileIDRankPerFileGroup] = 1 ORDER BY f.DBName;

				--	Find if data files to be added for [uhtdba]
				IF EXISTS (SELECT * FROM @mountPointVolumes AS v WHERE v.Volume = @oldVolume AND v.[freespace(GB)] >= @mountPointFreeSpaceThreshold_GB)
				BEGIN
					SET @_errorMSG = '/*	NOTE: Data file for [uhtdba] database is not being created since @oldVolume '+QUOTENAME(@oldVolume,'''') + ' has more than '+CAST(@mountPointFreeSpaceThreshold_GB AS VARCHAR(10))+' gb of free space.	*/';
					IF @forceExecute = 0 -- Ignore this message if @forceExecute = 1 since this is information only message
						PRINT @_errorMSG;
					DELETE FROM @T_Files_Final_Add
						WHERE DBName = 'uhtdba';
					DELETE FROM #T_Files_Final
						WHERE DBName = 'uhtdba';
				END

				IF @verbose = 1 
					PRINT	'	Initiating @_loopCounter and @_loopCounts';
				SELECT @_loopCounter=MIN(ID), @_loopCounts=MAX(ID) FROM	@T_Files_Final_Add;
			
				IF @verbose=1 
					PRINT	'9.3) Inside Begin:	@addDataFiles = 1 - Starting to print Data File Addition Code in loop';
				WHILE @_loopCounter <= @_loopCounts
				BEGIN	-- Begin Block of Loop

					SELECT @_loopSQLText = '
--	Add File: '+CAST(@_loopCounter AS VARCHAR(5))+';'+TSQL_AddFile 
							,@_dbName = DBName ,@_name = name ,@_newName = _name
					FROM @T_Files_Final_Add as f WHERE f.ID = @_loopCounter;
					IF @_loopCounter = 1
						SET @_loopSQLText =	'USE [master];
--	=====================================================================================================
	--	TSQL Code to Add Secondary Data Files on @newVolume '+QUOTENAME(@newVolume) + ' that exists on @oldVolume '+QUOTENAME(@oldVolume) + ' per FileGroup.
	' + @_loopSQLText;

					IF @forceExecute = 1
					BEGIN
						BEGIN TRY
							EXEC (@_loopSQLText);
						END TRY
						BEGIN CATCH
							IF @_errorOccurred = 0
								SET @_errorOccurred = 1;

							INSERT #ErrorMessages
							SELECT	'ALTER DATABASE Failed' AS ErrorCategory
									,@_dbName AS DBName 
									,@_name AS [FileName] 
									,ERROR_MESSAGE() AS ErrorDetails 
									,@_loopSQLText AS TSQLCode;
						END CATCH
					END
					ELSE
						PRINT @_loopSQLText;

					SET @_loopSQLText = '';
					SET @_loopCounter = @_loopCounter + 1;
				END		-- End Block of Loop
				IF @verbose=1 
					PRINT	'9.4) Inside Begin:	@addDataFiles = 1 - Loop Ended for print Data File Addition Code';
			END -- End block for tsql code generation
		
			IF @verbose = 1 
			BEGIN
					PRINT	'	Checking if need to un-restrict file growth if file already exists on @newVolume.';

					SELECT	'	SELECT	[Remove Growth Restriction] = CASE WHEN isExistingOn_NewVolume = 1 AND isExisting_UnrestrictedGrowth_on_OtherVolume = 0 THEN ''Yes'' ELSE ''No'' END
		,* 
		FROM #T_Files_Final;' AS RunningQuery, [Remove Growth Restriction] = CASE WHEN isExistingOn_NewVolume = 1 AND isExisting_UnrestrictedGrowth_on_OtherVolume = 0 THEN 'Yes' ELSE 'No' END
							,* 
					FROM #T_Files_Final;
			END

			--	Un-Restrict File Growth if file already exists on @newVolume
			IF EXISTS (SELECT * FROM #T_Files_Final WHERE isExistingOn_NewVolume = 1 AND isExisting_UnrestrictedGrowth_on_OtherVolume = 0)
			BEGIN	-- Begin block for Un-Restrict File Growth if file already exists on @newVolume
				IF @verbose=1 
					PRINT	'9.5) Inside Begin:	@addDataFiles = 1 - Begin block for Un-Restrict File Growth if file already exists on @newVolume';

				INSERT @T_Files_Final_AddUnrestrict (TSQL_AddFile,DBName,name,_name)
				SELECT	'
		'+(CASE WHEN @forceExecute = 0 THEN 'PRINT	''Modifying autogrowth setting for file '+QUOTENAME(name)+' of '+QUOTENAME(DB_NAME(mf.database_id))+' database'';' ELSE '' END) + '
ALTER DATABASE ['+DB_NAME(mf.database_id)+'] MODIFY FILE ( NAME = '+QUOTENAME(mf.name,'''')+', FILEGROWTH = '+s._autoGrowth+');'
						,DB_NAME(mf.database_id) AS dbName ,name, NULL as _name
				FROM	sys.master_files AS mf 
				INNER JOIN
						(	SELECT t.database_id, t.data_space_id, MAX(t._initialSize) AS _initialSize, MAX(t._autoGrowth) AS _autoGrowth FROM #T_Files_Final as t WHERE t.isExistingOn_NewVolume = 1 AND t.isExisting_UnrestrictedGrowth_on_OtherVolume = 0 GROUP BY t.database_id, t.data_space_id
						) AS s
				ON		s.database_id = mf.database_id
					AND	s.data_space_id = mf.data_space_id
				INNER JOIN
					(
						SELECT mf1.database_id, mf1.data_space_id, MAX(mf1.file_id) AS MAX_file_id 
						FROM sys.master_files AS mf1
						WHERE mf1.type_desc = 'ROWS' AND mf1.physical_name LIKE (@newVolume+'%')
						AND EXISTS (SELECT * FROM #T_Files_Final AS t -- Find files on @newVolume with restrict growth
										WHERE isExistingOn_NewVolume = 1 AND isExisting_UnrestrictedGrowth_on_OtherVolume = 0 AND t.database_id = mf1.database_id AND t.data_space_id = mf1.data_space_id) 
						GROUP BY mf1.database_id, mf1.data_space_id
					) AS rf
				ON		rf.database_id = mf.database_id
					AND	rf.data_space_id = mf.data_space_id
					AND	rf.MAX_file_id = mf.file_id
				ORDER BY DB_NAME(mf.database_id); --pick the latest file in case multiple log files exists

				SELECT @_loopCounter=MIN(ID), @_loopCounts=MAX(ID) FROM	@T_Files_Final_AddUnrestrict;
			
				WHILE @_loopCounter <= @_loopCounts
				BEGIN	-- Begin Block of Loop

					SELECT @_loopSQLText = '
--	Un-restrict Data File: '+CAST(@_loopCounter AS VARCHAR(5))+';'+TSQL_AddFile 
							,@_dbName = DBName ,@_name = name ,@_newName = _name
					FROM @T_Files_Final_AddUnrestrict as f WHERE f.ID = @_loopCounter;
					IF @_loopCounter = 1
						SET @_loopSQLText =	'

USE [master];
--	=====================================================================================================
	--	TSQL Code to Remove Data file Growth restriction on @newVolume '+QUOTENAME(@newVolume) + ' that exists on @oldVolume '+QUOTENAME(@oldVolume)+';
	'+ @_loopSQLText;

					IF @forceExecute = 1
					BEGIN
						BEGIN TRY
							EXEC @_loopSQLText;
						END TRY
						BEGIN CATCH
							IF @_errorOccurred = 0
								SET @_errorOccurred = 1;

							INSERT #ErrorMessages
							SELECT	'ALTER DATABASE Failed' AS ErrorCategory
									,@_dbName AS DBName 
									,@_name AS [FileName] 
									,ERROR_MESSAGE() AS ErrorDetails 
									,@_loopSQLText AS TSQLCode;
						END CATCH
					END
					ELSE
						PRINT @_loopSQLText;

					SET @_loopSQLText = '';
					SET @_loopCounter = @_loopCounter + 1;
				END		-- End Block of Loop
				IF @verbose=1 
					PRINT	'9.5) Inside Begin:	@addDataFiles = 1 - End block for Un-Restrict File Growth if file already exists on @newVolume';
			END -- End block for Un-Restrict File Growth if file already exists on @newVolume

			IF @verbose = 1 
			BEGIN
					PRINT	'	Checking if any action was taken for @addDataFiles.';

					SELECT	RunningQuery, F.*
					FROM  ( SELECT '/* Check if any action taken with @addDataFiles */
SELECT * FROM #T_Files_Final WHERE NOT (isExistingOn_NewVolume = 1 OR IsExisting_UnrestrictedGrowth_on_OtherVolume = 1)' AS RunningQuery ) AS Q
					LEFT JOIN #T_Files_Final AS F
					ON	1 = 1 AND NOT (isExistingOn_NewVolume = 1 OR isExisting_UnrestrictedGrowth_on_OtherVolume = 1);
			END

			IF @forceExecute = 0 AND NOT EXISTS (SELECT * FROM #T_Files_Final WHERE NOT (isExistingOn_NewVolume = 1 OR isExisting_UnrestrictedGrowth_on_OtherVolume = 1)) 
				PRINT	'	/*	~~~~ No secondary Data files to add on @newVolume '+QUOTENAME(@newVolume)+' with respect to @oldVolume '+QUOTENAME(@oldVolume) + '. ~~~~ */'; 
			IF	@verbose = 1
				PRINT	'/*	******************** End:	@addDataFiles = 1 *****************************/
';
		END	-- End Else portion for Validation of Data volumes

	END -- End block of @addDataFiles = 1
	--	----------------------------------------------------------------------------
		--	End:	@addDataFiles = 1
	--	============================================================================

	--	============================================================================
		--	Begin:	@addLogFiles = 1
	--	----------------------------------------------------------------------------
	IF	@addLogFiles = 1
	BEGIN
		IF @verbose = 1
			PRINT	'
/*	******************** Begin:	@addLogFiles = 1 *****************************/';

		IF (SELECT COUNT(*) FROM @mountPointVolumes as V WHERE V.Volume IN (@newVolume,@oldVolume))<>2
		BEGIN -- Begin block for Validation of Data volumes
			SET @_errorMSG = '@newVolume and @oldVolume parameter values mandatory with @addLogFiles = 1 parameter. Verify if valid values are supplied.';
			IF (select CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)),charindex('.',CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)))-1) AS INT)) >= 12
				EXEC sp_executesql N'THROW 50000,@_errorMSG,1',N'@_errorMSG VARCHAR(200)', @_errorMSG;
			ELSE
				EXEC sp_executesql N'RAISERROR (@_errorMSG, 16, 1)', N'@_errorMSG VARCHAR(200)', @_errorMSG;
		END -- End block for Validation of Data volumes
		ELSE
		BEGIN -- Begin Else portion for Validation of Data volumes
			IF @verbose = 1
			BEGIN
				PRINT	'	Validation of @newVolume and @oldVolume completed successfullly.';
				PRINT	'	Printing messages related to @_mirrorDatabases, @_nonAccessibleDatabases and @_principalDatabases';
			END

			IF	@_mirrorDatabases IS NOT NULL
			BEGIN
				SET @_errorMSG = '/*	NOTE: Following '+CAST(@_mirrorDatabaseCounts_Mirroring AS VARCHAR(5))+' database(s) '+(case when @_mirrorDatabaseCounts_Mirroring > 1 then 'are' else 'is' end) +' in role of ''Mirroring Partner''. So add secondary files on Partner server '''+@_mirroringPartner+''' for these dbs.
				'+@_mirrorDatabases+'
	*/';
				IF @forceExecute = 1
				BEGIN
					IF @_errorOccurred = 0
						SET @_errorOccurred = 1;

					INSERT #ErrorMessages
					SELECT	'Mirror Server' AS ErrorCategory
							,NULL AS DBName 
							,NULL AS [FileName] 
							,@_errorMSG AS ErrorDetails 
							,NULL AS TSQLCode;
				END
				ELSE
					PRINT @_errorMSG;
			END
	
			IF	@_nonAccessibleDatabases IS NOT NULL
			BEGIN
				SET @_errorMSG = '/*	NOTE: Following '+CAST(@_nonAccessibleDatabasesCounts AS VARCHAR(5))+' database(s) '+(case when @_nonAccessibleDatabasesCounts > 1 then 'are' else 'is' end) +' in non-accessible state. Either wait, or resolve the issue, and then create/restrict Data files.
				'+@_nonAccessibleDatabases+'
	*/';
				IF @forceExecute = 1
				BEGIN
					IF @_errorOccurred = 0
						SET @_errorOccurred = 1;

					INSERT #ErrorMessages
					SELECT	'Non-Accessible Databases' AS ErrorCategory
							,NULL AS DBName 
							,NULL AS [FileName] 
							,@_errorMSG AS ErrorDetails 
							,NULL AS TSQLCode;
				END
				ELSE
					PRINT @_errorMSG;
			END

			IF	@_principalDatabases IS NOT NULL
			BEGIN
				SET @_errorMSG = '/*	NOTE: Following '+CAST(@_principalDatabaseCounts_Mirroring AS VARCHAR(5))+' database(s) '+(case when @_principalDatabaseCounts_Mirroring > 1 then 'are' else 'is' end) +' in role of ''Mirroring Principal''. So generating code to add files for these dbs. Kindly make sure that Same Data Volumes exists on DR server '''+@_mirroringPartner+''' as well. Otherwise this shall fail.
				'+@_principalDatabases+'
	*/';
				IF @forceExecute = 0 -- Ignore this message if @forceExecute = 1 since this is information only message
					PRINT @_errorMSG;
			END

			--	Check if there are multiple log files on @oldVolume
			IF	@_databasesWithMultipleDataFiles IS NOT NULL
			BEGIN
				SET @_errorMSG = '/*	NOTE: Following '+CAST(@_databasesWithMultipleDataFilesCounts AS VARCHAR(5))+' database(s) exists that have multiple log files on @oldVolume '+QUOTENAME(@oldVolume,'''') + '. But, this script will add only single log file per database on @newVolume '+QUOTENAME(@newVolume,'''') + '.
				'+@_databasesWithMultipleDataFiles+'
	*/';
				IF @forceExecute = 0 -- Ignore this message if @forceExecute = 1 since this is information only message
					PRINT @_errorMSG;
			END

	--		IF	EXISTS (SELECT * FROM #T_Files_Final WHERE isExistingOn_NewVolume = 0 AND [FileIDRankPerFileGroup] = 1)
	--			PRINT	'/*	NOTE: Few database(s) exists that have multiple files per filegroup on @oldVolume '+QUOTENAME(@oldVolume) + '. But, this script will add only single file per filegroup per database on @newVolume '+QUOTENAME(@newVolume) + '.
	--*/';

			IF @verbose = 1
			BEGIN
				PRINT	'	Validate and Generate TSQL Code for adding log files when it does not exist';
				SELECT	RunningQuery, [Add New Log Files] = CASE WHEN isExistingOn_NewVolume = 0 AND isExisting_UnrestrictedGrowth_on_OtherVolume = 0 THEN 'Yes' ELSE 'No' END, f.*
				FROM  (	SELECT ('SELECT [Add New Log Files] = CASE WHEN isExistingOn_NewVolume = 0 AND isExisting_UnrestrictedGrowth_on_OtherVolume = 0 THEN ''Yes'' ELSE ''No'' END
		,* 
		FROM #T_Files_Final;') AS RunningQuery ) Query
				LEFT JOIN
						#T_Files_Final AS f
					ON	1 = 1;
			END

			--	Generate TSQL Code for adding log files when it does not exist
			IF EXISTS (SELECT * FROM #T_Files_Final WHERE isExistingOn_NewVolume = 0 AND isExisting_UnrestrictedGrowth_on_OtherVolume = 0)
			BEGIN	-- Begin block for tsql code generation
				IF @verbose = 1
				BEGIN
					PRINT	'	Declaring variables and inserting data into @T_LogFiles_Final_Add';
				END
			
				--DECLARE @T_LogFiles_Final_Add TABLE (ID INT IDENTITY(1,1), TSQL_AddFile VARCHAR(2000), DBName,name,_name);
				DELETE @T_LogFiles_Final_Add;
				INSERT @T_LogFiles_Final_Add (TSQL_AddFile,DBName,name,_name)
				SELECT TSQL_AddFile,DBName,name,_name FROM #T_Files_Final as f WHERE isExistingOn_NewVolume = 0 AND [FileIDRankPerFileGroup] = 1 AND isExisting_UnrestrictedGrowth_on_OtherVolume = 0 ORDER BY f.dbName;

				--	Find if log files to be added for [uhtdba] & [tempdb]
				IF EXISTS (SELECT * FROM @mountPointVolumes AS v WHERE v.Volume = @oldVolume AND v.[freespace(GB)] >= @mountPointFreeSpaceThreshold_GB)
				BEGIN
					SET @_errorMSG = '/*	NOTE: Log file for [uhtdba] and [tempdb] databases is not being created since @oldVolume '+QUOTENAME(@oldVolume,'''') + ' has more than '+cast(@mountPointFreeSpaceThreshold_GB as varchar(20))+' gb of free space.	*/';
					IF @forceExecute = 0 -- Ignore this message if @forceExecute = 1 since this is information only message
						PRINT @_errorMSG;
					DELETE FROM @T_LogFiles_Final_Add
						WHERE DBName IN ('uhtdba','tempdb');
				END

				IF @verbose = 1
				BEGIN
					PRINT	'	SELECT * FROM @T_LogFiles_Final_Add';
					SELECT 'SELECT * FROM @T_LogFiles_Final_Add' AS RunningQuery, * FROM @T_LogFiles_Final_Add
					PRINT	'	Preparing loop variables @_loopCounter and @_loopCounts';
				END

				SELECT @_loopCounter=MIN(ID), @_loopCounts=MAX(ID) FROM	@T_LogFiles_Final_Add;
			
				WHILE @_loopCounter <= @_loopCounts
				BEGIN	-- Begin Block of Loop

					SELECT @_loopSQLText = '
	--	Add File: '+CAST(@_loopCounter AS VARCHAR(5))+';'+TSQL_AddFile
							,@_dbName = DBName ,@_name = name ,@_newName = _name
					FROM @T_LogFiles_Final_Add as f WHERE f.ID = @_loopCounter;

					IF @_loopCounter = 1
						SET @_loopSQLText =	'USE [master];
--	=====================================================================================================
	--	TSQL Code to Add Log Files on @newVolume '+QUOTENAME(@newVolume) + ' that exists on @oldVolume '+QUOTENAME(@oldVolume) + '.
' + @_loopSQLText;

					IF @forceExecute = 1
					BEGIN
						BEGIN TRY
							EXEC (@_loopSQLText);
						END TRY
						BEGIN CATCH
							IF @_errorOccurred = 0
								SET @_errorOccurred = 1;

							INSERT #ErrorMessages
							SELECT	'ALTER DATABASE Failed' AS ErrorCategory
									,@_dbName AS DBName 
									,@_name AS [FileName] 
									,ERROR_MESSAGE() AS ErrorDetails 
									,@_loopSQLText AS TSQLCode;
						END CATCH
					END
					ELSE
						PRINT @_loopSQLText;

					SET @_loopSQLText = '';
					SET @_loopCounter = @_loopCounter + 1;
				END		-- End Block of Loop
			END -- End block for tsql code generation
		
			IF @verbose = 1
			BEGIN
				PRINT	'	Validate and Generate TSQL Code to Un-Restrict File Growth if file already exists on @newVolume';

				SELECT	RunningQuery, [Remove Growth Restriction] = CASE WHEN isExistingOn_NewVolume = 1 AND isExisting_UnrestrictedGrowth_on_OtherVolume = 0 THEN 'Yes' ELSE 'No' END, f.*
				FROM  (	SELECT 'SELECT [Remove Growth Restriction] = CASE WHEN isExistingOn_NewVolume = 1 AND isExisting_UnrestrictedGrowth_on_OtherVolume = 0 THEN ''Yes'' ELSE ''No'' END
				,* 
		FROM #T_Files_Final' AS RunningQuery) AS Query
				LEFT JOIN
						#T_Files_Final AS f
					ON	1 = 1;
			END

			--	Un-Restrict File Growth if file already exists on @newVolume
			IF EXISTS (SELECT * FROM #T_Files_Final WHERE isExistingOn_NewVolume = 1 AND isExisting_UnrestrictedGrowth_on_OtherVolume = 0)
			BEGIN	-- Begin block for Un-Restrict File Growth if file already exists on @newVolume

				INSERT @T_Files_Final_AddUnrestrictLogFiles (TSQL_AddFile,DBName,name,_name)
				SELECT	'
		'+(CASE WHEN @forceExecute = 0 THEN 'PRINT	''Modifying autogrowth setting for file '+QUOTENAME(name)+' of '+QUOTENAME(DB_NAME(mf.database_id))+' database'';' ELSE '' END) + '
ALTER DATABASE ['+DB_NAME(mf.database_id)+'] MODIFY FILE ( NAME = '+QUOTENAME(mf.name,'''')+', FILEGROWTH = '+s._autoGrowth+');',
						DB_NAME(mf.database_id) as dbName ,name, NULL as _name
				FROM	sys.master_files AS mf 
				INNER JOIN
						(	SELECT t.database_id, t.data_space_id, MAX(t._initialSize) AS _initialSize, MAX(t._autoGrowth) AS _autoGrowth FROM #T_Files_Final as t 
								WHERE t.isExistingOn_NewVolume = 1 AND t.isExisting_UnrestrictedGrowth_on_OtherVolume = 0
								GROUP BY t.database_id, t.data_space_id
						) AS s
				ON		s.database_id = mf.database_id
					AND	s.data_space_id = mf.data_space_id
				WHERE	mf.type_desc = 'LOG'
				AND		mf.physical_name LIKE (@newVolume+'%')
				AND		EXISTS (SELECT * FROM #T_Files_Final AS t -- Find files on @newVolume with restrict growth
								WHERE isExistingOn_NewVolume = 1 AND isExisting_UnrestrictedGrowth_on_OtherVolume = 0 AND t.database_id = mf.database_id)
				AND		mf.file_id IN (SELECT MAX(file_id) FROM sys.master_files AS mf1 WHERE mf1.type_desc = 'LOG' AND mf1.physical_name LIKE (@newVolume+'%') GROUP BY mf1.database_id)
				ORDER BY DB_NAME(mf.database_id); --pick the latest file in case multiple log files exists

				SELECT @_loopCounter=MIN(ID), @_loopCounts=MAX(ID) FROM	@T_Files_Final_AddUnrestrictLogFiles;
			
				WHILE @_loopCounter <= @_loopCounts
				BEGIN	-- Begin Block of Loop

					SELECT @_loopSQLText = '
--	Un-restrict Log File: '+CAST(@_loopCounter AS VARCHAR(5))+';'+TSQL_AddFile 
							,@_dbName = DBName ,@_name = name ,@_newName = _name
					FROM @T_Files_Final_AddUnrestrictLogFiles as f WHERE f.ID = @_loopCounter;
					IF @_loopCounter = 1
						SET @_loopSQLText =	'

USE [master];
--	=====================================================================================================
	--	TSQL Code to Remove Log file Growth restriction on @newVolume '+QUOTENAME(@newVolume) + ' that exists on @oldVolume '+QUOTENAME(@oldVolume)+'
	'+ @_loopSQLText;

					IF @forceExecute = 1
					BEGIN
						BEGIN TRY
							EXEC @_loopSQLText;
						END TRY
						BEGIN CATCH
							IF @_errorOccurred = 0
								SET @_errorOccurred = 1;

							INSERT #ErrorMessages
							SELECT	'ALTER DATABASE Failed' AS ErrorCategory
									,@_dbName AS DBName 
									,@_name AS [FileName] 
									,ERROR_MESSAGE() AS ErrorDetails 
									,@_loopSQLText AS TSQLCode;
						END CATCH
					END
					ELSE
						PRINT @_loopSQLText;

					SET @_loopSQLText = '';
					SET @_loopCounter = @_loopCounter + 1;
				END		-- End Block of Loop

			END -- End block for Un-Restrict File Growth if file already exists on @newVolume
		
			IF @verbose = 1
			BEGIN
				PRINT	'	Checking if any action was taken for @addLogFiles.';
				
				SELECT	RunningQuery, F.*
					FROM  ( SELECT '/* Check if any action taken with @addLogFiles */
SELECT * FROM #T_Files_Final WHERE NOT (isExistingOn_NewVolume = 1 OR IsExisting_UnrestrictedGrowth_on_OtherVolume = 1)' AS RunningQuery ) Q
					LEFT JOIN #T_Files_Final AS F
					ON	1 = 1 AND NOT (isExistingOn_NewVolume = 1 OR isExisting_UnrestrictedGrowth_on_OtherVolume = 1);
			END

			IF @forceExecute = 0 AND NOT EXISTS (SELECT * FROM #T_Files_Final WHERE NOT (isExistingOn_NewVolume = 1 OR isExisting_UnrestrictedGrowth_on_OtherVolume = 1))
				PRINT	'	/*	~~~~ No Log files to add on @newVolume '+QUOTENAME(@newVolume)+' with respect to @oldVolume '+QUOTENAME(@oldVolume) + '. ~~~~ */'; 
			IF	@verbose = 1
				PRINT	'/*	******************** End:	@addLogFiles = 1 *****************************/
';
		END	-- End Else portion for Validation of Data volumes
	END -- End block of @addLogFiles = 1
	--	----------------------------------------------------------------------------
		--	End:	@addLogFiles = 1
	--	============================================================================

	--	============================================================================
		--	Begin:	@restrictDataFileGrowth = 1
	--	----------------------------------------------------------------------------
	IF	@restrictDataFileGrowth = 1
	BEGIN
		IF @verbose = 1
		BEGIN
			PRINT	'
/*	******************** Begin:	@restrictDataFileGrowth = 1 *****************************/';
		END

		IF (SELECT COUNT(*) FROM @mountPointVolumes as V WHERE V.Volume IN (@oldVolume))<>1
		BEGIN -- Begin block for Validation of Data volumes
			SET @_errorMSG = '@oldVolume parameter value is must with @restrictDataFileGrowth = 1 parameter. Verify if valid values are supplied.';
			IF (select CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)),charindex('.',CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)))-1) AS INT)) >= 12
				EXEC sp_executesql N'THROW 50000,@_errorMSG,1',N'@_errorMSG VARCHAR(200)', @_errorMSG;
			ELSE
				EXEC sp_executesql N'RAISERROR (@_errorMSG, 16, 1)', N'@_errorMSG VARCHAR(200)', @_errorMSG;
		END

		IF EXISTS(SELECT 1 FROM @mountPointVolumes as V WHERE V.Volume = @oldVolume AND [freespace(%)] > (100-@mountPointGrowthRestrictionPercent)) -- default 21%
		BEGIN -- Begin block for Validation of Data volumes
			SET @_errorMSG = '@oldVolume '+QUOTENAME(@oldVolume)+' has free space more than '+CAST((100-@mountPointGrowthRestrictionPercent) AS VARCHAR(20))+' percent. So, skipping the data file restriction. If required, re-run the procedure with lower value for @mountPointGrowthRestrictionPercent parameter.';
			IF (select CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)),charindex('.',CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)))-1) AS INT)) >= 12
				EXEC sp_executesql N'THROW 50000,@_errorMSG,1',N'@_errorMSG VARCHAR(200)', @_errorMSG;
			ELSE
				EXEC sp_executesql N'RAISERROR (@_errorMSG, 16, 1)', N'@_errorMSG VARCHAR(200)', @_errorMSG;
		END
		ELSE
		BEGIN -- Begin Else portion for Validation of Data volumes
			IF @verbose = 1
			BEGIN
				PRINT	'	Validation of @oldVolume completed successfully.';
				PRINT	'	Printing values for @_mirrorDatabases, @_nonAccessibleDatabases, @_principalDatabases';
			END

			IF	@_mirrorDatabases IS NOT NULL
			BEGIN
				SET @_errorMSG = '/*	NOTE: Following '+CAST(@_mirrorDatabaseCounts_Mirroring AS VARCHAR(5))+' database(s) '+(case when @_mirrorDatabaseCounts_Mirroring > 1 then 'are' else 'is' end) +' in role of ''Mirroring Partner''. So restrict growth on Partner server '''+@_mirroringPartner+''' for these dbs.
				'+@_mirrorDatabases+'
	*/';
				IF @forceExecute = 1
				BEGIN
					IF @_errorOccurred = 0
						SET @_errorOccurred = 1;

					INSERT #ErrorMessages
					SELECT	'Mirror Server' AS ErrorCategory
							,NULL AS DBName 
							,NULL AS [FileName] 
							,@_errorMSG AS ErrorDetails 
							,NULL AS TSQLCode;
				END
				ELSE
					PRINT @_errorMSG;
			END
				
	
			IF	@_nonAccessibleDatabases IS NOT NULL
			BEGIN
				SET @_errorMSG = '/*	NOTE: Following '+CAST(@_nonAccessibleDatabasesCounts AS VARCHAR(5))+' database(s) '+(case when @_nonAccessibleDatabasesCounts > 1 then 'are' else 'is' end) +' in non-accessible state. Either wait, or resolve the issue, and then create/restrict Data files.
				'+@_nonAccessibleDatabases+'
	*/';
				IF @forceExecute = 1
				BEGIN
					IF @_errorOccurred = 0
						SET @_errorOccurred = 1;

					INSERT #ErrorMessages
					SELECT	'Non-Accessible Databases' AS ErrorCategory
							,NULL AS DBName 
							,NULL AS [FileName] 
							,@_errorMSG AS ErrorDetails 
							,NULL AS TSQLCode;
				END
				ELSE
					PRINT @_errorMSG;
			END

			IF	@_principalDatabases IS NOT NULL
			BEGIN
				SET @_errorMSG = '/*	NOTE: Following '+CAST(@_principalDatabaseCounts_Mirroring AS VARCHAR(5))+' database(s) '+(case when @_principalDatabaseCounts_Mirroring > 1 then 'are' else 'is' end) +' in role of ''Mirroring Principal''. So generating code to restrict growth of secondary files for these dbs.
				'+@_principalDatabases+'
	*/';
				IF @forceExecute = 0 -- Ignore this message if @forceExecute = 1 since this is information only message
					PRINT @_errorMSG;
			END

			IF @verbose = 1
				PRINT	'	Find all databases for which Secondary Data files are yet to be added on @newVolume';
		
			--	Find all databases for which Secondary Data files are yet to be added on @newVolume.
			SELECT	@_nonAddedDataFilesDatabases = COALESCE(@_nonAddedDataFilesDatabases+', '+DB_NAME(database_id),DB_NAME(database_id))
			FROM	(SELECT DISTINCT database_id FROM #T_Files_Final WHERE [isExisting_UnrestrictedGrowth_on_OtherVolume] = 0) as d;
			SET @_nonAddedDataFilesDatabasesCounts = (LEN(@_nonAddedDataFilesDatabases)-LEN(REPLACE(@_nonAddedDataFilesDatabases,',',''))+1);
			IF	@_nonAddedDataFilesDatabases IS NOT NULL
			BEGIN
				SET @_errorMSG = '/*	NOTE: New Data files for following '+CAST(@_nonAddedDataFilesDatabasesCounts AS VARCHAR(5))+' database(s) are yet to be added. So skipping these database for growth restriction.
				'+@_nonAddedDataFilesDatabases+'
	*/';
				IF @forceExecute = 1
				BEGIN
					IF @_errorOccurred = 0
						SET @_errorOccurred = 1;

					INSERT #ErrorMessages
					SELECT	'DataFile Not Created' AS ErrorCategory
							,NULL AS DBName 
							,NULL AS [FileName] 
							,@_errorMSG AS ErrorDetails 
							,NULL AS TSQLCode;
				END
				ELSE
					PRINT @_errorMSG;
			END

			IF @verbose = 1
			BEGIN
				PRINT	'	@_nonAddedDataFilesDatabases = ' + ISNULL(@_nonAddedDataFilesDatabases,'');
			END

			--	Generate TSQL Code for restricting data files growth
			IF EXISTS (SELECT * FROM #T_Files_Final WHERE [isExisting_UnrestrictedGrowth_on_OtherVolume] = 1 AND growth <> 0)
			BEGIN	-- Begin block for tsql code generation
						
				DELETE @T_Files_Final_Restrict;
				INSERT @T_Files_Final_Restrict (TSQL_RestrictFileGrowth,DBName,name,_name)
				SELECT [TSQL_RestrictFileGrowth],dbName,name,_name FROM #T_Files_Final as f WHERE [isExisting_UnrestrictedGrowth_on_OtherVolume] = 1 AND growth <> 0 ORDER BY f.dbName;

				SELECT @_loopCounter=MIN(ID), @_loopCounts=MAX(ID) FROM	@T_Files_Final_Restrict;
			
				WHILE @_loopCounter <= @_loopCounts
				BEGIN
					SELECT @_loopSQLText = '
--	Restrict Growth of File: '+CAST(ID AS VARCHAR(5))+';'+[TSQL_RestrictFileGrowth] 
					,@_dbName = DBName ,@_name = name ,@_newName = _name
					FROM @T_Files_Final_Restrict as f WHERE f.ID = @_loopCounter;
					IF @_loopCounter = 1
						SET @_loopSQLText =	'USE [master];
--	=====================================================================================================
	--	TSQL Code to Restrict Data Files growth on @oldVolume '+QUOTENAME(@oldVolume) + ' for which Data file already exists on other Data volumes.
' + @_loopSQLText;

					IF @forceExecute = 1
					BEGIN
						BEGIN TRY
							EXEC (@_loopSQLText);
						END TRY
						BEGIN CATCH
							IF @_errorOccurred = 0
								SET @_errorOccurred = 1;

							INSERT #ErrorMessages
							SELECT	'ALTER DATABASE Failed' AS ErrorCategory
									,@_dbName AS DBName 
									,@_name AS [FileName] 
									,ERROR_MESSAGE() AS ErrorDetails 
									,@_loopSQLText AS TSQLCode;
						END CATCH
					END
					ELSE
						PRINT @_loopSQLText;

					SET @_loopSQLText = '';
					SET @_loopCounter = @_loopCounter + 1;
				END
			END -- End block for tsql code generation
			ELSE
				PRINT	'	No Data files to restrict growth for @oldVolume '+QUOTENAME(@oldVolume)+'.';
		END	-- End Else portion for Validation of Data volumes

		IF @verbose = 1
			PRINT	'/*	******************** End:	@restrictDataFileGrowth = 1 *****************************/
';
	END -- End block of @restrictDataFileGrowth = 1
	--	============================================================================

	--	============================================================================
		--	Begin:	@restrictLogFileGrowth = 1
	--	----------------------------------------------------------------------------
	IF	@restrictLogFileGrowth = 1
	BEGIN
		IF @verbose = 1
			PRINT	'
/*	******************** Begin:	@restrictLogFileGrowth = 1 *****************************/';
	
		IF (SELECT COUNT(*) FROM @mountPointVolumes as V WHERE V.Volume IN (@oldVolume))<>1
		BEGIN -- Begin block for Validation of Log volumes
			SET @_errorMSG = '@oldVolume parameter value is must with @restrictLogFileGrowth = 1 parameter. Verify if valid values are supplied.';
			IF (select CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)),charindex('.',CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)))-1) AS INT)) >= 12
				EXEC sp_executesql N'THROW 50000,@_errorMSG,1',N'@_errorMSG VARCHAR(200)', @_errorMSG;
			ELSE
				EXEC sp_executesql N'RAISERROR (@_errorMSG, 16, 1)', N'@_errorMSG VARCHAR(200)', @_errorMSG;
		END
		ELSE
		BEGIN -- Begin Else portion for Validation of Log volumes
			IF @verbose = 1
			BEGIN
				PRINT	'	Validation of @newVolume and @oldVolume completed successfullly.';
				PRINT	'	Printing messages related to @_mirrorDatabases, @_nonAccessibleDatabases and @_principalDatabases';
			END

			IF	@_mirrorDatabases IS NOT NULL
				PRINT	'		/*	NOTE: Following '+CAST(@_mirrorDatabaseCounts_Mirroring AS VARCHAR(5))+' database(s) '+(case when @_mirrorDatabaseCounts_Mirroring > 1 then 'are' else 'is' end) +' in role of ''Mirroring Partner''. So restrict growth on Partner server '''+@_mirroringPartner+''' for these dbs.
					'+@_mirrorDatabases+'
		*/';
	
			IF	@_nonAccessibleDatabases IS NOT NULL
			PRINT	'		/*	NOTE: Following '+CAST(@_nonAccessibleDatabasesCounts AS VARCHAR(5))+' database(s) '+(case when @_nonAccessibleDatabasesCounts > 1 then 'are' else 'is' end) +' in non-accessible state. Either wait, or resolve the issue, and then create/restrict Log files.
					'+@_nonAccessibleDatabases+'
		*/';

			IF	@_principalDatabases IS NOT NULL
				PRINT	'		/*	NOTE: Following '+CAST(@_principalDatabaseCounts_Mirroring AS VARCHAR(5))+' database(s) '+(case when @_principalDatabaseCounts_Mirroring > 1 then 'are' else 'is' end) +' in role of ''Mirroring Principal''. So generating code to restrict growth of files for these dbs.
					'+@_principalDatabases+'
		*/';
		
			IF @verbose = 1
				PRINT	'	Finding all databases for which log files are yet to be added on @newVolume';

			--	Find all databases for which log files are yet to be added on @newVolume.
			SELECT	@_nonAddedLogFilesDatabases = COALESCE(@_nonAddedLogFilesDatabases+', '+DB_NAME(database_id),DB_NAME(database_id))
			FROM	(SELECT DISTINCT database_id FROM #T_Files_Final WHERE [isExisting_UnrestrictedGrowth_on_OtherVolume] = 0) as d;
			SET @_nonAddedLogFilesDatabasesCounts = (LEN(@_nonAddedLogFilesDatabases)-LEN(REPLACE(@_nonAddedLogFilesDatabases,',',''))+1);
			IF	@_nonAddedLogFilesDatabases IS NOT NULL
				PRINT	'		/*	NOTE: New Log files for following '+CAST(@_nonAddedLogFilesDatabasesCounts AS VARCHAR(5))+' database(s) are yet to be added. So skipping these database for growth restriction.
					'+@_nonAddedLogFilesDatabases+'
		*/';

			IF @verbose = 1
				PRINT	'	Validate and Generate TSQL Code for to restrict log files growth';

			--	Generate TSQL Code for restricting log files growth
			IF EXISTS (SELECT * FROM #T_Files_Final WHERE [isExisting_UnrestrictedGrowth_on_OtherVolume] = 1 AND growth <> 0)
			BEGIN	-- Begin block for tsql code generation
				IF @verbose = 1
					PRINT	'	Declaring variables and inserting data into @T_Files_Final_Restrict';

				DELETE @T_Files_Final_Restrict;
				INSERT @T_Files_Final_Restrict (TSQL_RestrictFileGrowth,DBName,name,_name)
				SELECT [TSQL_RestrictFileGrowth],dbName,name,_name  FROM #T_Files_Final as f WHERE [isExisting_UnrestrictedGrowth_on_OtherVolume] = 1 AND growth <> 0 ORDER BY f.dbName;

				IF @verbose = 1
					PRINT	'	Preparing loop variables @_loopCounter and @_loopCounts';

				SELECT @_loopCounter=MIN(ID), @_loopCounts=MAX(ID) FROM	@T_Files_Final_Restrict;
			
				WHILE @_loopCounter <= @_loopCounts
				BEGIN
					SELECT @_loopSQLText = '
	--	Restrict Growth of File: '+CAST(ID AS VARCHAR(5))+';'+[TSQL_RestrictFileGrowth] FROM @T_Files_Final_Restrict as f WHERE f.ID = @_loopCounter;
					IF @_loopCounter = 1
						SET @_loopSQLText =	'USE [master];
--	=====================================================================================================
	--	TSQL Code to Restrict Log Files growth on @oldVolume '+QUOTENAME(@oldVolume) + ' for which Log file already exists on other Log volumes.
' + @_loopSQLText;

					PRINT @_loopSQLText;

					SET @_loopSQLText = '';
					SET @_loopCounter = @_loopCounter + 1;
				END
			END -- End block for tsql code generation
			ELSE
				PRINT	'	--	No Log files to restrict growth for @oldVolume '+QUOTENAME(@oldVolume)+'.';
		END	-- End Else portion for Validation of Log volumes

		IF @verbose = 1
			PRINT	'/*	******************** End:	@restrictLogFileGrowth = 1 *****************************/
';
	END -- End block of @restrictLogFileGrowth = 1
	--	============================================================================

	--	============================================================================
		--	Begin:	@unrestrictFileGrowth = 1
	--	----------------------------------------------------------------------------
	IF	@unrestrictFileGrowth = 1
	BEGIN
		IF @verbose = 1
			PRINT	'
/*	******************** Begin:	@unrestrictFileGrowth = 1 *****************************/';

		IF (SELECT COUNT(*) FROM @mountPointVolumes as V WHERE V.Volume IN (@oldVolume))<>1
		BEGIN -- Begin block for Validation of Data volumes
			SET @_errorMSG = '@oldVolume parameter value is mandatory with @unrestrictFileGrowth = 1 parameter. Verify if valid values are supplied.';
			IF (select CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)),charindex('.',CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)))-1) AS INT)) >= 12
				EXEC sp_executesql N'THROW 50000,@_errorMSG,1',N'@_errorMSG VARCHAR(200)', @_errorMSG;
			ELSE
				EXEC sp_executesql N'RAISERROR (@_errorMSG, 16, 1)', N'@_errorMSG VARCHAR(200)', @_errorMSG;
		END -- End block for Validation of Data volumes
		ELSE
		BEGIN -- Begin Else portion for Validation of Data volumes
			IF	@_mirrorDatabases IS NOT NULL
				PRINT	'	/*	NOTE: Following '+CAST(@_mirrorDatabaseCounts_Mirroring AS VARCHAR(5))+' database(s) '+(case when @_mirrorDatabaseCounts_Mirroring > 1 then 'are' else 'is' end) +' in role of ''Mirroring Partner''. So unrestrict data files growth on Partner server '''+@_mirroringPartner+''' for these dbs.
				'+@_mirrorDatabases+'
	*/';
	
			IF	@_nonAccessibleDatabases IS NOT NULL
			PRINT	'	/*	NOTE: Following '+CAST(@_nonAccessibleDatabasesCounts AS VARCHAR(5))+' database(s) '+(case when @_nonAccessibleDatabasesCounts > 1 then 'are' else 'is' end) +' in non-accessible state. Either wait, or resolve the issue, and then unrestrict Data files.
				'+@_nonAccessibleDatabases+'
	*/';

			IF	@_principalDatabases IS NOT NULL
				PRINT	'	/*	NOTE: Following '+CAST(@_principalDatabaseCounts_Mirroring AS VARCHAR(5))+' database(s) '+(case when @_principalDatabaseCounts_Mirroring > 1 then 'are' else 'is' end) +' in role of ''Mirroring Principal''. So generating code to un-restrict growth of secondary files for these dbs.
				'+@_principalDatabases+'
	*/';

			--	Generate TSQL Code for un-restricting data file growth
			IF EXISTS (SELECT * FROM #T_Files_Final WHERE growth = 0)
			BEGIN	-- Begin block for tsql code generation
				IF @verbose = 1
					PRINT	'		Begin block for tsql code generation';

				DECLARE @T_Files_Final_UnRestrictFiles TABLE (ID INT IDENTITY(1,1), TSQL_UnRestrictFileGrowth VARCHAR(2000));
				INSERT @T_Files_Final_UnRestrictFiles
				SELECT TSQL_UnRestrictFileGrowth FROM #T_Files_Final as f WHERE growth = 0;

				SELECT @_loopCounter=MIN(ID), @_loopCounts=MAX(ID) FROM	@T_Files_Final_UnRestrictFiles;
			
				WHILE @_loopCounter <= @_loopCounts
				BEGIN	-- Begin Block of Loop
					SELECT @_loopSQLText = '
	--	Un-restrict Growth of File: '+CAST(ID AS VARCHAR(5))+';'+TSQL_UnRestrictFileGrowth FROM @T_Files_Final_UnRestrictFiles as f WHERE f.ID = @_loopCounter;
					IF @_loopCounter = 1
						SET @_loopSQLText =	'USE [master];
--	=====================================================================================================
	--	TSQL Code to Remove Restriction of Auto Growth for files on @oldVolume '+QUOTENAME(@oldVolume) + '.
' + @_loopSQLText;

					PRINT @_loopSQLText;

					SET @_loopSQLText = '';
					SET @_loopCounter = @_loopCounter + 1;
				END		-- End Block of Loop
			END -- End block for tsql code generation
			ELSE
				PRINT	'/*	------------------------------------------------------------------------------------------------
		No files exists on @oldVolume '+QUOTENAME(@oldVolume) + ' with Auto growth restriction.
	------------------------------------------------------------------------------------------------
	*/';
		END	-- End Else portion for Validation of Data volumes

		IF @verbose = 1
			PRINT	'/*	******************** End:	@unrestrictFileGrowth = 1 *****************************/
';
	END -- End block of @unrestrictFileGrowth = 1
	--	----------------------------------------------------------------------------
		--	End:	@unrestrictFileGrowth = 1
	--	============================================================================

	--	============================================================================
		--	Begin:	@generateCapacityException = 1
	--	----------------------------------------------------------------------------
	IF	@generateCapacityException = 1
	BEGIN
		IF @verbose = 1
			PRINT	'
/*	******************** Begin: @generateCapacityException = 1 *****************************/';

		IF (SELECT COUNT(*) FROM @mountPointVolumes as V WHERE V.Volume = @oldVolume) <> 1
		BEGIN -- Begin block for Validation of Data volumes
			SET @_errorMSG = '@oldVolume parameter value is mandatory with @generateCapacityException = 1 parameter. Verify if valid values are supplied.';
			IF (select CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)),charindex('.',CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)))-1) AS INT)) >= 12
				EXEC sp_executesql N'THROW 50000,@_errorMSG,1',N'@_errorMSG VARCHAR(200)', @_errorMSG;
			ELSE
				EXEC sp_executesql N'RAISERROR (@_errorMSG, 16, 1)', N'@_errorMSG VARCHAR(200)', @_errorMSG;
		END -- End block for Validation of Data volumes
		--
		IF EXISTS (SELECT * FROM @mountPointVolumes as V WHERE V.Volume = @oldVolume AND [freespace(%)] > 20.0 )
		BEGIN -- if % free space on @oldVolume is more than 20%, then Add an entry in #ErrorMessages table but Continue with this code generation.
			SET @_errorMSG = '@oldVolume still has free space more than 20%. So, it is not recommended to add Capacity Exception in MNA table right now.
Kindly use @restrictMountPointGrowth functionality to increase the space utilization of files.';
			
			BEGIN
				IF @_errorOccurred = 0
					SET @_errorOccurred = 1;

				INSERT #ErrorMessages
				SELECT	'Under utilized Space Capacity' AS ErrorCategory
						,NULL AS DBName 
						,NULL AS [FileName] 
						,@_errorMSG AS ErrorDetails 
						,NULL AS TSQLCode;
			END
			
		END -- End block for Validation of Data volumes
		--
		IF EXISTS (SELECT f.dbName, f.data_space_id FROM #T_Files_Final AS f WHERE f.dbName NOT IN ('uhtdba','tempdb') AND f.growth <> 0 GROUP BY f.dbName, f.data_space_id)
		BEGIN	--	Check if all the files are set to 0 auto growth
			SET @_errorMSG = 'Kindly restrict the data/log files on @oldVolume before using @generateCapacityException option.';
			IF (select CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)),charindex('.',CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)))-1) AS INT)) >= 12
				EXEC sp_executesql N'THROW 50000,@_errorMSG,1',N'@_errorMSG VARCHAR(200)', @_errorMSG;
			ELSE
				EXEC sp_executesql N'RAISERROR (@_errorMSG, 16, 1)', N'@_errorMSG VARCHAR(200)', @_errorMSG;
		END
		--
		ELSE
		BEGIN -- Begin Else portion for Validation of Data volumes
			PRINT	'	--	NOTE:	'+CAST(@_freeSpace_OldVolume_GB AS VARCHAR(20))+'gb('+CAST(@_freeSpace_OldVolume_Percent AS VARCHAR(20))+'%) of '+CAST(@_totalSpace_OldVolume_GB AS VARCHAR(20))+'gb is available on @oldVolume '+QUOTENAME(@oldVolume,'''')+'.';
			PRINT	'
	--	Add Space Capacity Exception for '+QUOTENAME(@oldVolume,'''')+'
		--	Execute Below code on MNA server <DBSWP0230CLS>
	';
			--	Find FQN
			DECLARE @Domain varchar(100), @key varchar(100);
			SET @key = 'SYSTEM\ControlSet001\Services\Tcpip\Parameters\';
			EXEC master..xp_regread @rootkey='HKEY_LOCAL_MACHINE', @key=@key,@value_name='Domain',@value=@Domain OUTPUT;

			IF @verbose = 1
			BEGIN
				PRINT	'	SELECT * FROM @mountPointVolumes v WHERE v.Volume = @oldVolume;';
				SELECT 'SELECT * FROM @mountPointVolumes v WHERE v.Volume = @oldVolume;' AS RunningQuery, * FROM @mountPointVolumes v WHERE v.Volume = @oldVolume;
			END

			;WITH T_Thresholds AS
			(
				--	Removing below code since sys.dm_os_volume_stats DMV is not available before SQL 2008.
				SELECT	Volume, 
						[capacity (gb)] = [capacity(GB)],
						[pWarningThreshold%] = CEILING(100-[freespace(%)]), -- find used %
						[pWarningThreshold (gb)] = FLOOR([capacity(GB)] - [freespace(GB)]), -- find used space
						[pCriticalThreshold%] = CEILING(100-[freespace(%)])+2, -- set critical to used % + 2.
						[pCriticalThreshold (gb)] = FLOOR(((CEILING(100-[freespace(%)])+2)*[capacity(GB)])/100)
						--,s.*--,f.ID
				FROM  @mountPointVolumes v WHERE v.Volume = @oldVolume

			)
			,T_Exception AS
			(
				SELECT	*
						,[pReason] = 'Data '+LEFT(f.Volume,LEN(f.Volume)-1)+' Unrestricted Cap:'+CAST([capacity (gb)] AS VARCHAR(20))+'gbs  Warn:'+CAST([pWarningThreshold%] AS VARCHAR(20))+'% '+CAST([pWarningThreshold (gb)] AS VARCHAR(20))+'gbs  Crit:'+CAST([pCriticalThreshold%] AS VARCHAR(20))+'% '+CAST([pCriticalThreshold (gb)] AS VARCHAR(20))+'gbs'
				FROM T_Thresholds as f
			)
				SELECT	@_capacityExceptionSQLText = '
	IF NOT EXISTS (SELECT * FROM MNA.MA.EXCEPTION e WHERE e.eventName = ''Capacity Constrained'' AND e.serverName LIKE '''+@@SERVERNAME+'%'' AND volumeName = '''+LEFT(e.Volume,LEN(e.Volume)-1)+''')
	BEGIN
		IF NOT EXISTS (SELECT * FROM MNA.ma.VolumeUseType AS v WHERE v.serverName LIKE '''+@@SERVERNAME+'%'' AND v.volume = '''+LEFT(e.Volume,LEN(e.Volume)-1)+''')
			PRINT	''--	Data Volume is not present on MNA.ma.VolumeUseType table.''
		ELSE
		BEGIN
			DECLARE	@DateOfException SMALLDATETIME = GETDATE();

			--	Space Capacity Exception
			EXEC MNA.ma.SpaceCapacity_AddException	
					@pServerName	= '''+@@servername+'.'+@Domain+''',
					@pVolumeName		= '''+LEFT(e.Volume,LEN(e.Volume)-1)+''',
					@pWarningThreshold	= '+CAST([pWarningThreshold%] AS VARCHAR(20))+',
					@pCriticalThreshold = '+CAST([pCriticalThreshold%] AS VARCHAR(20))+',
					@pStartDTS			= @DateOfException,
					@pEndDTS			= NULL,
					@pReason			= '''+[pReason]+''';
		END
	END
	'
				FROM	T_Exception AS e;

				PRINT	@_capacityExceptionSQLText;
		END	-- End Else portion for Validation of Data volumes

		IF @verbose = 1
			PRINT	'/*	******************** End: @generateCapacityException = 1 *****************************/
';
	END -- End block of @generateCapacityException = 1
	--	----------------------------------------------------------------------------
		--	End:	@generateCapacityException = 1
	--	============================================================================

	--	============================================================================
		--	Begin:	@UpdateMountPointSecurity = 1
	--	----------------------------------------------------------------------------
	IF	@UpdateMountPointSecurity = 1
	BEGIN
			PRINT	'/*	Import <<SQLDBATools>> powershell module, and then use <<Update-MountPointSecurity>> command after that.

	Import-Module "\\Naselrrr01\sql_infra\DBATools\SQLDBATools.psm1"
	Update-MountPointSecurity -ServerName '+QUOTENAME(@@SERVERNAME,'"')+ '
	Update-TSMFolderPermissions -ServerName '+QUOTENAME(@@SERVERNAME,'"')+ '
	Update-SQLBackupFolderPermissions -ServerName '+QUOTENAME(@@SERVERNAME,'"')+ '
	*/';

	END -- End block of @UpdateMountPointSecurity = 1
	--	----------------------------------------------------------------------------
		--	End:	@UpdateMountPointSecurity = 1
	--	============================================================================

	--	============================================================================
		--	Begin:	@restrictMountPointGrowth = 1
	--	----------------------------------------------------------------------------
	IF	@restrictMountPointGrowth = 1
	BEGIN
		IF @verbose = 1
			PRINT	'Begin:	@restrictMountPointGrowth = 1';

		IF EXISTS (SELECT * FROM sys.master_files as mf WHERE mf.physical_name LIKE (@oldVolume + '%') AND mf.growth <> 0  
															AND DB_NAME(mf.database_id)IN (SELECT f.DBName FROM @filterDatabaseNames AS f))
		BEGIN
			PRINT	'Kindly restrict the growth of files +nt in @oldVolume = '+QUOTENAME(@oldVolume,'''')+'. Then, proceed for this step.';
		END
		--ELSE
		BEGIN	-- Begin block : Real Logic for restricting mount point volume

			IF @verbose = 1
				PRINT	'	Assigning values for @_Total_Files_Size_MB, @_Space_That_Can_Be_Freed_MB, @_Total_Files_SpaceUsed_MB and @_SpaceToBeFreed_MB.';

			SELECT	@_Space_That_Can_Be_Freed_MB = SUM(f.FreeSpaceMB)
			FROM	@DBFiles AS f
			WHERE	f.physical_name LIKE (@oldVolume + '%')
				AND	f.DbName IN (SELECT d.DBName FROM @filterDatabaseNames AS d);

			--	Since some DBs can be in offline state, Total File Size can not be calculated using @DBFiles.
			--	@_SpaceToBeFreed_MB will be -ve is @mountPointGrowthRestrictionPercent > [% Full]. Otherwise +ve if space has to be released from files using Shrink operation.
			SELECT	@_SpaceToBeFreed_MB = (((100-@mountPointGrowthRestrictionPercent)*v.[capacity(MB)])/100) - [freespace(MB)]
					,@_Total_Files_Size_MB = ([capacity(MB)] - [freespace(MB)])
					,@_Total_Files_SpaceUsed_MB = ([capacity(MB)] - [freespace(MB)]) - @_Space_That_Can_Be_Freed_MB
			FROM	@mountPointVolumes v
			WHERE	v.Volume = @oldVolume;

			IF @verbose = 1
				PRINT	'	Values for @_Total_Files_Size_MB = '+CAST(@_Total_Files_Size_MB AS VARCHAR)+' 
			@_Space_That_Can_Be_Freed_MB = '+CAST(@_Space_That_Can_Be_Freed_MB AS VARCHAR)+'
			@_Total_Files_SpaceUsed_MB = '+CAST(@_Total_Files_SpaceUsed_MB AS VARCHAR)+' 
			@_SpaceToBeFreed_MB = '+CAST(@_SpaceToBeFreed_MB AS VARCHAR);

			IF @verbose = 1
				PRINT '		Creating temp table #DBFiles_By_Weightage.';

			--	Create table with Weightage of files
			IF OBJECT_ID('tempdb..#DBFiles_By_Weightage') IS NOT NULL
				DROP TABLE #DBFiles_By_Weightage;
			WITH T_DBFiles_By_Weightage AS 
			(
				SELECT	*
						,[Weightage] = [% space used] + [SpaceRatio_b/w_All]
				FROM  (
						SELECT	*
								,[SpaceRatio_b/w_All] = CAST( (SpaceUsed * 100.0) / @_Total_Files_SpaceUsed_MB AS DECIMAL(18,2))
						FROM	@DBFiles AS f 
						WHERE	f.physical_name LIKE (@oldVolume + '%')
							AND	f.DbName IN (SELECT d.DBName FROM @filterDatabaseNames AS d)
					  ) AS f1
			)
			,T_DBFiles_Total_Weightage_Sum AS
			(
				SELECT Weightage_Sum = SUM([Weightage]) FROM T_DBFiles_By_Weightage
			)
			SELECT	*
					,Weightage_Ratio = CAST([Weightage] / Weightage_Sum AS DECIMAL(18,2))
			INTO	#DBFiles_By_Weightage
			FROM	T_DBFiles_By_Weightage,T_DBFiles_Total_Weightage_Sum;

			IF @verbose = 1
			BEGIN
				PRINT	'Printing Data of @DBFiles';
				SELECT	*
				FROM	#DBFiles_By_Weightage
				ORDER BY [Weightage] DESC;

				PRINT	'Printing Data of @mountPointVolumes';
				SELECT	*
				FROM	@mountPointVolumes v
				WHERE	v.Volume = @oldVolume;
			END

			IF EXISTS (SELECT * FROM @mountPointVolumes WHERE Volume = @oldVolume AND [freespace(%)] > (100-@mountPointGrowthRestrictionPercent))
			BEGIN
				IF @verbose = 1
					PRINT '	Increase size of files +nt on @oldVolume';

				--	Find space that has to be added to Data/Log files
				SELECT	@_Space_To_Add_to_Files_MB = (([freespace(%)]-(100.0-@mountPointGrowthRestrictionPercent))*[capacity(MB)])/100
				FROM	@mountPointVolumes 
				WHERE	Volume = @oldVolume

				IF @verbose = 1
					PRINT '	space that has to be added to Data/Log files: '+cast(@_Space_To_Add_to_Files_MB as varchar);
			
				PRINT	'--	Add space in files on volume '+QUOTENAME(@oldVolume,'''')+ ' to '+CAST(@mountPointGrowthRestrictionPercent AS VARCHAR(10))+'% of mount point capacity.

	';

				--	Truncate table
				DELETE FROM @T_Files_restrictMountPointGrowth;

				IF @verbose = 1
				BEGIN
					PRINT	'	Printing data of #DBFiles_By_Weightage';
						SELECT 'SELECT * FROM #DBFiles_By_Weightage;' AS RunningQuery, * FROM #DBFiles_By_Weightage;
					PRINT	'	Printing data of below CTE
		WITH T_FileSpace_01 AS
		(
			SELECT	*
					,RowID = ROW_NUMBER()OVER(ORDER BY Weightage DESC)
					,SpaceToAddOnFile = Weightage_Ratio * @_Space_To_Add_to_Files_MB
			FROM	#DBFiles_By_Weightage AS f
			WHERE	Weightage_Ratio <> 0.0
		)
		,T_FileSpace_Final AS
		(
			SELECT	DbName, FileName, physical_name, CurrentSizeMB, FreeSpaceMB, SpaceUsed, type_desc, growth, is_percent_growth, [% space used], [SpaceRatio_b/w_All], Weightage, Weightage_Sum, Weightage_Ratio, RowID --, SpaceToAddOnFile
					,SpaceToAddOnFile =		CASE	WHEN s.RowID = (SELECT MAX(s1.RowID) FROM T_FileSpace_01 AS s1)
													THEN @_Space_To_Add_to_Files_MB - (SELECT SUM(s1.SpaceToAddOnFile) FROM T_FileSpace_01 AS s1 WHERE s1.RowID < s.RowID)
													ELSE SpaceToAddOnFile
											END
			FROM	T_FileSpace_01 AS s
		)
		SELECT * FROM T_FileSpace_Final';
					WITH T_FileSpace_01 AS
					(
						SELECT	*
								,RowID = ROW_NUMBER()OVER(ORDER BY Weightage DESC)
								,SpaceToAddOnFile = Weightage_Ratio * @_Space_To_Add_to_Files_MB
						FROM	#DBFiles_By_Weightage AS f
						WHERE	Weightage_Ratio <> 0.0
					)
					,T_FileSpace_Final AS
					(
						SELECT	DbName, FileName, physical_name, CurrentSizeMB, FreeSpaceMB, SpaceUsed, type_desc, growth, is_percent_growth, [% space used], [SpaceRatio_b/w_All], Weightage, Weightage_Sum, Weightage_Ratio, RowID --, SpaceToAddOnFile
								,SpaceToAddOnFile =		CASE	WHEN s.RowID = (SELECT MAX(s1.RowID) FROM T_FileSpace_01 AS s1)
																THEN @_Space_To_Add_to_Files_MB - ISNULL((SELECT SUM(s1.SpaceToAddOnFile) FROM T_FileSpace_01 AS s1 WHERE s1.RowID < s.RowID),0)
																ELSE SpaceToAddOnFile
														END
						FROM	T_FileSpace_01 AS s
					)
					SELECT * FROM T_FileSpace_Final;
				END;

				--	Prepare code
				WITH T_FileSpace_01 AS
				(
					SELECT	*
							,RowID = ROW_NUMBER()OVER(ORDER BY Weightage DESC)
							,SpaceToAddOnFile = Weightage_Ratio * @_Space_To_Add_to_Files_MB
					FROM	#DBFiles_By_Weightage AS f
					WHERE	Weightage_Ratio <> 0.0
				)
				,T_FileSpace_Final AS
				(
					SELECT	DbName, FileName, physical_name, CurrentSizeMB, FreeSpaceMB, SpaceUsed, type_desc, growth, is_percent_growth, [% space used], [SpaceRatio_b/w_All], Weightage, Weightage_Sum, Weightage_Ratio, RowID --, SpaceToAddOnFile
							,SpaceToAddOnFile =		CASE	WHEN s.RowID = (SELECT MAX(s1.RowID) FROM T_FileSpace_01 AS s1)
															THEN @_Space_To_Add_to_Files_MB - ISNULL((SELECT SUM(s1.SpaceToAddOnFile) FROM T_FileSpace_01 AS s1 WHERE s1.RowID < s.RowID),0)
															ELSE SpaceToAddOnFile
													END
					FROM	T_FileSpace_01 AS s
				)
					INSERT @T_Files_restrictMountPointGrowth (TSQL_restrictMountPointGrowth)
					SELECT	--*,
							TSQL_ShrinkFile = '		PRINT	''Adding additional space for file '+QUOTENAME([FileName])+' of database '+QUOTENAME(DbName)+'.'';
ALTER DATABASE ['+DbName+'] MODIFY FILE ( NAME = N'''+[FileName]+''', SIZE = '+CAST(CAST(CurrentSizeMB+SpaceToAddOnFile AS BIGINT) AS VARCHAR(20))+'MB);
		'
					FROM	T_FileSpace_Final AS s;

				IF @verbose = 1
				BEGIN
					PRINT	'	Printing data of @T_Files_restrictMountPointGrowth';
					SELECT 'SELECT * FROM @T_Files_restrictMountPointGrowth;' AS RunningQuery, * FROM @T_Files_restrictMountPointGrowth;
				END
			
				SELECT @_loopCounter=MIN(ID), @_loopCounts=MAX(ID) FROM	@T_Files_restrictMountPointGrowth;
				WHILE @_loopCounter <= @_loopCounts
				BEGIN	-- Begin Block of Loop
					SELECT @_loopSQLText = '	--	Add Space into File: '+CAST(ID AS VARCHAR(5))+';'+TSQL_restrictMountPointGrowth FROM @T_Files_restrictMountPointGrowth as f WHERE f.ID = @_loopCounter;
					IF @_loopCounter = 1
						SET @_loopSQLText =	'USE [master];
	--	=====================================================================================================
	--	TSQL Code to Shrink file.
		' + @_loopSQLText;

					PRINT @_loopSQLText;

					SET @_loopSQLText = '';
					SET @_loopCounter = @_loopCounter + 1;
				END		-- End Block of Loop

			END
			ELSE
			BEGIN
				IF @verbose = 1
					PRINT '	Shrink files +nt on @oldVolume such that required space is returned to Drive';

				PRINT	'--	Generate Code for shrinking files on volume '+QUOTENAME(@oldVolume,'''')+ ' to '+CAST(@mountPointGrowthRestrictionPercent AS VARCHAR(10))+'% of mount point capacity.';

				;WITH T_FileSpace_01 AS
				(
					SELECT	*
							,RowID = ROW_NUMBER()OVER(ORDER BY FreeSpaceMB DESC)
					FROM	@DBFiles AS f
					WHERE	f.physical_name LIKE (@oldVolume + '%')
						AND	f.DbName IN (SELECT d.DBName FROM @filterDatabaseNames AS d)
				)
				,T_FileSpace_Final AS
				(
					SELECT	*
							,SpaceFreedOnFile = (s.FreeSpaceMB-512)
							,Total_SpaceFreedTillNow = (SELECT SUM(s1.FreeSpaceMB-512) FROM T_FileSpace_01 as s1 WHERE s1.RowID <= s.RowID)
					FROM	T_FileSpace_01 AS s
				)
					INSERT @T_Files_restrictMountPointGrowth (TSQL_restrictMountPointGrowth)
					SELECT	--*,
							TSQL_ShrinkFile = '
		USE ['+DbName+'];
		DBCC SHRINKFILE (N'''+[FileName]+''' , '+ (CASE WHEN s.Total_SpaceFreedTillNow <= @_SpaceToBeFreed_MB THEN cast(convert(numeric,(SpaceUsed+512) ) as varchar(50)) ELSE (cast(convert(numeric,(SpaceUsed+512+(Total_SpaceFreedTillNow-@_SpaceToBeFreed_MB)) ) as varchar(50))) END)   +');
			PRINT	''Shrinking file '+QUOTENAME([FileName])+ ' for database '+QUOTENAME(DbName)+'.'';
		--	Space freed on file '+QUOTENAME([FileName])+ ' for database '+QUOTENAME(DbName)+' = '+cast(SpaceFreedOnFile as varchar(50))+' MB
		'
					FROM	T_FileSpace_Final AS s
					WHERE	s.Total_SpaceFreedTillNow <= @_SpaceToBeFreed_MB
						OR	(s.Total_SpaceFreedTillNow - @_SpaceToBeFreed_MB < SpaceFreedOnFile);
			
				SELECT @_loopCounter=MIN(ID), @_loopCounts=MAX(ID) FROM	@T_Files_restrictMountPointGrowth;
				WHILE @_loopCounter <= @_loopCounts
				BEGIN	-- Begin Block of Loop
					SELECT @_loopSQLText = '
		--	Shrink File: '+CAST(ID AS VARCHAR(5))+';'+TSQL_restrictMountPointGrowth FROM @T_Files_restrictMountPointGrowth as f WHERE f.ID = @_loopCounter;
					IF @_loopCounter = 1
						SET @_loopSQLText =	'USE [master];
		--	=====================================================================================================
		--	TSQL Code to Shrink file.
			' + @_loopSQLText;

					PRINT @_loopSQLText;

					SET @_loopSQLText = '';
					SET @_loopCounter = @_loopCounter + 1;
				END		-- End Block of Loop
			END
			
			--END
		END	-- End block : Real Logic for restricting mount point volume

		IF @verbose = 1
			PRINT	'End - @restrictMountPointGrowth = 1';
	END -- End block of @restrictMountPointGrowth = 1
	--	----------------------------------------------------------------------------
		--	End:	@restrictMountPointGrowth = 1
	--	============================================================================


	--	============================================================================
		--	Begin:	@expandTempDBSize = 1
	--	----------------------------------------------------------------------------
	IF	@expandTempDBSize = 1
	BEGIN
		IF @verbose = 1
			PRINT	'
/*	******************** Begin:	@expandTempDBSize = 1 *****************************/';

		IF @verbose = 1
			PRINT	'	Populate data into @tempDBFiles';

		IF (SELECT SERVERPROPERTY ('IsHadrEnabled')) = 1
		BEGIN
			SET @_loopSQLText = 'The server is part of AlwaysOn. Kindly run this procedure on other replicas as well.';

			IF @forceExecute = 1
			BEGIN
				IF @_errorOccurred = 0
					SET @_errorOccurred = 1;

				INSERT #ErrorMessages
				SELECT	'Need Extra Efforts' AS ErrorCategory
						,NULL AS DBName 
						,NULL AS [FileName] 
						,@_loopSQLText AS ErrorDetails 
						,NULL AS TSQLCode;
			END
			ELSE
				PRINT '/********* '+ @_loopSQLText+'			*/';
		END
			

		INSERT @tempDBFiles
			([DBName], [LogicalName], [physical_name], [FileSize_MB], [Volume], [VolumeName], [VolumeSize_MB])
		SELECT	DB_NAME(mf.database_id) as DBName, mf.name as LogicalName, mf.physical_name, ((mf.size*8.0)/1024) as FileSize_MB, 
				s.Volume, s.VolumeName, s.[capacity(MB)] as VolumeSize_MB
		FROM	sys.master_files as mf
		CROSS APPLY
				(SELECT * FROM @mountPointVolumes AS v WHERE mf.physical_name LIKE (v.Volume+'%')) AS s
		WHERE	mf.database_id = DB_ID('tempdb')
			AND	mf.type_desc = 'ROWS'
		ORDER BY mf.[file_id] ASC;

		IF @verbose = 1
		BEGIN
			SELECT	RunningQuery, tf.*
			FROM  (SELECT 'SELECT * FROM @tempDBFiles' AS RunningQuery) AS Qry
			LEFT JOIN
				@tempDBFiles as tf
			ON	1 = 1;
		END

		SET @_logicalCores = (select cpu_count from sys.dm_os_sys_info);
		--	SET @_logicalCores = @_logicalCores + 1;
		IF @verbose = 1
			PRINT	'	Logical CPU = '+CAST(@_logicalCores AS VARCHAR(10));

		SET @_maxFileNO = (SELECT MAX( CAST(RIGHT(REPLACE(REPLACE(LogicalName,']',''),'[',''),PATINDEX('%[a-zA-Z_ ]%',REVERSE(REPLACE(REPLACE(LogicalName,']',''),'[','')))-1) AS BIGINT)) FROM @tempDBFiles);

		IF @verbose = 1
			PRINT	'	@_maxFileNO for Tempdb files = '+CAST(@_maxFileNO AS VARCHAR(10));

		SET @_fileCounts = (SELECT COUNT(*) FROM @tempDBFiles as f WHERE [isToBeDeleted] = 0);
		IF @verbose = 1
			PRINT	'	Current TempDB data files (@_fileCounts) = '+CAST(@_fileCounts AS VARCHAR(10));

		IF @_fileCounts <> (CASE WHEN @_logicalCores >= 8 THEN 8 ELSE @_logicalCores END)
			SET @_counts_of_Files_To_Be_Created = (CASE WHEN @_logicalCores >= 8 THEN 8 ELSE @_logicalCores END) - @_fileCounts;
		
		IF @verbose = 1
		BEGIN
			IF @_logicalCores > 8
				PRINT	'	Logical CPU are more than 8. Still creating tempdb files upto 8 only.';
			PRINT	'	Extra Tempdb data files to be created (@_counts_of_Files_To_Be_Created) = '+CAST(@_counts_of_Files_To_Be_Created AS VARCHAR(10));
		END

		IF @verbose = 1
			PRINT	'	Dropping and creating temp table #tempDBFiles';
			 
		IF OBJECT_ID('tempdb..#tempDBFiles') IS NOT NULL
			DROP TABLE #tempDBFiles
		SELECT	O.*				
				,TSQL_AddFile = CASE WHEN isToBeCreated = 1 THEN '
	ALTER DATABASE [tempdb] ADD FILE ( NAME = N'''+LogicalName+''', FILENAME = N'''+physical_name+''' , SIZE = '+CAST(CAST(FileSize_MB AS NUMERIC(10,0)) AS VARCHAR(10))+'MB , FILEGROWTH = 0);' ELSE NULL END				
				,[TSQL_EmptyFile] = CASE WHEN isToBeDeleted = 1 THEN '
	DBCC SHRINKFILE (N'''+LogicalName+''' , EMPTYFILE);' ELSE NULL END
				,[TSQL_RemoveFile] = CASE WHEN isToBeDeleted = 1 THEN '
	ALTER DATABASE [tempdb]  REMOVE FILE ['+LogicalName+'];' ELSE NULL END
		INTO	#tempDBFiles
		FROM  (
				SELECT	COALESCE(tf.DBName, df.DBName) as DBName,
						COALESCE(tf.LogicalName,'tempdev'+ cast( (@_maxFileNO+df.FileNo_Add) as varchar(3) )) as LogicalName,
						COALESCE(tf.physical_name,df.Volume + 'tempdb'+ cast( (@_maxFileNO+df.FileNo_Add) as varchar(3) ) + '.ndf') as physical_name,
						COALESCE(tf.FileSize_MB,8000) AS FileSize_MB,
						COALESCE(tf.Volume,df.Volume) AS Volume, 
						COALESCE(tf.VolumeName,df.VolumeName) AS VolumeName, 
						COALESCE(tf.VolumeSize_MB, df.VolumeSize_MB) AS VolumeSize_MB,
						isToBeDeleted = COALESCE(tf.isToBeDeleted, 0),
						isExtraFile = CASE WHEN tf.fileNo-(CASE WHEN @_logicalCores >= 8 THEN 8 ELSE @_logicalCores END) > 0 THEN 1 ELSE 0 END,
						isToBeCreated = CASE WHEN tf.isToBeDeleted IS NULL THEN 1 ELSE 0 END
				FROM	@tempDBFiles as tf
				FULL OUTER JOIN
					(	SELECT DBName, LogicalName, physical_name, FileSize_MB, Volume, VolumeName, VolumeSize_MB, isToBeDeleted, FileNo_Add
						--FROM (VALUES (1),(2),(3),(4),(5),(6),(7),(8)) AS FileIterator_Table (FileNo_Add) 
						FROM (SELECT 1  AS FileNo_Add
							UNION ALL
							SELECT 2
							UNION ALL
							SELECT 3 
							UNION ALL
							SELECT 4
							UNION ALL
							SELECT 5
							UNION ALL
							SELECT 6
							UNION ALL
							SELECT 7
							UNION ALL
							SELECT 8) AS FileIterator_Table
						CROSS JOIN
						(SELECT TOP 1 * FROM @tempDBFiles WHERE [isToBeDeleted] = 0 ORDER BY LogicalName DESC) AS t
						WHERE	FileIterator_Table.FileNo_Add <= @_counts_of_Files_To_Be_Created
						AND @output4IdealScenario = 1
					) AS df
				ON		1 = 2
				) AS O;

		IF @verbose = 1
		BEGIN
			SELECT	'SELECT * FROM #tempDBFiles' AS RunningQuery, *
			FROM	#tempDBFiles
		END

		--	If some invalid file exists, then remove that file
		IF EXISTS (SELECT * FROM #tempDBFiles WHERE isToBeDeleted = 1) AND @output4IdealScenario = 1
		BEGIN
			DELETE @T_Files_Remove;
			INSERT @T_Files_Remove ( TSQL_EmptyFile, TSQL_RemoveFile, name, Volume )
			SELECT TSQL_EmptyFile,TSQL_RemoveFile,LogicalName,Volume FROM #tempDBFiles as f WHERE isToBeDeleted = 1 OR isExtraFile = 1 ORDER BY f.LogicalName DESC;

			IF @verbose = 1 
				PRINT	'	Initiating @_loopCounter and @_loopCounts';
			SELECT @_loopCounter=MIN(ID), @_loopCounts=MAX(ID) FROM	@T_Files_Remove;

			IF @verbose=1 
					PRINT	'	Starting Loop to remove tempdb files which are either on non-tempdb volumes, or extra files (more than CPU count)';
			WHILE @_loopCounter <= @_loopCounts
			BEGIN	-- Begin Block of Loop

				SELECT @_loopSQLText = '
--	Empty File: '+CAST(@_loopCounter AS VARCHAR(5))+TSQL_EmptyFile+'

--	Remove File: '+CAST(@_loopCounter AS VARCHAR(5))+TSQL_RemoveFile
						,@_dbName = 'tempdb' ,@_name = name
				FROM @T_Files_Remove as f WHERE f.ID = @_loopCounter;

				IF @_loopCounter = 1
					SET @_loopSQLText =	'USE [tempdb];
--	=====================================================================================================
--	TSQL Code to Remove data files which are either on non-tempdb volumes, or extra files (more than CPU count).
' + @_loopSQLText;

				IF @forceExecute = 1
				BEGIN
					BEGIN TRY
						EXEC (@_loopSQLText);
					END TRY
					BEGIN CATCH
						IF @_errorOccurred = 0
							SET @_errorOccurred = 1;

						INSERT #ErrorMessages
						SELECT	'Remove TempDB File Failed' AS ErrorCategory
								,@_dbName AS DBName 
								,@_name AS [FileName] 
								,ERROR_MESSAGE() AS ErrorDetails 
								,@_loopSQLText AS TSQLCode;
					END CATCH
				END
				ELSE
					PRINT @_loopSQLText;

				SET @_loopSQLText = '';
				SET @_loopCounter = @_loopCounter + 1;
			END		-- End Block of Loop
		END

		--	If no of tempdb files is not as per no of CPUs
		IF EXISTS (SELECT * FROM #tempDBFiles WHERE isToBeCreated = 1) AND @output4IdealScenario = 1
		BEGIN
			DELETE @T_Files_Final_Add;
			INSERT @T_Files_Final_Add (TSQL_AddFile,DBName,name,_name)
			SELECT TSQL_AddFile,DBName,LogicalName,'' FROM #tempDBFiles as f WHERE isToBeCreated = 1 ORDER BY f.LogicalName;

			IF @verbose = 1 
				PRINT	'	Initiating @_loopCounter and @_loopCounts';
			SELECT @_loopCounter=MIN(ID), @_loopCounts=MAX(ID) FROM	@T_Files_Final_Add;

			IF @verbose=1 
					PRINT	'	Starting Loop to add tempdb files as per number of logical Cores';
			WHILE @_loopCounter <= @_loopCounts
			BEGIN	-- Begin Block of Loop

				SELECT @_loopSQLText = '
--	Add File: '+CAST(@_loopCounter AS VARCHAR(5))+';	'+TSQL_AddFile 
						,@_dbName = DBName ,@_name = name ,@_newName = _name
				FROM @T_Files_Final_Add as f WHERE f.ID = @_loopCounter;

				IF @_loopCounter = 1
					SET @_loopSQLText =	'

USE [master];
--	=====================================================================================================
--	TSQL Code to Add Secondary Data Files on tempdb database as per no of logical CPUs upto 8.
' + @_loopSQLText;

				IF @forceExecute = 1
				BEGIN
					BEGIN TRY
						EXEC (@_loopSQLText);
					END TRY
					BEGIN CATCH
						IF @_errorOccurred = 0
							SET @_errorOccurred = 1;

						INSERT #ErrorMessages
						SELECT	'Remove TempDB File Failed' AS ErrorCategory
								,@_dbName AS DBName 
								,@_name AS [FileName] 
								,ERROR_MESSAGE() AS ErrorDetails 
								,@_loopSQLText AS TSQLCode;
					END CATCH
				END
				ELSE
					PRINT @_loopSQLText;

				SET @_loopSQLText = '';
				SET @_loopCounter = @_loopCounter + 1;
			END		-- End Block of Loop
		END
		
		IF @verbose = 1
			PRINT	'	Implementing logic to resize tempdb data files upto 89% of tempdb volume size';

		;WITH T_Files_01 AS
		(
			--	Find all the data files with details to be re-sized
			SELECT	DBName, LogicalName, physical_name, FileSize_MB, Volume, VolumeSize_MB
			FROM	#tempDBFiles as f
			WHERE	(@output4IdealScenario = 1 AND f.isToBeDeleted = 0 AND isExtraFile = 0)
				OR	 @output4IdealScenario = 0
		)
		,T_Volume_Details_01 AS
		(
			--	Find tempdb volume detaile
			SELECT	Volume, MAX(VolumeSize_MB) AS VolumeSize_MB, COUNT(*) AS FileCount
			FROM	T_Files_01
			GROUP BY Volume
		)
		,T_Volume_Details_02 AS
		(
			SELECT	Volume, VolumeSize_MB, FileCount
					-- CapacityThresholdSize_MB = Volume size - space of Tempdb log files if log files is in same as data volume
					,CapacityThresholdSize_MB = ((@tempDBMountPointPercent * VolumeSize_MB)/100.00) - ISNULL((SELECT ((SUM(size) * 8.00)/1024) as size_MB FROM sys.master_files AS mf WHERE mf.database_id = DB_ID('tempdb') AND mf.type_desc = 'LOG' AND mf.physical_name LIKE (v.Volume + '%') ),0)
					--,CapacityThresholdSizePerFile_MB = CAST((((@tempDBMountPointPercent) * VolumeSize_MB)/100.0)/FileCount AS NUMERIC(20,2))
			FROM	T_Volume_Details_01 AS v
		)
		,T_Volume_Details AS
		(
			SELECT	Volume, VolumeSize_MB, FileCount, CapacityThresholdSize_MB
					,CapacityThresholdSizePerFile_MB = CAST((CapacityThresholdSize_MB)/FileCount AS NUMERIC(20,0))
			FROM	T_Volume_Details_02
		)
		INSERT @T_Files_ReSizeTempDB (TSQL_ResizeTempDB_Files)
		SELECT	'
	ALTER DATABASE [tempdb] MODIFY FILE ( NAME = N'''+f.LogicalName+''', SIZE = '+CAST(CapacityThresholdSizePerFile_MB AS VARCHAR(20))+'MB );
'
		FROM	T_Files_01 as f
		INNER JOIN
				T_Volume_Details AS v
			ON	v.Volume = f.Volume;

		SELECT @_loopCounter=MIN(ID), @_loopCounts=MAX(ID) FROM	@T_Files_ReSizeTempDB;
		WHILE @_loopCounter <= @_loopCounts
		BEGIN	-- Begin Block of Loop
			SELECT @_loopSQLText = '
--	Resize File: '+CAST(ID AS VARCHAR(5))+';'+TSQL_ResizeTempDB_Files FROM @T_Files_ReSizeTempDB as f WHERE f.ID = @_loopCounter;
			IF @_loopCounter = 1
				SET @_loopSQLText =	'

USE [master];
--	=====================================================================================================
--	TSQL Code to reset Initial Size for TempDB files.
' + @_loopSQLText;

			PRINT @_loopSQLText;

			SET @_loopSQLText = '';
			SET @_loopCounter = @_loopCounter + 1;
		END		-- End Block of Loop

		IF @verbose = 1
			PRINT	'/*	******************** End:	@expandTempDBSize = 1 *****************************/
';
	END -- End block of @expandTempDBSize = 1
	--	----------------------------------------------------------------------------
		--	End:	@expandTempDBSize = 1
	--	============================================================================

	--	============================================================================
		--	Begin:	@optimizeLogFiles = 1
	--	----------------------------------------------------------------------------
	IF	@optimizeLogFiles = 1
	BEGIN
		IF @verbose = 1
			PRINT	'
/*	******************** Begin:	@optimizeLogFiles = 1 *****************************/';

		

		IF @verbose = 1
			PRINT	'/*	******************** End:	@optimizeLogFiles = 1 *****************************/
';
	END -- End block of @optimizeLogFiles = 1
	--	----------------------------------------------------------------------------
		--	End:	@optimizeLogFiles = 1
	--	============================================================================

	--	============================================================================
		--	Begin:	@testAllOptions = 1
	--	----------------------------------------------------------------------------
	IF	@testAllOptions = 1
	BEGIN
		PRINT	'/*	Executing 
					EXEC tempdb..[usp_AnalyzeSpaceCapacity] 
	*/';
			WAITFOR DELAY '00:01';

		PRINT	'/*	Executing 
					EXEC tempdb..[usp_AnalyzeSpaceCapacity] @help = 1
	*/';
		EXEC tempdb..[usp_AnalyzeSpaceCapacity] @help = 1
			WAITFOR DELAY '00:01';

		PRINT	'/*	Executing 
					EXEC [dbo].[usp_AnalyzeSpaceCapacity] @getLogInfo = 1
	*/';
		EXEC tempdb.[dbo].[usp_AnalyzeSpaceCapacity] @getLogInfo = 1
			WAITFOR DELAY '00:01';

		PRINT	'/*	Executing 
					EXEC [dbo].[usp_AnalyzeSpaceCapacity] @addDataFiles = 1 ,@newVolume = ''E:\Data1\'' ,@oldVolume = ''E:\Data\''
	*/';
		EXEC tempdb.[dbo].[usp_AnalyzeSpaceCapacity] @addDataFiles = 1 ,@newVolume = 'E:\Data1\' ,@oldVolume = 'E:\Data\'
			WAITFOR DELAY '00:01';

		PRINT	'/*	Executing 
					EXEC [dbo].[usp_AnalyzeSpaceCapacity] @restrictDataFileGrowth = 1 ,@oldVolume = ''E:\Data\''
	*/';
		EXEC tempdb.[dbo].[usp_AnalyzeSpaceCapacity] @restrictDataFileGrowth = 1 ,@oldVolume = 'E:\Data\'
			WAITFOR DELAY '00:01';

		PRINT	'/*	Executing 
					EXEC [dbo].[usp_AnalyzeSpaceCapacity] @addLogFiles = 1 ,@newVolume = ''E:\Logs1\'' ,@oldVolume = ''E:\Logs\''
	*/';
		EXEC tempdb.[dbo].[usp_AnalyzeSpaceCapacity] @addLogFiles = 1 ,@newVolume = 'E:\Logs1\' ,@oldVolume = 'E:\Logs\'
			WAITFOR DELAY '00:01';

		PRINT	'/*	Executing 
					EXEC [dbo].[usp_AnalyzeSpaceCapacity] @restrictLogFileGrowth = 1 ,@oldVolume = ''E:\Logs\''
	*/';
		EXEC tempdb.[dbo].[usp_AnalyzeSpaceCapacity] @restrictLogFileGrowth = 1 ,@oldVolume = 'E:\Logs\'
			WAITFOR DELAY '00:01';

		PRINT	'/*	Executing 
					EXEC [dbo].[usp_AnalyzeSpaceCapacity] @unrestrictFileGrowth = 1, @oldVolume = ''E:\Data\''
	*/';
		EXEC tempdb.[dbo].[usp_AnalyzeSpaceCapacity] @unrestrictFileGrowth = 1, @oldVolume = 'E:\Data\'
			WAITFOR DELAY '00:01';

		PRINT	'/*	Executing 
					EXEC [dbo].[usp_AnalyzeSpaceCapacity] @generateCapacityException = 1, @oldVolume = ''E:\Data\''
	*/';
		EXEC tempdb.[dbo].[usp_AnalyzeSpaceCapacity] @generateCapacityException = 1, @oldVolume = 'E:\Data\'
			WAITFOR DELAY '00:01';

		PRINT	'/*	Executing 
					EXEC [dbo].[usp_AnalyzeSpaceCapacity] @UpdateMountPointSecurity = 1
	*/';
		EXEC tempdb.[dbo].[usp_AnalyzeSpaceCapacity] @UpdateMountPointSecurity = 1
			WAITFOR DELAY '00:01';

		PRINT	'/*	Executing 
					EXEC [dbo].[usp_AnalyzeSpaceCapacity] @restrictMountPointGrowth = 1, @oldVolume = ''E:\Data\'', @mountPointGrowthRestrictionPercent = 95
	*/';
		EXEC tempdb.[dbo].[usp_AnalyzeSpaceCapacity] @restrictMountPointGrowth = 1, @oldVolume = 'E:\Data\', @mountPointGrowthRestrictionPercent = 95
			WAITFOR DELAY '00:01';

		PRINT	'/*	Executing 
					EXEC [dbo].[usp_AnalyzeSpaceCapacity] @restrictMountPointGrowth = 1, @oldVolume = ''E:\Data\'', @mountPointGrowthRestrictionPercent = 70
	*/';
		EXEC tempdb.[dbo].[usp_AnalyzeSpaceCapacity] @restrictMountPointGrowth = 1, @oldVolume = 'E:\Data\', @mountPointGrowthRestrictionPercent = 70
			WAITFOR DELAY '00:01';

		PRINT	'/*	Executing 
					EXEC [dbo].[usp_AnalyzeSpaceCapacity] @expandTempDBSize = 1, @tempDBMountPointPercent = 89
	*/';
		EXEC tempdb.[dbo].[usp_AnalyzeSpaceCapacity] @expandTempDBSize = 1, @tempDBMountPointPercent = 89
			WAITFOR DELAY '00:01';

	END -- End block of @testAllOptions = 1
	--	----------------------------------------------------------------------------
		--	End:	@testAllOptions = 1
	--	============================================================================
	--	Sample Error
	--SELECT 1/0 as [Divide By Zero];
	END TRY
	BEGIN CATCH
		IF @verbose=1
			PRINT	'*** Inside Outer Catch Block ***';
	
		-- If we are inside Catch block, that means something went wrong.
		IF @_errorOccurred = 0
			SET @_errorOccurred = 1;

		--	If some select/update tsql statement failed, it will be called compilation error
		INSERT #ErrorMessages
			SELECT	CASE WHEN PATINDEX('%has free space more than%',ERROR_MESSAGE()) > 0
						THEN 'Reconsider Space Threshold'
						WHEN PATINDEX('%Kindly restrict the data/log files on @oldVolume before using @generateCapacityException option.%',ERROR_MESSAGE()) > 0
						THEN 'Files Growth Yet to be Restricted'
						WHEN ERROR_MESSAGE() = 'Volume configuration is not per standard. Kindly perform the activity manually.'
						THEN 'Not Supported'
						WHEN ERROR_MESSAGE() = 'Backup job is running. So kindly create/restrict files later.'
						THEN 'Backup Job is running.'
						WHEN CHARINDEX('@',ERROR_MESSAGE()) > 0
						THEN 'Improper Parameter'
						ELSE 'Compilation Error'
						END 
								AS ErrorCategory
					,NULL AS DBName 
					,NULL AS [FileName] 
					,ERROR_MESSAGE() AS ErrorDetails 
					,NULL AS TSQLCode;
	END CATCH

	-- Print the #ErrorMessages table data
	IF @_errorOccurred = 1
	BEGIN
		SELECT * FROM #ErrorMessages;
		IF @verbose=1
			PRINT	'Returing #ErrorMessages table data';
	END
	RETURN @_errorOccurred; -- 1 = Error, 0 = Success

END -- End Procedure