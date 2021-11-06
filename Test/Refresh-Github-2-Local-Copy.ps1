Get-Variable Sdt* | Remove-Variable
Remove-Module SQLDBATools

cls
robocopy "C:\Users\Public\Documents\GitHub\SQLDBATools\" "C:\Users\Public\Documents\WindowsPowerShell\Modules\SQLDBATools\" /e /is /it /MT:4
Import-Module SQLDBATools -DisableNameChecking

cls
C:\Users\Public\Documents\WindowsPowerShell\Modules\SQLDBATools\Wrapper\Wrapper-SdtDiskSpace.ps1 -DelayMinutes 5 -Verbose -Debug

