Function Get-DatabaseRestoreScript3
{
<#
.SYNOPSIS
    Script out TSQL RESTORE code for databases during Database Restore Activity
.DESCRIPTION
    This function accepts backup path, data and log directory for restore operation on destination sql instance, and create RESTORE script for database restore/migration activity.
    It can be used for performing database restore operation with latest available backups on BackupPath.
    Can be used to restore database for Point In Time.
    Can be used for restoring database with new name on Destination SQL Instance.
.PARAMETER BackupPath
    The directory or path where database backups are kept. It can find backup files even under child folders. Say, we provide BackupPth  = 'E:\Backups', and backups for [Test] database are under 'E:\Backups\Test' folder. So the function can consider even child items as well.
.PARAMETER RestoreCategory
    Based on selected RestoreCategory, this function can generated TSQL Restore code for either for latest application Full, Diff & TLog, or only for either Full or Diff. This function only provides functionality of Point In Time database restore.
.PARAMETER StopAtTime
    Provide this parameter value when RestoreCategory of 'PointInTime' is selected. The parameter value accepts datetime value in format 'yyyy-MM-dd hh:mm:ss'.
.PARAMETER Destination_SQLInstance
    Instance name of target sql server instance. For example SQL-A\sql2012 instance
.PARAMETER ExecuteDirectly_DonotScriptout
    With this switch, the created TSQL Restore code is directly executed against Destination_SQLInstance.
.PARAMETER Overwrite
    With this switch, the TSQL RESTORE code generated will be generated with REPLACE option.
.PARAMETER ScanBackupsOnDisk
    With this swtich, backups from local disk are prefe
.PARAMETER NoRecovery
    With this switch, the TSQL RESTORE code generated will be generated with NORECOVERY option.
.PARAMETER DestinationPath_Data
    Parameter to accept Data files path or directory on target/destination SQL Server Instance.
.PARAMETER DestinationPath_Log
    Parameter to accept Log files path or directory on target/destination SQL Server Instance.
.PARAMETER SourceDatabase
    Accepts multiple database names separated by comma (,). Should not be used when RESTORE script is to be generated for all databases.
    When database names specified here, then RESTORE tsql code is generated only for those database.
    When used with '-Skip_Databases' switch, then the RESTORE script is NOT generated for databases mentioned.
    Accepts single database name when used with parameter '-RestoreAs'.
.PARAMETER RestoreAs
    Accepts new name for single database when '-SourceDatabase' it has to be restored as new New on Destination SQL Instance.
.EXAMPLE
    C:\PS> Script-SQLDatabaseRestore -BackupPath \\SQLBackups\ProdSrv01 -Destination_SQLInstance ProdSrv02 -DestinationPath_Data F:\mssqldata\Data -DestinationPath_Log E:\Mssqldata\Log -RestoreCategory LatestAvailable
    Generates RESTORE tsql code for all database with latest Full/Diff/TLog backups from path '\\SQLBackups\ProdSrv01'.
.EXAMPLE
    C:\PS> Script-SQLDatabaseRestore -BackupPath \\SQLBackups\ProdSrv01 -Destination_SQLInstance ProdSrv02 -DestinationPath_Data F:\mssqldata\Data -DestinationPath_Log E:\Mssqldata\Log -RestoreCategory LatestAvailable -SourceDatabase Cosmo,DBA
    Generates RESTORE tsql code for [Cosmo] and [DBA] databases with latest Full/Diff/TLog backup from path '\\SQLBackups\ProdSrv01'.
.EXAMPLE
    C:\PS> Script-SQLDatabaseRestore -BackupPath \\SQLBackups\ProdSrv01 -Destination_SQLInstance ProdSrv02 -DestinationPath_Data F:\mssqldata\Data -DestinationPath_Log E:\Mssqldata\Log -RestoreCategory LatestAvailable -Skip_Databases -SourceDatabase Cosmo, DBA
    Generates RESTORE tsql code for all database except [Cosmo] and [DBA] with latest Full/Diff/TLog backups from path '\\SQLBackups\ProdSrv01'.
.EXAMPLE
    C:\PS> Script-SQLDatabaseRestore -BackupPath \\SQLBackups\ProdSrv01 -Destination_SQLInstance ProdSrv02 -DestinationPath_Data F:\mssqldata\Data -DestinationPath_Log E:\Mssqldata\Log -RestoreAs Cosmo_Temp -RestoreCategory LatestAvailable -SourceDatabase Cosmo
    Generates RESTORE tsql code for [Cosmo] database to be restored as [Cosmo_Temp] on destination with latest Full/Diff/TLog backup from path '\\SQLBackups\ProdSrv01'.
.EXAMPLE
    C:\PS> Script-SQLDatabaseRestore -BackupPath \\SQLBackups\ProdSrv01 -Destination_SQLInstance ProdSrv02 -DestinationPath_Data F:\mssqldata\Data -DestinationPath_Log E:\Mssqldata\Log -RestoreCategory LatestAvailable -SourceDatabase Cosmo, DBA -StopAtTime "2018-04-12 23:15:00"
   Generates RESTORE tsql code for [Cosmo] and [DBA] databases upto time '2018-04-12 23:15:00' using Full/Diff/TLog backups from path '\\SQLBackups\ProdSrv01'.
.LINK
    https://github.com/imajaydwivedi/SQLDBATools
    https://www.mssqltips.com/sqlservertip/3209/understanding-sql-server-log-sequence-numbers-for-backups/
    https://youtu.be/v4r2lhIFii4
.NOTES
    Author: Ajay Dwivedi
    EMail:  ajay.dwivedi2007@gmail.com
    Date:   June 28, 2010 
    Documentation: https://github.com/imajaydwivedi/SQLDBATools   
#>
    [CmdletBinding()]
    Param
    (
        [Parameter( Mandatory=$true )]
        [ValidateNotNullOrEmpty()]
        [Alias('Target_SQLInstance','SQLInstance_Destination')]
        [String]$Destination_SQLInstance = (Read-Host "Provide Destination SQL Instance name: "),

        [Parameter( Mandatory=$true )]
        [Alias('SQLInstance_Source')]
        [String]$Source_SQLInstance = (Read-Host "Provide Source SQL Instance name: "),

        [parameter( Mandatory=$false)]
        [Alias('ConsiderBackupsOnDisk')]
        [Switch]$ScanBackupsOnDisk,

        [Parameter( Mandatory=$true )]
        [ValidateNotNullOrEmpty()]
        [Alias('PathOfBackups')]
        [String]$BackupPath,

        [Parameter( Mandatory=$true,
                    ParameterSetName="FromBackupHistory")]
        [Parameter( Mandatory=$true,
                    ParameterSetName="RestoreAs_BackupFromHistory" )]
        [Alias('SQLInstance_Source')]
        [String]$Source_SQLInstance,

        [Parameter( Mandatory=$true )]
        [ValidateSet("LatestAvailable", "LatestFullOnly", "LatestFullAndDiffOnly","PointInTime")]
        [String]$RestoreCategory = "LatestAvailable",

        [Parameter( Mandatory=$false, HelpMessage="Enter DateTime in 24 hours format (yyyy-MM-dd hh:mm:ss)")]
        [String]$StopAtTime = $null,

        
        
        [Parameter( Mandatory=$false,
                    ParameterSetName="RestoreAs_BackupFromPath" )]
        [Parameter( Mandatory=$false,
                    ParameterSetName="RestoreAs_BackupFromHistory" )]
        [Alias('DirectlyExecute')]
        [Switch]$ExecuteDirectly_DonotScriptout,

        [parameter( Mandatory=$false)]
        [Alias('Replace')]
        [Switch]$Overwrite,

        [parameter( Mandatory=$false)]
        [Switch]$NoRecovery,

        [Parameter( Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias('Destination_Data_Path','Data_Path_Destination')]
        [String]$DestinationPath_Data,

        [Parameter( Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias('Destination_Log_Path','Log_Path_Destination')]
        [String]$DestinationPath_Log,

        [Parameter( Mandatory=$false,
                    ParameterSetName="BackupsFromPath")]
        [Parameter( Mandatory=$true,
                    ParameterSetName="RestoreAs_BackupFromPath" )]
        [Parameter( Mandatory=$false,
                    ParameterSetName="FromBackupHistory")]
        [Parameter( Mandatory=$true,
                    ParameterSetName="RestoreAs_BackupFromHistory" )]
        [Alias('SourceDatabasesToRestore')]
        [String[]]$SourceDatabase,

        [Parameter( Mandatory=$false,
                    ParameterSetName="BackupsFromPath")]
        [Parameter( Mandatory=$false,
                    ParameterSetName="FromBackupHistory")]
        [Switch]$Skip_Databases,

        [Parameter( Mandatory=$true,
                    ParameterSetName="RestoreAs_BackupFromPath" )]
        [Parameter( Mandatory=$true,
                    ParameterSetName="RestoreAs_BackupFromHistory" )]
        [Alias('DestinationDatabase_NewName')]
        [String]$RestoreAs
    )

    
    # Create File for storing result
    $ResultFile = "C:\temp\RestoreDatabaseScripts_$(Get-Date -Format ddMMMyyyyTHHmm).sql";
    
    if ([string]::IsNullOrEmpty($StopAtTime) -eq $false) 
    {
        # StopAt in String format
        try 
        {   
            Write-Verbose "`$StopAtTime = '$StopAtTime'";

            $format = "yyyy-MM-dd HH:mm:ss";
            Write-Verbose "`$format = '$format'";

            $StopAt_Time = [DateTime]::ParseExact($StopAtTime, $format, $null);
            Write-Verbose "`$StopAt_Time = '$StopAt_Time'";

            $StopAt_String = ($StopAt_Time).ToString('MMM dd, yyyy hh:mm:ss tt');
            Write-Verbose "`$StopAt_String = '$StopAt_String'";
        }
        catch 
        {
            Write-Error "Invalid datetime format specified for `$StopAt_Time parameter. Kindly use format:  (yyyy-MM-dd hh:mm:ss)";
            return;
        }
    }
    
    if ([string]::IsNullOrEmpty($StopAtTime) -eq $false -and $RestoreCategory -ne 'PointInTime')
    {
        Write-Error "Value for `$StopAtTime parameter is not required since `$RestoreCategory is not equal to 'PointInTime'";
        return;
    }
    
    if ($RestoreCategory -eq 'PointInTime' -and [string]::IsNullOrEmpty($StopAtTime) -eq $true)
    {
        Write-Error "Value for `$StopAtTime parameter is Mandatory for `$RestoreCategory = 'PointInTime'";
        return;
    }
    
    # Add blackslash '\' at the end of path
    if ($DestinationPath_Data.EndsWith('\') -eq $false) {
        $DestinationPath_Data += '\';
    }
    if ($DestinationPath_Log.EndsWith('\') -eq $false) {
        $DestinationPath_Log += '\';
    }

    # Final Query to execute against Destination
    $fileHeaders = @();
   
    # Check if backups is to be searched from BackupPath/BackupHistory
    if (([String]::IsNullOrEmpty($BackupPath)) -eq $false)
    {
        Write-Verbose "Value for `$BackupPath parameter is provided. Checking its validity";
        if ( (Test-Path -Path $BackupPath) -eq $false )
        {
            Write-Error "`$BackupPath value '$BackupPath' is invalid. Pls check again.";
            return;
        }

        Write-Verbose "Finding all files from path:- $BackupPath";
        $files = @(Get-ChildItem -Path $BackupPath -File -Recurse | Select-Object -ExpandProperty FullName);

        Write-Verbose "Reading Header of all the backup files found.";
        foreach ($bkpFile in $files)
        {
            $header = (Invoke-Sqlcmd -ServerInstance $Destination_SQLInstance -Query "restore headeronly from disk = '$bkpFile'");
            if($header.BackupTypeDescription -eq 'Database')
            {
                $IsBaseBackupAvailable = $true;
                if ($header.IsCopyOnly -eq 0)
                {
                    $IsValidForPointInTimeRecovery = $true;
                }
                else
                {
                    $IsValidForPointInTimeRecovery = $false;
                }
            }
            else
            {
                $IsBaseBackupAvailable = $false; 
                $IsValidForPointInTimeRecovery = $true;
            }

            $headerInfo = [Ordered]@{
                                    'BackupFile' = $bkpFile;
                                    'BackupTypeDescription' = $header.BackupTypeDescription;
                                    'ServerName' = $header.ServerName;
                                    'UserName' = $header.UserName;
                                    'DatabaseName' = $header.DatabaseName;
                                    'DatabaseCreationDate' = $header.DatabaseCreationDate;
                                    'BackupSize' = $header.BackupSize;
                                    'FirstLSN' = $header.FirstLSN;
                                    'LastLSN' = $header.LastLSN;
                                    'CheckpointLSN' = $header.CheckpointLSN;
                                    'DatabaseBackupLSN' = $header.DatabaseBackupLSN;
                                    'BackupStartDate' = $header.BackupStartDate;
                                    'BackupFinishDate' = $header.BackupFinishDate;
                                    'CompatibilityLevel' = $header.CompatibilityLevel;
                                    'Collation' = $header.Collation;
                                    'IsCopyOnly' = $header.IsCopyOnly;
                                    'RecoveryModel' = $header.RecoveryModel;
                                    'NextDiffBackupFile' = $null;
                                    'NextTLogBackupFile' = $null;
                                    'IsValidForPointInTimeRecovery' = $IsValidForPointInTimeRecovery;
                                    'FilePresentOnDisk' = $true;
                                   }
            $obj = New-Object -TypeName psobject -Property $headerInfo;
            $fileHeaders += $obj;
        }        
    }
    else #     Find backups from Backup History
    {
        Write-Host "Trying to read Backup History.";
        if($SourceDatabase.Count -gt 0)
        {            
            $SourceDatabase_CommaSeparated = "'"+($SourceDatabase -join "','")+"'";
            Write-Verbose "`$SourceDatabase_CommaSeparated = $SourceDatabase_CommaSeparated";
        }


        # Find databases whose backup history is available
        $query_databasesFromBackupHistory = @"
SET NOCOUNT ON;
DECLARE @dbName VARCHAR(125),
		@backupStartDate datetime,
		@stopAtTime datetime;
DECLARE @SQLString nvarchar(2000);  
DECLARE @ParmDefinition nvarchar(500); 

IF OBJECT_ID('tempdb..#BackupHistory') IS NOT NULL
	DROP TABLE #BackupHistory;
CREATE TABLE #BackupHistory
(
	[BackupFile] [nvarchar](260) NULL,
	[BackupTypeDescription] [varchar](21) NULL,
	[ServerName] [char](100) NULL,
	[UserName] [nvarchar](128) NULL,
	[DatabaseName] [nvarchar](128) NULL,
	[DatabaseCreationDate] [datetime] NULL,
	[BackupSize] [numeric](20, 0) NULL,
	[FirstLSN] [numeric](25, 0) NULL,
	[LastLSN] [numeric](25, 0) NULL,
	[CheckpointLSN] [numeric](25, 0) NULL,
	[DatabaseBackupLSN] [numeric](25, 0) NULL,
	[BackupStartDate] [datetime] NULL,
	[BackupFinishDate] [datetime] NULL,
	[CompatibilityLevel] [tinyint] NULL,
	[Collation] [nvarchar](128) NULL,
	[IsCopyOnly] [bit] NULL,
	[RecoveryModel] [nvarchar](60) NULL
) ;

/* Build the SQL string to get all latest backups for database. */  
SET @SQLString =  
     N'SELECT	BackupFile = bmf.physical_device_name,
		CASE bs.type WHEN ''D'' THEN ''Database'' WHEN ''I'' THEN ''Differential database'' WHEN ''L'' THEN ''Log'' ELSE NULL END as BackupTypeDescription,
		LTRIM(RTRIM(CAST(SERVERPROPERTY(''ServerName'') AS VARCHAR(125)))) as ServerName,
		UserName = bs.user_name,
		bs.database_name,
		DatabaseCreationDate = bs.database_creation_date,
		BackupSize = bs.backup_size,
		FirstLSN = bs.first_lsn, 
		LastLSN = bs.last_lsn, 
		CheckpointLSN = bs.checkpoint_lsn,
		DatabaseBackupLSN = bs.database_backup_lsn,
		BackupStartDate = bs.backup_start_date,
		BackupFinishDate = bs.backup_finish_date,
		CompatibilityLevel = bs.compatibility_level,
		Collation = bs.collation_name,
		IsCopyOnly = bs.is_copy_only,
		RecoveryModel = bs.recovery_model
FROM	msdb.dbo.backupmediafamily AS bmf
INNER JOIN msdb.dbo.backupset AS bs ON bmf.media_set_id = bs.media_set_id
WHERE	database_name = @q_dbName
AND		bs.backup_start_date >= @q_backupStartDate';  

SET @ParmDefinition = N'@q_dbName varchar(125), @q_backupStartDate datetime2'; 
  
DECLARE databases_cursor CURSOR LOCAL FORWARD_ONLY FOR 
		--	Find latest Full backup for each database
		SELECT MAX(bs.backup_start_date) AS Latest_FullBackupDate, database_name
		FROM msdb.dbo.backupmediafamily AS bmf INNER JOIN msdb.dbo.backupset AS bs 
		ON bmf.media_set_id = bs.media_set_id WHERE bs.type='D' and is_copy_only = 0
        $( if($RestoreCategory -eq 'PointInTime'){ "AND bs.backup_start_date <= '$StopAtTime'"} )
        $( if($SourceDatabase.Count -gt 0){ if($Skip_Databases){"AND database_name NOT IN ($SourceDatabase_CommaSeparated)"}else{"AND database_name IN ($SourceDatabase_CommaSeparated)"} } )
		GROUP BY database_name;

OPEN databases_cursor
FETCH NEXT FROM databases_cursor INTO @backupStartDate, @dbName;

WHILE @@FETCH_STATUS = 0 
BEGIN
	BEGIN TRY
		--	Find latest backups
		INSERT #BackupHistory
		EXECUTE sp_executesql @SQLString, @ParmDefinition,  
							  @q_dbName = @dbName,
							  @q_backupStartDate = @backupStartDate; 
	END TRY
	BEGIN CATCH
		PRINT ' -- ---------------------------------------------------------';
		PRINT ERROR_MESSAGE();
		PRINT ' -- ---------------------------------------------------------';
	END CATCH
		
	FETCH NEXT FROM databases_cursor INTO @backupStartDate, @dbName;
END

CLOSE databases_cursor;
DEALLOCATE databases_cursor ;

SELECT * FROM #BackupHistory;
"@;

        $databasesFromBackupHistory = Invoke-Sqlcmd -ServerInstance $Source_SQLInstance -Query $query_databasesFromBackupHistory;
        $nodes = @(Invoke-Sqlcmd -ServerInstance $Source_SQLInstance -Query 'SELECT NodeName FROM sys.dm_os_cluster_nodes;' | Select-Object -ExpandProperty NodeName);
        
        foreach ($header in $databasesFromBackupHistory)
        {
            if($header.BackupTypeDescription -eq 'Database')
            {
                $IsBaseBackupAvailable = $true;
                if ($header.IsCopyOnly -eq 1)
                {
                    $IsValidForPointInTimeRecovery = $false;
                }
                else
                {
                    $IsValidForPointInTimeRecovery = $true;
                }
            }
            else
            {
                $IsBaseBackupAvailable = $false; 
                $IsValidForPointInTimeRecovery = $true;
            }

            # Check if backupFile is connecting
            $bkpFile = $header.BackupFile;

            if( ([System.IO.File]::Exists($bkpFile)) -eq $false  -and $bkpFile -like "*:*")
            {
                Write-Verbose "   Trying to find network path for backup file  $bkpFile";
                $n = "\\$($header.ServerName)\"+($bkpFile -replace ":","$");
                if ([System.IO.File]::Exists($n)) { $bkpFile = $n; }
                elseif ($nodes.Count -gt 0)
                {
                    foreach($node in $nodes)
                    {
                        $n = "\\$node\"+($bkpFile -replace ":","$");
                        if ([System.IO.File]::Exists($n)) { $bkpFile = $n; break; }
                    }
                }
            }

            if ([System.IO.File]::Exists($bkpFile)) { $FilePresentOnDisk = $true; } else {$FilePresentOnDisk = $false;}

            $headerInfo = [Ordered]@{
                                    'BackupFile' = $bkpFile;
                                    'BackupTypeDescription' = $header.BackupTypeDescription;
                                    'ServerName' = $header.ServerName;
                                    'UserName' = $header.UserName;
                                    'DatabaseName' = $header.DatabaseName;
                                    'DatabaseCreationDate' = $header.DatabaseCreationDate;
                                    'BackupSize' = $header.BackupSize;
                                    'FirstLSN' = $header.FirstLSN;
                                    'LastLSN' = $header.LastLSN;
                                    'CheckpointLSN' = $header.CheckpointLSN;
                                    'DatabaseBackupLSN' = $header.DatabaseBackupLSN;
                                    'BackupStartDate' = $header.BackupStartDate;
                                    'BackupFinishDate' = $header.BackupFinishDate;
                                    'CompatibilityLevel' = $header.CompatibilityLevel;
                                    'Collation' = $header.Collation;
                                    'IsCopyOnly' = $header.IsCopyOnly;
                                    'RecoveryModel' = $header.RecoveryModel;
                                    'NextDiffBackupFile' = $null;
                                    'NextTLogBackupFile' = $null;
                                    'IsValidForPointInTimeRecovery' = $IsValidForPointInTimeRecovery;
                                    'FilePresentOnDisk' = $FilePresentOnDisk;
                                   }
            $obj = New-Object -TypeName psobject -Property $headerInfo;
            $fileHeaders += $obj;
            
        }
    }
    
    if (@($fileHeaders | Where-Object {$_.FilePresentOnDisk -eq $false}).Count -gt 0)
    {
        " Below backup files are missing from disk:- " | Write-Host -ForegroundColor DarkRed -BackgroundColor Yellow;
        $fileHeaders | Where-Object {$_.FilePresentOnDisk -eq $false} | Select-Object DatabaseName, BackupTypeDescription, BackupFile | Write-Host -ForegroundColor Magenta -BackgroundColor Yellow;
    }

    Write-Verbose "Removing system databases, and backup files not present on disk.";
    $fileHeaders = ($fileHeaders | Where-Object {@('master','model','msdb') -notcontains $_.DatabaseName -and $_.FilePresentOnDisk -eq $true} | Sort-Object -Property DatabaseName, BackupStartDate);

    Write-Verbose "Updating value for additional fields like NextDiffBackupFile and NextTLogBackupFile";
    $databases = @($fileHeaders | Select-Object DatabaseName -Unique | Select-Object -ExpandProperty DatabaseName);
    foreach ($dbName in $databases)
    {
        Write-Verbose "   Lopping for Database [$dbName]";

        #Fetch all backups for database
        $dbBackups = $fileHeaders | Where-Object {$_.DatabaseName -eq $dbName} | Sort-Object BackupStartDate, BackupFinishDate;

        #Loop through each backup file, and update those additional fields
        foreach ($file in $dbBackups)
        {
            # if current file is Full Backup
            if ($file.BackupTypeDescription -eq 'Database' -and $file.IsValidForPointInTimeRecovery) 
            {
                # Diff.DatabaseBackupLSN = Full.CheckpointLSN
                $NextDiffBackupFile = $dbBackups | Where-Object {$_.BackupTypeDescription -eq 'Differential database' -and $_.DatabaseBackupLSN -eq $file.CheckpointLSN} | Sort-Object BackupStartDate -Descending | Select-Object -ExpandProperty BackupFile -First 1;
                if ($NextDiffBackupFile -eq $null) {
                    Write-Verbose "      No applicable Differential backups found.";
                } else {
                    Write-Verbose "      `$NextDiffBackupFile = $NextDiffBackupFile";
                }
                
                # Full.LastLSN + 1 between TLog.FirstLSN and TLog.LastLSN
                $FullLastLSN = $file.LastLSN + 1;
                $NextTLogBackupFile = $dbBackups | Where-Object {$_.BackupTypeDescription -eq 'Log' -and ( $FullLastLSN -ge $_.FirstLSN -and $FullLastLSN -le $_.LastLSN )} | Select-Object -ExpandProperty BackupFile;
                if ($NextTLogBackupFile -eq $null) {
                    Write-Verbose "      No applicable Transaction log backups found.";
                }
            }

            # if current file is Diff Backup
            if ($file.BackupTypeDescription -eq 'Differential database') 
            {
                # Full.LastLSN + 1 between TLog.FirstLSN and TLog.LastLSN
                $DiffLastLSN = $file.LastLSN + 1;
                $NextTLogBackupFile = $dbBackups | Where-Object {$_.BackupTypeDescription -eq 'Log' -and ( $DiffLastLSN -ge $_.FirstLSN -and $DiffLastLSN -le $_.LastLSN )} | Select-Object -ExpandProperty BackupFile;
                if ($NextTLogBackupFile -eq $null) {
                    Write-Verbose "      No applicable Transaction log backups found.";
                }
            }

            if ([String]::IsNullOrEmpty($NextDiffBackupFile) -eq $false) {
                $file.NextDiffBackupFile = $NextDiffBackupFile;
                $file.NextTLogBackupFile = $NextDiffBackupFile;
            }

            if ([String]::IsNullOrEmpty($NextTLogBackupFile) -eq $false) {
                $file.NextTLogBackupFile = $NextTLogBackupFile;
                $file.NextTLogBackupFile = $NextTLogBackupFile;
            }
        }
    }

    Write-Verbose "Checking if specific source databases are provided";
    if ([String]::IsNullOrEmpty($SourceDatabase) -eq $false)
    {
        # if 'RestoreAs_BackupFromPath' or 'RestoreAs_BackupFromHistory' options are selected
        if( [String]::IsNullOrEmpty($RestoreAs) -eq $false -and $SourceDatabase.Count -ne 1)
        {
            Write-Error "Kindly provide only single database name for parameter `$SourceDatabase";
            return;
        }

        Write-Verbose "Checking if databases are to be Skipped.";
        if ($Skip_Databases) 
        {
            Write-Verbose "Skip_Databases is set to TRUE";
            Write-Verbose "Removing databases based on parameter value `$SourceDatabase";
            $fileHeaders = ($fileHeaders | Where-Object {$SourceDatabase -notcontains $_.DatabaseName} | Sort-Object -Property DatabaseName, BackupStartDate);
        }
        else
        {
            Write-Verbose "Filtering databases based on parameter value `$SourceDatabase";
            $fileHeaders = ($fileHeaders | Where-Object {$SourceDatabase -contains $_.DatabaseName} | Sort-Object -Property DatabaseName, BackupStartDate);
        }
    }
    
    Write-Verbose "Perform action based on value of `$RestoreCategory parameter";
    if ($RestoreCategory -eq 'LatestAvailable')
    {
        # No action to be taken for RestoreCategory = "LatestAvailable"
        Write-Verbose "Filtering backups based on `$RestoreCategory = '$RestoreCategory'";
    }
    elseif ($RestoreCategory -eq 'LatestFullOnly')
    {
        Write-Verbose "Filtering backups based on `$RestoreCategory = '$RestoreCategory'";
        $fileHeaders = ($fileHeaders | Where-Object {$_.BackupTypeDescription -eq 'Database'} | Sort-Object -Property DatabaseName, BackupStartDate -Descending);
    }
    elseif ($RestoreCategory -eq 'LatestFullAndDiffOnly') #"LatestFullOnly", "LatestFullAndDiffOnly","PointInTime"
    {
        Write-Verbose "Filtering backups based on `$RestoreCategory = '$RestoreCategory'";
        $fileHeaders = ($fileHeaders | Where-Object {$_.BackupTypeDescription -eq 'Database' -or $_.BackupTypeDescription -eq 'DATABASE DIFFERENTIAL'} | Sort-Object -Property DatabaseName, BackupStartDate);
    }
    elseif ($RestoreCategory -eq 'PointInTime')
    {
        $databases = @($fileHeaders | Select-Object DatabaseName -Unique | Select-Object -ExpandProperty DatabaseName);

        Write-Verbose "Filtering backups based on `$RestoreCategory = '$RestoreCategory'";
        $pit_Backups_FullorDiff = @();
        $pit_Backups_TLog = @();
       
        # get full and diff backups upto @StopAtTime
        $pit_Backups_FullorDiff = ($fileHeaders | Where-Object {'DATABASE','DATABASE DIFFERENTIAL' -contains $_.BackupTypeDescription -and $_.BackupStartDate -le $StopAt_Time} | Sort-Object -Property DatabaseName, BackupStartDate);

        # get tlog backups to recover for @StopAtTime
        foreach ( $dbName in $databases )
        {
            $pit_LastTLogStartDate = $null;
            $pit_LastTLogStartDate = ($fileHeaders | Where-Object {$dbName -eq $_.DatabaseName -and $_.BackupTypeDescription -eq 'TRANSACTION LOG' -and $_.BackupStartDate -ge $StopAt_Time} | Measure-Object -Property BackupStartDate -Minimum).Minimum;
            $pit_Backups_TLog += ($fileHeaders | Where-Object {$dbName -eq $_.DatabaseName -and $_.BackupTypeDescription -eq 'TRANSACTION LOG' -and $_.BackupStartDate -le $pit_LastTLogStartDate} | Sort-Object -Property DatabaseName, BackupStartDate);
        }

        $fileHeaders = $pit_Backups_FullorDiff;
        $fileHeaders += $pit_Backups_TLog;
        $fileHeaders = $fileHeaders | Sort-Object DatabaseName, BackupStartDate;
    }

    $latestBackups = @();
    $latestBackups_Full = @();
    $latestBackups_Diff = @();
    $latestBackups_TLog = @();

    # reset names of $databases
    $databases = @($fileHeaders | Select-Object DatabaseName -Unique | Select-Object -ExpandProperty DatabaseName);
    foreach ( $dbName in $databases )
    {
        $lastestFullBackupDate = $null; # reset variable value
        $lastestDiffBackupDate = $null; # reset variable value
        $fullBackupHeader = $null; # reset variable value

        # Get Full Backup details
        $lastestFullBackupDate = ($fileHeaders | Where-Object {$dbName -eq $_.DatabaseName -and $_.BackupTypeDescription -eq 'Database'} | Measure-Object -Property BackupStartDate -Maximum).Maximum;
        $fullBackupHeader = ($fileHeaders | Where-Object {$dbName -eq $_.DatabaseName -and $_.BackupTypeDescription -eq 'Database' -and $_.BackupStartDate -eq $lastestFullBackupDate});
        $latestBackups_Full += $fullBackupHeader;

        if ($fullBackupHeader.IsCopyOnly -eq 1)
        {
            Write-Verbose "Latest Full Backup of database [$dbName] is COPY_ONLY";
        }
        else
        {
            # Get Diff Backup details on top of Full Backup
            if ($lastestFullBackupDate -ne $null) 
            {
                $lastestDiffBackupDate = ($fileHeaders | Where-Object {$dbName -eq $_.DatabaseName -and $_.BackupTypeDescription -eq 'DATABASE DIFFERENTIAL' -and $_.BackupStartDate -ge $lastestFullBackupDate} | Measure-Object -Property BackupStartDate -Maximum).Maximum;
                $latestBackups_Diff += ($fileHeaders | Where-Object {$dbName -eq $_.DatabaseName -and $_.BackupTypeDescription -eq 'DATABASE DIFFERENTIAL' -and $_.BackupStartDate -eq $lastestDiffBackupDate});
            }

            if ($fullBackupHeader.RecoveryModel -ne 'SIMPLE')
            {
                if ($lastestDiffBackupDate -eq $null) 
                {
                    $lastestDiffBackupDate = $lastestFullBackupDate;
                }

                # Get TLog Backup details on top of Differential Backup
                if ($lastestDiffBackupDate -ne $null) 
                {
                    $latestBackups_TLog += ($fileHeaders | Where-Object {$dbName -eq $_.DatabaseName -and $_.BackupTypeDescription -eq 'Log' -and $_.BackupStartDate -ge $lastestDiffBackupDate});
                }
            }
        }
    }

    $latestBackups += $latestBackups_Full;
    $latestBackups += $latestBackups_Diff;
    $latestBackups += $latestBackups_TLog;
    
    #$filelistFromBackupFiles = @();
    [int]$fileCounter_Total = 1;
    [int]$fileCounter_Database = 1;
    Write-Verbose "Looping through all the databases one by one to generate RESTORE statement.";
    foreach ( $dbName in $databases )
    {
        $fileCounter_Database = 1;
        if([String]::IsNullOrEmpty($RestoreAs) -eq $false) {
            $dbName_New = $RestoreAs;
        }else {
            $dbName_New = $dbName;
        };
        Write-Verbose "   Generating RESTORE statement for database [$dbName]";

        $backupFilesForDatabase = $latestBackups | Where-Object {$dbName -eq $_.DatabaseName} | Sort-Object BackupStartDate;
        $bkpCountsForDB = @($backupFilesForDatabase).Count;
        Write-Verbose "   `$bkpCountsForDB for [$dbName] database is $bkpCountsForDB";

        $tsql4Database = $null;
        $tsql4Database = @"


PRINT '$fileCounter_Total) Restoring database [$dbName_New]'

"@;
        
        foreach ($file in $backupFilesForDatabase)
        {
            $tsql4Database += @"


    PRINT '   File no: $fileCounter_Database'
RESTORE DATABASE [$dbName_New] FROM DISK ='$($file.BackupFile)'
    WITH 
"@;
            Write-Verbose "      Reading filelist for file '$($file.BackupFile)'";
            $query = "restore filelistonly from disk = '$($file.BackupFile)'";
            $list = Invoke-Sqlcmd -ServerInstance $Destination_SQLInstance -Query $query;
            $list = ($list | Sort-Object FileId);

            # If differtial or TLog, with MOVE option is not required
            if($fileCounter_Database -eq 1)
            {
                foreach ($f in $list)
                {
                    $physicalName = $f.PhysicalName; #F:\Mssqldata\Data\UserTracking_data.mdf
                    $r = $physicalName -match "^(?'PathPhysicalName'.*[\\\/])(?'BasePhysicalNameWithExtension'(?'BasePhysicalNameWithoutExtension'.+)(?'Extension'\.[a-zA-Z]+$))";

                    $BasePhysicalNameWithExtension = $Matches['BasePhysicalNameWithExtension']; #UserTracking_data.mdf
                    $Extension = $Matches['Extension']; #.mdf
                    $PathPhysicalName = $Matches['PathPhysicalName']; #F:\Mssqldata\Data\
                    $BasePhysicalNameWithoutExtension = $Matches['BasePhysicalNameWithoutExtension']; #UserTracking_data

                    # When database has to be restored with New Name. Then change physicalName of files
                    if ([String]::IsNullOrEmpty($RestoreAs) -eq $false)
                    {
                        $BasePhysicalNameWithExtension_New = $BasePhysicalNameWithExtension.Replace("$dbName","$RestoreAs");
                        if($BasePhysicalNameWithExtension_New -eq $BasePhysicalNameWithExtension) {
                            $BasePhysicalNameWithExtension_New = $RestoreAs +'_'+ $BasePhysicalNameWithExtension_New;
                        }
                    }
                    else {
                        $BasePhysicalNameWithExtension_New = $BasePhysicalNameWithExtension;
                    }
                
                    if ($f.Type -eq 'D') 
                    {
                        $PhysicalPath_New = $DestinationPath_Data + $BasePhysicalNameWithExtension_New;
                    }
                    else 
                    {
                        $PhysicalPath_New = $DestinationPath_Log + $BasePhysicalNameWithExtension_New;
                    }

                    $tsql4Database += @"

			MOVE '$($f.LogicalName)' TO '$PhysicalPath_New',
"@;
                
                }
            }

            #$tsql4BackupFile += $tsql4MoveCommand;
            
            #if its last backup file to apply
            if ($bkpCountsForDB -eq $fileCounter_Database)
            {
                $tsql4Database += @"

			$(if($Overwrite -and $fileCounter_Database -eq 1){'REPLACE, '})$(if($NoRecovery){'NORECOVERY, '})$(if($fileCounter_Database -ne 1 -and $RestoreCategory -eq 'PointInTime'){'STOPAT = '''+$StopAt_String+''', '})STATS = 3 
GO
"@;
            }
            else 
            {
                $tsql4Database += @"

			$(if($Overwrite -and $fileCounter_Database -eq 1){'REPLACE, '})NORECOVERY, STATS = 3
GO
"@;
            }

                $fileCounter_Database += 1;
        }

        $tsql4Database | Out-File -Append $ResultFile;

        $fileCounter_Total += 1;
    }

    Write-Host "Opening generated script file '$ResultFile' with SSMS.";
    if ($Destination_SQLInstance -eq $null)
    {
        $Destination_SQLInstance = $sdtInventoryInstance;
    }
    if (Test-Path $ResultFile)
    {
        #ssms.exe $ResultFile -S $Destination_SQLInstance -E;
        notepad.exe $ResultFile;
    }
    else
    {
        Write-Host "No valid backup files found for Restore Activity..";
    }
}
