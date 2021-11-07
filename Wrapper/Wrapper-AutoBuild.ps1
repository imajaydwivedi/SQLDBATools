function Install-SqlInstance {
<#
    .SYNOPSIS
    This function installs and configures SQL Server on computer
    .DESCRIPTION
    This function take ServerName, SQLServiceAccount, InstanceName etc are parameters, and installl SQL Server on Server.
    .PARAMETER ServerName
    Name of the Server where SQL Services will be installed
    .PARAMETER SQLServiceAccount
    SQL Server Service account to choose out of "Corporate\DevSQL", "Corporate\ProdSQL" and "Corporate\QASQL". By default 'Corporate\DevSQL' is passed.
    .InstanceName
    Name of the Instance. By default assumed to be default installation 'MSSQLSERVER'.
#>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [Alias('ComputerName')]
        [String]$ServerName,

        [Parameter(Mandatory=$true)]
        [ValidateSet(2014, 2016, 2017, 2019)]
        [String] $Version = 2014,

        [Parameter(Mandatory=$true)]
        [ValidateSet('Developer','Enterprise','Standard','Express')]
        [String] $Edition = 'Developer',

        [Parameter(Mandatory=$false)]
        [ValidateSet("Corporate\DevSQL", "Corporate\ProdSQL", "Corporate\QASQL")]
        [string] $SQLServiceAccount = 'Corporate\DevSQL',

        [Parameter(Mandatory=$false)]
        [string] $InstanceName = 'MSSQLSERVER',

        [Parameter(Mandatory=$false)]
        [string] $SQLServiceAccountPassword,

        [Parameter(Mandatory=$false)]
        [string] $SAPassword,

        [Parameter(Mandatory=$false)]
        [string] $Administrators = 'Corporate\SQL Admins'        
    )

    $sdtSQL_Server_Setups = "$SdtSQL_Server_Setups";

    Write-Verbose "Creating credentail for SQLDBATools for PSRemoting";

    # File Path for Credentials & Key
    $SQLDBATools = Get-Module -ListAvailable -Name SQLDBATools | Select-Object -ExpandProperty ModuleBase;
    $AESKeyFilePath = "$SQLDBATools\SQLDBATools_AESKey.key";
    $credentialFilePath = "$SQLDBATools\SQLDBATools_Credentials.xml";
    $sdtSQL_Server_Setups = "$SdtSQL_Server_Setups";
    [string]$userName = 'Corporate\SQLDBATools'

    # Create credential Object
    $AESKey = Get-Content $AESKeyFilePath;
    $pwdTxt = (Import-Clixml $credentialFilePath | Where-Object {$_.UserName -eq $userName}).Password;
    [SecureString]$securePwd = $pwdTxt | ConvertTo-SecureString -Key $AESKey;
    [PSCredential]$credentialObject = New-Object System.Management.Automation.PSCredential -ArgumentList $userName, $securePwd;

    Write-Verbose "Registering PSSessionConfiguration for SQLDBATools";
    # Create PSSessionConfig
    #Invoke-Command -ComputerName $ServerName -ScriptBlock { Register-PSSessionConfiguration -Name SQLDBATools -RunAsCredential $Using:credentialObject -Force -WarningAction Ignore}

    Write-Verbose "Starting PSRemoting Session to perform SQL Installation";
    $scriptBlock = {
        $sdtSQL_Server_Setups = $Using:sdtSQL_Server_Setups;
        $Version = $Using:Version;
        $Edition = $Using:Edition;
        $SetupFolder = "$sdtSQL_Server_Setups\$Version\$Edition";
        $SetupFolder_Local = "C:\";

        # Copy Setup File
        Write-Output "Copying SQL Server setup from path '$SetupFolder' to '$SetupFolder_Local' ..";
        Copy-Item $SetupFolder -Destination $SetupFolder_Local -Recurse -Force;    
    }
    #$scriptBlock = {$env:COMPUTERNAME}
    #Invoke-Command -ComputerName $ServerName -ScriptBlock $scriptBlock -ConfigurationName SQLDBATools -ErrorVariable err;
    $VerbosePreference;
    Invoke-Command -ComputerName $ServerName -ScriptBlock $scriptBlock -ConfigurationName SQLDBATools -ErrorVariable err;
    
    Write-Host $err;
    #Get-Service *winrm* -ComputerName $ServerName | Start-Service

    Write-Verbose "PSRemoting Session ended.";
}

$ServerName = 'SqlPoc01'; $Version = 2014; $Edition = 'Developer';
Install-SqlInstance -ServerName $ServerName -Version 2014 -Edition Developer -Verbose;