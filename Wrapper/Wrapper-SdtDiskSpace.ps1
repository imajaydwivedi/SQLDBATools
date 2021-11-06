﻿[CmdletBinding()]
Param (
    [Parameter(Mandatory=$false)]
    [Alias('ServerName','MachineName')]
    [string[]]$ComputerName = @($SdtInventoryInstance),
    [Parameter(Mandatory=$false)]
    [string[]]$ExcludeDrive,
    [Parameter(Mandatory=$false)]
    [decimal]$WarningThresholdPercent = 80.0,
    [Parameter(Mandatory=$false)]
    [decimal]$CriticalThresholdPercent = 90.0,
    [Parameter(Mandatory=$false)]
    [string]$ThresholdTable = 'dbo.sdt_disk_space_threshold',
    [Parameter(Mandatory=$false)]
    [int]$FailureNotifyThreshold = 3,
    [Parameter(Mandatory=$false)]
    [string[]]$EmailTo = @($SdtDBAMailId),
    [Parameter(Mandatory=$false)]
    [int]$DelayMinutes = 30,
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
# Log files
$statusLogFile = $(Join-Path $SdtLogsPath $($Script.Replace('.ps1','__Status.log')))
$executionLogFile = $(Join-Path $SdtLogsPath $($Script.Replace('.ps1',"__Log__$($dtmm).log")))

# Set Error variables
"`n`n`n`n`n`n{0} {1,-10} {2}" -f "($((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))","(START)","Execute script '$Script'.." | Tee-Object $executionLogFile | Write-Output
$isCustomError = $false
$isScriptError = $false
[bool]$isVerbose = $false;
if( ($PSCmdlet -ne $null -and $PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent) -or $VerbosePreference -eq 'Continue' ) {
    $isVerbose = $true
}

# Remove Old log files
Get-ChildItem -Path "$SdtLogsPath\$($Script.Replace('.ps1',"__Log__*.log"))" -Force `
        | Where-Object {$_.PSIsContainer -eq $false -and $_.LastAccessTime -lt (Get-Date).AddMinutes(-$LogRetentionMinutes) } `
        | Remove-Item | Out-Null

# Read Last Execution Status
[int]$lastRunStatus = 0
"{0} {1,-10} {2}" -f "($((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))","(INFO)","Create log file '$statusLogFile' if not exists.." | Write-Output
if(-not (Test-Path $statusLogFile)) {
    New-Item -Path $statusLogFile -Force -ItemType File | Out-Null
    $lastRunStatus | Out-File -FilePath $statusLogFile -Append
    #Get-Content $LogFile
}
else {
    "{0} {1,-10} {2}" -f "($((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))","(INFO)","Get last run status from status file '$statusLogFile'.." | Write-Output
    [int]$lastRunStatus = (Get-Content $statusLogFile | select -First 1| Out-String ) # First line contains continous failure state
    "{0} {1,-10} {2}" -f "($((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))","(INFO)","Last run status was $lastRunStatus" | Write-Output
}

try
{
    "{0} {1,-10} {2}" -f "($((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))","(INFO)","Execute Alert-SdtDiskSpace.." | Write-Output
    #1/0;
    Alert-SdtDiskSpace -ComputerName $ComputerName -DelayMinutes $DelayMinutes -WarningThresholdPercent $WarningThresholdPercent `
                -CriticalThresholdPercent $CriticalThresholdPercent | Tee-Object $executionLogFile

    "{0} {1,-10} {2}" -f "($((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))","(INFO)","End of try block of $script.." | Tee-Object $executionLogFile | Write-Output
    0 | Out-File $statusLogFile
}
catch {
    $errMessage = $_;
    $lastRunStatus += 1;
    $lastRunStatus | Out-File $statusLogFile

    "{0} {1,-10} {2}" -f "($((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))","(ERROR)","Something went wrong. Inside catch block." | Tee-Object $executionLogFile | Write-Output
    if( $lastRunStatus -ge $FailureNotifyThreshold )
    {
        $subject = "[$($Script.Replace('.ps1',''))] - Failed"
        $footer = "<p>Alert Created @ $(Get-Date -format 'yyyy-MMM-dd HH.mm.ss')</p>"
        "{0} {1,-10} {2}" -f "($((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))","(INFO)","Sending mail notification using Raise-SdtAlert.." | Tee-Object $executionLogFile | Write-Output
        Raise-SdtAlert -To $EmailTo -Subject $subject -BodyAsHtml -Priority High -DelayMinutes $DelayMinutes `
                -Body @"
$SdtCssStyle
<h2><span class=blue>$($Script.Replace('.ps1',''))</span> failed for <span class=red>$lastRunStatus</span> times continously</h2>
<p>Error =></p>
<p style="color:red">$errMessage</p>
<br>$('-'*50)<br>$footer
"@
    }
    throw $errMessage
}
