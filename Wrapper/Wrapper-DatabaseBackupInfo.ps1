$env:PSModulePath = $env:PSModulePath + ";" + "C:\Program Files\WindowsPowerShell\Modules;C:\Windows\system32\WindowsPowerShell\v1.0\Modules\;C:\Program Files\MVPSI\Modules\";

Import-Module SQLDBATools -DisableNameChecking;

$ExecutionLogsFile = "$sdtSQLDBATools_ResultsDirectory\Logs\Get-DatabaseBackupInfo\___ExecutionLogs.txt";


$instancesquery ="SELECT InstanceName FROM Info.Instance WHERE IsDecommissioned = 0";
#$instances = Invoke-Sqlcmd -Query $instancesquery -ServerInstance $sdtInventoryInstance -Database $sdtInventoryDatabase #-ConnectionTimeout 0 -QueryTimeout 0
$instances = Execute-SqlQuery -Query $instancesquery -ServerInstance $sdtInventoryInstance -Database $sdtInventoryDatabase;
$servers = @($instances | select -ExpandProperty InstanceName);


TRY {
    if (Test-Path $ExecutionLogsFile) {
        Remove-Item $ExecutionLogsFile;
    }

    "Script running under context of [$($env:USERDOMAIN)\$($env:USERNAME)]
------------------------------------------------------------------------------------
------------------------------------------------------------------------------------
" | Out-File -Append $ExecutionLogsFile;

    $stime = Get-Date;
    Set-Location 'C:\Users\adwivedi\Documents\WindowsPowerShell\Modules\SQLDBATools';
    Run-CommandMultiThreaded `
        -MaxThreads 26 `
        -MaxResultTime 240 `
        -Command Collect-DatabaseBackupInfo `
        -ObjectList ($servers) `
        -InputParam SQLInstance;

    $etime = Get-Date

    $timeDiff = New-TimeSpan -Start $stime -End $etime ;
    
    return 0;
}
CATCH {
     throw "Something went wrong";
     return 1;
}