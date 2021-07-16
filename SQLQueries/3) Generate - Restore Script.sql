/*	Created By:		AJAY DWIVEDI
	Created Date:	NOV 22, 2014
	Purpose:		Script out Restore DB on Target
	Total Input:	3
*/
SET NOCOUNT ON;

--Variable for finding .bak files
DECLARE
       @BasePath varchar(1000)
      ,@Path varchar(1000)
      ,@FullPath varchar(2000)
      ,@Id int
      ,@RowCount int;

--1) specify database backup directory
SET @BasePath = 'G:\Backup\';

--2) Overwrite DB ( 1=TRUE   OR   0=FALSE  )
DECLARE	@do_overwrite_db TINYINT
SET		@do_overwrite_db = 0

--3) NORECOVERY Mode (1=TRUE   OR   0=FALSE  )
DECLARE	@with_NORECOVERY TINYINT
SET		@with_NORECOVERY = 0

DECLARE	@Target_Data_Path NVARCHAR (250),
		@Target_Log_Path NVARCHAR (250)

PRINT '/* Please ignore this message ';
--Queries to find Data & Log files path  /* SELECT name, filename FROM master.sys.sysaltfiles */
DECLARE @DefaultLog nvarchar(512)
EXEC master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'DefaultLog', @DefaultLog output

DECLARE @MasterData nvarchar(512)
EXEC master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer\Parameters', N'SqlArg0', @MasterData output
SELECT @MasterData=substring(@MasterData, 3, 255)
SELECT @MasterData=substring(@MasterData, 1, len(@MasterData) - charindex('\', reverse(@MasterData)))

SELECT	@Target_Data_Path = COALESCE(CONVERT(NVARCHAR(250),SERVERPROPERTY('instancedefaultdatapath')), @MasterData+'\', '<Data File Location>')
		,@Target_Log_Path = COALESCE(CONVERT(NVARCHAR(250),SERVERPROPERTY('instancedefaultlogpath')), @DefaultLog+'\', '<Log File Location>') 
PRINT '
*/ ';

-- Variables for Scripting out restore script
DECLARE @db_name NVARCHAR(100)
		,@DatabaseFileId TINYINT
		,@LogicalName NVARCHAR(150)
		,@DatabaseFileType VARCHAR(2)
		,@Maiden_File_Name NVARCHAR(100)
		,@PhysicalName NVARCHAR(150)
		,@SQLString NVARCHAR(max)
		,@DataLogFileCount TINYINT
		,@DataLogFileCounter TINYINT
		,@FileCount TINYINT
		,@FileCounter TINYINT
		,@BackupFile VARCHAR(2000)
		,@DatabaseFile VARCHAR(2000);

DECLARE @DirectoryTree TABLE
(
       id int IDENTITY(1,1)
      ,fullpath varchar(2000)
      ,subdirectory nvarchar(512)
      ,depth int
      ,isfile bit
);

DECLARE @BackupFileList TABLE( id int IDENTITY(1,1), BackupFile VARCHAR(2000) );

CREATE TABLE #headers
( BackupName varchar(256), BackupDescription varchar(256), BackupType varchar(256), 
ExpirationDate varchar(256), Compressed varchar(256), Position varchar(256), DeviceType varchar(256), 
UserName varchar(256), ServerName varchar(256), DatabaseName varchar(256), DatabaseVersion varchar(256), 
DatabaseCreationDate varchar(256), BackupSize varchar(256), FirstLSN varchar(256), LastLSN varchar(256), 
CheckpointLSN varchar(256), DatabaseBackupLSN varchar(256), BackupStartDate varchar(256), BackupFinishDate varchar(256), 
SortOrder varchar(256), CodePage varchar(256), UnicodeLocaleId varchar(256), UnicodeComparisonStyle varchar(256), 
CompatibilityLevel varchar(256), SoftwareVendorId varchar(256), SoftwareVersionMajor varchar(256), 
SoftwareVersionMinor varchar(256), SoftwareVersionBuild varchar(256), MachineName varchar(256), Flags varchar(256), 
BindingID varchar(256), RecoveryForkID varchar(256), Collation varchar(256), FamilyGUID varchar(256), 
HasBulkLoggedData varchar(256), IsSnapshot varchar(256), IsReadOnly varchar(256), IsSingleUser varchar(256), 
HasBackupChecksums varchar(256), IsDamaged varchar(256), BeginsLogChain varchar(256), HasIncompleteMetaData varchar(256), 
IsForceOffline varchar(256), IsCopyOnly varchar(256), FirstRecoveryForkID varchar(256), ForkPointLSN varchar(256), 
RecoveryModel varchar(256), DifferentialBaseLSN varchar(256), DifferentialBaseGUID varchar(256), 
BackupTypeDescription varchar(256), BackupSetGUID varchar(256), CompressedBackupSize varchar(256), 
Containment varchar(256) ); 

-- Drop Containment column from #headers for SQL Server 2008 R2
IF (SELECT CONVERT(VARCHAR(50),SERVERPROPERTY('productversion'))) LIKE '10.50.%'
BEGIN
	ALTER TABLE #headers
		DROP COLUMN Containment;
END

DECLARE @Backup_File_Details table
(
    LogicalName          nvarchar(128),
    PhysicalName         nvarchar(260),
    [Type]               char(1),
    FileGroupName        nvarchar(128),
    Size                 numeric(20,0),
    MaxSize              numeric(20,0),
    FileID               bigint,
    CreateLSN            numeric(25,0),
    DropLSN              numeric(25,0),
    UniqueID             uniqueidentifier,
    ReadOnlyLSN          numeric(25,0),
    ReadWriteLSN         numeric(25,0),
    BackupSizeInBytes    bigint,
    SourceBlockSize      int,
    FileGroupID          int,
    LogGroupGUID         uniqueidentifier,
    DifferentialBaseLSN  numeric(25,0),
    DifferentialBaseGUID uniqueidentifier,
    IsReadOnl            bit,
    IsPresent            bit,
    TDEThumbprint        varbinary(32) -- remove this column if using SQL 2005
)

--Populate the table using the initial base path.
INSERT @DirectoryTree (subdirectory,depth,isfile) EXEC master.sys.xp_dirtree @BasePath,1,1;

UPDATE @DirectoryTree SET fullpath = @BasePath + '\' + subdirectory;
INSERT INTO @BackupFileList SELECT fullpath FROM @DirectoryTree WHERE isfile = 1;
DELETE FROM @DirectoryTree WHERE isfile = 1;

--Loop through the table as long as there are still folders to process.
WHILE EXISTS (SELECT id FROM @DirectoryTree WHERE isfile = 0)
BEGIN

	SELECT TOP (1) @Id = id, @BasePath = fullpath FROM @DirectoryTree WHERE isfile = 0;
	
	SET NOCOUNT ON;
	INSERT @DirectoryTree (subdirectory,depth,isfile) EXEC master.sys.xp_dirtree @BasePath,1,1;
	SET @RowCount = @@ROWCOUNT ;
	
	IF @RowCount <> 0
		UPDATE @DirectoryTree SET fullpath = @BasePath + '\' + subdirectory WHERE id = @@IDENTITY;
	ELSE
		PRINT 'NOTE: Backup missing on path = '+@BasePath;
	
	--Delete the processed folder.
    DELETE FROM @DirectoryTree WHERE id = @Id;
END;

--Prepare Final list of .bak Files from Base Path
INSERT INTO @BackupFileList SELECT fullpath FROM @DirectoryTree WHERE isfile = 1;
--SELECT * from @BackupFileList;

--*****************************************************************************************
--*****************************************************************************************
--*****************************************************************************************

--Loop through each Backup File
DECLARE BackupFile_cursor CURSOR FOR 
	SELECT ROW_NUMBER()OVER(ORDER BY BackupFile) AS id, BackupFile FROM @BackupFileList ORDER BY BackupFile;

OPEN BackupFile_cursor
FETCH NEXT FROM BackupFile_cursor INTO @id, @BackupFile;

WHILE @@FETCH_STATUS = 0 
BEGIN
	BEGIN TRY
	--Get Header info. One row per .bak file
	INSERT INTO #headers
	EXEC ('restore headeronly from disk = '''+ @BackupFile + '''');
	
	SELECT @db_name = DatabaseName FROM #headers;

	--Get Data & Log Files. Two or more rows per .bak file
	INSERT INTO @Backup_File_Details
	EXEC ('restore filelistonly from disk = '''+ @BackupFile + '''');

	SET	@DataLogFileCount = (SELECT COUNT(1) AS COUNTS FROM @Backup_File_Details);
	SET @DataLogFileCounter = 1;

	SET @SQLString =  '
--	'+CAST(@id AS VARCHAR(3))+') ['+ @db_name +']
restore database ['+ @db_name +'] from disk ='''+@BackupFile+ '''
with ';

	WHILE (@DataLogFileCounter <= @DataLogFileCount)
	BEGIN
	
		SELECT	@LogicalName = LogicalName 
				,@PhysicalName = RIGHT(physicalname,CHARINDEX('\',REVERSE(physicalname))-1)
				,@DatabaseFileType = Type
				,@DatabaseFileId = FileId
		FROM @Backup_File_Details WHERE FileId = @DataLogFileCounter;
	
		if(@DatabaseFileType='D')
		SET @SQLString =  @SQLString + 
			'move '''+ @LogicalName +''' to ''' + @Target_Data_Path + @PhysicalName +''',
	 ';
		if(@DatabaseFileType='L')
			SET @SQLString =  @SQLString + 
			'move '''+ @LogicalName +''' to ''' + @Target_Log_Path + @PhysicalName +''',
	 ';

		SET @DataLogFileCounter = @DataLogFileCounter + 1;
	END;

	if (@do_overwrite_db<>0)
		SET @SQLString =  @SQLString + 'replace ,';
	if (@with_NORECOVERY<>0)
		SET @SQLString = @SQLString + 'NORECOVERY ,';
	SET @SQLString =  @SQLString + 'STATS = 10
GO

'  ;

	PRINT	@SQLString;
	DELETE FROM @Backup_File_Details;
	DELETE FROM #headers;
	
	END TRY
	BEGIN CATCH
		PRINT	'--	'+CAST(@id AS VARCHAR(3))+')
Error Occurred with Message: '+ ERROR_MESSAGE();
		IF (ERROR_MESSAGE()='RESTORE HEADERONLY is terminating abnormally.')
		PRINT'HINT:	Kindly check if backup path "'+@BackupFile + '" exists

';
		ELSE
		IF (ERROR_MESSAGE()='RESTORE FILELIST is terminating abnormally.')
		PRINT'HINT:	Backup File "'+@BackupFile + '" belongs to higher version of SQL Server

';

	END CATCH

FETCH NEXT FROM BackupFile_cursor INTO @id, @BackupFile;
END

CLOSE BackupFile_cursor 
DEALLOCATE BackupFile_cursor 
DROP TABLE #headers;
--*****************************************************************************************
--*****************************************************************************************
--*****************************************************************************************