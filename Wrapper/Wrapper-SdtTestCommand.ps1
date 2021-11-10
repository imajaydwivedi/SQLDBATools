[CmdletBinding()]
Param (
    [Parameter(Mandatory=$false)]
    [string[]]$ComputerName = $env:COMPUTERNAME
)
Import-Module dbatools
Get-DbaDiskSpace $ComputerName