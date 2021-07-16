Import-Module SqlServer;
Import-Module dbatools;
Import-Module SQLDBATools -DisableNameChecking;

$global:sdtLogErrorToInventoryTable = $true;

$env:PSModulePath = $env:PSModulePath + ";" + "C:\Program Files\WindowsPowerShell\Modules;C:\Windows\system32\WindowsPowerShell\v1.0\Modules\;C:\Program Files\MVPSI\Modules\";
$ExecutionLogsFile = "$sdtSQLDBATools_ResultsDirectory\Logs\Wrapper-ServerInfo\___ExecutionLogs.txt";

$tsqlInventoryServers = @"
select case when s.Domain = 'Corporate' then server+'.corporate.local'
				when s.Domain = 'Armus' then server+'.tvguide.com'
				when s.Domain = 'Angoss' then server+'.angoss.local'
				else Server
				end as Server, 
            case when s.ServerType = 'Development' then 'Dev'
					 when s.ServerType = 'Production ' then 'Prod'
					 when s.ServerType = 'Cluster Instance ' then 'Prod'
					 else null
				end as ServerType, 
            s.ShortDescription 
from [YourOrgSQLInventory].dbo.Server s
where Domain not in ('Armus','Angoss')
"@;

$Servers = Invoke-DbaQuery -SqlInstance $sdtInventoryInstance -Query $tsqlInventoryServers;
$SuccessServers = @();
$FailedServers = @();
foreach($Server in $Servers)
{
    Write-Host "Processing server [$($Server.Server)]";
    $Error.Clear();
    $ErrorText = $null;
    $CommandText = $null;

    try 
    {
        # Validation 01:- Ping Validation
        $ErrorText = "Server not reachable using Ping";
        $CommandText = "Test-Connection -ComputerName $($Server.Server) -Count 1 -Quiet";
        if ((Test-Connection -ComputerName $Server.Server -Count 1 -Quiet) -eq $false) {
            throw $Message;
        }

        # Validation 02:- WinRM Service
        $ErrorText = "WinRM service not running";
        $CommandText = "Invoke-Command -ComputerName $($Server.Server) -ScriptBlock {`$PSVersionTable}";
        $o = Invoke-Command -ComputerName $Server.Server -ScriptBlock {$PSVersionTable} -ErrorAction Stop | Out-Null;

        # Validation 03:- Sql Connection
        $ErrorText = "SQL Connection Failed";
        $CommandText = "Invoke-DbaQuery -SqlInstance $($Server.Server) -Query 'select @@servername'";
        $r = Invoke-DbaQuery -SqlInstance $Server.Server -Query 'select @@servername' -ErrorAction Stop -WarningAction Stop;

        # Add-ServerInfo
        if(![string]::IsNullOrEmpty($($Server.ServerType).Trim())) {
            Add-ServerInfo -ComputerName $Server.Server -EnvironmentType $Server.ServerType -GeneralDescription $Server.ShortDescription -CallTSQLProcedure No #-Verbose
        } 
        else {
            Add-ServerInfo -ComputerName $Server.Server -GeneralDescription $Server.ShortDescription -CallTSQLProcedure No #-Verbose
        }
        
        $SuccessServers += $Server.Server;
    }
    catch {
        $returnMessage = $null;
        $formatstring = "{0} : {1}`n{2}`n" +
                    "    + CategoryInfo          : {3}`n" +
                    "    + FullyQualifiedErrorId : {4}`n"
        $fields = $_.InvocationInfo.MyCommand.Name,
                  $_.ErrorDetails.Message,
                  $_.InvocationInfo.PositionMessage,
                  $_.CategoryInfo.ToString(),
                  $_.FullyQualifiedErrorId

        $returnMessage = $formatstring -f $fields;

        @"


Error:- 

    $returnMessage
"@ | Out-File -Append $ExecutionLogsFile;

        
        # If Invoke-DbaQuery error
        if($ErrorText -eq "SQL Connection Failed") {
            $returnMessage = @"

$ErrorText
$($_.Exception.Message)


"@ + $returnMessage;
        } else {
            $returnMessage = @"

$ErrorText

"@ + $returnMessage;
        }

        if($sdtLogErrorToInventoryTable) {
            Add-CollectionError -ComputerName $Server.Server `
                                -Cmdlet 'Wrapper-ServerInfo' `
                                -CommandText $CommandText `
                                -ErrorText $returnMessage `
                                -Remark "$ErrorText";
        } else {
            Write-Verbose $returnMessage;
        }

        $FailedServers += $Server.Server;
    }
}

$global:sdtLogErrorToInventoryTable = $false;

$SuccessServers | ogv -Title "Successfully connected Servers"
$FailedServers | ogv -Title "Servers with failed connection"
