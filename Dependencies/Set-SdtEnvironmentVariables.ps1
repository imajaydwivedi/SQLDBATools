Set-Variable -Name sdtInventoryInstance -Value 'InventoryInstance' -Scope Global;
Set-Variable -Name sdtInventoryDatabase -Value 'SQLDBATools' -Scope Global;
Set-Variable -Name sdtSQLDBATools_ResultsDirectory -Value $(Join-Path $env:USERPROFILE 'SQLDBATools') -Scope Global;
Set-Variable -Name sdtInventoryErrorLogsTable -Value '[staging].[collection_errors]' -Scope Global;
Set-Variable -Name sdtDBAMailId -Value 'dba@domain.local' -Scope Global;
Set-Variable -Name sdtDBAGroupMailId -Value 'DBAGroup@domain.local' -Scope Global;
Set-Variable -Name sdtDbaDatabase -Value 'DBA' -Scope Global;
Set-Variable -Name sdtAutomationDatabase -Value 'SQLDBATools' -Scope Global;
Set-Variable -Name sdtLogErrorToInventoryTable -Value $false -Scope Global;
Set-Variable -Name sdtPrintUserFriendlyMessage -Value $false -Scope Global;
Set-Variable -Name sdtSQLDBATools_ServiceAccount -Value "$($env:USERDOMAIN)\SQLDBATools" -Scope Global;
Set-Variable -Name sdtSQL_Server_Setups -Value 'itserver\it\SQL_Server_Setups\' -Scope Global;

