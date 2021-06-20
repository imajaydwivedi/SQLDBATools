Function Add-SecurityCheckInfo
{
    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true)]
        [Alias('ServerName','SQLInstance')]
        [String]$ServerInstance
    )
    $Result = $null;
    $Result = Get-SecurityCheckInfo -ServerInstance $ServerInstance;
    
    Write-Host "Result for [$ServerInstance]:-" -ForegroundColor Green;
    $Result | ft -AutoSize;

    if([String]::IsNullOrEmpty($Result))
    {
        Add-CollectionError -ComputerName $ServerInstance `
                            -Cmdlet 'Collect-SecurityCheckInfo' `
                            -CommandText "Get-SecurityCheckInfo -ServerInstance $ServerInstance" `
                            -ErrorText "Get-SecurityCheckInfo did not return output for server" `
                            -Remark $null;
        if($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent) {
            Write-Host "Error ($ServerInstance) => Error occurred. Kindly check [DBA].[Staging].[CollectionErrors] table " -ForegroundColor Red;
        }

        return;
    }

    $dtable = $Result | Out-DataTable;    

    $cn = new-object System.Data.SqlClient.SqlConnection("Data Source=$sdtInventoryInstance;Integrated Security=SSPI;Initial Catalog=$sdtInventoryDatabase");
    $cn.Open();

    $bc = new-object ("System.Data.SqlClient.SqlBulkCopy") $cn;
    $bc.DestinationTableName = "Staging.SecurityCheckInfo";
    $bc.WriteToServer($dtable);
    $cn.Close();
}