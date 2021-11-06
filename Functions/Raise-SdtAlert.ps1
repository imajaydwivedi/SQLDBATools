function Raise-SdtAlert
{
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)]
        [string]$Subject,
        [Parameter(Mandatory=$true)]
        [string]$Body,
        [Parameter(Mandatory=$false)]
        [string[]]$To = @($SdtDBAGroupMailId),
        [Parameter(Mandatory=$false, ParameterSetName="Email")]
        [string[]]$Attachments,
        [Parameter(Mandatory=$false, ParameterSetName="Email")]
        [Switch]$BodyAsHtml,
        [Parameter(Mandatory=$false, ParameterSetName="Email")]
        [string]$SmtpServer = $SdtSmtpServer,
        [Parameter(Mandatory=$false, ParameterSetName="Email")]
        [int]$Port = $SdtSmtpServerPort,
        [Parameter(Mandatory=$false, ParameterSetName="Email")][ValidateSet('Normal', 'High', 'Low')]
        $Priority = 'Normal',
        [Parameter(Mandatory=$false)][ValidateSet('Email', 'Slack', 'MSTeams')]
        $AlertType = 'Email',
        [Parameter(Mandatory=$false)]
        [int]$DelayMinutes = 15,
        [Switch]$ClearAlert
    )

    $alertTime = Get-Date
    $alertTimeString = $alertTime.ToString('yyyy-MM-dd HH.mm.ss')
    $AlertRetentionHours = 168 # 7 days

    # Import existing active alerts
    $allAlerts = @()
    $allAlertsNew = @()
    $currentAlert = @()
    $otherAlert = @()
    $lastAlertDate = $alertTime;
    $xmlLogFileBaseName = "SdtAlerts.xml"
    $xmlLogFile = Join-Path $SdtLogsPath $xmlLogFileBaseName
    if(Test-Path $xmlLogFile) {
        Write-Verbose "Import existing alerts from $xmlLogFileBaseName"
        $allAlerts += Import-Clixml -Path $xmlLogFile
    }

    Write-Debug "Inside Raise-SdtAlert.ps1"
    
    # divide current & other alerts from history
    if($allAlerts.Count -gt 0) {
        $currentAlert += $allAlerts | Where-Object {$_.AlertKey -eq $Subject}
        $otherAlert += $allAlerts | Where-Object {$_.AlertKey -ne $Subject -and $_.LastUpdated -gt ($alertTime).AddHours(-$AlertRetentionHours)} # remove alerts older than $AlertRetentionHours
    }

    # if alert is not active, remove it
    if($ClearAlert -and $currentAlert.Count -gt 0) {
        Write-Verbose "Clear alert from logs history"
        if($otherAlert.Count -gt 0) {
            $allAlertsNew += $otherAlert
        }
    }

    # if alert is active, and present in history. Then update history
    if( (-not $ClearAlert) -and $currentAlert.Count -ne 0 ) {
        Write-Verbose "Alert found for '$Subject' in history logs"
        # capture LastUpdated time
        $lastAlertDate = $currentAlert[0].LastAlertDate;
        $newAlertDate = $lastAlertDate;
        if ($lastAlertDate -le $alertTime.AddMinutes(-$DelayMinutes)) {
            $newAlertDate = $alertTime
        }
        # update alert fields
        $activeAlert = $currentAlert | ForEach-Object {
            $_.UpdateCounts += 1;
            $_.LastUpdated = $alertTime;
            $_.LastAlertDate = $newAlertDate;
            $_
        }
        $currentAlert = @()
        $currentAlert += $activeAlert
        $allAlertsNew += $otherAlert + $currentAlert
    }

    # if alert is active, but not found in history
    if( (-not $ClearAlert) -and $currentAlert.Count -eq 0) {
        Write-Verbose "No existing alert found for '$Subject'"
        $currentAlert += $(New-Object psobject -Property @{
                            CreatedDate = $alertTime;
                            AlertKey = $Subject;
                            To = $To;
                            State = $(if($ClearAlert){'Cleared'}else{'Active'});
                            LastUpdated = $alertTime;
                            LastAlertDate = $alertTime;
                            UpdateCounts = 0;
                        })

        $allAlertsNew += $otherAlert + $currentAlert
    }    

    # Save alert back to xml log file
    Write-Verbose "Exporting updated alert history to log file '$xmlLogFileBaseName'"
    $allAlertsNew | Export-Clixml -Path $xmlLogFile

    if($ClearAlert -and $currentAlert.Count -gt 0)
    {
        Write-Host "Clear the alert '$Subject'" -ForegroundColor Yellow
        Send-MailMessage -From $SdtAlertEmailAddress -To $To -Subject $Subject -Body $Body -Priority $Priority -DeliveryNotificationOption OnSuccess, OnFailure -SmtpServer $SmtpServer -Port $Port -BodyAsHtml:$BodyAsHtml
    }
    else 
    {
        if ( ($lastAlertDate -eq $alertTime) -or ($lastAlertDate -le $alertTime.AddMinutes(-$DelayMinutes)) )
        {
            if ($AlertType -eq 'Email') {
                if([String]::IsNullOrEmpty($Attachments)) {
                    Send-MailMessage -From $SdtAlertEmailAddress -To $To -Subject $Subject -Body $Body -Priority $Priority -DeliveryNotificationOption OnSuccess, OnFailure -SmtpServer $SmtpServer -Port $Port -BodyAsHtml:$BodyAsHtml
                }
                else {
                    Send-MailMessage -From $SdtAlertEmailAddress -To $To -Subject $Subject -Body $Body -Attachments $Attachments -Priority $Priority -DeliveryNotificationOption OnSuccess, OnFailure -SmtpServer $SmtpServer -Port $Port -BodyAsHtml:$BodyAsHtml
                }
            }
        }
        else {
            "{0} {1,-10} {2}" -f "($((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))","(INFO)","Raise-SdtAlert => Last alert was sent @ $($lastAlertDate.ToString('yyyy-MM-dd HH.mm.ss'))" | Write-Output
            "{0} {1,-10} {2}" -f "($((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))","(INFO)","Raise-SdtAlert => Last alert is within `$DelayMinutes ($DelayMinutes). So skipping current alert." | Write-Output
        }

        if ($AlertType -eq 'Slack') {
            Write-Host "Send Slack Alert"
        }

        if ($AlertType -eq 'MSTeams') {
            Write-Host "Send MSTeams Alert"
        }
    }
<#
.SYNOPSIS 
    Send Alert on Email, Slack, or MS Teams.
.DESCRIPTION
    This function helps to send alert message with attachment using Mail, Slack or Microsoft Teams
.PARAMETER Subject
    Alert Subject. Would be used as Subject for Email.
.PARAMETER Body
    Text of alert body
.PARAMETER AlertKey
    String that uniquely identifies the Alert. Based on alert key, existing alert is found & cleared when required.
.PARAMETER To 
    Receiver of alert. Could be comma separated list of email addresses, slack channel or team channel name.
.PARAMETER Attachments
    Comma separated list of documents to be sent with email as attachment.
.PARAMETER BodyAsHtml
    Switch when alert need to be send as html body.
.PARAMETER SmtpServer
    SMTP Server name
.PARAMETER Port 
    SMTP Server port
.PARAMETER Priority
    Email priority. Possible values are Normal, High, Low. Default is Normal.
.PARAMETER AlertType
    Alert type. Possible values are Email, Slack, MSTeams. Default is Email.
.PARAMETER ClearAlert
    When this switch is used, alert matching by Alert Key would be cleared.
.EXAMPLE
    Raise-SdtAlert -To $SdtDBAMailId -Subject 'Raise-SdtAlert' -Body "Testing Email using SQLDBATools PowerShell module"
      
    Send a normal email alert
.EXAMPLE
    Raise-SdtAlert -To $SdtDBAMailId -Subject 'Raise-SdtAlert' -Body 'Testing Email using <span style="color:blue;">SQLDBATools</span> PowerShell module' -BodyAsHtml -Priority High
      
    Send a high priority email alert with html body
.LINK
    https://github.com/imajaydwivedi/SQLDBATools
#>
}

