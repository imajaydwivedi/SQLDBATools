$env:PSModulePath = $env:PSModulePath + ";" + "C:\Program Files\WindowsPowerShell\Modules;C:\Windows\system32\WindowsPowerShell\v1.0\Modules\;C:\Program Files\MVPSI\Modules\";

Import-Module dbatools #-Scope Local -ErrorAction SilentlyContinue;
#Import-Module SQLDBATools -DisableNameChecking;
Import-Module JAMS;
Invoke-Expression -Command "C:\Set-EnvironmentVariables.ps1";

$ExecutionLogsFile = "$$SdtLogsPath\Wrapper-JAMSEntry\___ExecutionLogs.txt";

# Set Jams Server
$JAMS_Server = 'SqlProd3';

TRY 
{
    if (Test-Path $ExecutionLogsFile) {
        Remove-Item $ExecutionLogsFile;
    }

    "Script running under context of [$($env:USERDOMAIN)\$($env:USERNAME)]
------------------------------------------------------------------------------------
------------------------------------------------------------------------------------
" | Out-File -Append $ExecutionLogsFile;
    
    $Error.Clear();
    # Push JAMSEntry queue to SQL Table
    $JAMS_CurrentSetups = Get-JAMSEntry -Server $JAMS_Server | Where-Object {$_.Setup -like 'Setup: Sync*'};
    
    
    $JAMS_CurrentSetups | Select-Object @{l='ServerName';e={ if($_.Setup -match "\s(?'ServerName'BLR\w+)") { $Matches['ServerName'] } else {$null} }}, SetupID, Setup, JAMSEntry, JobName, Description, CurrentState, TodaysDate, HoldTime, OriginalHoldTime, `
                                    ElapsedTime, CompletionTime, FinalStatus, Held, Stalled, WaitFor, StepWait, Halted, InitiatorType, SubmittedBy, @{l='CollectionTime';e={Get-Date}} | #ogv
    Write-DbaDataTable -SqlInstance $sdtInventoryInstance -Database $sdtInventoryDatabase -Schema 'Staging' -Table JAMSEntry #-AutoCreateTable

    #return "Script Wrapper-JAMSEntry executed successfully";
    return '0';
}
CATCH {
    $formatstring = "{0} : {1}`n{2}`n" +
                "    + CategoryInfo          : {3}`n" +
                "    + FullyQualifiedErrorId : {4}`n"
    $fields = $_.InvocationInfo.MyCommand.Name,
              $_.ErrorDetails.Message,
              $_.InvocationInfo.PositionMessage,
              $_.CategoryInfo.ToString(),
              $_.FullyQualifiedErrorId

    $returnMessage = $formatstring -f $fields;

    if ($Error -eq 'Unable to Find CurJob')
    {
        return "No job in queue right now.";
    }
    else {
    "Error:- 
$returnMessage
" | Out-File -Append $ExecutionLogsFile;
     #throw "$Error";
     return $returnMessage;
    }
}
