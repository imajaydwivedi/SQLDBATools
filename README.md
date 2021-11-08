# SQLDBATools
Powershell Module containing cmdlets for carrying out SQL DBA activities. 

**Functionality** covered includes finding our server properties, disk utilization, discover sql instance in network, find license keys, setup mail profile, setup dba operator, get backup history, audit user/database permissions, maintain inventory, cleanup orphan database files from disk, find resouce consuming queries on server, space consumers, estimate space to add into disk/database files, setup maintenance jobs, perform basic basic server optimization settings etc.

This module also has built-in capability to setup **Monitoring & Alerting** system using PowerShell & SqlServer. The alerting system is designed to *automatically clear alerts* when no longer active, *send email notifications*, *suppress* alert is required, display *alert history* on Grafana. This available alerts include Disk Space, Blocking, Job Failure, High CPU, Memory Issue, and many more.

## How to Install
One way to work with this module is to simply download this github repository at zip file, extract downloaded zip file, and extract it to folder named 'SQLDBATools'. Finally copy/paste it on one of the module folders returned by variable $PSGetPath.

It can also be installed easily from PSGallery using below command -

```
Install-Module -Name SQLDBATools
# Update-Module -Name SQLDBATools
```

## Donation
If this project help you reduce time to develop, you can give me a cup of coffee :) 

PayPal | UPI
------ | -----------
[![paypal](https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif)](https://paypal.me/imajaydwivedi?country.x=IN&locale.x=en_GB) | [![upi](https://www.vectorlogo.zone/logos/upi/upi-ar21.svg)](https://github.com/imajaydwivedi/Images/raw/master/Miscellaneous/UPI-PhonePe-Main.jpeg)

-------------------------------------------------------------------------------------
Some of the common functionalities of this module are as follows -

## Get-SdtLinkedServer
This function scripts out SQL Server Linked Servers with actual passwords into a script file.

![](https://ajaydwivedi.com/wp-content/uploads/2021/06/image-3-1024x379.png)

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
