Function Get-SQLServices_HashArray
{
    [CmdletBinding()]
    [Alias('Computers','Machines')]
    Param (
        [String[]]$Servers = $env:COMPUTERNAME
    )

    $ServiceStatus = @{}; #Initialize our Version Hash table

    foreach($computer in $Servers)
    {
        Get-Service -Name *SQL* -ComputerName $computer -ErrorAction SilentlyContinue |
            Sort-Object -Property DisplayName |
            foreach {
                $k = $computer + ' - ' + $_.DisplayName # Key
                $v = $_.Status                          # Value
                $ServiceStatus[$k] = $v;
                
                # Get Parent Service without which start is not possible #
                Get-Service $_.Name |
                    Select-Object -ExpandProperty ServicesDependedOn |
                    foreach {
                        $kd = $k + " has dependency on " + $_.DisplayName;
                        $s = $_.Status;
                        $ServiceStatus[$kd] = $s;
                    } # Inner Get-Services
            } # Outer Get-Service
    } # Loop for $Computers

    <# GetEnumerator method sends each entry in the hash table across the pipeline as a separate object #>
    $ServiceStatus.GetEnumerator() | Sort-Object Value;
    #$ServiceStatus.GetEnumerator() | Sort-Object Value | Format-Table -AutoSize;
    #$ServiceStatus.GetEnumerator() | Sort-Object Value | Where-Object {$_.Value -eq 'Stopped'};
    #$ServiceStatus.GetEnumerator() | Where-Object {$_.Value -eq 'Stopped' -and $_.Name -notlike "*SQL Server Agent*"} | ft -AutoSize
    <#
    $body = $ServiceStatus.GetEnumerator() | Where-Object {$_.Value -eq 'Stopped' -and $_.Name -notlike "*SQL Server Agent*"} | ft -AutoSize | Out-String;
    Send-SQLMail -Subject "Stopped Services" -Body $body;
    #>
}