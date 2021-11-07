function Get-SdtServers
{
    [CmdletBinding()]
    Param (
    )

    "Getting list from [$SdtInventoryInstance].[$SdtInventoryDatabase].[dbo].[$($SdtInventoryTable -replace 'dbo.','')].." | Write-Verbose
    $Global:SdtServers += Invoke-DbaQuery -SqlInstance $SdtInventoryInstance -Database $SdtInventoryDatabase `
                            -Query "select * from $SdtInventoryTable where is_active = 1 and monitoring_enabled = 1;"
    $Global:SdtServersList += $Global:SdtServers | Select-Object -ExpandProperty server;
    $Global:SdtServersFriendlyName += $Global:SdtServers | Select-Object -ExpandProperty friendly_name;
}