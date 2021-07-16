
Function ExecuteAdoNonQuery {
Param(	[Parameter(Mandatory=$true,ValueFromPipeline=$true)]
		[String]$connectionString,
		[Parameter(Mandatory=$true,ValueFromPipeline=$true)]
		[String] $SQLStatement )
	$sqlCmd = new-object System.Data.Sqlclient.SqlCommand;
    $sqlCmd.CommandTimeout = 0;
	$sqlCmd.Connection = $connectionString;
	$sqlCmd.CommandText = $SQLStatement;
	$sqlCmd.Connection.Open();
	$sqlCmd.executeNonQuery();
	$sqlCmd.Connection.Close();
}

Function ExecuteAdoScalar {
Param(	[Parameter(Mandatory=$true,ValueFromPipeline=$true)]
		[String]$connectionString, 
		[Parameter(Mandatory=$true,ValueFromPipeline=$true)]
		[String]$SQLStatement )
	$sqlCmd = new-object System.Data.Sqlclient.SqlCommand;
    $sqlCmd.CommandTimeout = 0;
	$sqlCmd.Connection = $connectionString;
	$sqlCmd.CommandText = $SQLStatement;
	$sqlCmd.Connection.Open();
	[string]$value = $sqlCmd.ExecuteScalar();
	$sqlCmd.Connection.Close();
	return, $value
}

Function ExecuteAdoScalarWithMessage {
Param(	[Parameter(Mandatory=$true,ValueFromPipeline=$true)]
		[String]$connectionString, 
		[Parameter(Mandatory=$true,ValueFromPipeline=$true)]
		[String]$SQLStatement ,
		[String]$logfile,
		$timeout = 0)
	$conn = New-Object System.Data.SqlClient.SqlConnection "$connectionString"; 
	## Attach the InfoMessage Event Handler to the connection to write out the messages 
	$handler = [System.Data.SqlClient.SqlInfoMessageEventHandler] {param($sender, $event)  Write-Log $event.Message $logfile -nohost; $global:sqlerror = $event.Message;}; 
	$conn.add_InfoMessage($handler); 
	$conn.FireInfoMessageEventOnUserErrors = $true;
	$cmd = $conn.CreateCommand(); 
	$cmd.CommandTimeout = $timeout;
	$cmd.CommandText = $SQLStatement; 
	$conn.Open();
	[string]$returncode = $cmd.ExecuteScalar()
	$conn.Close();
	return, $returncode
}