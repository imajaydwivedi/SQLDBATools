Import-Module SqlServer;
Import-Module dbatools;
Remove-Module SQLDBATools -ErrorAction SilentlyContinue;
Import-Module SQLDBATools -DisableNameChecking;

$global:sdtLogErrorToInventoryTable = $true;

$env:PSModulePath = $env:PSModulePath + ";" + "C:\Program Files\WindowsPowerShell\Modules;C:\Windows\system32\WindowsPowerShell\v1.0\Modules\;C:\Program Files\MVPSI\Modules\";
$ExecutionLogsFile = "$$SdtLogsPath\Wrapper-ServerInfo\___ExecutionLogs.txt";

$tsqlInventoryServers = @"
select * from dbo.Server s where s.IsStandaloneServer = 1 or s.IsSqlCluster = 1 or s.IsAG = 1 or s.IsAgNode = 1
"@;

$Servers = Invoke-DbaQuery -SqlInstance $sdtInventoryInstance -Database $sdtInventoryDatabase -Query $tsqlInventoryServers;
foreach($Server in $Servers)
{
    Write-Host "Processing server [$($Server.FQDN)]";
    $Error.Clear();
    $ErrorText = $null;
    $CommandText = $null;

    try 
    {
        <#
        # Add-ServerInfo
        if(![string]::IsNullOrEmpty($($Server.ServerType).Trim())) {
            Add-ServerInfo -ComputerName $Server.Server -EnvironmentType $Server.ServerType -GeneralDescription $Server.ShortDescription -CallTSQLProcedure No #-Verbose
        } 
        else {
            Add-ServerInfo -ComputerName $Server.Server -GeneralDescription $Server.ShortDescription -CallTSQLProcedure No #-Verbose
        }
        #>

        Get-SQLInstanceInfo -ServerName $Server.FQDN;
        
        #$SuccessServers += $Server.Server;
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

        
        Write-Host $returnMessage -ForegroundColor Red;
    }
}

$global:sdtLogErrorToInventoryTable = $false;

