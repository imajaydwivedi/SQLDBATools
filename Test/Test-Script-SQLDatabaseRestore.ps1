Clear-Host;

Script-SQLDatabaseRestore   -RestoreCategory LatestAvailable `
                            -Source_SQLInstance SqlProd1 `
                            -SourceDatabase Cosmo `
                            -Destination_SQLInstance SqlProd1 `
                            -DestinationPath_Data "F:\mssqldata\Data" `
                            -DestinationPath_Log "E:\Mssqldata\Log" `
                            -Verbose;

<#
Script-SQLDatabaseRestore   -BackupPath '\\SqlProd3\g$\Backup' `
                            -RestoreCategory LatestAvailable `
                            -Destination_SQLInstance SqlProd1 `
                            -DestinationPath_Data "F:\mssqldata\Data" `
                            -DestinationPath_Log "E:\Mssqldata\Log" `
                            -Verbose
#>
