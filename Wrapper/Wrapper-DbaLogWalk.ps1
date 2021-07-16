<#
Remove-Module SQLDBATools -ErrorAction SilentlyContinue;
Import-Module SQLDBATools -DisableNameChecking;
#>
cls
$SourceDatabases_DS12 = @('AMG_AVG','AMG_Extra','AMG_Music','AMG_MusicMore','Babel','DSG_EU','Facebook','Mosaic','MuzeUK','MuzeUS','MuzeVideo','Prism','RGS','RCM_morecore_20130710_NoMusic1a_en-US','Sky','Staging','Staging2','Twitter','TVGolConfigs','UKVideo');
foreach($SourceDb in $SourceDatabases_DS12)
{
    Setup-DbaLogWalk -SourceServer TUL1MDPDWMID01 -SourceDbName $SourceDb -DestinationServer TUL1MDPDWDS12 -GenerateRESTOREScriptOnly;
}

$SourceDatabases_DS13 = @('AMG_AVG','AMG_Extra','AMG_Music','AMG_MusicMore','Babel','DSG_EU','Facebook','IDS_Turner','Mosaic','MuzeUK','MuzeVideo','Prism','Staging','Staging2','Twitter','TVGolConfigs');
foreach($SourceDb in $SourceDatabases_DS13)
{
    Setup-DbaLogWalk -SourceServer TUL1MDPDWMID01 -SourceDbName $SourceDb -DestinationServer TUL1MDPDWDS13 -GenerateRESTOREScriptOnly;
}

<#
$babelHistory = Get-DbaBackupHistory -SqlInstance TUL1CIPCNPDB1 -Database Babel -Last
$babelHistory | Select-Object * | ogv
    $ProcessAllLogBackups = $true;
    $logBackupFiles_Count = 0;
    if($ProcessAllLogBackups)
    {
        @($babelHistory | Where-Object {$_.Type -eq 'LOG'}).Count
    }
#>
<#
foreach($bkp in $babelHistory)
{
        $bkpFileSize_GB = $bkp.CompressedBackupSize.Gigabyte;
        #if([string]::IsNullOrEmpty($bkpFileSize)) {$bkpFileSize = $bkp.TotalSize}

        #$bkpFileSizeUnit = $bkpFileSize.SubString($bkpFileSize.LastIndexOf(' ')+1);
        #$bkpFileSizeValue = [float]($bkpFileSize.Substring(0,$bkpFileSize.LastIndexOf(' ')));
        #$bkpFileSize_GB = if($bkpFileSizeUnit -eq 'KB'){0} elseif($bkpFileSizeUnit -eq 'MB'){1} elseif ($bkpFileSizeUnit -eq 'GB'){$bkpFileSizeValue} elseif($bkpFileSizeUnit -eq 'TB'){$bkpFileSizeValue*1024};

        if($bkpFileSize_GB -le 30 -and $bkp.Path -match ":") {
            $backupPath = "\\$SourceServer\" + ($($bkp.Path) -replace ':\\','$\');   
        }else {
            $backupPath = $bkp.Path;
        }
        $backupPath
}
#>


#Invoke-Command -ComputerName DestinationServer -ScriptBlock { robocopy '\\TUL1MDPDWMID01\J$\MSSQLData\Backups' 'Local\Path\On\Destination' Babel_FULL_20190613.bak }