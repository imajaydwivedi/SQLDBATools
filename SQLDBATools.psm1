<#
    Module Name:-   SQLDBATools
    Created By:-    Ajay Kumar Dwivedi
    Email ID:-      ajay.dwivedi2007@gmail.com
    Modified Date:- 15-Feb-2023
    Version:-       0.0.14
#>

Push-Location;

# Establish and enforce coding rules in expressions, scripts, and script blocks.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Verbose "Inside '$MyInvocation.MyCommand.Path'"

# Check for OS version
if([bool]($PSVersionTable.PSobject.Properties.name -match "Platform")) {
    [bool]$isWin = $PSVersionTable.Platform -match '^($|(Microsoft )?Win)'
}
else {
    [bool]$isWin = $true
}
$global:SdtModulePath = Split-Path $MyInvocation.MyCommand.Path -Parent;
$global:SdtFunctionsPath = Join-Path $SdtModulePath 'Functions'
$global:SdtPrivatePath = Join-Path $SdtModulePath 'Private'
$global:SdtDependenciesPath = Join-Path $SdtModulePath 'Dependencies'

$global:SdtPathSeparator = if($isWin) {'\'} else {'/'}
$verbose = $false;
if ($PSBoundParameters.ContainsKey('Verbose')) { # Command line specifies -Verbose[:$false]
    $verbose = $PSBoundParameters.Get_Item('Verbose')
}

# Set basic environment variables
$global:SdtBaseEnvFile = Join-Path $SdtDependenciesPath 'Set-SdtEnvironmentVariables.ps1'
$global:SdtEnvFile = Join-Path $SdtPrivatePath 'Set-SdtEnvironmentVariables.ps1'
$global:SdtModuleVersion = (Get-Module -ListAvailable $SdtModulePath).Version

# Save variables created within *.psm1 file
$global:SdtModuleVariables = Get-Variable Sdt*

# Get variables defined in Base Env File on SdtDependenciesPath
$envFileBaseContent = Get-Content $SdtBaseEnvFile
$global:SdtBaseEnvVariablesList = @()
foreach($line in $envFileBaseContent) {
    if($line -match '^\$global:(?<varName>Sdt\w+)\s') {
        $global:SdtBaseEnvVariablesList += $Matches['varName']
    }
}

$isEnvFileLoaded = $false
$blockLoadEnvFile = { & "$SdtEnvFile" }

# First Load Environment Variables
if($verbose) {
    Write-Host "====================================================";
    Write-Host "'Environment Variables are being loaded from '$envFile'.." -ForegroundColor Yellow;
}
# If environment variable file present
if(Test-Path $SdtEnvFile) {
    Invoke-Command -ScriptBlock $blockLoadEnvFile -NoNewScope
    $isEnvFileLoaded = $true

    # Create Logs Directory
    if( -not (Test-Path $SdtLogsPath) ) { [System.IO.Directory]::CreateDirectory($SdtLogsPath) | Out-Null }
}
else {
    if(-not (Test-Path $SdtPrivatePath)) { # create Private folder
        [System.IO.Directory]::CreateDirectory($SdtPrivatePath);
    }
    [String]$previousEnvFile = $null
    if(-not(Test-Path $SdtEnvFile))
    { # check for Env file in Private folder
        if((Split-Path $SdtModulePath -Leaf) -ne 'SQLDBATools') {
            "SQLDBATools Module was installed using Install-Module cmdlet" | Write-Verbose
            "Trying to check for previous version 'Set-SdtEnvironmentVariables.ps1' file" | Write-Verbose
            $previousModule = Get-Module SQLDBATools -ListAvailable `
                                    | Where-Object {$_.ModuleBase -like "$(Split-Path $SdtModulePath -Parent)*" -and $_.Version -lt $SdtModuleVersion} `
                                    | Sort-Object Version -Descending | Select-Object -First 1
            if([String]::IsNullOrEmpty($previousModule)) {
                "No previous version installation found. So no settings to import." | Write-Verbose
            }
            else {
                "Previous version installation found. Trying to import settings from it" | Write-Verbose
                $previousEnvFile = "$($previousModule.ModuleBase)\Private\Set-SdtEnvironmentVariables.ps1"
                if(Test-Path $previousEnvFile) {
                    Copy-Item $previousEnvFile -Destination $SdtEnvFile | Out-Null;
                }
            }
        }
        else {
            "SQLDBATools Module was not installed using Install-Module cmdlet" | Write-Verbose
        }
    }
    if([String]::IsNullOrEmpty($previousEnvFile) -or (-not (Test-Path $previousEnvFile)) ) {
        Copy-Item $SdtBaseEnvFile -Destination $SdtEnvFile | Out-Null;
        Write-Output "Environment file '$SdtEnvFile' created.`nKindly modify the variable values according to your environment";
    }
    Invoke-Command -ScriptBlock $blockLoadEnvFile -NoNewScope
    $isEnvFileLoaded = $true
}

# Validate Private\EnvFile with Dependencies\EnvFile for variable counts
if($isEnvFileLoaded) {
    $sdtEnvVariables = @()
    $sdtEnvVariables += (Get-Variable Sdt* -Scope Global | Where-Object {$_.Name -notin @($SdtModuleVariables.Name)})
    $missingVariables = @()
    if($sdtEnvVariables.Count -gt 0) {
        $missingVariables += ($SdtBaseEnvVariablesList | ForEach-Object {if($_ -notin $sdtEnvVariables.Name){$_}})
    }
    else {
        $missingVariables += $SdtBaseEnvVariablesList
    }

    if($missingVariables.Count -ne 0 -and $SdtEnableInventory) {
        Write-Error "`n$('*'*60)`nFollowing Environment Variables are missing =>`n$('-'*15)`n$($missingVariables -join ', ')`n$('-'*15)`nKindly copy above specific variables `nfrom `t '$SdtBaseEnvFile' `nto `t`t'$SdtEnvFile'`n`n$('*'*60)`n" -ErrorAction Stop
    }
}

$M_dbatools = Get-Module -Name dbatools -ListAvailable -Verbose:$false;
if([String]::IsNullOrEmpty($M_dbatools)) {
    Write-Output 'dbatools powershell module needs to be installed. Kindly execute below command in Elevated shell:-'
    Write-Output "`tInstall-Module -Name dbatools -Scope AllUsers -Force -Confirm:`$false -Verbose:`$false'"
}
elseif ($isEnvFileLoaded)
{ # If dbatools is present and environment variables are loaded, then check for required tables
    
    # if Inventory setup has to be done
    if($SdtEnableInventory)
    {
        # $SdtInventoryTable
        $r = Invoke-DbaQuery -SqlInstance $SdtInventoryInstance -Database $SdtInventoryDatabase `
                        -Query "select [exists] = convert(bit,(case when object_id('$SdtInventoryTable') is not null then 1 else 0 end));" -EnableException
        if(-not $r.exists)
        { # Inventory table does not exist
            $message = "Table '$SdtInventoryTable' not found in [$SdtInventoryDatabase] database of [$SdtInventoryInstance] server.
    `nIf already existing in another server/database, then update `$SdtInventoryInstance & `$SdtInventoryDatabase variables in 'SQLDBATools\Private\Set-SdtEnvironmentVariables.ps1' file.
    `nIf not existing anywhere, then kindly create it in [$SdtInventoryInstance].[$SdtInventoryDatabase] database using below tsql -
    `n`n$SdtInventoryTableDefinitionSql`n"
            Write-Warning -Message $message;
        }
        else
        { # Inventory table exists. So validate required columns
            Invoke-DbaQuery -SqlInstance $SdtInventoryInstance -Database 'tempdb' -Query $SdtInventoryTableDefinitionSql -ErrorAction Ignore | Out-Null;
            $r = Invoke-DbaQuery -SqlInstance $SdtInventoryInstance -Database 'tempdb' `
                            -Query @"
    set nocount on;
    go

    select [exists] = convert(bit,(case when exists (
    select *
    from tempdb.INFORMATION_SCHEMA.COLUMNS t with (nolock)
    left join $SdtInventoryDatabase.INFORMATION_SCHEMA.COLUMNS i with (nolock)
	    on t.TABLE_SCHEMA = i.TABLE_SCHEMA and t.TABLE_NAME = i.TABLE_NAME
	    and t.COLUMN_NAME = i.COLUMN_NAME
    where (t.TABLE_SCHEMA+'.'+t.TABLE_NAME) = '$SdtInventoryTable'
    and i.COLUMN_NAME is null
    ) then 0 else 1 end))
    go
"@
            if(-not $r.exists) # If required columns not found
            {
                $message = "Table '$SdtInventoryTable' in [$SdtInventoryInstance].[$SdtInventoryDatabase] does not have matching columns required.
        `nKindly update table columns according to definition mentioned in 'SQLDBATools\Private\Set-SdtEnvironmentVariables.ps1' file.
        `n`n$SdtInventoryTableDefinitionSql`n"
                Write-Warning -Message $message;
            }
        }

        # $SdtAlertTable
        $r = Invoke-DbaQuery -SqlInstance $SdtInventoryInstance -Database $SdtInventoryDatabase `
                        -Query "select [exists] = convert(bit,(case when object_id('$SdtAlertTable') is not null then 1 else 0 end));"
        if(-not $r.exists)
        {
            $message = "Table '$SdtAlertTable' not found in [$SdtInventoryDatabase] database of [$SdtInventoryInstance] server.
    `nKindly create it in [$SdtInventoryInstance].[$SdtInventoryDatabase] database using below tsql -
    `n`n$SdtAlertTableDefinitionSql`n"
            Write-Warning -Message $message;
        }


        # $SdtErrorTable
        $r = Invoke-DbaQuery -SqlInstance $SdtInventoryInstance -Database $SdtInventoryDatabase `
                        -Query "select [exists] = convert(bit,(case when object_id('$SdtErrorTable') is not null then 1 else 0 end));"
        if(-not $r.exists)
        {
            $message = "Table '$SdtErrorTable' not found in [$SdtInventoryDatabase] database of [$SdtInventoryInstance] server.
    `nKindly create it in [$SdtInventoryInstance].[$SdtInventoryDatabase] database using below tsql -
    `n`n$SdtErrorTableDefinitionSql`n"
            Write-Warning -Message $message;
        }


        # $SdtAlertRulesTable
        $r = Invoke-DbaQuery -SqlInstance $SdtInventoryInstance -Database $SdtInventoryDatabase `
                        -Query "select [exists] = convert(bit,(case when object_id('$SdtAlertRulesTable') is not null then 1 else 0 end));"
        if(-not $r.exists)
        {
            $message = "Table '$SdtAlertRulesTable' not found in [$SdtInventoryDatabase] database of [$SdtInventoryInstance] server.
    `nKindly create it in [$SdtInventoryInstance].[$SdtInventoryDatabase] database using below tsql -
    `n`n$SdtAlertRulesTableDefinitionSql`n"
            Write-Warning -Message $message;
        }
    }
}

<#
# Check for SqlServer PS Module
$M_SqlServer = Get-Module -Name SqlServer -ListAvailable -Verbose:$false;
if([String]::IsNullOrEmpty($M_SqlServer)) {
    Write-Output 'SqlServer powershell module needs to be installed. Kindly execute below command in Elevated shell:-'
    Write-Output "`tInstall-Module -Name SqlServer -Scope AllUsers -Force -Confirm:`$false -Verbose:`$false'"
}
#>

$M_PoshRSJob = Get-Module -Name PoshRSJob -ListAvailable -Verbose:$false;
if([String]::IsNullOrEmpty($M_PoshRSJob)) {
    Write-Output 'PoshRSJob powershell module needs to be installed. Kindly execute below command in Elevated shell:-'
    Write-Output "`tInstall-Module -Name PoshRSJob -Scope AllUsers -Force -Confirm:`$false -Verbose:`$false'"
}

$M_ImportExcel = Get-Module -Name ImportExcel -ListAvailable -Verbose:$false;
if([String]::IsNullOrEmpty($M_ImportExcel)) {
    Write-Output 'ImportExcel powershell module needs to be installed. Kindly execute below command in Elevated shell:-'
    Write-Output "`tInstall-Module -Name ImportExcel -Scope AllUsers -Force -Confirm:`$false -Verbose:`$false'"
}

$M_EnhancedHTML2 = Get-Module -Name EnhancedHTML2 -ListAvailable -Verbose:$false;
if([String]::IsNullOrEmpty($M_EnhancedHTML2)) {
    Write-Output 'EnhancedHTML2 powershell module needs to be installed. Kindly execute below command in Elevated shell:-'
    Write-Output "`tInstall-Module -Name EnhancedHTML2 -Scope AllUsers -Force -Confirm:`$false -Verbose:`$false'"
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
Import-Module -Name $(Join-Path $SdtModulePath "ChildModules$($SdtPathSeparator)Get-SqlServerProductKeys.psm1")


if($verbose) {
    Write-Host "====================================================";
    Write-Host "Loading other Functions.." -ForegroundColor Yellow;
}
foreach($file in Get-ChildItem -Path $SdtFunctionsPath) {
    . ($file.FullName)
}
#Export-ModuleMember -Alias * -Function * -Cmdlet *

Push-Location;

<#
Get-Variable Sdt* | Remove-Variable
Remove-Module SQLDBATools,dbatools,SqlServer -ErrorAction SilentlyContinue;
Import-Module SQLDBATools -DisableNameChecking
#>
