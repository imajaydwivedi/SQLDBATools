$timestamp = (get-date).ToString('yyMMMddhhmmss')
$outputpath = 'E:\inetpub\wwwroot\InfrastructureInfo\sn\users'
$inputpath = 'E:\PSSCripts\SNOWScripts\users.txt'
$pwpath = 'E:\psscripts\snowscripts\cred\snowpw.txt'
$date = (get-date).tostring('g')
[string]$user = 'rharrington_ps'
[string]$password = get-content $pwpath

[string]$instance = 'YourOrg'

#// Set Instance 
$InstanceName = "https://"+$Instance+".service-now.com/" 
 
#// Create SN REST API credentials 
$SNowUser = $User 
$SNowPass = $Password | ConvertTo-SecureString -asPlainText -Force 
$SNowCreds = New-Object –TypeName System.Management.Automation.PSCredential –ArgumentList $SNowUser, $SNowPass 
 
$users = gc $inputpath
foreach($user in $users)
{
[string]$AssignedTo = $user
[string]$displayname = get-aduser -identity $assignedto |select -ExpandProperty name
$newname = $displayname.replace(' ','_')
$outputhtml = "$outputpath\$newname.html"
'<html>'|out-file $outputhtml
'<center><h1>' + "$displayname Open Tickets" + '</h1></center>' |out-file $outputhtml -append

'<center><i>Last Update: '+ $date +'</i></center>'  |out-file $outputhtml -append


#// Get all items Assigned To 
$URI = ''
$items = ''
$results = ''
$URI = $InstanceName+"api/now/table/sc_req_item?sysparm_query=assigned_to.user_name=$assignedto"+"^state=2^ORstate=9^ORstate=13" 
$URI2 = $InstanceName+"api/now/table/incident?sysparm_query=assigned_to.user_name=$assignedto"+"^state=2^ORstate=9^ORstate=13^ORstate=3^ORstate=1"
$items = @()
$items += try{Invoke-RestMethod -Uri $URI -Credential $SNowCreds -Method GET -ContentType "application/json"}catch{ 
'Service Now Query failed. Check your queue directly.' |out-file $outputhtml -append
continue}
$items += try{Invoke-RestMethod -Uri $URI2 -Credential $SNowCreds -Method GET -ContentType "application/json"}catch{
'Service Now Query failed. Check your queue directly.' |out-file $outputhtml -append
continue}
$Resultsunsorted = $items.result # |sort number -Descending

$results = $Resultsunsorted |sort opened_at -Descending
#// Show each item found 
$item = ''
foreach ($item in $Results) { 
    $openedby = ''
    $Openedby = get-aduser -identity $item.sys_created_by |select -ExpandProperty name
    $ReqURLbase =  ''
    if($item.number -like "RIT*")
    {$ReqURLbase = "https://YourOrg.service-now.com/nav_to.do?uri=sc_req_item.do?sys_id="}
    if($item.number -like "INC*")
    {$ReqURLbase = "https://YourOrg.service-now.com/nav_to.do?uri=incident.do?sys_id="}
    $ReqURLFull = ''
    $ReqURLFull = $ReqURLbase+$item.sys_id
    '<a href=' +$requrlfull +'><b>' + $item.number + '</b></a><br><br>'|out-file $outputhtml -append
    #'Number: ' +  + '<br><br>'|out-file $outputhtml -append
    '<b>Date Opened:</b> ' + $item.opened_at + '<br><br>'|out-file $outputhtml -append
    '<b>Opened by:</b> ' + $openedby +'<br><br>'|out-file $outputhtml -append
    '<b>Short Description:</b> ' + $item.short_description.replace("`n","<br>") + '<br><br>'|out-file $outputhtml -append
    '<b>Full Description:</b> ' + '<br><br>' |out-file $outputhtml -append
    $item.description.Replace("`n","<br>")   |out-file $outputhtml -append
    '<br><br><hr><br>'|out-file $outputhtml -append

}#end foreach $result
'</html>' |out-file $outputhtml -append
}#end foreach $user
