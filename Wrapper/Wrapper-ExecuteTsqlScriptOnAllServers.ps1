$env:PSModulePath = $env:PSModulePath + ";" + "C:\Program Files\WindowsPowerShell\Modules;C:\Windows\system32\WindowsPowerShell\v1.0\Modules\;C:\Program Files\MVPSI\Modules\";
Import-Module SQLDBATools -DisableNameChecking;

$tQuery = @"
    select InstanceName  from Info.Instance
"@;

$Servers = Invoke-Sqlcmd -ServerInstance $sdtInventoryInstance -Database $sdtInventoryDatabase -Query $tQuery | Select-Object -ExpandProperty InstanceName;

$Services = $Servers | Run-CommandMultiThreaded -Command "Get-Service" `
                            -InputParam 'ComputerName'

$Services | Where-Object {$_.Name -like '*sql*' } | Select-Object MachineName, Name, DisplayName, Status, StartType | ft -AutoSize