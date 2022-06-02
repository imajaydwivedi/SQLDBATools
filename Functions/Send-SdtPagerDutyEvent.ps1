function Send-SdtPagerDutyEvent
{
    [CmdletBinding(DefaultParameterSetName='Trigger',
                  ConfirmImpact='Low')]
    [OutputType([String])]
    Param
    (
        # Resolve events cause the referenced incident to enter the resolved state.
        [Parameter(Mandatory=$true,ParameterSetName="Resolve")]
        [switch]$Resolve,

        # Acknowledge events cause the referenced incident to enter the acknowledged state.
        [Parameter(Mandatory=$true,ParameterSetName="Acknowledge")]
        [switch]$Acknowledge,

        # Your monitoring tools should send PagerDuty a trigger event to report a new or ongoing problem. When PagerDuty receives a trigger event, it will either open a new incident, or add a new trigger log entry to an existing incident, depending on the provided incident_key.
        [Parameter(Mandatory=$true,ParameterSetName="Trigger")]
        [switch]$Trigger,

        # The GUID of one of your "Events API" services. This is the "service key" listed on a Generic API's service detail page.
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [string]$ServiceKey,

        # Identifies the incident to which this trigger event should be applied. If there's no open (i.e. unresolved) incident with this key, a new one will be created. If there's already an open incident with a matching key, this event will be appended to that incident's log. The event key provides an easy way to "de-dup" problem reports. If this field isn't provided, PagerDuty will automatically open a new incident with a unique key.
        [Parameter(Mandatory=$false)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [string]$IncidentKey,

        # The name of the monitoring client that is triggering this event.
        [Parameter(Mandatory=$false,ParameterSetName="Trigger")]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [string]$Client,

        # A short description of the problem that led to this trigger.
        [Parameter(Mandatory=$false)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [string]$Description,

        # An arbitrary JSON object containing any data you'd like included in the incident log.
        [Parameter(Mandatory=$false)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [PSObject[]]$Details
    )

    # Trigger Command
    if ($Trigger)
    {
        # If there are details
        if ($Details -ne $null)
        {
            $body = @{
                        service_key = $ServiceKey
                        incident_key = $IncidentKey
                        event_type = "trigger"
                        description = $Description
                        client = $Client
                        details = $details
                    } | ConvertTo-Json 
        } # End If

        # If there are no details
        else
        {
            $body = @{
                        service_key = $ServiceKey
                        incident_key = $IncidentKey
                        event_type = "trigger"
                        description = $Description
                        client = $Client
                    } | ConvertTo-Json 
        } # End Else
        
        # Invoke Request
        Invoke-RestMethod -Uri https://events.pagerduty.com/generic/2010-04-15/create_event.json -method Post -Body $body -ContentType "application/json"
    }

    if ($Acknowledge)
    {
        # If there are details
        if ($Details -ne $null)
        {
            $body = @{
                        service_key = $ServiceKey
                        incident_key = $IncidentKey
                        event_type = "acknowledge"
                        description = $Description
                        details = $details
                    } | ConvertTo-Json 
        } # End If

        # If there are no details
        else
        {
            $body = @{
                        service_key = $ServiceKey
                        incident_key = $IncidentKey
                        event_type = "acknowledge"
                        description = $Description
                    } | ConvertTo-Json 
        } # End Else
        
        # Invoke Request
        Invoke-RestMethod -Uri https://events.pagerduty.com/generic/2010-04-15/create_event.json -method Post -Body $body -ContentType "application/json"
    }

    if ($Resolve)
    {
        # If there are details
        if ($Details -ne $null)
        {
            $body = @{
                        service_key = $ServiceKey
                        incident_key = $IncidentKey
                        event_type = "resolve"
                        description = $Description
                        details = $details
                    } | ConvertTo-Json 
        } # End If

        # If there are no details
        else
        {
            $body = @{
                        service_key = $ServiceKey
                        incident_key = $IncidentKey
                        event_type = "resolve"
                        description = $Description
                    } | ConvertTo-Json 
        } # End Else
        
        # Invoke Request
        Invoke-RestMethod -Uri https://events.pagerduty.com/generic/2010-04-15/create_event.json -method Post -Body $body -ContentType "application/json"
    }
<#
.Synopsis
   Send events to the PagerDuty API.
.DESCRIPTION
   Allows you to send Trigger, Acknowledge and Resolve events to the PagerDuty API.
.EXAMPLE
   Send-SdtPagerDutyEvent -Trigger -ServiceKey fbe312204f634360b17ffc5150fc6ad5 -Client "PowerShell Function" -Description "Test Description" -IncidentKey "TESTKEY2"

   Creates a new trigger event and specfies its IncidentKey
.EXAMPLE
   Send-SdtPagerDutyEvent -Trigger -ServiceKey fbe312204f634360b17ffc5150fc6ad5 -Description "Test Description" -Details $Object

   Creates a new trigger event and without specifying its IncidentKey. Also passing an object to fill in alert details.
.EXAMPLE
   Send-SdtPagerDutyEvent -Acknowledge -ServiceKey fbe312204f634360b17ffc5150fc6ad5 -Description "Test Acknowledge" -IncidentKey TESTKEY2

   Acknowledge a pager duty event.
.EXAMPLE
   Send-SdtPagerDutyEvent -Resolve -ServiceKey fbe312204f634360b17ffc5150fc6ad5 -Description "Resolved the issue" -IncidentKey "c0173fc0e4b04d6bb6f083817cee4549"

   Resolve a PagerDuty event.
.NOTES
       NAME:      Get-PagerDutyEvent
       AUTHOR:    Matthew Hodgkins
       WEBSITE:   http://www.hodgkins.net.au
       WEBSITE:   https://github.com/MattHodge
#>
} # End Function