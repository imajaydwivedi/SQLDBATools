Function Get-SdtLocalTime
{
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)][Alias('Time')]
        [DateTime]$UTCTime
    )
    $strCurrentTimeZone = (Get-WmiObject win32_timezone).StandardName
    $TZ = [System.TimeZoneInfo]::FindSystemTimeZoneById($strCurrentTimeZone)
    $LocalTime = [System.TimeZoneInfo]::ConvertTimeFromUtc($UTCTime, $TZ)
    
    $LocalTime | Write-Output
}