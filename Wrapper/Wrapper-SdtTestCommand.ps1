[CmdletBinding()]
Param (
    [Parameter(Mandatory=$false)]
    [string[]]$ComputerName = $env:COMPUTERNAME
)
$isModuleFileLoaded = $false
if(Get-Module SQLDBATools) {
    Write-Verbose "Module SQLDBATools already imported in session."
    $isModuleFileLoaded = $true
}
else {
    $commandPath = Split-Path $MyInvocation.MyCommand.Path -Parent;
    $modulePathBasedOnWrapperLocation = Split-Path $PSScriptRoot -Parent;
    $moduleFileBasedOnWrapperLocation = Join-Path $modulePathBasedOnWrapperLocation 'SQLDBATools.psm1';

    if( Test-Path $moduleFileBasedOnWrapperLocation )  {
        Write-Verbose "Module file found based on wrapper file location"
        Import-Module $moduleFileBasedOnWrapperLocation -DisableNameChecking
        $isModuleFileLoaded = $true
    }

    if(-not $isModuleFileFound) {
        Write-Verbose "Loading module from `$env:PSModulePath"
        Import-Module SQLDBATools -DisableNameChecking
        $isModuleFileLoaded = $true
    }
}
@"
`nWrapper-SdtTestCommand => You called me.
`$ComputerName = '$ComputerName'
`n
"@ | Write-Output;

