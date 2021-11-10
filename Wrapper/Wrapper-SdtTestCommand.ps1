[CmdletBinding()]
Param (
    [Parameter(Mandatory=$false)]
    [string[]]$ComputerName = $env:COMPUTERNAME
)
$isModuleFileFound = $false
$commandPath = Split-Path $MyInvocation.MyCommand.Path -Parent;
$modulePathBasedOnWrapperLocation = Split-Path $PSScriptRoot -Parent;
$moduleFileBasedOnWrapperLocation = Join-Path $modulePathBasedOnWrapperLocation 'SQLDBATools.psm1';

if( Test-Path $moduleFileBasedOnWrapperLocation )  {
    Write-Verbose "Module file found based on wrapper file location"
    $isModuleFileFound = $true
    Import-Module $moduleFileBasedOnWrapperLocation -DisableNameChecking
}

if(-not $isModuleFileFound) {
    Write-Verbose "Loading module from `$env:PSModulePath"
    Import-Module SQLDBATools -DisableNameChecking
}

@"
`nWrapper-SdtTestCommand => You called me.
`$ComputerName = '$ComputerName'
`n
"@ | Write-Output;

