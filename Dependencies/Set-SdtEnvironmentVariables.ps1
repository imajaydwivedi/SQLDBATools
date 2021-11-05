Set-Variable -Name SdtInventoryInstance -Value 'InventoryInstance' -Scope Global;
Set-Variable -Name SdtInventoryDatabase -Value 'SQLDBATools' -Scope Global;
Set-Variable -Name SdtSQLDBATools_ResultsDirectory -Value $(Join-Path $env:USERPROFILE 'SQLDBATools') -Scope Global;
Set-Variable -Name SdtInventoryErrorLogsTable -Value '[staging].[collection_errors]' -Scope Global;
Set-Variable -Name SdtDBAMailId -Value 'dba@domain.local' -Scope Global;
Set-Variable -Name SdtDBAGroupMailId -Value 'DBAGroup@domain.local' -Scope Global;
Set-Variable -Name SdtDbaDatabase -Value 'DBA' -Scope Global;
Set-Variable -Name SdtAutomationDatabase -Value 'SQLDBATools' -Scope Global;
Set-Variable -Name SdtLogErrorToInventoryTable -Value $false -Scope Global;
Set-Variable -Name SdtPrintUserFriendlyMessage -Value $false -Scope Global;
Set-Variable -Name SdtSQLDBATools_ServiceAccount -Value "$($env:USERDOMAIN)\SQLDBATools" -Scope Global;
Set-Variable -Name SdtSQL_Server_Setups -Value 'itserver\it\SQL_Server_Setups\' -Scope Global;

