$env:PSModulePath = $env:PSModulePath + ";" + "C:\Program Files\WindowsPowerShell\Modules;C:\Windows\system32\WindowsPowerShell\v1.0\Modules\;C:\Program Files\MVPSI\Modules\";

Import-Module dbatools #-Scope Local -ErrorAction SilentlyContinue;
#Import-Module SQLDBATools -DisableNameChecking;
Invoke-Expression -Command "C:\Set-EnvironmentVariables.ps1";

$ExecutionLogsFile = "$$SdtLogsPath\Wrapper-EventLogs\___ExecutionLogs.txt";

$Servers = @('SqlNode01','SqlNode02','SqlNode03');
$EventIDs = @(7034,1069,2004)
#$After = (Get-Date).AddDays(-10);

TRY 
{
    if (Test-Path $ExecutionLogsFile) {
        Remove-Item $ExecutionLogsFile;
    } else {
        $f = New-Item -Path $ExecutionLogsFile -ItemType "file" -Force;
    }
    

    "Script running under context of [$($env:USERDOMAIN)\$($env:USERNAME)]
------------------------------------------------------------------------------------
------------------------------------------------------------------------------------
" | Out-File -Append $ExecutionLogsFile;
    
    $Error.Clear();
    $Command = {
    $After = (Get-Date).AddHours(-2);
    Get-EventLog -EntryType Error -LogName System -After $After | Where-Object {$_.EventID -in $EventIDs} | Select-Object TimeGenerated, MachineName, Source, EventID, EntryType, Message;
    }
    $ErrorLogs = Invoke-Command -ComputerName $Servers -ScriptBlock $Command -ErrorAction SilentlyContinue;
    $ErrorLogs | Select-Object TimeGenerated, MachineName, Source, EventID, @{l='EntryType';e={$_.EntryType.Value}}, Message `
               | Write-DbaDataTable -SqlInstance $sdtInventoryInstance -Database $sdtAutomationDatabase -Schema 'dbo' -Table 'EventLogs' -AutoCreateTable -Truncate;
    
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
