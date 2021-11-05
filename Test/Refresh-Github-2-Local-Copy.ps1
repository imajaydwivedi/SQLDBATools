cls
robocopy "C:\Users\Public\Documents\GitHub\SQLDBATools\" "C:\Users\Public\Documents\WindowsPowerShell\Modules\SQLDBATools\" /e /is /it /MT:4
Import-Module SQLDBATools -Verbose

Get-Variable sdt* | Remove-Variable
Remove-Module SQLDBATools 

Get-Module -Name SQLDBATools | SELECT *