# Cleanup
Get-Variable Sdt* | Remove-Variable
Remove-Module SQLDBATools

cls
Get-SdtServers -Verbose
#$servers = @('SqlDr1','SqlProd1')
$servers = $SdtFriendlyNameList
Alert-SdtDiskSpace -ComputerName $servers -WarningThresholdPercent 65 -CriticalThresholdPercent 80 -DelayMinutes 1 -Verbose -Debug


# Copy files from b/w directories. Ensure not to add '\' at end of path
cls
$srcPath = "C:\Users\$($env:USERNAME)\Documents\WindowsPowerShell\Modules\SQLDBATools"
#$dstPath = "C:\Program Files\WindowsPowerShell\Modules\SQLDBATools\0.0.7"
#$srcPath = "C:\Users\Public\Documents\GitHub\SQLDBATools"
#$dstPath = "C:\Users\$($env:USERNAME)\Documents\WindowsPowerShell\Modules\SQLDBATools"
#$dstPath = "C:\Users\Public\Documents\WindowsPowerShell\Modules\SQLDBATools"
$dstPath = "C:\Users\adwivedi\Documents\SQLDBATools"
robocopy $srcPath $dstPath /e /is /it /MT:4 /XD Private Logs

# Import module by manual path specification
Import-Module SQLDBATools -DisableNameChecking
Import-Module "C:\Program Files\WindowsPowerShell\Modules\SQLDBATools\0.0.7\SQLDBATools" -DisableNameChecking
Import-Module "C:\Users\$($env:USERNAME)\Documents\WindowsPowerShell\Modules\SQLDBATools" -DisableNameChecking


# Unblock files if getting untrusted non signed warnings
Get-ChildItem -Recurse | Unblock-File

# Test function
Get-SdtServers -Verbose

cls
& 'C:\Users\Public\Documents\GitHub\SQLDBATools\Wrapper\Wrapper-SdtTestCommand.ps1' -ComputerName 'SqlProd2' -Verbose

cls
& 'C:\Users\Public\Documents\GitHub\SQLDBATools\Wrapper\Wrapper-SdtDiskSpace.ps1' `
        -DelayMinutes 2 -WarningThresholdPercent 50 -CriticalThresholdPercent 85 `
        -Verbose -Debug

cls
Get-SdtServers -Verbose
$servers = @('SqlDr1','SqlProd1')
#$servers = $SdtFriendlyNameList
& "C:\Users\$($env:USERNAME)\Documents\WindowsPowerShell\Modules\SQLDBATools\Wrapper\Wrapper-SdtDiskSpace.ps1" `
        -DelayMinutes 1 -WarningThresholdPercent 65 -CriticalThresholdPercent 85 `
        -Debug `
        -ComputerName $servers -Verbose `

cls
Get-SdtServers -Verbose
$servers = @('SqlDr1','SqlProd1')
Alert-SdtDiskSpace -ComputerName $servers -WarningThresholdPercent 60 -CriticalThresholdPercent 85 -DelayMinutes 1 -Verbose -Debug

# CmdExec Step Type with below format of Script Call. Try both of these methods in command prompt first
powershell.exe -executionpolicy bypass -Noninteractive C:\Program` Files\WindowsPowerShell\Modules\SQLDBATools\0.0.8\Wrapper\Wrapper-SdtDiskSpace.ps1 -WarningThresholdPercent 30 -CriticalThresholdPercent 50 -DelayMinutes 2
powershell.exe -executionpolicy bypass C:\Program` Files\WindowsPowerShell\Modules\SQLDBATools\0.0.8\Wrapper\Wrapper-SdtTestCommand.ps1 -ComputerName 'SqlProd1'

# Powershell Step Type with below format of Script Call => Working
Invoke-Command -ScriptBlock { & "C:\Users\Public\Documents\WindowsPowerShell\Modules\SQLDBATools\Wrapper\Wrapper-SdtTestCommand.ps1" -ComputerName 'SqlProd1'}
Invoke-Command -ScriptBlock { & 'C:\Program Files\WindowsPowerShell\Modules\SQLDBATools\0.0.8\Wrapper\Wrapper-SdtDiskSpace.ps1' -WarningThresholdPercent 30 -CriticalThresholdPercent 50 -DelayMinutes 5 }

<#
use DBA
go

select GETDATE() as srv_time, GETUTCDATE() as utc_time, *
from dbo.sdt_server_inventory
go

select DATEDIFF(minute,last_notified_date_utc,GETUTCDATE()) as last_notified_minutes, 
		[is_suppressed_valid] = case when state = 'Suppressed' and (GETUTCDATE() between a.suppress_start_date_utc and a.suppress_end_date_utc) then 1 else 0 end,
		*
--update a set [state] = 'Suppressed', suppress_start_date_utc = GETUTCDATE(), suppress_end_date_utc = DATEADD(minute,20,GETUTCDATE())
--update a set [state] = 'Suppressed', suppress_end_date_utc = DATEADD(minute,2,suppress_start_date_utc)
--delete a
from dbo.sdt_alert a with (nolock)
--where alert_key = 'Alert-SdtDiskSpace'
order by created_date_utc desc
-- truncate table dbo.sdt_alert
go

select *
from dbo.sdt_alert_rules ar
go

/*
insert dbo.sdt_alert_rules (alert_key, server_friendly_name, severity, alert_receiver, alert_receiver_name, reference_request)
select 'Alert-SdtDiskSpace','SqlProd1',NULL,'ajay.dwivedi2007@gmail.com','Ajay','Testing'
union all
select 'Alert-SdtDiskSpace','SqlDr1',NULL,'ajay.dwivedi2007@gmail.com','Ajay','Testing'
*/

/*
if object_id('tempdb..#sdt_alert_rules_by_server') is not null
	drop table #sdt_alert_rules_by_server;
if object_id('tempdb..#sdt_alert_rules_by_owner') is not null
	drop table #sdt_alert_rules_by_owner;

select ar.rule_id, ar.alert_key, ar.server_friendly_name, i.server_owner, ar.alert_receiver
into #sdt_alert_rules_by_server
from dbo.sdt_alert_rules ar left join dbo.sdt_server_inventory i on i.friendly_name = ar.server_friendly_name
where ar.alert_key = 'Alert-SdtDiskSpace'
and ar.server_friendly_name in ('SqlProd1','SqlDr1','SqlProd2','Sqldr2','SqlProd3','SqlDr3')

select ar.rule_id, ar.alert_key, ar.server_friendly_name, i.server_owner, ar.alert_receiver
into #sdt_alert_rules_by_owner
from dbo.sdt_server_inventory i left join dbo.sdt_alert_rules ar on i.server_owner = ar.server_owner
where ar.alert_key = 'Alert-SdtDiskSpace'
and i.friendly_name in ('SqlProd1','SqlDr1','SqlProd2','Sqldr2','SqlProd3','SqlDr3')

select *
from #sdt_alert_rules_by_server s

select *
from #sdt_alert_rules_by_owner o
*/
#>

