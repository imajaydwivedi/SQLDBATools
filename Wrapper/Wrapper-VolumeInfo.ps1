$env:PSModulePath = $env:PSModulePath + ";" + "C:\Program Files\WindowsPowerShell\Modules;C:\Windows\system32\WindowsPowerShell\v1.0\Modules\;C:\Program Files\MVPSI\Modules\";

Import-Module SQLDBATools -DisableNameChecking;

$ExecutionLogsFile = "$sdtSQLDBATools_ResultsDirectory\Logs\Get-VolumeInfo\___ExecutionLogs.txt";
if (!(Test-Path "$sdtSQLDBATools_ResultsDirectory\Logs\Get-VolumeInfo")) {
    Write-Verbose "Path "+"$sdtSQLDBATools_ResultsDirectory\Logs\Get-VolumeInfo does not exist. Creating it.";
    New-Item -ItemType "directory" -Path "$sdtSQLDBATools_ResultsDirectory\Logs\Get-VolumeInfo";
}


$instancesquery = @"
select ServerName from [info].[Server];
--SELECT Name as InstanceName FROM [Info].[Instance] WHERE IsDecommissioned = 0
"@;

$machines = Execute-SqlQuery -Query $instancesquery -ServerInstance $sdtInventoryInstance -Database $sdtInventoryDatabase;
$servers = @($machines | select -ExpandProperty ServerName);


TRY {
    if (Test-Path $ExecutionLogsFile) {
        Remove-Item $ExecutionLogsFile;
        # Clear last Log generated
        Get-ChildItem "$sdtSQLDBATools_ResultsDirectory\Logs\Get-VolumeInfo" | Remove-Item;
    }

    "Script running under context of [$($env:USERDOMAIN)\$($env:USERNAME)]
------------------------------------------------------------------------------------
------------------------------------------------------------------------------------
" | Out-File -Append $ExecutionLogsFile;

    $Error.Clear();

    $stime = Get-Date;
    Set-Location 'C:\Users\adwivedi\Documents\WindowsPowerShell\Modules\SQLDBATools';
    Run-CommandMultiThreaded `
        -MaxThreads 26 `
        -MaxResultTime 240 `
        -Command Collect-VolumeInfo `
        -ObjectList ($servers) `
        -InputParam ComputerName;

    $etime = Get-Date

    $timeDiff = New-TimeSpan -Start $stime -End $etime ;
    
    return "Script Wrapper-VolumeInfo executed successfully.";
}
CATCH {
    @"
Error occurred while running 'Wrapper-VolumeInfo'
$Error
"@ | Out-File -Append $ExecutionLogsFile;

     throw "$Error";
}