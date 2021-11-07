cls
[boolean]$generateOnly = $true;
$serverName = 'SqlProd1';
$dbName = 'Cosmo';

# Provide New Drives
[String]$_new_Data_Drive = 'P:\';
[String]$_new_Log_Drive = 'Q:\';

$fileText = "";

Write-Host "Validating variable values.." -ForegroundColor Yellow;
<# Validate Drive letters #>
if($_new_Data_Drive -match "^(?'letter'[a-zA-Z]{1})") {$_new_Data_Drive = ($Matches['letter']).ToUpper()+':\'};

$Matches.Clear();
if($_new_Log_Drive -match "^(?'letter'[a-zA-Z]{1})") {$_new_Log_Drive = ($Matches['letter']).ToUpper()+':\'};

$_newDataPath = "$($_new_Data_Drive)Mssqldata\Data\";
$_newLogPath = "$($_new_Log_Drive)Mssqldata\Log\";

# Step 01 => Set Database to Restricted Mode & Read Only
$tsql_setToRestricted = @"
USE master;
-- Set to Single User mode
ALTER DATABASE [$dbName] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
-- Set to Restricted ReadOnly mode
ALTER DATABASE [$dbName] SET READ_ONLY;
-- Set to Multi User Again
ALTER DATABASE [$dbName] SET MULTI_USER;
GO
"@;
if($generateOnly)
{
    $fileText = @"
/* Step 01 => Execute below TSQL code in SSMS */
$tsql_setToRestricted


"@;
}
else
{
    Write-Host "Setting [$dbName] database to READ_ONLY mode .." -ForegroundColor Yellow;
    Invoke-Sqlcmd2 -ServerInstance $serverName -Database 'master' -Query $tsql_setToRestricted -ParseGO;
}

# Step 02 => Perform Database Backup
Write-Host "Fetching last FULL backup location for [$dbName] database ..";
$lastBackupFile = Get-DbaBackupHistory -SqlInstance $serverName -Database $dbName -LastFull | Select-Object -ExpandProperty Path;
$lastBackupPath = [System.IO.Path]::GetDirectoryName($lastBackupFile);
$backupFileName = "$lastBackupPath\$($dbName)_FULL_$((Get-Date -Format 'yyyyMMddTHHmm')).BAK";
$tsql_BackupDatabase = @"
USE master;
BACKUP DATABASE [$dbName] TO DISK = '$backupFileName'
	 WITH STATS = 5 ,CHECKSUM, COMPRESSION --,COPY_ONLY
;
--RESTORE VERIFYONLY FROM  DISK = N'$backupFileName'
GO
"@;

if($generateOnly) { 
    $fileText += @"

/* Step 02 => Execute below script in SSMS */
$tsql_BackupDatabase


"@;
}
else {
    Write-Host "Performing FULL backup for [$dbName] database, and verifying same .." -ForegroundColor Yellow;
    Write-Host "Backup file = '$backupFileName'" -ForegroundColor Green;
    Invoke-Sqlcmd2 -ServerInstance $serverName -Database 'master' -Query $tsql_BackupDatabase -ParseGO;
}

# Step 03 => Bring database to READ_WRITE, and Change Metadata with ALTER DATABASE MODIFY FILE
    #        and set database OFFLINE 
Write-Host "Getting [$dbName] database file information .." -ForegroundColor Yellow;
$tsql_GetFiles = @"
select db_name(mf.database_id) as dbName, mf.name as logicalName, mf.physical_name as physicalName,type_desc as typeDesc from sys.master_files mf 
	where mf.database_id = db_id('$dbName');
"@;
$dbFiles = Invoke-Sqlcmd2 -ServerInstance $serverName -Database 'master' -Query $tsql_GetFiles -ParseGO;

#$dbFiles | ogv
$tsqlAlterCode = @"

/* Step 03 => Execute below TSQL Code on SQL Server */
USE master;
-- Set database in Single User mode
ALTER DATABASE [$dbName] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
-- Set database back to write mode
ALTER DATABASE [$dbName] SET READ_WRITE;
"@;

# Create Folders if not exists
$tsqlCreateFolders = '';
$foldersToBeCreated = $dbFiles | Select-Object @{l='Directory';e={[System.IO.Path]::GetDirectoryName($_.physicalName)}} -Unique;
$foldersToBeCreated | foreach {
    $tsqlCreateFolders += "exec master..xp_create_subdir N'$($_.Directory)';
";
}
#Write-Host $tsqlCreateFolders;


if($generateOnly)
{
    $tsqlAlterCode += @"


-- Create Folders required
$tsqlCreateFolders
"@;
}

foreach($file in $dbFiles)
{
    [String]$physicalName = '';
    $sourceFolder = [System.IO.Path]::GetDirectoryName($file.physicalName);
    $fileName = [System.IO.Path]::GetFileName($file.physicalName);


    if($sourceFolder -match "^(?'driveLetter'[a-zA-Z]{1}):\\(?'remainingPath'[\w\\]*)") {
        $_newDataPath = "$($_new_Data_Drive)$($Matches['remainingPath'])";
    }
    if($sourceFolder -match "^(?'driveLetter'[a-zA-Z]{1}):\\(?'remainingPath'[\w\\]*)") {
        $_newLogPath = "$($_new_Log_Drive)$($Matches['remainingPath'])";
    }
    
    if($file.typeDesc -eq 'LOG')
    {
        $physicalName = $_newLogPath + '\' + $fileName;
    }
    else
    {
        $physicalName = $_newDataPath + '\' + $fileName;
    }

    $tsqlAlterCode += @"

-- Move logical file [$($file.logicalName)]
ALTER DATABASE [$($file.dbName)] MODIFY FILE ( NAME = $($file.logicalName), FILENAME = '$physicalName' );
"@;
}
$tsqlAlterCode += @"


-- Set database OFFLINE
ALTER DATABASE [$dbName] SET OFFLINE;
GO
"@;

if($generateOnly) 
{ 
    $fileText += @"

$tsqlAlterCode
"@;
}
else 
{
    Write-Host @" 
Setting database back to MULTI_USER, 
    and then ALTERing database meta data to MOVE database files to new location,
    and setting then to OFFLINE again..
"@ -ForegroundColor Yellow;
    $foldersToBeCreated | ForEach-Object {New-Item -ItemType "Directory" -Path $_.Directory};
    Invoke-Sqlcmd2 -ServerInstance $serverName -Database 'master' -Query $tsqlAlterCode -ParseGO;
}

# Step 04 => Copy files to New Drives
$dbFiles.Count | Out-File -FilePath c:\temp\processedFileCount.txt;
if($generateOnly) { 
        $fileText += @"


/* Step 04 => Run follow code in PowerShell to 'Copy' files to New location */
Invoke-Command -ComputerName $serverName -ScriptBlock {
"@;
}
foreach($file in $dbFiles)
{
    #$file.physicalName;
    $path = $file.physicalName;
    $sourceFolder = [System.IO.Path]::GetDirectoryName($path);
    $fileName = [System.IO.Path]::GetFileName($path);

    if($sourceFolder -match "^(?'driveLetter'[a-zA-Z]{1}):\\(?'remainingPath'[\w\\]*)") 
    {
        $_newDataPath = "$($_new_Data_Drive)$($Matches['remainingPath'])";
#    }
    #if($sourceFolder -match "^(?'driveLetter'[a-zA-Z]{1}):\\(?'remainingPath'[\w\\]*)") {
        $_newLogPath = "$($_new_Log_Drive)$($Matches['remainingPath'])";
    }
    
    if($file.typeDesc -eq 'LOG')
    {
        if($generateOnly) { 
            $fileText += @"

    Copy-Item  '$path' -Destination '$_newLogPath';
    #robocopy $sourceFolder $_newLogPath $fileName;
"@;
        }
        else 
        {
            Invoke-Command -ComputerName $serverName -ScriptBlock {
                #Get-Item $Using:path;
                Write-Host "Copying file '$($Using:path)' to folder '$($Using:_newLogPath)'" -ForegroundColor Yellow;
                if(![System.IO.Directory]::Exists($Using:_newLogPath)){
                    New-Item -Path $Using:_newLogPath -ItemType "Container";   
                }
                Copy-Item  $Using:path -Destination $Using:_newLogPath;    
                #robocopy $sourceFolder $_newLogPath $fileName;
            }
        }
    }
    else
    {
        if($generateOnly) { 
            $fileText += @"

    Copy-Item  '$path' -Destination '$_newDataPath';
    #robocopy $sourceFolder $_newDataPath $fileName;
"@;
        }
        else 
        {
            Invoke-Command -ComputerName $serverName -ScriptBlock {
                #Get-Item $Using:path;
                Write-Host "Coping file '$($Using:path)' to folder '$($Using:_newDataPath)'" -ForegroundColor Yellow;
                if(![System.IO.Directory]::Exists($Using:_newDataPath)){
                    New-Item -Path $Using:_newDataPath -ItemType "Container";   
                }
                Copy-Item  $Using:path -Destination $Using:_newDataPath;
                #robocopy $sourceFolder $_newDataPath $fileName;
            }
        }
    }
}

if($generateOnly) 
{ 
            $fileText += @"

}
"@;
}


# Step 05 => Generate TSQL for Making db Online and MULTI_USER
$tsql_setOnline = @"
-- Bring database Online
ALTER DATABASE [$dbName] SET ONLINE;
-- Set database to Multi User
ALTER DATABASE [$dbName] SET MULTI_USER;
GO
"@;

if($generateOnly) 
{ 
    $fileText += @"


/* Step 05 => Execute below TSQL code to make database Online and MultiUser */
USE master;
$tsql_setOnline
"@;
}
else {
    Write-Host "Trying to bring database [$dbName] Online, and set [sa] as Owner.." -ForegroundColor Yellow;
    Invoke-Sqlcmd2 -ServerInstance $serverName -Database 'master' -Query $tsql_setOnline -ParseGO;
}


# Step 06 => Remove Old files
if($generateOnly) { 
        $fileText += @"



/* Step 06 => Run follow code in PowerShell to 'Remove' files from old location */
Invoke-Command -ComputerName $serverName -ScriptBlock {
"@;
}
foreach($file in $dbFiles)
{
    #$file.physicalName;
    $path = $file.physicalName;
    $newName = [System.IO.Path]::GetFileName($path);
    #$newName -match "(?'baseName'\w+)\.(?'Extension'[a-zA-Z]{3})";
    #$newName = $Matches['baseName']+$Matches['Extension'];
    $newName = "[__DeleteAfter$((Get-Date).AddDays(7).ToString("yyyyMMMdd"))__] $newName";

    if($generateOnly) { 
            $fileText += @"

    #Remove-Item -Path '$path' -Force ;
    Rename-Item -Path '$path' -NewName '$newName';

"@;
    }
    else 
    {
        Invoke-Command -ComputerName $serverName -ScriptBlock {
            #Get-Item $Using:path;
            Write-Host "Removing file '$($Using:path)'.." -ForegroundColor Yellow;
            #Remove-Item -Path $Using:path -Force;             
            Rename-Item -Path '$path' -NewName '$newName';
        }
    }
}
if($generateOnly) 
{ 
            $fileText += @"

}
"@;
}

if($generateOnly)
{
    #Write-Host $fileText
    $scriptOutFile = "MoveDatabase_Steps_$($serverName)_$($dbName) __$((Get-Date -Format 'dd-MMM-yyyy HH.mm tt')).txt";
    Write-Host "Saving the generated TSQL code to 'c:\temp\$scriptOutFile'" -ForegroundColor Green;
    Write-Host "Opening the generated TSQL code file..." -ForegroundColor Yellow;
    $fileText | Out-File -FilePath "c:\temp\$scriptOutFile";
    notepad "c:\temp\$scriptOutFile";
}
