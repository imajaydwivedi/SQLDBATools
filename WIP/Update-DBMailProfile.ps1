Function Update-DBMailProfile {
<#
.SYNOPSIS
Creates command modifies the default Database mail profile for server/instance passed as parameter
.DESCRIPTION
Creates command modifies the default Database mail profile for server/instance passed as parameter. Below are the steps taken in TSQL script:-

1)	Take out details like Mail profiles, Accounts, and Sequence Number into @ProfilesAccounts variable table.
2)	Check if an entry exists where profileName = @@SERVERNAME and accountName = ‘SQLAlerts’. If yes, then do nothing. Else proceed to Step 3.
3)	Take below actions:-
a.	Add profile if not exists
b.	Add account if not exists
c.	Bind account with profile if not there
d.	Move other account sequence number to > 1, and set sequence number for ‘SQLAlerts’ account to 1.

.PARAMETER SQLInstance
Name of the server where sp_Blitz procedures need to be created.
For Example:
Modify-DBMailProfile -SQLInstance ServerName01
.EXAMPLE
 Modify-DBMailProfile -SQLInstance ServerName01
 This example will create mail profile with server name (@@servername), set it as default public profile.
#>
    Param (
               [Alias('ServerName')][String]$SQLInstance,
               [String]$scriptPath = $PSScriptRoot+'\DatabaseMailProfile.sql'
          )

    Push-Location;
    Import-Module SQLPS -DisableNameChecking;
    Pop-Location;

    $path = "$PSScriptRoot\Results";
    If(!(test-path $path))
    {
          New-Item -ItemType Directory -Force -Path $path;
    }
    try
    {
        Write-Host "Executing script '$scriptPath' on [$SQLInstance] server.";
        Invoke-Sqlcmd -ServerInstance $SQLInstance -Database msdb -InputFile $scriptPath -ErrorAction Stop| `
            Out-File -FilePath "$path\$($SQLInstance)__OUTPUT.txt"
    }

    Catch
    {
        #Write-Host "        Error occurred" -BackgroundColor Yellow -ForegroundColor Red ;
        $ErrorMessage = $_.Exception.Message;
        "Error occurred:- $ErrorMessage" | `
            Out-File -FilePath "$path\$($SQLInstance)__ERROR.txt"
        Break
    }
}

$instances = Invoke-Sqlcmd -ServerInstance 'BAN-1ADWIVEDI-L' -Database DBServers_master -Query 'select [Server/Instance Name] as InstanceName from [dbo].[Production] as p 
	where p.[ID/Count] = 2';

foreach($inst in $instances) {
    Try
    {
        Modify-DBMailProfile -SQLInstance $inst.InstanceName;
    }
    Catch
    {
        #Write-Host "        Error occurred" -BackgroundColor Yellow -ForegroundColor Red ;
        $ErrorMessage = $_.Exception.Message;
        "Error occurred:- $ErrorMessage" | `
            Out-File -FilePath "$path\$($inst.InstanceName)__ERROR.txt" -Append;
        Break
    }
}


