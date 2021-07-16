$sizeThreshold_In_MB = 5;
$pingResultPath = 'F:\PingMirroringPartners\';
$pingResultFile = 'F:\PingMirroringPartners\pingResult';
$names = @('Server01','Server02');
# Delete files older than 15 days
$limit = (Get-Date).AddDays(-15);
Get-ChildItem -Path $pingResultPath -Recurse -Force | Where-Object {$_.Name -like 'pingResult*' -and !$_.PSIsContainer -and $_.CreationTime -lt $limit } | Remove-Item -Force;

if (Test-Path $pingResultFile -PathType Leaf)
{
  $fileDetails = Get-ItemProperty $pingResultFile;
  $sizeInKB = ([Math]::Ceiling(($fileDetails.Length/1mb)));

  if ($sizeInKB -ge $sizeThreshold_In_MB)
  {
    Write-Host "Renaming file $pingResultFile to $($pingResultFile) $(Get-Date -Format ddMMMyyyyTHHmm) since threshold size of $sizeThreshold_In_MB MB is crossed.";
    Rename-Item -Path $pingResultFile -NewName ($pingResultFile+(Get-Date -Format ddMMMyyyyTHHmm));
  }
}

foreach ($name in $names)
{
  if (Test-Connection -ComputerName $name -Count 1 -ErrorAction SilentlyContinue)
  {
   Out-File -FilePath $pingResultFile -Append -InputObject "$((Get-Date).ToString()) - $name is Up and Running";
  }
  else
  {
    Out-File -FilePath $pingResultFile -Append -InputObject "$((Get-Date).ToString()) - $name is not connecting";
    Out-File -FilePath $pingResultFile -Append -InputObject (Test-Connection $name -Count 1 );
  }
}
# Return 0 for Success
return 0; 