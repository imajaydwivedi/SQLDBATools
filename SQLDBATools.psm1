<#
    Module Name:-   SQLDBATools
    Created By:-    Ajay Kumar Dwivedi
    Email ID:-      ajay.dwivedi2007@gmail.com
    Modified Date:- 20-June-2021
    Version:-       0.0.3
#>

Push-Location;

# Establish and enforce coding rules in expressions, scripts, and script blocks.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Check for OS version
if([bool]($PSVersionTable.PSobject.Properties.name -match "Platform")) {
    [bool]$isWin = $PSVersionTable.Platform -match '^($|(Microsoft )?Win)'
}
else {
    [bool]$isWin = $true
}
$modulePath = Split-Path $MyInvocation.MyCommand.Path -Parent;
$functionsPath = Join-Path $modulePath 'Functions'
$privatePath = Join-Path $modulePath 'Private'
$DependenciesPath = Join-Path $modulePath 'Dependencies'
$pathSeparator = if($isWin) {'\'} else {'/'}
$verbose = $false;
if ($PSBoundParameters.ContainsKey('Verbose')) { # Command line specifies -Verbose[:$false]
    $verbose = $PSBoundParameters.Get_Item('Verbose')
}

# Set basic environment variables
$envFileBase = Join-Path $DependenciesPath 'Set-SdtEnvironmentVariables.ps1'
$envFile = Join-Path $privatePath 'Set-SdtEnvironmentVariables.ps1'

# First Load Environment Variables
# File :Set-EnvironmentVariables.ps1" is also present inside Functions subdirectory with dummy values.
if($verbose) {
    Write-Host "====================================================";
    Write-Host "'Environment Variables are being loaded from '$envFile'.." -ForegroundColor Yellow;
}
# If environment variable file present
if(Test-Path $envFile) {
    Invoke-Expression -Command $envFile;
}
else {
    if(-not (Test-Path $privatePath)) {
        [System.IO.Directory]::CreateDirectory($privatePath);
    }
    Copy-Item $envFileBase -Destination $envFile | Out-Null;
    Write-Output "Environment file '$envFile' created.`nKindly modify the variable values according to your environment";
}

$M_dbatools = Get-Module -Name dbatools -ListAvailable -Verbose:$false;
if([String]::IsNullOrEmpty($M_dbatools)) {
    Write-Output 'dbatools powershell module needs to be installed. Kindly execute below command in Elevated shell:-'
    Write-Output "`tInstall-Module -Name dbatools -Scope AllUsers -Force -Confirm:`$false -Verbose:`$false'"
}

# Check for ActiveDirectory module
if ( (Get-Module -ListAvailable | Where-Object { $_.Name -eq 'ActiveDirectory' }) -eq $null )
{
    if($verbose)
    {
        Write-Host "====================================================";
        Write-Host "'ActiveDirectory' module is not installed." -ForegroundColor DarkRed;
        @"
    ** So, few functions like 'Add-SdtApplicationInfo' might not work with this module. Kindly execute below Functions to import ActiveDirectory.

        Install-Module ServerManager -Force;
        Add-WindowsFeature RSAT-AD-PowerShell;
        Install-Module ActiveDirectory -Force;

"@ | Write-Host -ForegroundColor Yellow;
    }
}


if($verbose) {
    Write-Host "====================================================";
    Write-Host "'Get-SqlServerProductKeys.psm1' Module is being loaded.." -ForegroundColor Yellow;
}
Import-Module -Name $(Join-Path $modulePath "ChildModules$($pathSeparator)Get-SqlServerProductKeys.psm1")


if($verbose) {
    Write-Host "====================================================";
    Write-Host "Loading other Functions.." -ForegroundColor Yellow;
}
foreach($file in Get-ChildItem -Path $functionsPath) {
    . ($file.FullName)
}
#Export-ModuleMember -Alias * -Function * -Cmdlet *

Push-Location;

<#
Remove-Module SQLDBATools,dbatools,SqlServer -ErrorAction SilentlyContinue;
Import-Module SQLDBATools -DisableNameChecking
#>
