Clear-Host;

Script-SQLDatabaseRestore   -RestoreCategory LatestAvailable `
                            -Source_SQLInstance TUL1CIPEDB2 `
                            -SourceDatabase Cosmo `
                            -Destination_SQLInstance TUL1DBAPMTDB1 `
                            -DestinationPath_Data "F:\mssqldata\Data" `
                            -DestinationPath_Log "E:\Mssqldata\Log" `
                            -Verbose;

<#
Script-SQLDatabaseRestore   -BackupPath '\\Tul1cipedb3\g$\Backup' `
                            -RestoreCategory LatestAvailable `
                            -Destination_SQLInstance TUL1DBAPMTDB1 `
                            -DestinationPath_Data "F:\mssqldata\Data" `
                            -DestinationPath_Log "E:\Mssqldata\Log" `
                            -Verbose
#>
