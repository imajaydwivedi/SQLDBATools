[CmdletBinding()]
Param (
    [Parameter(Mandatory=$false)]
    [Alias('ServerName','MachineName')]
    [string[]]$ComputerName,
    [Parameter(Mandatory=$false)]
    [string[]]$ExcludeDrive,
    [Parameter(Mandatory=$false)]
    [decimal]$WarningThresholdPercent = 75.0,
    [Parameter(Mandatory=$false)]
    [decimal]$CriticalThresholdPercent = 85.0,
    [Parameter(Mandatory=$false)]
    [int]$FailureNotifyThreshold = 3,
    [Parameter(Mandatory=$false)]
    [string[]]$EmailTo,
    [Parameter(Mandatory=$false)]
    [int]$DelayMinutes = 60,
    [Parameter(Mandatory=$false)]
    [int]$LogRetentionMinutes = 10080 # 7 days
)

# Set Initial Variables
$startTime = Get-Date
$dtmm = $startTime.ToString('yyyy-MM-dd HH.mm.ss')
$script = $MyInvocation.MyCommand.Name
if([String]::IsNullOrEmpty($Script)) {
    $Script = 'Wrapper-SdtDiskSpace.ps1'
}

# Fetch Verbose & Debug Preference
$verbose = $false;
if ($PSBoundParameters.ContainsKey('Verbose')) { # Command line specifies -Verbose[:$false]
    $verbose = $PSBoundParameters.Get_Item('Verbose')
}
$debug = $false;
if ($PSBoundParameters.ContainsKey('Debug')) { # Command line specifies -Verbose[:$false]
    $debug = $PSBoundParameters.Get_Item('Debug')
}
$verboseDebugPreferences = @{Verbose = $verbose; Debug = $debug}

# Load SQLDBATools
$isModuleFileLoaded = $false
if(Get-Module SQLDBATools) {
    Write-Output "Module SQLDBATools already imported in session."
    $isModuleFileLoaded = $true
}
else {
    Write-Output "Looking for location of SQLDBATools module to import.."
    $commandPath = Split-Path $MyInvocation.MyCommand.Path -Parent;
    $modulePathBasedOnWrapperLocation = Split-Path $PSScriptRoot -Parent;
    $moduleFileBasedOnWrapperLocation = Join-Path $modulePathBasedOnWrapperLocation 'SQLDBATools.psm1';

    if( Test-Path $moduleFileBasedOnWrapperLocation )  {
        Write-Output "Module file found based on wrapper file location"
        "Import-Module `"$moduleFileBasedOnWrapperLocation`" -DisableNameChecking" | Write-Output
        Import-Module "$moduleFileBasedOnWrapperLocation" -DisableNameChecking
        $isModuleFileLoaded = $true
    }

    if(-not $isModuleFileFound) {
        Write-Output "Loading module from `$env:PSModulePath"
        Import-Module SQLDBATools -DisableNameChecking
        $isModuleFileLoaded = $true
    }
}


# Set $EmailTo to DBA Group
if([String]::IsNullOrEmpty($EmailTo)) {
    $EmailTo = @($SdtDBAGroupMailId)
}

# Log files
$statusLogFile = $(Join-Path $SdtLogsPath $($Script.Replace('.ps1','__Status.txt')))
$executionLogFile = $(Join-Path $SdtLogsPath $($Script.Replace('.ps1',"__Log__$($dtmm).txt")))

# Set Error variables
"`n{0} {1,-10} {2}" -f "($((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))","(START)","Execute script '$Script'.." | Tee-Object $executionLogFile -Append | % {"`n`n`n`n`n$_"} | Write-Output
$isCustomError = $false
$isScriptError = $false
[bool]$isVerbose = $false;
if( ($PSCmdlet -ne $null -and $PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent) -or $VerbosePreference -eq 'Continue' ) {
    $isVerbose = $true
}

# Remove Old log files
"{0} {1,-10} {2}" -f "($((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))","(INFO)","Remove log files older than $LogRetentionMinutes minutes.." | Tee-Object $executionLogFile -Append | Write-Output
Get-ChildItem -Path "$SdtLogsPath\$($Script.Replace('.ps1',"__Log__*.txt"))" -Force `
        | Where-Object {$_.PSIsContainer -eq $false -and $_.LastAccessTime -lt (Get-Date).AddMinutes(-$LogRetentionMinutes) } `
        | Remove-Item | Out-Null

# Read Last Execution Status
[int]$lastRunStatus = 0
"{0} {1,-10} {2}" -f "($((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))","(INFO)","Create log file '$statusLogFile' if not exists.." | Tee-Object $executionLogFile -Append | Write-Output
if(-not (Test-Path $statusLogFile)) {
    New-Item -Path $statusLogFile -Force -ItemType File | Out-Null
    $lastRunStatus | Out-File -FilePath $statusLogFile -Append
    #Get-Content $LogFile
}
else {
    "{0} {1,-10} {2}" -f "($((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))","(INFO)","Get last run status from status file '$statusLogFile'.." | Tee-Object $executionLogFile -Append | Write-Output
    [int]$lastRunStatus = (Get-Content $statusLogFile | select -First 1| Out-String ) # First line contains continous failure state
    "{0} {1,-10} {2}" -f "($((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))","(INFO)","Last run status was $lastRunStatus" | Tee-Object $executionLogFile -Append | Write-Output
}

try
{
    "{0} {1,-10} {2}" -f "($((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))","(INFO)","ComputerName not provided." | Tee-Object $executionLogFile -Append | Write-Output
    if([String]::IsNullOrEmpty($ComputerName)) {
        "{0} {1,-10} {2}" -f "($((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))","(INFO)","Fetch list of servers from Inventory.." | Tee-Object $executionLogFile -Append | Write-Output
        if($SdtInventoryTableData.Count -eq 0) {
            Get-SdtServers -Verbose
        }
        $ComputerName = @()
        $ComputerName += $SdtServerList;
    }

    #1/0;
    "{0} {1,-10} {2}" -f "($((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))","(INFO)","Execute Alert-SdtDiskSpace.." | Tee-Object $executionLogFile -Append | Write-Output
    Alert-SdtDiskSpace -ComputerName $ComputerName -DelayMinutes $DelayMinutes -WarningThresholdPercent $WarningThresholdPercent `
                -CriticalThresholdPercent $CriticalThresholdPercent -ExcludeDrive $ExcludeDrive -EmailTo $EmailTo @verboseDebugPreferences `
                | Tee-Object $executionLogFile -Append

    "{0} {1,-10} {2}" -f "($((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))","(INFO)","End of try block of $script.." | Tee-Object $executionLogFile -Append | Write-Output
    0 | Out-File $statusLogFile
}
catch {
    $errMessage = $_;
    $lastRunStatus += 1;
    $lastRunStatus | Out-File $statusLogFile

    "{0} {1,-10} {2}" -f "($((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))","(ERROR)","Something went wrong. Inside catch block of '$script'." | Tee-Object $executionLogFile -Append | Write-Output
    "`n$('*'*40)`n" | Out-File $executionLogFile -Append
    $errMessage | Out-File $executionLogFile -Append
    "$('*'*40)`n" | Out-File $executionLogFile -Append

    if( $lastRunStatus -ge $FailureNotifyThreshold )
    {
        $subject = "$($Script.Replace('.ps1','')) - Failed"
        $footer = "<p>Alert Created @ $(Get-Date -format 'yyyy-MMM-dd HH.mm.ss')</p>"
        "{0} {1,-10} {2}" -f "($((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))","(INFO)","Calling 'Raise-SdtAlert' with alert key '$subject'.." | Tee-Object $executionLogFile -Append | Write-Output
        Raise-SdtAlert @verboseDebugPreferences -To $EmailTo -Subject $subject -BodyAsHtml -Attachments "$executionLogFile" -Priority High -DelayMinutes $DelayMinutes `
                -Body @"
$SdtCssStyle
<h2><span class=blue>$($Script.Replace('.ps1',''))</span> failed for <span class=red>$lastRunStatus</span> times continously</h2>
<p>Error =></p>
<p style="color:red"><pre>
$($errMessage.Exception.Message)
</pre></p>
<p>
<br><br>-- For details analysis, kindly read attached log file '$executionLogFile'
</p>
<br>$('-'*50)<br>$footer
"@
    }
    
    throw $errMessage
}
