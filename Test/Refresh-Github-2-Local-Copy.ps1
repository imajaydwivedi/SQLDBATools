Get-Variable Sdt* | Remove-Variable
Remove-Module SQLDBATools

cls
robocopy "C:\Users\Public\Documents\GitHub\SQLDBATools\" "C:\Users\Public\Documents\WindowsPowerShell\Modules\SQLDBATools\" /e /is /it /MT:4
Import-Module SQLDBATools -DisableNameChecking

Get-SdtServers -Verbose

cls
C:\Users\Public\Documents\WindowsPowerShell\Modules\SQLDBATools\Wrapper\Wrapper-SdtDiskSpace.ps1 `
        -DelayMinutes 2 -WarningThresholdPercent 50 -CriticalThresholdPercent 85 `
        -Verbose -Debug

cls
$servers = @($SdtInventoryInstance,'SqlProd1')
C:\Users\Public\Documents\WindowsPowerShell\Modules\SQLDBATools\Wrapper\Wrapper-SdtDiskSpace.ps1 `
        -ComputerName $servers -DelayMinutes 2 `
        -WarningThresholdPercent 50 -CriticalThresholdPercent 85 `
        -Verbose -Debug

cls
$servers = @($SdtInventoryInstance)
Alert-SdtDiskSpace -ComputerName $servers -WarningThresholdPercent 50 -CriticalThresholdPercent 85 -DelayMinutes 5 -Verbose -Debug

# How to add inside SQL Agent Job Code
powershell.exe -executionpolicy bypass C:\Users\Public\Documents\WindowsPowerShell\Modules\SQLDBATools\Wrapper\Wrapper-SdtDiskSpace.ps1 -DelayMinutes 2 -WarningThresholdPercent 80 -CriticalThresholdPercent 90 -FailureNotifyThreshold 3

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
from dbo.sdt_alert a with (nolock)
where alert_key = 'Alert-SdtDiskSpace'
go
#>

