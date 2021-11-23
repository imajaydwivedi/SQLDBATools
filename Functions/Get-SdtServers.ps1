function Get-SdtServers
{
    [CmdletBinding()]
    Param (
    )

    "Getting list from [$SdtInventoryInstance].[$SdtInventoryDatabase].[dbo].[$($SdtInventoryTable -replace 'dbo.','')].." | Write-Verbose
    $Global:SdtInventoryTableData += Invoke-DbaQuery -SqlInstance $SdtInventoryInstance -Database $SdtInventoryDatabase `
                            -Query "select * from $SdtInventoryTable where is_active = 1 and monitoring_enabled = 1;"
    $Global:SdtServerList += $Global:SdtInventoryTableData | Select-Object -ExpandProperty server -Unique ;
    $Global:SdtFriendlyNameList += $Global:SdtInventoryTableData | Select-Object -ExpandProperty friendly_name -Unique ;
    $Global:SdtSqlInstanceList += $Global:SdtInventoryTableData | Select-Object -ExpandProperty sql_instance -Unique ;
}
