<#
Remove-Module SQLDBATools -ErrorAction SilentlyContinue;
Import-Module SQLDBATools -DisableNameChecking;
#>

#Get-VolumeSpaceConsumers -ComputerName $env:computerName -pathOrFolder 'D:\' | Out-GridView;
Get-VolumeSpaceConsumers -ComputerName $env:COMPUTERNAME -pathOrFolder e:\ -Verbose | Out-GridView