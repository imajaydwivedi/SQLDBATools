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
        [string[]]$EmailTo = @($SdtDBAMailId),
        [Parameter(Mandatory=$false)]
        [int]$DelayMinutes = 60
    )

    # Set Initial Variables
    $startTime = Get-Date
    $dtmm = $startTime.ToString('yyyy-MM-dd HH.mm.ss')
    $script = $MyInvocation.MyCommand.Name
    if([String]::IsNullOrEmpty($Script)) {
        $Script = 'Alert-SdtDiskSpace'
    }

    Try 
    {
        $isCustomError = $false

        #1/0;

        Write-Debug "Inside Alert-SdtDiskSpace"

        $serverList = @()
        $serverList += ($ComputerName | Foreach-Object {"'$_'"}) -join ','
        [System.Collections.ArrayList]$ComputerNames = @()

        # Is Custom Credential have to be used, then 
        if($SdtUseSpecificCredentials) 
        {
            
            $sqlMatchServersFromInventory = @"
;with t_servers as (
    select server as ServerName, friendly_name, host_name, rdp_credential, sql_credential from [$SdtInventoryDatabase].[dbo].[sdt_server_inventory] i 
    where is_active = 1 and monitoring_enabled = 1 and i.server in ($serverList)
    union all
    select friendly_name as ServerName, friendly_name, host_name, rdp_credential, sql_credential from [$SdtInventoryDatabase].[dbo].[sdt_server_inventory] i 
    where is_active = 1 and monitoring_enabled = 1 and  i.friendly_name in ($serverList)
    union all
    select sql_instance as ServerName, friendly_name, host_name, rdp_credential, sql_credential from [$SdtInventoryDatabase].[dbo].[sdt_server_inventory] i 
    where is_active = 1 and monitoring_enabled = 1 and  i.sql_instance in ($serverList)
    union all
    select ipv4 as ServerName, friendly_name, host_name, rdp_credential, sql_credential from [$SdtInventoryDatabase].[dbo].[sdt_server_inventory] i 
    where is_active = 1 and monitoring_enabled = 1 and  i.ipv4 in ($serverList)
)
select i.ServerName, i.friendly_name, i.host_name, rdp_credential_username = i.rdp_credential, sql_credential_username = i.sql_credential
		,rdp_credential_password = crd_rdp.password
		,sql_credential_password = crd_sql.password
from t_servers i
outer apply (select top 1 server_ip, server_name, [user_name], is_sql_user, is_rdp_user, 
					password_hash, [password] = cast(DecryptByPassPhrase(cast(salt as varchar),password_hash ,1, server_ip) as varchar),
					salt, salt_raw = cast(salt as varchar),	created_date, created_by, updated_date, updated_by, 
					delegate_login_01, delegate_login_02, remarks 
			from dbo.credential_manager crd
			where crd.user_name = i.rdp_credential
			order by (case when server_ip is not null then 1 else 2 end) asc
			) crd_rdp
outer apply (select top 1 server_ip, server_name, [user_name], is_sql_user, is_rdp_user, 
					password_hash, [password] = cast(DecryptByPassPhrase(cast(salt as varchar),password_hash ,1, server_ip) as varchar),
					salt, salt_raw = cast(salt as varchar),	created_date, created_by, updated_date, updated_by, 
					delegate_login_01, delegate_login_02, remarks 
			from dbo.credential_manager crd
			where crd.user_name = i.sql_credential
			order by (case when server_ip is not null then 1 else 2 end) asc
			) crd_sql
"@
            $matchedServersFromInventory = @()
            $matchedServersFromInventory += Invoke-DbaQuery -SqlInstance $SdtInventoryInstance -Database $SdtInventoryDatabase -Query $sqlMatchServersFromInventory -EnableException

            foreach($comp in $matchedServersFromInventory) 
            {
                #"Working on [$($comp.ServerName)].." | Write-Host

                [PSCredential]$rdpCredential = $null
                [PSCredential]$sqlCredential = $null

                if(-not [String]::IsNullOrEmpty($comp.rdp_credential_username)) {
                    [SecureString]$rdpCredentialSecureString = $null
                    [SecureString]$rdpCredentialSecureString = $comp.rdp_credential_password | ConvertTo-SecureString -AsPlainText -Force;
                    if($comp.rdp_credential_username -eq 'Administrator') {
                        [PSCredential]$rdpCredential = New-Object System.Management.Automation.PSCredential -ArgumentList $($comp.host_name+'\'+$comp.rdp_credential_username), $rdpCredentialSecureString;
                    }
                    else {
                        [PSCredential]$rdpCredential = New-Object System.Management.Automation.PSCredential -ArgumentList $comp.rdp_credential_username, $rdpCredentialSecureString;
                    }
                }
                if(-not [String]::IsNullOrEmpty($comp.sql_credential_username)) {
                    [SecureString]$sqlCredentialSecureString = $null
                    [SecureString]$sqlCredentialSecureString = $comp.sql_credential_password | ConvertTo-SecureString -AsPlainText -Force;
                    [PSCredential]$sqlCredential = New-Object System.Management.Automation.PSCredential -ArgumentList $comp.sql_credential_username, $sqlCredentialSecureString;
                }

                $obj = [PSCustomObject]@{
                    ComputerName = $comp.ServerName
                    FriendlyName = $comp.friendly_name
                    HostName = $comp.host_name
                    RdpCredential = $rdpCredential
                    SqlCredential = $sqlCredential
                } 
                $ComputerNames.Add($obj) | Out-Null
            }
        }
        else 
        {
            
            $sqlMatchServersFromInventory = @"
;with t_servers as (
    select server as ServerName, friendly_name, host_name, rdp_credential = null, sql_credential = null from [$SdtInventoryDatabase].[dbo].[sdt_server_inventory] i 
    where is_active = 1 and monitoring_enabled = 1 and i.server in ($serverList)
    union all
    select friendly_name as ServerName, friendly_name, host_name, rdp_credential = null, sql_credential = null from [$SdtInventoryDatabase].[dbo].[sdt_server_inventory] i 
    where is_active = 1 and monitoring_enabled = 1 and  i.friendly_name in ($serverList)
    union all
    select sql_instance as ServerName, friendly_name, host_name, rdp_credential = null, sql_credential = null from [$SdtInventoryDatabase].[dbo].[sdt_server_inventory] i 
    where is_active = 1 and monitoring_enabled = 1 and  i.sql_instance in ($serverList)
    union all
    select ipv4 as ServerName, friendly_name, host_name, rdp_credential = null, sql_credential = null from [$SdtInventoryDatabase].[dbo].[sdt_server_inventory] i 
    where is_active = 1 and monitoring_enabled = 1 and  i.ipv4 in ($serverList)
)
select i.ServerName, i.friendly_name, rdp_credential_username = i.rdp_credential, sql_credential_username = i.sql_credential
from t_servers i
"@
            $matchedServersFromInventory = @()
            $matchedServersFromInventory += Invoke-DbaQuery -SqlInstance $SdtInventoryInstance -Database $SdtInventoryDatabase -Query $sqlMatchServersFromInventory -EnableException

            foreach($comp in $matchedServersFromInventory) 
            {
                #"Working on [$($comp.ServerName)].." | Write-Host

                $obj = [PSCustomObject]@{
                    ComputerName = $comp.ServerName
                    FriendlyName = $comp.friendly_name
                    HostName = $comp.host_name
                    RdpCredential = $null
                    SqlCredential = $null
                } 
                $ComputerNames.Add($obj) | Out-Null
            }
        }

        # Start Actual Work
        $blockDbaDiskSpace = {
            $ComputerName = $_.ComputerName
            $FriendlyName = $_.FriendlyName
            $RdpCredential = $_.RdpCredential
            $SqlCredential = $_.SqlCredential

            $r = Get-DbaDiskSpace -ComputerName $ComputerName -Credential $RdpCredential -EnableException
            $r | Add-Member -NotePropertyName FriendlyName -NotePropertyValue $FriendlyName
            $r | Add-Member -MemberType ScriptProperty -Name "PercentUsed" -Value {[math]::Round((100.00 - $this.PercentFree), 2)}
            $r
        }

        "{0} {1,-10} {2}" -f "($((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))","(INFO)","Start RSJobs with $SdtDOP threads.." | Write-Output
        $jobs = @()
        $jobs += $ComputerNames | Start-RSJob -Name {"$($_.ComputerName)"} -ScriptBlock $blockDbaDiskSpace -Throttle $SdtDOP
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
            $errMessage = "`nBelow jobs either timed or failed-`n$($jobs_exception | Select-Object Name, State, HasErrors | Format-Table -AutoSize | Out-String -Width 700)"
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

        $subject = "Alert-SdtDiskSpace"
        $footer = "<br><p>Report Generated @ $(Get-Date -format 'yyyy-MM-dd HH.mm.ss')</p>"

        
        # Get alert rules for the alert key
        "{0} {1,-10} {2}" -f "($((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))","(INFO)","Get rules for Alert Key '$Subject'.." | Write-Output
        $currentAlertRules = @()
        $currentAlertRules += Invoke-DbaQuery -SqlInstance $SdtInventoryInstance -Database $SdtInventoryDatabase `
                    -Query "select * from $SdtAlertRulesTable ar with (nolock) where alert_key = '$Subject' and is_active = 1";

        # Add Warning & Critical threshold inline with Details
        "{0} {1,-10} {2}" -f "($((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))","(INFO)","Add inline properties like receiver, thresholds, delay etc based on alert rules.." | Write-Output
        $jobsResultExtended = @()
        foreach($srvGroup in $($jobsResult | Group-Object ComputerName)) {
            [decimal]$alertWarningThreshold = $WarningThresholdPercent
            [decimal]$alertCriticalThreshold = $CriticalThresholdPercent
            [System.Array]$alertReceiver = $EmailTo
            $alertReceiverName = 'DBA'
            $alertDelayMinutes = $DelayMinutes

            $alertServerName = $srvGroup.Name
            $alertDiskDetails = $srvGroup.Group

            $srvRule = @()
            $srvRule += $currentAlertRules | Where-Object {$_.server_friendly_name -eq $alertServerName}
            if($srvRule.Count -eq 1) {
                [system.Array]$alertReceiverRules = if(-not [String]::IsNullOrEmpty($srvRule.alert_receiver)){((($srvRule.alert_receiver) -split ';') -split ',')}

                [decimal]$alertWarningThreshold = if([String]::IsNullOrEmpty($srvRule.severity_high_threshold)){$alertWarningThreshold}else{$srvRule.severity_high_threshold}
                [decimal]$alertCriticalThreshold = if([String]::IsNullOrEmpty($srvRule.severity_critical_threshold)){$alertCriticalThreshold}else{$srvRule.severity_critical_threshold}
                $alertReceiver += $alertReceiverRules
                $alertReceiverName = if([String]::IsNullOrEmpty($srvRule.alert_receiver_name)){$alertReceiverName}else{$srvRule.alert_receiver_name}
                $alertDelayMinutes = if([String]::IsNullOrEmpty($srvRule.delay_minutes)){$alertDelayMinutes}else{$srvRule.delay_minutes}
            }

            $srvDiskDetails = @()
            $srvDiskDetails += $($srvGroup.Group)
            $srvDiskDetails | Add-Member -NotePropertyName WarningThreshold -NotePropertyValue $alertWarningThreshold -Force
            $srvDiskDetails | Add-Member -NotePropertyName CriticalThreshold -NotePropertyValue $alertCriticalThreshold -Force
            $srvDiskDetails | Add-Member -NotePropertyName Receiver -NotePropertyValue $alertReceiver -Force
            $srvDiskDetails | Add-Member -NotePropertyName ReceiverName -NotePropertyValue $alertReceiverName -Force
            $srvDiskDetails | Add-Member -NotePropertyName DelayMinutes -NotePropertyValue $alertDelayMinutes -Force

            $jobsResultExtended += $srvDiskDetails
        }
        
        $jobsResultFiltered = @()
        $jobsResultFiltered += $jobsResultExtended | Where-Object {$_.PercentUsed -ge $_.WarningThreshold}
        if($jobsResultFiltered.Count -gt 0) {
            $jobsResultFiltered | Add-Member -MemberType ScriptProperty -Name "Severity" -Value { if($this.PercentUsed -ge $this.CriticalThreshold) {'Critical'} else {'Warning'} }
        }

        # Raise alert
        $alertsCreated = @()
        foreach($alertGroup in $($jobsResultFiltered | Group-Object -Property ReceiverName, Severity))
        {
            $receiverName = ($alertGroup.Name -split ',')[0].Trim()
            $severity = ($alertGroup.Name -split ',')[1].Trim()
            [string[]]$receiver = $alertGroup.Group | Select-Object -ExpandProperty Receiver -Unique
            $groupAlertDelayMinutes = $alertGroup.Group | Select-Object -ExpandProperty DelayMinutes -First 1
    
            $alertResult = @()
            $alertResult += $alertGroup.Group | Select-Object @{l='Server';e={$_.FriendlyName}}, @{l='DiskVolume';e={$_.Name}}, Severity, `
                                                @{l='FreePercent';e={"$($_.PercentFree)% ($($_.Free)/$($_.Capacity))"}}, `
                                                @{l='WarningPercent';e={[math]::Round($_.WarningThreshold,2)}}, @{l='CriticalPercent';e={[math]::Round($_.CriticalThreshold,2)}}, `
                                                Receiver, DelayMinutes, @{l='DashboardURL';e={"http://$SdtGrafanaBaseURL"}} 
        
            "`n{0} {1,-10} {2}" -f "($((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))","(INFO)","Below disk(s) are found with [$severity] space issue for receiver '$receiverName'- " | Write-Output
            $alertResult | ft -AutoSize | Out-String

            $alertServers = @()
            $alertServers += $alertResult | Select-Object -ExpandProperty Server -Unique
            $serverCounts = $alertServers.Count

            $title = "<h2>Alert-SdtDiskSpace - $(if($serverCounts -gt 1){"$serverCounts Servers"}else{"[$alertServers]"}) - $($alertGroup.Count) $severity</h2>"
            $params = @{
                        'As'='Table';
                        'PreContent'= "<p>Hi $receiverName,<br><br>Kindly take corrective action.</p><br><h3 class=`"blue`">Disk Space Utilization</h3>";
                        'EvenRowCssClass' = 'even';
                        'OddRowCssClass' = 'odd';
                        'MakeTableDynamic' = $true;
                        'TableCssClass' = 'grid';
                        'Properties' = 'Server', 'DiskVolume', @{n='Severity';e={$_.Severity};css={if ($_.Severity -eq 'Critical') { 'red' }}},
                                        @{n='Warning %';e={$($_.WarningPercent).ToString("#.00")}}, @{n='Critical %';e={$($_.CriticalPercent).ToString("#.00")}},
                                        @{n='Free Space %';e={$_.FreePercent}}, 'DashboardURL'
                    }
            $content = $alertResult | Sort-Object -Property Severity, Server | ConvertTo-EnhancedHTMLFragment @params
            $body = "<html><head>$SdtCssStyle</head><body> $title $content $footer </body></html>" | Out-String

            if($severity -eq 'Critical') { $priority = 'High' } else { $priority = 'Normal'; $severity = 'HIGH' }
            "{0} {1,-10} {2}" -f "($((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))","(INFO)","Calling 'Raise-SdtAlert' with alert key '$subject' for receiver '$receiverName'.." | Write-Output
            Raise-SdtAlert -To $receiver -Subject $subject -Body $body -ServersAffected $alertServers -Priority $priority -Severity $severity -BodyAsHtml -DelayMinutes $groupAlertDelayMinutes
            
            # Create alerted list to clear other combinations
            $alertsCreated += [PSCustomObject]@{
                                    ReceiverName = $receiverName;
                                    Receiver = $receiver;
                                    Severity = $severity;
                                    IsAlerted = $true;
                                    JoinKey = "$receiverName | $severity";
                                }
        }

        # Get all alert combinations
        $alertCombinations = @()
        foreach($alertGroup in $($jobsResultExtended | Group-Object -Property ReceiverName)) {
            $receiverName = $alertGroup.Name
            $severity = @('Critical','High') # Supported Severities for Alert-Key
            [string[]]$receiver = $alertGroup.Group | Select-Object -ExpandProperty Receiver -Unique
            $alertDelay = $alertGroup.Group | Select-Object -ExpandProperty DelayMinutes -First 1

            foreach($svt in $severity) {
                $alertCombinations += [PSCustomObject]@{
                                    ReceiverName = $receiverName;
                                    Receiver = $receiver;
                                    Severity = $svt;
                                    JoinKey = "$receiverName | $svt";
                                }
            }
        }

        # Get alerts to clear
        $alerts2Clear = @()
        if($alertsCreated.Count -eq 0) {
            $alerts2Clear += $alertCombinations
        } else {
            $alerts2Clear += Join-SdtObject -Left $alertCombinations -Right $alertsCreated -LeftJoinProperty JoinKey -RightJoinProperty JoinKey `
                                    -Type AllInLeft -RightProperties IsAlerted | Where-Object {[String]::IsNullOrEmpty($_.IsAlerted)}
        }
        
        # Clear the alerts if pending
        "`n{0} {1,-10} {2}" -f "($((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))","(INFO)","Checking existing alerts to be cleared.." | Write-Output
        foreach($alert in $alerts2Clear) {
            $content = '<p style="color:blue">Alert has cleared. No action pending</p>'
            $body = "$SdtCssStyle $content $footer" | Out-String
            "{0} {1,-10} {2}" -f "($((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))","(INFO)","Calling 'Raise-SdtAlert' to clear [$($alert.Severity)] alert for [$($alert.ReceiverName)] (if any).." | Write-Output
            Raise-SdtAlert -To $alert.Receiver -Subject $subject -Body $body -Priority 'Normal' -Severity $alert.Severity -BodyAsHtml -ClearAlert -DelayMinutes $DelayMinutes
        }
    }
    catch {
        $errMessage = $_;
        "{0} {1,-10} {2}" -f "($((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))","(ERROR)","Something went wrong. Inside catch block of '$script'." | Write-Output
        $isCustomError = $true
        $_ | Write-Warning
    }
    finally {
        if($isCustomError) {
            throw $errMessage
        }
    }
<#
.SYNOPSIS 
    Check Disk Space on Computer, and send Alert 
.DESCRIPTION
    This function analyzes disk space on Computer, and send an email alert for Critical & Warning state.
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
