Import-Module SQLPS -DisableNameChecking;

Set-Location SQLSERVER:\;
Get-ChildItem

Set-Location SQLSERVER:\SQL;
Get-ChildItem

# Set variable with Current Machine Name
$ServerName = $env:COMPUTERNAME;
$InstanceName = "SQLSERVER:\SQL\$ServerName\DEFAULT";

# Get databases for instance
Set-Location $InstanceName\Databases;
Get-ChildItem

Set-Location $InstanceName\Databases\AdventureWorks2014\Tables;
Get-ChildItem

<# Get the SQL Server Instance for each machine we pass #>

# Load an array of instances object
$ServerName = $env:COMPUTERNAME;
$instances = Get-ChildItem "SQLSERVER:\SQL\$ServerName";
Write-Output $instances

# Load Instances as an Array of Strings
$instances = @();
Get-ChildItem "SQLSERVER:\SQL\$ServerName" | 
    foreach {$instances += $_.PSChildName};

Write-Output $instances;

<# ----------------------------------------------------------------------
    Code to Get Backup History
#>
# Pretend like this is an array of Server Names
$machines = $env:COMPUTERNAME;
#$machines = @();
#$machines = Invoke-Sqlcmd -ServerInstance $env:COMPUTERNAME -Database 'DBServers_master' -Query 'select [Server/Instance Name] from [dbo].[Production]' |
                #Select-Object -ExpandProperty 'Server/Instance Name';

Push-Location;
$machineInstances = @();
foreach ($machine in $machines) {
    if ($machine -ne "") {
        Get-ChildItem "SQLSERVER:\SQL\$ServerName" | 
            foreach {$machineInstances += "$machine\$($_.PSChildName)"};
    }
}

foreach ($instance in $machineInstances){
    Get-ChildItem -Force SQLSERVER:\SQL\$instance\Databases | where-object {$_.Name -ne 'tempdb'; $_.Refresh()} |  
        Format-Table @{Label="ServerName"; Expression={ $_.Parent -replace '[[\]]',''}}, 
                    @{l='DatabaseName';e={$_.Name}}, 
                    @{l='DatabaseCreationDate';e={IF ($_.CreateDate -eq "01/01/0001 00:00:00") {$null} else {($_.CreateDate).ToString("yyyy-MM-dd HH:mm:ss")}}}, 
                    RecoveryModel, 
                    @{l='LastFullBackupDate';e={IF ($_.LastBackupDate -eq "01/01/0001 00:00:00") {$null} else {($_.LastBackupDate).ToString("yyyy-MM-dd HH:mm:ss")}}}, 
                    @{l='LastDifferentialBackupDate';e={IF ($_.LastDifferentialBackupDate -eq "01/01/0001 00:00:00") {$null} else {($_.LastDifferentialBackupDate).ToString("yyyy-MM-dd HH:mm:ss")}}},  
                    @{l='LastLogBackupDate';e={IF ($_.LastLogBackupDate -eq "01/01/0001 00:00:00") {$null} else {($_.LastLogBackupDate).ToString("yyyy-MM-dd HH:mm:ss")}}} `
            -AutoSize
    
        #Select *
}
Pop-Location;

#Write-Output $machineInstances;
<# ----------------------------------------------------------------------
#>

<# Create Database #>
$srv = New-Object Microsoft.SqlServer.Management.Smo.Server($machineInstances[0]);
$db = New-Object Microsoft.SqlServer.Management.Smo.Database($srv, "Test_SMO_Database")
$db.Create()
Write-Host $db.CreateDate
$db.Drop()

