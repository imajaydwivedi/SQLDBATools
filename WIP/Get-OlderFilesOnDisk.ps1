function Get-OlderFilesOnDisk {
<#
    .SYNOPSIS
    Get files from disk older than threshold hours
    .DESCRIPTION
    .PARAMETER
    .EXAMPLE
    .LINK
    https://github.com/imajaydwivedi/SQLDBATools
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)]
        [Alias('ServerName')]
        [string]$ComputerName,

        [Parameter(Mandatory=$true)]
        [Alias('Path')]
        [string]$Directory,

        [Parameter(Mandatory=$false)]
        [Alias('ThresholdTime_Hours')]
        [int]$Hours = 120
    )
    Write-Verbose "Validating variables..";

    Write-Verbose "Executing remote script to find files older than $Hours hours";
    $scriptBlock = {
        $files_all = Get-ChildItem -Path $Using:Directory -Recurse | Where-Object {-not $_.PSIsContainer};
        [System.Collections.ArrayList]$files_old = @();

        if($files_all.Count -gt 0) {
            foreach($file in $files_all) {
                $LastUsedTime = $null;
                if($file.LastAccessTime -ge $file.LastWriteTime -and $file.LastAccessTime -ge $file.CreationTime) {
                    $LastUsedTime = $file.LastAccessTime;
                }elseif($file.LastWriteTime -ge $file.CreationTime) {
                    $LastUsedTime = $file.LastWriteTime;
                }else {
                    $LastUsedTime = $file.CreationTime;
                }
                $age = ((Get-Date) - $LastUsedTime); # LastAccessTime, LastWriteTime, CreationTime
                $age_Hours = ($age.Days * 24) + ($age.Hours);
                
                if($age_Hours -gt $Hours) {
                    #$file | Add-Member -MemberType NoteProperty -Name LastUsed_Hours -Value $age_Hours;
                    $files_old.Add($file) | Out-Null;
                } # take action on older files
            } # process each file
        } # process if files are found
        Write-Output $files_old;
    }
    $olderFiles = Invoke-Command -ComputerName $ComputerName -ScriptBlock $scriptBlock | Sort-Object -Property LastAccessTime, LastWriteTime, CreationTime;
    Write-Output $olderFiles
}

Get-OlderFilesOnDisk -ComputerName tul1cipxdb15 -Directory 'F:\' -Hours 168 | ogv