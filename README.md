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

PayPal |   | UPI
------ | - | -----------
[![paypal](https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif)](https://paypal.me/imajaydwivedi?country.x=IN&locale.x=en_GB) | | [![upi](https://www.vectorlogo.zone/logos/upi/upi-ar21.svg)](https://github.com/imajaydwivedi/Images/raw/master/Miscellaneous/UPI-PhonePe-Main.jpeg)


## Help or Documentation
Want to know in details about functionalitires supported by this module, kindly check below documentation -

<b> [Documentation on [SQLDBATools]](docs/index.md)</b>

To learn on how to use this script, please watch below YouTube video:-

[![Watch this video](Images/PlayThumbnail____CustomLogShipping.jpg)](https://youtu.be/vF-EsyHnFRk)
