<#  Using ServiceNow REST APIs and PowerShell To Automatically Create Incidents
    https://virtuallysober.com/2018/07/24/using-servicenow-rest-apis-and-powershell-to-automatically-create-incidents/
    https://github.com/Sam-Martin/servicenow-powershell#example---creating-a-incident-with-custom-table-entries
    https://www.powershellgallery.com/packages/ServiceNow/1.7.0
#>

###############################################
# Configure variable below, you will be prompted for your SNOW login
###############################################
$SNOWURL = "https://YourOrg.service-now.com/"
################################################################################
# Nothing to configure below this line - Starting the main function 
################################################################################
###############################################
# Prompting & saving SNOW credentials, delete the XML file created to reset
###############################################
# Setting credential file
$SNOWCredentialsFile = ".\SNOWCredentials.xml"
# Testing if file exists
$SNOWCredentialsFileTest =  Test-Path $SNOWCredentialsFile
# IF doesn't exist, prompting and saving credentials
IF ($SNOWCredentialsFileTest -eq $False)
{
$SNOWCredentials = Get-Credential -Message "Enter SNOW login credentials"
$SNOWCredentials | EXPORT-CLIXML $SNOWCredentialsFile -Force
}
# Importing credentials
$SNOWCredentials = IMPORT-CLIXML $SNOWCredentialsFile
# Setting the username and password from the credential file (run at the start of each script)
$SNOWUsername = $SNOWCredentials.UserName
$SNOWPassword = $SNOWCredentials.GetNetworkCredential().Password
##################################
# Building Authentication Header & setting content type
##################################
$HeaderAuth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $SNOWUsername, $SNOWPassword)))
$SNOWSessionHeader = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$SNOWSessionHeader.Add('Authorization',('Basic {0}' -f $HeaderAuth))
$SNOWSessionHeader.Add('Accept','application/json')
$Type = "application/json"
###############################################
# Getting list of Incidents
###############################################
$IncidentListURL = $SNOWURL+"api/now/table/incident"
Try 
{
$IncidentListJSON = Invoke-RestMethod -Method GET -Uri $IncidentListURL -TimeoutSec 100 -Headers $SNOWSessionHeader -ContentType $Type
$IncidentList = $IncidentListJSON.result
}
Catch 
{
Write-Host $_.Exception.ToString()
$error[0] | Format-List -Force
}
###############################################
# Host output of the data
###############################################
$IncidentCount = $IncidentList.count
$ActiveIncidentCount = $IncidentList | Where-Object {$_.active -eq "true"} | Measure | Select -ExpandProperty Count
"Open Incidents:"
$IncidentList | Where-Object {$_.active -eq "true"} | Select number,short_description,opened_at,impact,priority | Sort-Object opened_at -Descending | Format-Table
"ActiveIncidents:$ActiveIncidentCount"
"TotalIncidents:$IncidentCount"
