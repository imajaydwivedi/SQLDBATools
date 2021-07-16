[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("Corporate\DevSQL", "Corporate\ProdSQL", "Corporate\QASQL")]
    [string] $SQLServiceAccount = 'Corporate\DevSQL',

    [Parameter(Mandatory=$false)]
    [string] $InstanceName = 'MSSQLSERVER'
)

# Find temp File path
$tmp = [System.IO.Path]::GetTempFileName()

Write-Verbose "Export current Local Security Policy";
secedit.exe /export /cfg "$($tmp)"

$c = Get-Content -Path $tmp;

$SqlServicePriviledges = @();
$ArrySqlPriviledges = @('SeInteractiveLogonRight','SeServiceLogonRight','SeAssignPrimaryTokenPrivilege','SeChangeNotifyPrivilege','SeIncreaseQuotaPrivilege','SeManageVolumePrivilege');

<#
    Log on as a service (SeServiceLogonRight)
    Replace a process-level token (SeAssignPrimaryTokenPrivilege)
    Bypass traverse checking (SeChangeNotifyPrivilege)
    Adjust memory quotas for a process (SeIncreaseQuotaPrivilege)
    Perform Volume Maintainence Tasks (SeManageVolumePrivilege)
#>
foreach($s in $c) 
{
    foreach($p in $ArrySqlPriviledges)
    {
        $currentSetting = "";
        $actionNeeded = $true;
	    if( $s -like "$p*") 
        {
		    $x = $s.split("=",[System.StringSplitOptions]::RemoveEmptyEntries)
		    $currentSetting = $x[1].Trim();

            if( [string]::IsNullOrEmpty($currentSetting) ) {
		        $currentSetting = "*$($sidstr)";
	        } elseif ($currentSetting -notlike "*$($sidstr)*") {
                $currentSetting = "*$($sidstr),$($currentSetting)";
            } else {
		        Write-Verbose "No action needed for Log on Locally";
                $actionNeeded = $false;
	        }
        
            if ($actionNeeded)
            {
                $priviledge = [Ordered]@{
                    'PolicyName' = $x[0];
                    'PolicyMembers' = $currentSetting;
                }
                $priviledgeObj = New-Object -TypeName PSObject -Property $priviledge;
                $SqlServicePriviledges += $priviledgeObj;
            }
	    }
        
    }
}

if( $SqlServicePriviledges.Count -gt 0)
{
    $SqlServicePriviledges;
    $outfile = '';
    foreach($item in $SqlServicePriviledges)
    {
        $outfile += @"
[Unicode]
Unicode=yes
[Version]
signature="`$CHICAGO`$"
Revision=1
[Privilege Rights]
$($item.PolicyName) = $($item.PolicyMembers)
"@
    }

    $tmp2 = [System.IO.Path]::GetTempFileName()
	
	
	Write-Verbose "Import new settings to Local Security Policy" -ForegroundColor DarkCyan
	$outfile | Set-Content -Path $tmp2 -Encoding Unicode -Force

	#notepad.exe $tmp2
	Push-Location (Split-Path $tmp2)
	
	try {
		secedit.exe /configure /db "secedit.sdb" /cfg "$($tmp2)" /areas USER_RIGHTS 
		#write-host "secedit.exe /configure /db ""secedit.sdb"" /cfg ""$($tmp2)"" /areas USER_RIGHTS "
	} finally {	
		Pop-Location
	}
}
else {
	Write-Verbose "NO ACTIONS REQUIRED regarding SQL Service Account Priviledges!"
}

Write-Host "SQL Service Account Priviledges! Finished!"
