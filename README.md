# SQLDBATools
Powershell Module containing cmdlets for carrying out SQL DBA activities. It includes:-

## Get-SdtServerInfo
This function returns basic information about machine(s) passed in pipeline or as value. This includes Operating System, Service Pack, LastBoot Time, Model, RAM & CPU for computer(s).

![](https://github.com/imajaydwivedi/Images/raw/master/SQLDBATools/Get-ServerInfo.gif)

## Get-SdtVolumeInfo
This function returns utilization of Disk Volumes on machine including mounted volumes.

[![Watch this video](https://github.com/imajaydwivedi/Images/raw/master/SQLDBATools/Get-VolumeInfo.gif)](https://youtu.be/n160GyC0g-8)

## Script-SdtSQLDatabaseRestore
This function accepts backup path, data and log directory for restore operation on destination sql instance, and create RESTORE script for database restore/migration activity.
It can be used for performing database restore operation with latest available backups on BackupPath.
Can be used to restore database for Point In Time.
Can be used for restoring database with new name on Destination SQL Instance.

![](https://github.com/imajaydwivedi/Images/raw/master/SQLDBATools/Help___Script-SQLDatabaseRestore.gif)

For more information on how to use this, kindly [watch below YouTube video](https://youtu.be/v4r2lhIFii4):-

[![Watch this video](https://github.com/imajaydwivedi/Images/raw/master/SQLDBATools/PlayThumbnail____Script-SQLDatabaseRestore.jpg)](https://youtu.be/v4r2lhIFii4)

## Get-SdtProcessForDBA
This function displays ComputerName, ProcessId, ProcessName, Description, StartTime, Threads, Memory(MB), Path, Company, Product for all processes of Server name(s) passed as parameter.

![](https://github.com/imajaydwivedi/Images/raw/master/SQLDBATools/Get-ProcessForDBA.gif)

For more information on how to use this, kindly [watch below YouTube video](https://youtu.be/bhzc2LO2Pb4):-

[![Watch this video](https://github.com/imajaydwivedi/Images/raw/master/SQLDBATools/PlayThumbnail____Get-ProcessForDBA.png)](https://youtu.be/bhzc2LO2Pb4)

## Get-SdtVolumeSpaceConsumers
This function displays all files and folders including hidden items with details like Owner, Size, Created Date, Updated By etc path passed in parameter.

![](https://github.com/imajaydwivedi/Images/raw/master/SQLDBATools/Get-VolumeSpaceConsumers.gif)
