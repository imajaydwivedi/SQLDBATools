Get-Variable Sdt* | Remove-Variable
Remove-Module SQLDBATools

cls
robocopy "C:\Users\Public\Documents\GitHub\SQLDBATools\" "C:\Users\Public\Documents\WindowsPowerShell\Modules\SQLDBATools\" /e /is /it /MT:4 /XD Private
robocopy "C:\Users\$($env:USERNAME)\Documents\WindowsPowerShell\Modules\SQLDBATools\" "C:\Program Files\WindowsPowerShell\Modules\SQLDBATools\0.0.6\" /e /is /it /MT:4 /XD Private
Import-Module "C:\Users\$($env:USERNAME)\Documents\WindowsPowerShell\Modules\SQLDBATools" -DisableNameChecking

Get-SdtServers -Verbose

cls
& 'C:\Users\Public\Documents\GitHub\SQLDBATools\Wrapper\Wrapper-SdtTestCommand.ps1' -ComputerName 'SqlProd2' -Verbose

cls
& 'C:\Users\Public\Documents\GitHub\SQLDBATools\Wrapper\Wrapper-SdtDiskSpace.ps1' `
        -DelayMinutes 2 -WarningThresholdPercent 50 -CriticalThresholdPercent 85 `
        -Verbose -Debug

cls
$servers = @($SdtInventoryInstance,'SqlProd1')
& 'C:\Users\Public\Documents\WindowsPowerShell\Modules\SQLDBATools\Wrapper\Wrapper-SdtDiskSpace.ps1' `
        -ComputerName $servers -DelayMinutes 2 `
        -WarningThresholdPercent 50 -CriticalThresholdPercent 85 `
        -Verbose -Debug

cls
$servers = @($SdtInventoryInstance)
Alert-SdtDiskSpace -ComputerName $servers -WarningThresholdPercent 20 -CriticalThresholdPercent 50 -DelayMinutes 5 -Verbose -Debug

# CmdExec Step Type with below format of Script Call. Try both of these methods in command prompt first
powershell.exe -executionpolicy bypass C:\Users\Public\Documents\Study` Material\Wrapper-SdtTestCommand.ps1 -ComputerName 'SqlProd1'
powershell.exe -executionpolicy bypass C:\Users\Public\Documents\Study^ Material\Wrapper-SdtTestCommand.ps1 -ComputerName 'SqlProd1'

# Powershell Step Type with below format of Script Call => Working
Invoke-Command -ScriptBlock { & "C:\Users\Public\Documents\WindowsPowerShell\Modules\SQLDBATools\Wrapper\Wrapper-SdtTestCommand.ps1" -ComputerName 'SqlProd1'}

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

