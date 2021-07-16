function Restore-DatabaseByScriptOut
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] [string]$SourceSqlInstance,
        [Parameter(Mandatory=$true)] [string]$SourceDatabase,
        [Parameter(Mandatory=$true)] [string]$DestinationSqlInstance,
        [Parameter(Mandatory=$true)] [string]$DestinationDatabase,
        [Parameter(Mandatory=$true)] [string]$WorkingDirectory,
        [Parameter(Mandatory=$false)][switch]$CreateDatabaseShell
    )

    if($CreateDatabaseShell) 
    {
        Write-Verbose "Logic to create Database Shell begins here..";

        $d_srv = new-Object Microsoft.SqlServer.Management.Smo.Server("$DestinationSqlInstance")  
        $d_db = New-Object Microsoft.SqlServer.Management.Smo.Database($d_srv, "$DestinationDatabase")  
        $d_db.Create()  
        if($d_db.CreateDate) {
            Write-Verbose "Database [$DestinationSqlInstance].[$DestinationDatabase] shell is created..";
        }

    }else {
        Write-Verbose "Checking to make sure database [$DestinationSqlInstance].[$DestinationDatabase] shell already exists";
    }

    $SourceSqlInstance_p = $SourceSqlInstance;
    if($SourceSqlInstance -notcontains '\') {$SourceSqlInstance_p += '\MSSQLSERVER'}

    $DestinationSqlInstance_p = $DestinationSqlInstance;
    if($DestinationSqlInstance -notcontains '\') {$DestinationSqlInstance_p += '\MSSQLSERVER'}
}

Invoke-Sqlcmd -ServerInstance tul1dbapmtdb1 -Query 'drop database Global';

Restore-DatabaseByScriptOut -SourceSqlInstance TUL1RAZPDB1 -SourceDatabase Global `
                            -DestinationSqlInstance TUL1DBAPMTDB1 -DestinationDatabase Global `
                            -WorkingDirectory c:\temp\migration -CreateDatabaseShell `
                            -Verbose