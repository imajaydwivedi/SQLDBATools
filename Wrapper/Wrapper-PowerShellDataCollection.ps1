Import-Module SQLDBATools -DisableNameChecking;

#Set-Variable -Name sdtInventoryInstance -Value 'BAN-1ADWIVEDI-L' -Scope Global;
#Set-Variable -Name sdtInventoryDatabase -Value 'DBServers_master' -Scope Global;

#$sdtInventoryInstance = 'BAN-1ADWIVEDI-L';
#$sdtInventoryDatabase = 'DBServers_master';

$instancesquery ="select [Server/Instance Name] as InstanceName from [dbo].[Production]";
$instances = Invoke-Sqlcmd -Query $instancesquery -ServerInstance $sdtInventoryInstance -Database $sdtInventoryDatabase #-ConnectionTimeout 0 -QueryTimeout 0
$servers = @($instances | select -ExpandProperty InstanceName);

#$servers = @($env:COMPUTERNAME);

#$servers
#cd C:\temp\Collect-DatabaseBackupInfo;
#Remove-Item "c:\temp\PowerShellDataCollection\Collect-DatabaseBackupInfo.txt" -ErrorAction Ignore;

Push-Location;

$stime = Get-Date;
Set-Location 'C:\Users\adwivedi\Documents\WindowsPowerShell\Modules\SQLDBATools';
Run-CommandMultiThreaded `
    -MaxThreads 3 `
    -Command Collect-DatabaseBackupInfo `
    -ObjectList ($servers) `
    -InputParam SQLInstance -Verbose

$etime = Get-Date

$timeDiff = New-TimeSpan -Start $stime -End $etime ;
write-host $timeDiff;

Pop-Location;