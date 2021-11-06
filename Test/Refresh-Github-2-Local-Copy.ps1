cls
robocopy "C:\Users\Public\Documents\GitHub\SQLDBATools\" "C:\Users\Public\Documents\WindowsPowerShell\Modules\SQLDBATools\" /e /is /it /MT:4
Import-Module SQLDBATools -DisableNameChecking

Get-Variable Sdt* | Remove-Variable
Remove-Module SQLDBATools

