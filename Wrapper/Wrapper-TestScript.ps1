$env:PSModulePath = $env:PSModulePath + ";" + "C:\Program Files\WindowsPowerShell\Modules;C:\Windows\system32\WindowsPowerShell\v1.0\Modules\;C:\Program Files\MVPSI\Modules\";

Import-Module dbatools;
Import-Module SQLDBATools -DisableNameChecking;
Import-Module JAMS;

$ExecutionLogsFile = "$$SdtLogsPath\Wrapper-TestScript\___ExecutionLogs.txt";


TRY 
{
    if (Test-Path $ExecutionLogsFile) {
        Remove-Item $ExecutionLogsFile;
    }

    "
$(Get-Date) => Script running under context of [$($env:USERDOMAIN)\$($env:USERNAME)]
------------------------------------------------------------------------------------
------------------------------------------------------------------------------------
" | Out-File -Append $ExecutionLogsFile;
    
    $Error.Clear();
    # Generate Dummy Error
    #$x = 12/0;
    return "Wrapper-TestScript executed successfully";
}
CATCH {
    "Error:- 
$Error
" | Out-File -Append $ExecutionLogsFile;
     throw $Error;
     #return 1;
}
