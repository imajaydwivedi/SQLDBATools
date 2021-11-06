[CmdletBinding()]
Param (
    [Parameter(Mandatory=$true)]
    [Alias('ServerName','MachineName')]
    [string[]]$ComputerName,
    [Parameter(Mandatory=$false)]
    [string[]]$ExcludeDrive,
    [Parameter(Mandatory=$false)]
    [decimal]$WarningThresholdPercent = 80.0,
    [Parameter(Mandatory=$false)]
    [decimal]$CriticalThresholdPercent = 90.0,
    [Parameter(Mandatory=$false)]
    [string]$ThresholdTable = 'dbo.sdt_disk_space_threshold'
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
$executionLogFile = $(Join-Path $SdtLogsPath $($Script.Replace('.ps1','__$dtmm.log')))

# Set Error variables
"`n`n`n`n`n`n{0} {1,-10} {2}" -f "($((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))","(START)","Execute script '$Script'.." | Tee-Object $executionLogFile | Write-Output
$isCustomError = $false
$isScriptError = $false
[bool]$isVerbose = $false;
if( ($PSCmdlet -ne $null -and $PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent) -or $VerbosePreference -eq 'Continue' ) {
    $isVerbose = $true
}

# Read Last Execution Status
[int]$lastRunStatus = 0
"{0} {1,-10} {2}" -f "($((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))","(INFO)","Create log file '$statusLogFile' if not exists.." | Write-Output
if(-not (Test-Path $statusLogFile)) {
    New-Item -Path $statusLogFile -Force -ItemType File
    $lastRunStatus | Out-File -FilePath $statusLogFile -Append
    #Get-Content $LogFile
}
else {
    "{0} {1,-10} {2}" -f "($((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))","(INFO)","Get last run status from status file '$statusLogFile'.." | Write-Output
    [int]$lastRunStatus = (Get-Content $statusLogFile | select -First 1| Out-String ) # First line contains continous failure state
    "{0} {1,-10} {2}" -f "($((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))","(INFO)","Last run status was $lastRunStatus" | Write-Output
}

"{0} {1,-10} {2}" -f "($((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))","(INFO)","Open $SdtDOP concurrent RSJobs & Execute `$blockDbaDiskSpace.." | Write-Output

