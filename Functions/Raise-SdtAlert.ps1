function Raise-SdtAlert
{
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()]
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
        [Parameter(Mandatory=$false)][ValidateSet('Critical', 'High', 'Medium', 'Low')]
        $Severity = 'High',
        [Parameter(Mandatory=$false)][ValidateSet('Email', 'Slack', 'MSTeams')]
        $AlertType = 'Email',
        [Parameter(Mandatory=$false)]
        [int]$DelayMinutes = 15,
        [Switch]$ClearAlert
    )

    # Declare local variables
    $alert = $true
    if ($ClearAlert) {
        $alert = $false
    }

    $alertTime = Get-Date
    $alertTimeUTC = (Get-Date).ToUniversalTime()
    $alertTimeString = $alertTime.ToString('yyyy-MM-dd HH.mm.ss')
        
    $lastOccurredDateUTC = $alertTimeUTC
    $lastNotifiedDateUTC = $alertTimeUTC
    $newOccurredDateUTC = $alertTimeUTC
    $newNotifiedDateUTC = $alertTimeUTC
        
    Write-Debug "Inside Raise-SdtAlert.ps1"

    $currentAlert = @()
    $currentAlert += Invoke-DbaQuery -SqlInstance $SdtInventoryInstance -Database $SdtInventoryDatabase `
                -Query "select * from $SdtAlertTable a with (nolock) where alert_key = '$Subject' and state in ('active','suppressed')";
    
    
    # if alert is not active and history is found, then clear history
    if($ClearAlert -and $currentAlert.Count -gt 0)
    {
        Write-Verbose "Alert is inactive, but history is found."
        Write-Verbose "Clearing mail notification.."
        Send-MailMessage -From $SdtAlertEmailAddress -To $To -Subject $Subject -Body $Body -Priority $Priority `
                        -DeliveryNotificationOption OnSuccess, OnFailure `
                        -SmtpServer $SmtpServer -Port $Port -BodyAsHtml:$BodyAsHtml
        
        Write-Verbose "Marking cleared in alert table.."
        $alertUpdateSql = @"
set nocount on; 
update a 
set [state] = 'Cleared', last_occurred_date_utc = '$($newOccurredDateUTC.ToString('yyyy-MM-dd HH:mm:ss.fff'))'
from $SdtAlertTable a --with (nolock) 
where alert_key = '$Subject' and state in ('active','suppressed')
"@
        Invoke-DbaQuery -SqlInstance $SdtInventoryInstance -Database $SdtInventoryDatabase -Query $alertUpdateSql -EnableException
    }

    # if alert is active but not found in history, then send mail notification and add entry into alert table
    if( (-not $ClearAlert) -and $currentAlert.Count -eq 0) 
    {
        $alert = $true
        Write-Verbose "No existing alert found for '$Subject'"
        Write-Verbose "Creating alert in alert table.."
        $alertUpdateSql = @"
set nocount on; 
insert $SdtAlertTable (alert_key, email_to, severity)
select '$Subject', '$($To -join ',')', '$Severity';
"@
        Invoke-DbaQuery -SqlInstance $SdtInventoryInstance -Database $SdtInventoryDatabase -Query $alertUpdateSql -EnableException

        Write-Verbose "Sending mail notification.."
        if([String]::IsNullOrEmpty($Attachments)) {
            Send-MailMessage -From $SdtAlertEmailAddress -To $To -Subject $Subject -Body $Body -Priority $Priority -DeliveryNotificationOption OnSuccess, OnFailure -SmtpServer $SmtpServer -Port $Port -BodyAsHtml:$BodyAsHtml
        }
        else {
            Send-MailMessage -From $SdtAlertEmailAddress -To $To -Subject $Subject -Body $Body -Attachments $Attachments -Priority $Priority -DeliveryNotificationOption OnSuccess, OnFailure -SmtpServer $SmtpServer -Port $Port -BodyAsHtml:$BodyAsHtml
        }
    }

    # if alert is active, and present in history. Then update history
    if( (-not $ClearAlert) -and $currentAlert.Count -ne 0 ) 
    {
        Write-Verbose "Alert found for '$Subject' in alert table."
        $lastOccurredDateUTC = $currentAlert[0].last_occurred_date_utc
        $lastNotifiedDateUTC = $currentAlert[0].last_notified_date_utc        

        # if alert is out of $DelayMinutes
        if ($lastNotifiedDateUTC -le $alertTimeUTC.AddMinutes(-$DelayMinutes)) {
            $alert = $true
        }
        else { # no alert please
            $alert = $false
            $newNotifiedDateUTC = $lastNotifiedDateUTC
            "{0} {1,-10} {2}" -f "($((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))","(INFO)","Raise-SdtAlert => Last alert was sent @ $((Get-SdtLocalTime $lastNotifiedDateUTC).ToString('yyyy-MM-dd HH.mm.ss'))" | Write-Output
            "{0} {1,-10} {2}" -f "($((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))","(INFO)","Raise-SdtAlert => Last alert is within `$DelayMinutes ($DelayMinutes). So skipping current alert." | Write-Output
        }

        if( ($currentAlert[0].state -eq 'Suppressed') -and ($alertTimeUTC -ge $currentAlert[0].suppress_start_date_utc -and $alertTimeUTC -le $currentAlert[0].suppress_end_date_utc) ) {
            "{0} {1,-10} {2}" -f "($((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))","(INFO)","Alert '$Subject' is in suppressed state." | Write-Output
            $alert = $false
            $newNotifiedDateUTC = $lastNotifiedDateUTC
        }

        Write-Verbose "Updating alert in alert table.."
        $alertUpdateSql = @"
set nocount on; 
update a 
set last_occurred_date_utc = '$($newOccurredDateUTC.ToString('yyyy-MM-dd HH:mm:ss.fff'))'
    $(if($alert){",last_notified_date_utc = '$($newNotifiedDateUTC.ToString('yyyy-MM-dd HH:mm:ss.fff'))', notification_counts += 1"})
from $SdtAlertTable a with (nolock) 
where alert_key = '$Subject' and state in ('active','suppressed')
"@
        Invoke-DbaQuery -SqlInstance $SdtInventoryInstance -Database $SdtInventoryDatabase -Query $alertUpdateSql -EnableException

        if($alert)
        {
            Write-Verbose "Sending mail notification.."
            if([String]::IsNullOrEmpty($Attachments)) {
                Send-MailMessage -From $SdtAlertEmailAddress -To $To -Subject $Subject -Body $Body -Priority $Priority -DeliveryNotificationOption OnSuccess, OnFailure -SmtpServer $SmtpServer -Port $Port -BodyAsHtml:$BodyAsHtml
            }
            else {
                Send-MailMessage -From $SdtAlertEmailAddress -To $To -Subject $Subject -Body $Body -Attachments $Attachments -Priority $Priority -DeliveryNotificationOption OnSuccess, OnFailure -SmtpServer $SmtpServer -Port $Port -BodyAsHtml:$BodyAsHtml
            }
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

