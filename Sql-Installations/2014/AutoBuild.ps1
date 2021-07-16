[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("Corporate\DevSQL", "Corporate\ProdSQL", "Corporate\QASQL")]
    [string] $SQLServiceAccount = 'Corporate\DevSQL',

    [Parameter(Mandatory=$false)]
    [string] $InstanceName = 'MSSQLSERVER',

    [Parameter(Mandatory=$false)]
    [string] $SQLServiceAccountPassword,

    [Parameter(Mandatory=$false)]
    [string] $SAPassword,

    [Parameter(Mandatory=$false)]
    [string] $Administrators = 'Corporate\SQL Admins'
)

#$PSScriptRoot = "C:\Users\adwivedi\Documents\WindowsPowerShell\Modules\SQLDBATools\Sql-Installations\2014";
$ConfigFile = "$PSScriptRoot\ConfigurationFile.ini";

if(Get-Content $ConfigFile | Where-Object {$_ -match "INSTALLSQLDATADIR=`"(?'INSTALLSQLDATADIR'.+)`""}) {
    $INSTALLSQLDATADIR = (($Matches['INSTALLSQLDATADIR']).split('\')[0])+'\';
}
if(Get-Content $ConfigFile | Where-Object {$_ -match "SQLBACKUPDIR=`"(?'SQLBACKUPDIR'.+)`""}) {
    $SQLBACKUPDIR = (($Matches['SQLBACKUPDIR']).split('\')[0])+'\';
}
if(Get-Content $ConfigFile | Where-Object {$_ -match "SQLUSERDBDIR=`"(?'SQLUSERDBDIR'.+)`""}) {
    $SQLUSERDBDIR = (($Matches['SQLUSERDBDIR']).split('\')[0])+'\';
}
if(Get-Content $ConfigFile | Where-Object {$_ -match "SQLUSERDBLOGDIR=`"(?'SQLUSERDBLOGDIR'.+)`""}) {
    $SQLUSERDBLOGDIR = (($Matches['SQLUSERDBLOGDIR']).split('\')[0])+'\';
}
if(Get-Content $ConfigFile | Where-Object {$_ -match "SQLTEMPDBDIR=`"(?'SQLTEMPDBDIR'.+)`""}) {
    $SQLTEMPDBDIR = (($Matches['SQLTEMPDBDIR']).split('\')[0])+'\';
}

if( -not ( (Test-Path $INSTALLSQLDATADIR) -and  (Test-Path $SQLBACKUPDIR) -and (Test-Path $SQLUSERDBDIR) -and (Test-Path $SQLUSERDBLOGDIR) -and (Test-Path $SQLTEMPDBDIR) ) ) {
    Write-Host "Kindly make sure all reqired disk drives are present.`n$INSTALLSQLDATADIR, $SQLUSERDBDIR, $SQLUSERDBLOGDIR, $SQLBACKUPDIR & $SQLTEMPDBDIR" -ForegroundColor Red;
    if((Get-PSCallStack).Count -gt 1) {
        exit;
    }
}


# If SQLServiceAccountPassword or SAPassword is not provided in parameter
if([string]::IsNullOrEmpty($SQLServiceAccountPassword) -or [string]::IsNullOrEmpty($SAPassword)) {
    $InventoryServer = 'TUL1DBAPMTDB1';
    $ssn = New-PSSession -ComputerName $InventoryServer -Name $InventoryServer;

    if([string]::IsNullOrEmpty($SQLServiceAccountPassword)) {
        # Get Password for SQLServiceAccount
        $ScriptBlock = { Import-Module SQLDBATools; Get-Password4Account -UserName $Using:SQLServiceAccount; }
        $SQLServiceAccountPassword = Invoke-Command -Session $ssn -ScriptBlock $ScriptBlock;
    }

    if([string]::IsNullOrEmpty($SAPassword)) {
        # Get Password for SA
        $ScriptBlock = { Import-Module SQLDBATools; Get-Password4Account -UserName "SA"; }
        $SAPassword = Invoke-Command -Session $ssn -ScriptBlock $ScriptBlock;
    }
}

Write-Host "Starting installation of SQL Server setup.." -ForegroundColor Yellow;

if($InstanceName -ne 'MSSQLSERVER') {
    $configFileContent = Get-Content 'ConfigurationFile.ini';
    $configFileContent.Replace("MSSQLSERVER",$InstanceName) | Set-Content 'ConfigurationFile.ini';
}

.\SETUP.EXE /INSTANCENAME=$InstanceName /SQLSYSADMINACCOUNTS=$Administrators `
            /SQLSVCACCOUNT=$SQLServiceAccount /SQLSVCPASSWORD=$SQLServiceAccountPassword `
            /AGTSVCACCOUNT=$SQLServiceAccount /AGTSVCPASSWORD=$SQLServiceAccountPassword `
            /SAPWD=$SAPassword /CONFIGURATIONFILE="./ConfigurationFile.ini"
            
            
$logFolder = 'C:\Program Files\Microsoft SQL Server\120\Setup Bootstrap\Log'
<#
    1) Open Summary.txt
    2) Open folder with most recent Modified Date. Folder name would be like '20191016_135940'
    3) If step 01 file not present, open file like 'Summary_TESTVM_20191016_135940' in step 02 folder
#>

$Summary = Get-Content "$logFolder\Summary.txt" | Select-Object -First 6;
$Summary | Where-Object {$_ -match "Exit code \(Decimal\):\s*(?'ExitCode'\d+)"} | Out-Null
$ExitCode = $Matches['ExitCode'];
if($ExitCode -eq 0) {
    Write-Host "Installation completed Successfully" -ForegroundColor Green;
    Write-Host $Summary;
} 
elseif($ExitCode -eq 3010) {
    Write-Host "Installation completed but REBOOT is required" -ForegroundColor Green;
    Write-Host $Summary;
}
else {
    Write-Host "Some Issue occurred. Kindly check summary page." -ForegroundColor Red;
    explorer $logFolder;
    notepad "$logFolder\Summary.txt";
}

