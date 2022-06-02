function Get-SdtPagerDutyEvent
{
    [CmdletBinding(ConfirmImpact='Low')]
    Param
    (
        # View only Triggerd incidents
        [Parameter(Mandatory=$false)]
        [switch]$Triggered,

        # View only Acknowledged incidents
        [Parameter(Mandatory=$false)]
        [switch]$Acknowledged,
           
        # View only Resolved incidents
        [Parameter(Mandatory=$false)]
        [switch]$Resolved,

        # The Subdomain of your pager duty account
        [Parameter(Mandatory=$true)]
        [string]$PagerDutySubDomain,

        # API key for your PagerDuty account
        [Parameter(Mandatory=$true)]
        [string]$APIKey
    )
        $query = $null

        if($Resolved)
        {
            $query = '?status=resolved'
        }

        if($Acknowledged)
        {
            $query = '?status=acknowledged'
        }

        if($Triggered)
        {
            $query = '?status=triggered'
        }

        $results = Invoke-RestMethod -Uri ('https://' + $PagerDutySubDomain + '.pagerduty.com/api/v1/incidents' + $query) -method Get -ContentType "application/json" -Headers @{"Authorization"=("Token token=" + $APIKey)}
        
        # Clean the OutPut
        $results.incidents | Select-Object incident_number,incident_key,status,trigger_summary_data
<#
.Synopsis
   Get events from PagerDuty API.
.DESCRIPTION
   Allows you to list PagerDuty events by querying the API.
.EXAMPLE
   Get-SdtPagerDutyEvent -Triggered -PagerDutySubDomain 'mysubdomain' -APIKey IDFJ8ioujffd8vd

   Lists only Triggered Events
.EXAMPLE
   Get-SdtPagerDutyEvent -Acknowledged -PagerDutySubDomain 'mysubdomain' -APIKey IDFJ8ioujffd8vd

   Lists only Acknowledged Events
.EXAMPLE
   Get-SdtPagerDutyEvent -Resolved -PagerDutySubDomain 'mysubdomain' -APIKey IDFJ8ioujffd8vd

   Lists only Resolved Events
.NOTES
       NAME:      Get-PagerDutyEvent
       AUTHOR:    Matthew Hodgkins
       WEBSITE:   http://www.hodgkins.net.au
       WEBSITE:   https://github.com/MattHodge
#>
} # End Function