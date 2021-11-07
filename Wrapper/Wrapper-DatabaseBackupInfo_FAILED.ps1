Import-Module SQLDBATools -DisableNameChecking;

$ExecutionLogsFile = "$$SdtLogsPath\Get-DatabaseBackupInfo\___ExecutionLogs.txt";

$instancesquery = @"
SELECT Name as InstanceName FROM [dbo].[Instance] 
WHERE IsDecommissioned = 0 AND [IsPowerShellLinked] = 0 AND Domain = 'Corporate.local'
"@;
$instances = Execute-SqlQuery -Query $instancesquery -ServerInstance $sdtInventoryInstance -Database $sdtInventoryDatabase;
$servers = @($instances | select -ExpandProperty InstanceName);

if (Test-Path $ExecutionLogsFile) {
        Remove-Item $ExecutionLogsFile;
}

    "Following SQL Instances are processed in order:-
" | Out-File -Append $ExecutionLogsFile;

    $stime = Get-Date;
    Set-Location 'C:\Users\adwivedi\Documents\WindowsPowerShell\Modules\SQLDBATools';
    
   Run-CommandMultiThreaded `
        -MaxThreads 26 `
        -MaxResultTime 240 `
        -Command Collect-DatabaseBackupInfo `
        -ObjectList ($servers) `
        -InputParam SQLInstance;
    

    <#
    $i = 0;
    foreach($SQLInstance in $servers)
    {
        $i = $i + 1;
         # Making entry into General Logs File
        "$i) $SQLInstance " | Out-File -Append $ExecutionLogsFile;

        Collect-DatabaseBackupInfo -SQLInstance $SQLInstance -Verbose;
        
    }
    #>

    "Processed $i sql instances" | Out-File -Append $ExecutionLogsFile;

    $etime = Get-Date

    $timeDiff = New-TimeSpan -Start $stime -End $etime ;
    
    
