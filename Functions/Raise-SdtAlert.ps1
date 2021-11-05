function Raise-SdtAlert
{
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)]
        [string]$Subject,
        [Parameter(Mandatory=$true)]
        [string]$Body,
        [Parameter(Mandatory=$false, ParameterSetName="Email")]
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
        $AlertType = 'Email'

    )

    if ($AlertType -eq 'Email') {
        if([String]::IsNullOrEmpty($Attachments)) {
            Send-MailMessage -From $SdtAlertEmailAddress -To $To -Subject $Subject -Body $Body -Priority $Priority -DeliveryNotificationOption OnSuccess, OnFailure -SmtpServer $SmtpServer -Port $Port -BodyAsHtml:$BodyAsHtml
        }
        else {
            Send-MailMessage -From $SdtAlertEmailAddress -To $To -Subject $Subject -Body $Body -Attachments $Attachments -Priority $Priority -DeliveryNotificationOption OnSuccess, OnFailure -SmtpServer $SmtpServer -Port $Port -BodyAsHtml:$BodyAsHtml
        }
    }

    if ($AlertType -eq 'Slack') {
        Write-Host "Send Slack Alert"
    }

    if ($AlertType -eq 'MSTeams') {
        Write-Host "Send MSTeams Alert"
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

