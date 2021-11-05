function Alert-SdtDiskSpace
{
    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [Alias('ServerName','MachineName')]
        [string[]]$ComputerName,
        [Parameter(Mandatory=$false)]
        [string[]]$ExcludeDrive,
        [Parameter(Mandatory=$false)]
        [int]$WarningThresholdPercent = 80,
        [Parameter(Mandatory=$false)]
        [int]$CriticalThresholdPercent = 90,
        [Parameter(Mandatory=$false)]
        [string]$ThresholdTable = 'dbo.sdt_disk_space_threshold'
    )



}

<#
Get-DbaDiskSpace $SdtInventoryInstance
Get-SdtVolumeInfo $SdtInventoryInstance | ft -AutoSize
#>