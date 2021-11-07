function AutoBuild {
<#
    .SYNOPSIS
    This function installs and configures SQL Server on local computer
    .DESCRIPTION
    This function take SQLServiceAccount, InstanceName etc as parameters, and installl SQL Server on Server.
    .PARAMETER SQLServiceAccount
    SQL Server Service account to choose out of "Corporate\DevSQL", "Corporate\ProdSQL" and "Corporate\QASQL". By default 'Corporate\DevSQL' is passed.
    .PARAMETER InstanceName
    Name of the Instance. By default assumed to be default installation 'MSSQLSERVER'.
    .PARAMETER SQLServiceAccountPassword
    Password for SQL Service account. By Default will be fetched from SQLDBATools Inventory.
    .PARAMETER SAPassword
    Password for SA account. By Default will be fetched from SQLDBATools Inventory.
    .PARAMETER Administrators
    AD accounts that are to be made SysAdmin in SqlInstance. By default, 'Coprorate\SQL Admins' is added.    
    .EXAMPLE
    . .\AutoBuild.ps1; AutoBuild -SQLServiceAccount 'Corporate\ProdSQL'
    This command will install default instance on server with 'Corporate\ProdSQL' as Service account along with all other default parameter values.
    .EXAMPLE
    . .\AutoBuild.ps1; AutoBuild -InstanceName 'SQL2016'
    This command will install Named instance 'SQL2016' with all other default parameter values.
    .LINK
    https://github.com/imajaydwivedi/SQLDBATools
#>
    [CmdletBinding(SupportsShouldProcess=$True, ConfirmImpact='High')]
    param(
        [Parameter(Mandatory=$false)]
        [ValidateSet("Corporate\DevSQL", "Corporate\ProdSQL", "Corporate\QASQL")]
        [string] $SQLServiceAccount = 'Corporate\ProdSQL',

        [Parameter(Mandatory=$false)]
        [string] $InstanceName = 'MSSQLSERVER',

        [Parameter(Mandatory=$false)]
        [string] $SQLServiceAccountPassword,

        [Parameter(Mandatory=$false)]
        [string] $SAPassword,

        [Parameter(Mandatory=$false)]
        [string] $Administrators = 'Corporate\SQL Admins',

        [Parameter(Mandatory=$false)]
        [string] $SdtSqlServerRepository = "$SdtSqlServerRepository"
    )

    $ConfigFile = "$PSScriptRoot\ConfigurationFile.ini";

    Write-Verbose "Validating existence of Install Directories as per ConfigurationFile ..";
    if(Get-Content $ConfigFile | Where-Object {$_ -match "INSTALLSQLDATADIR=`"(?'INSTALLSQLDATADIR'.+)`""}) {
        $INSTALLSQLDATADIR = (($Matches['INSTALLSQLDATADIR']).split('\')[0])+'\';
    }
    if(Get-Content $ConfigFile | Where-Object {$_ -match "SQLBACKUPDIR=`"(?'SQLBACKUPDIR'.+)`""}) {
        $SQLBACKUPDIR = (($Matches['SQLBACKUPDIR']).split('\')[0])+'\';
    }
    if(Get-Content $ConfigFile | Where-Object {$_ -match "SQLUSERDBDIR=`"(?'SQLUSERDBDIR'.+)`""}) {
        $SQLUSERDBDIR = (($Matches['SQLUSERDBDIR']).split('\')[0])+'\';
    }
    if(Get-Content $ConfigFile | Where-Object {$_ -match "SQLUSERDBLOGDIR=`"(?'SQLUSERDBLOGDIR'.+)`""}) {
        $SQLUSERDBLOGDIR = (($Matches['SQLUSERDBLOGDIR']).split('\')[0])+'\';
    }
    if(Get-Content $ConfigFile | Where-Object {$_ -match "SQLTEMPDBDIR=`"(?'SQLTEMPDBDIR'.+)`""}) {
        $SQLTEMPDBDIR = (($Matches['SQLTEMPDBDIR']).split('\')[0])+'\';
    }

    if( -not ( (Test-Path $INSTALLSQLDATADIR) -and  (Test-Path $SQLBACKUPDIR) -and (Test-Path $SQLUSERDBDIR) -and (Test-Path $SQLUSERDBLOGDIR) -and (Test-Path $SQLTEMPDBDIR) ) ) {
        Write-Host "Kindly make sure all reqired disk drives are present.`n$INSTALLSQLDATADIR, $SQLUSERDBDIR, $SQLUSERDBLOGDIR, $SQLBACKUPDIR & $SQLTEMPDBDIR" -ForegroundColor Red;
        if((Get-PSCallStack).Count -gt 1) {
            return
        }
    }

    # Install JRE
    Write-Verbose "Make sure JRE is installed";
    Write-Verbose "`$SdtSqlServerRepository = "$SdtSqlServerRepository""
    Start-Process -Wait -FilePath "$SdtSqlServerRepository\jre-8u231-windows-x64.exe" -ArgumentList "/s" -NoNewWindow;

    # Install .net Framework
    Write-Verbose "Validating dot net Framework feature..";
    if((Get-WindowsFeature Net-Framework-Core).Installed -eq $false) {
        Install-WindowsFeature Net-Framework-Core -source "$($SdtSqlServerRepository)dotNetFx40_Full_x86_x64.exe" | Out-Null;
        Install-WindowsFeature Net-Framework-Core -source "$($SdtSqlServerRepository)dotNetFx35setup.exe" | Out-Null;
    }

    # If SQLServiceAccountPassword or SAPassword is not provided in parameter
    Write-Verbose "Validating All Passwords";
    if([string]::IsNullOrEmpty($SQLServiceAccountPassword) -or [string]::IsNullOrEmpty($SAPassword)) {
        $InventoryServer = $SdtInventoryInstance;
        $ssn = New-PSSession -ComputerName $InventoryServer -Name $InventoryServer;

        if([string]::IsNullOrEmpty($SQLServiceAccountPassword)) {
            # Get Password for SQLServiceAccount
            $ScriptBlock = { Import-Module SQLDBATools; Get-Password4Account -UserName $Using:SQLServiceAccount; }
            $SQLServiceAccountPassword = Invoke-Command -Session $ssn -ScriptBlock $ScriptBlock;
        }

        if([string]::IsNullOrEmpty($SAPassword)) {
            # Get Password for SA
            $ScriptBlock = { Import-Module SQLDBATools; Get-Password4Account -UserName "SA"; }
            $SAPassword = Invoke-Command -Session $ssn -ScriptBlock $ScriptBlock;
        }
    }

    Write-Verbose "Starting installation of SQL Server setup..";
    if($InstanceName -ne 'MSSQLSERVER') {
        $configFileContent = Get-Content 'ConfigurationFile.ini';
        $configFileContent.Replace("MSSQLSERVER",$InstanceName) | Set-Content 'ConfigurationFile.ini';
    }

    .\SETUP.EXE /INSTANCENAME=$InstanceName /SQLSYSADMINACCOUNTS=$Administrators `
                /SQLSVCACCOUNT=$SQLServiceAccount /SQLSVCPASSWORD=$SQLServiceAccountPassword `
                /AGTSVCACCOUNT=$SQLServiceAccount /AGTSVCPASSWORD=$SQLServiceAccountPassword `
                /SAPWD=$SAPassword /CONFIGURATIONFILE="./ConfigurationFile.ini"
            
    $logFolder = 'C:\Program Files\Microsoft SQL Server\130\Setup Bootstrap\Log';
    $logFolder_remote = '\\'+$env:COMPUTERNAME+'\'+($logFolder.Replace(':','$'));
    Write-Verbose "Setup Logs can be found in below path:-`n$logFolder_remote`n";
    <#
        1) Open Summary.txt
        2) Open folder with most recent Modified Date. Folder name would be like '20191016_135940'
        3) If step 01 file not present, open file like 'Summary_TESTVM_20191016_135940' in step 02 folder
    #>

    $Summary = Get-Content "$logFolder\Summary.txt" | Select-Object -First 6;
    $Summary | Where-Object {$_ -match "Exit code \(Decimal\):\s*(?'ExitCode'\d+)"} | Out-Null
    $ExitCode = $Matches['ExitCode'];
    Write-Verbose "`$ExitCode = $ExitCode";
    
    if($ExitCode -eq 0) {
        Write-Output "--------------------------`nInstallation completed Successfully`n--------------------------";
        Write-Verbose "`n$Summary`n" ;
        return '0'; # return success
    } 
    elseif($ExitCode -eq 3010) {
        Write-Output "Installation completed but REBOOT is required";
        Write-Verbose $Summary;
        return "$ExitCode"; # return ExitCode
    }
    else {
        Write-Output "`n--------------------------`nSome Issue occurred. Kindly check summary page.`n--------------------------";
        Write-Verbose "`nexplorer '$logFolder_remote'";
        Write-Verbose "`nnotepad '$logFolder\Summary.txt'`n";
        return "$ExitCode"; # return ExitCode
    }
}