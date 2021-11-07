function Alert-SdtDiskSpace
{
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
        [string]$ThresholdTable = 'dbo.sdt_disk_space_threshold',
        [Parameter(Mandatory=$false)]
        [string[]]$EmailTo = @($SdtDBAMailId),
        [Parameter(Mandatory=$false)]
        [int]$DelayMinutes = 60
    )

    $isCustomError = $false
    <#
    #$errMessage = @()

    # Check for server connectivity
    $servers = @()
    $servers = $ComputerName
    $ComputerName = @()
    foreach($srv in $servers) {
        if(Test-Connection $srv -Count 2) {
        }
    }
    if(-not (Test-Connection $ComputerName -Count 2)) {
        Write-Verbose "Servers are connecting"
    }
    #>

    # Start Actual Work
    $blockDbaDiskSpace = {
        $ComputerName = $_
        $FriendlyName = $ComputerName.Split('.')[0]
        $r = Get-DbaDiskSpace -ComputerName $ComputerName -EnableException
        $r | Add-Member -NotePropertyName FriendlyName -NotePropertyValue $FriendlyName
        $r | Add-Member -MemberType ScriptProperty -Name "PercentUsed" -Value {[math]::Round((100.00 - $this.PercentFree), 2)}
        $r
    }

    $jobs = @()
    $jobs += $ComputerName | Start-RSJob -Name {$_} -ScriptBlock $blockDbaDiskSpace -Throttle $SdtDOP
    "{0} {1,-10} {2}" -f "($((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))","(INFO)","Waiting for RSJobs to complete.." | Write-Verbose
    $jobs | Wait-RSJob -ShowProgress -Timeout 1200 -Verbose:$false | Out-Null

    $jobs_timedout = @()
    $jobs_timedout += $jobs | Where-Object {$_.State -in ('NotStarted','Running','Stopping')}
    $jobs_success = @()
    $jobs_success += $jobs | Where-Object {$_.State -eq 'Completed' -and $_.HasErrors -eq $false}
    $jobs_fail = @()
    $jobs_fail += $jobs | Where-Object {$_.HasErrors -or $_.State -in @('Disconnected')}

    $jobsResult = @()
    $jobsResult += $jobs_success | Receive-RSJob -Verbose:$false
    
    if($jobs_success.Count -gt 0) {
        "{0} {1,-10} {2}" -f "($((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))","(INFO)","Below jobs finished without error.." | Write-Output
        $jobs_success | Select-Object Name, State, HasErrors | Format-Table -AutoSize | Out-String | Write-Output
    }

    if($jobs_timedout.Count -gt 0)
    {
        "{0} {1,-10} {2}" -f "($((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))","(ERROR)","Some jobs timed out. Could not completed in 20 minutes." | Write-Output
        $jobs_timedout | Format-Table -AutoSize | Out-String | Write-Output
        "{0} {1,-10} {2}" -f "($((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))","(INFO)","Stop timedout jobs.." | Write-Output
        $jobs_timedout | Stop-RSJob
    }

    if($jobs_fail.Count -gt 0)
    {
        "{0} {1,-10} {2}" -f "($((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))","(ERROR)","Some jobs failed." | Write-Output
        $jobs_fail | Format-Table -AutoSize | Out-String | Write-Output
        "--"*20 | Write-Output
    }

    $jobs_exception = @()
    $jobs_exception += $jobs_timedout + $jobs_fail
    [System.Collections.ArrayList]$jobErrMessages = @()
    if($jobs_exception.Count -gt 0 ) {   
        $alertHost = $jobs_exception | Select-Object -ExpandProperty Name -First 1
        $isCustomError = $true
        $errMessage = "`nBelow jobs either timed or failed-`n$($jobs_exception | Select-Object Name, State, HasErrors | Out-String)"
        $failCount = $jobs_fail.Count
        $failCounter = 0
        foreach($job in $jobs_fail) {
            $failCounter += 1
            $jobErrMessage = ''
            if($failCounter -eq 1) {
                $jobErrMessage = "`n$("_"*20)`n" | Write-Output
            }
            $jobErrMessage += "`nError Message for server [$($job.Name)] => `n`n$($job.Error | Out-String)"
            $jobErrMessage += "$("_"*20)`n`n" | Write-Output
            $jobErrMessages.Add($jobErrMessage) | Out-Null;
        }
        $errMessage += ($jobErrMessages -join '')
        #throw $errMessage
    }
    $jobs | Remove-RSJob -Verbose:$false

    $jobsResultFiltered = @()
    $jobsResultFiltered += $jobsResult | Where-Object {$_.PercentUsed -ge $WarningThresholdPercent}

    #$subject = "Alert-SdtDiskSpace - $(Get-Date -format 'yyyy-MMM-dd')"
    $subject = "Alert-SdtDiskSpace"
    $footer = "<p>Report Generated @ $(Get-Date -format 'yyyy-MM-dd HH.mm.ss')</p>"

    if($jobsResultFiltered.Count -gt 0)
    {
        $jobsResultFiltered | Add-Member -MemberType ScriptProperty -Name "Severity" -Value { if($this.PercentUsed -ge $CriticalThresholdPercent) {'CRITICAL'} else {'WARNING'} }
    
        $alertResult = @()
        $alertResult += $jobsResultFiltered | Select-Object @{l='Server';e={$_.FriendlyName}}, @{l='DiskVolume';e={$_.Name}}, Severity, `
                                            @{l='FreePercent';e={"$($_.PercentFree) ($($_.Free)/$($_.Capacity))"}}, `
                                            @{l='DashboardURL';e={"$SdtGrafanaBaseURL"}} 
        
        "{0} {1,-10} {2}" -f "($((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))","(INFO)","Below disk(s) are found with space issue - " | Write-Output
        $alertResult | ft -AutoSize | Out-String

        $alertServers = @()
        $alertServers += $alertResult | Select-Object -ExpandProperty Server -Unique
        $serverCounts = $alertServers.Count

        $criticalDisks = @()
        $criticalDisks += $alertResult | Where-Object {$_.Severity -eq 'CRITICAL'}
        $criticalDisksCount = $criticalDisks.Count

        $warningDisks = @()
        $warningDisks += $alertResult | Where-Object {$_.Severity -eq 'WARNING'}        
        $warningDisksCount = $warningDisks.Count

        $title = "<h2>Alert-SdtDiskSpace - $(if($serverCounts -gt 1){"$serverCounts Servers"}else{"[$alertServers]"}) $(if($criticalDisksCount -gt 0){"- $criticalDisksCount CRITICAL"}) $(if($warningDisksCount -gt 0){"- $warningDisksCount WARNING"})</h2>"
        #$content = $alertResult | Sort-Object -Property Severity, Server |  ConvertTo-Html -Fragment
        $params = @{
                    'As'='Table';
                    'PreContent'= '<h3 class="blue">Disk Space Utilization</h3>';
                    'EvenRowCssClass' = 'even';
                    'OddRowCssClass' = 'odd';
                    'MakeTableDynamic' = $true;
                    'TableCssClass' = 'grid';
                    'Properties' = 'Server', 'DiskVolume', @{n='Severity';e={$_.Severity};css={if ($_.Severity -eq 'CRITICAL') { 'red' }}},
                                    'FreePercent', 'DashboardURL'
                }
        $content = $alertResult | Sort-Object -Property Severity, Server | ConvertTo-EnhancedHTMLFragment @params
        $body = "$SdtCssStyle $title $content $footer" | Out-String

        if($criticalDisksCount -gt 0) { $priority = 'High' } else { $priority = 'Normal' }
        "{0} {1,-10} {2}" -f "($((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))","(INFO)","Calling 'Raise-SdtAlert' to generate alert notification.." | Write-Output
        Raise-SdtAlert -To $EmailTo -Subject $subject -Body $body -Priority $priority -Severity High -BodyAsHtml -DelayMinutes $DelayMinutes
    }
    else {
        $content = '<p style="color:blue">Alert has cleared. No action pending</p>'
        $body = "$SdtCssStyle $content $footer" | Out-String
        "{0} {1,-10} {2}" -f "($((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))","(INFO)","No space issue found. Calling 'Raise-SdtAlert' to clear active alert (if any).." | Write-Output
        Raise-SdtAlert -To $EmailTo -Subject $subject -Body $body -Priority 'Normal' -Severity High -BodyAsHtml -ClearAlert -DelayMinutes $DelayMinutes
    }

    if($isCustomError) {
        throw $errMessage
    }
<#
.SYNOPSIS 
    Check Disk Space on Computer, and send Alert 
.DESCRIPTION
    This function analyzes disk space on Computer, and send an email alert for CRITICAL & WARNING state.
.PARAMETER ComputerName
    Server name where disk space has to be analyzed.
.PARAMETER ExcludeDrive
    List of drives that should not be part of alert
.PARAMETER WarningThresholdPercent 
    Used space warning threshold. Default 80 percent.
.PARAMETER CriticalThresholdPercent
    Used space critical threshold. Default 90 percent.
.PARAMETER ThresholdTable
    Table containing more specific threshold for server & disk drive at percentage & size level.
.PARAMETER EmailTo
    Email ids that should receive alert email.
.EXAMPLE
    Alert-SdtDiskSpace -ComputerName 'SqlProd1','SqlDr1' -WarningThresholdPercent 70 -CriticalThresholdPercent 85
      
    Analyzes SqlProd1 & SqlDr1 servers for disk drives having used space above 70 percent.
.LINK
    https://github.com/imajaydwivedi/SQLDBATools
#>
}
