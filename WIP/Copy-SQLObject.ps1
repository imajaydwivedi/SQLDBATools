#Function Copy-SQLObject
#{
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true)]
        [Alias('ServerName','MachineName')]
        $ComputerName = $env:COMPUTERNAME,

        [String[]]$DatabaseName
    )
    $InstanceName = 'DEFAULT';

    Import-Module SQLPS -DisableNameChecking;

    $dbs = Get-ChildItem "SQLServer:\SQL\$ComputerName\$InstanceName\Databases";

    foreach($dbObject in $dbs)
    {
        $tables = $dbObject.Tables 
    }
    $tables;
    

#}