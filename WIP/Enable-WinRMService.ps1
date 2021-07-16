Import-Module SqlServer;
Import-Module dbatools;
Import-Module SQLDBATools -DisableNameChecking;

$tsqlInventoryServers = @"
select ServerName from [SQLDBATools].[Staging].[CollectionErrors] as e with(nolock) where e.Command like '%Invoke-Command%'
"@;

$Servers = Invoke-DbaQuery -SqlInstance $sdtInventoryInstance -Query $tsqlInventoryServers;

$CommandText = @();
foreach($Server in $Servers)
{
    $cmd = @"

psexec.exe \\$($Server.ServerName) -s powershell Enable-PSRemoting -Force
"@;
    $CommandText += $cmd;
}

$CommandText | ogv