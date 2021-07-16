$env:PSModulePath = $env:PSModulePath + ";" + "C:\Program Files\WindowsPowerShell\Modules;C:\Windows\system32\WindowsPowerShell\v1.0\Modules\;C:\Program Files\MVPSI\Modules\";
Import-Module SQLDBATools -DisableNameChecking -Force;

# Fetch ServerInstances from Inventory
$tsqlInventory = @"
select InstanceName from Info.Instance
"@;

$ServerInstances = @(Invoke-Sqlcmd -ServerInstance $sdtInventoryInstance -Database $sdtInventoryDatabase -Query $tsqlInventory | 
                        Select-Object -ExpandProperty InstanceName);

#Run-CommandMultiThreaded -ObjectList $ServerInstances -Command "Collect-SecurityCheckInfo" -InputParam ServerInstance -MaxThreads 26;
$Result = Get-SecurityCheckInfo -ServerInstance $ServerInstances;
#$Result | ft -AutoSize

$dtable = $Result | Out-DataTable;    

$cn = new-object System.Data.SqlClient.SqlConnection("Data Source=$sdtInventoryInstance;Integrated Security=SSPI;Initial Catalog=$sdtInventoryDatabase");
$cn.Open();

$bc = new-object ("System.Data.SqlClient.SqlBulkCopy") $cn;
$bc.DestinationTableName = "Staging.SecurityCheckInfo";
$bc.WriteToServer($dtable);
$cn.Close();