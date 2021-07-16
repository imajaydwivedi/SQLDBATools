function Get-UberBill_USA {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$true)]
        [Double]$Total_USD = (Read-Host "Enter Total Amount (Dollars): "),

        [Parameter(Mandatory=$True,ValueFromPipelineByPropertyName=$true)]
        [Double]$Extras_USD = (Read-Host "Enter amount for Tolls/Surcharge/Fees (USD): "),

        [Parameter(Mandatory=$True,ValueFromPipelineByPropertyName=$true)]
        [Double]$Total_INR = (Read-Host "Enter Total Amount (Rupees): "),

        [Parameter(Mandatory=$False,ValueFromPipelineByPropertyName=$true)]
        [Alias("Distance",'DistanceCovered')]
        [Double]$Miles, #= (Read-Host "Enter total Miles: "),

        [String]$Time_UberTravel, #Tue, Oct 01, 2019
        [String]$Time_GmailReceipt, #Tue, Oct 1, 2019 at 9:34 PM

        [Parameter(HelpMessage="Enter increment value in percentage (for 20%, provide 0.2).")]
        [Alias('Increment')]
        [Double]$PercentageIncrement = 0.2
    )
    #https://itknowledgeexchange.techtarget.com/powershell/powershell-f-string/#targetText=A%20PowerShell%20%E2%80%93f%20string%20is,to%20as%20the%20format%20operator.&targetText='A'%20is%20the%20first%20argument,%7B0%7D%20and%20so%20on.&targetText=index%20is%20the%20zero%20based,operator%20as%20you've%20seen.

    $ExchangeRate = $Total_INR / $Total_USD;
    Write-Host "$('{0,-35} = {1:F2}' -f 'ExchangeRate', $ExchangeRate)" -ForegroundColor Green;

    $TripFare_USD = $Total_USD - $Extras_USD;
    $TripFare_USD_New = [System.Math]::Round((1.0 + $PercentageIncrement) * $TripFare_USD,2);
    Write-Host "$('{0,-35} = {1:F2} => {2:F2}' -f 'Trip Fare', $TripFare_USD, $TripFare_USD_New)" -ForegroundColor Yellow;

    #$Extras_USD_New = [System.Math]::Round((1.0 + $PercentageIncrement) * $Extras_USD,2);
    #Write-Host "$('{0,-35} = {1:F2} => {2:F2}' -f 'Tolls, Surcharges, and Fees', $Extras_USD, $Extras_USD_New)" -ForegroundColor Cyan;

    $Total_USD_New = [System.Math]::Round($TripFare_USD_New + $Extras_USD,2);
    #Write-Host "Total = `$$Total_USD => `$$Total_USD_New" -ForegroundColor Yellow;
    Write-Host "$('{0,-35} = {1:F2} => {2:F2}' -f 'Total (USD)', $Total_USD, $Total_USD_New)" -ForegroundColor Yellow;
    
    $Total_INR_New = [System.Math]::Round($Total_USD_New * $ExchangeRate,2);
    #Write-Host "Total = `$$Total_INR => `$$Total_INR_New" -ForegroundColor Cyan;
    Write-Host "$('{0,-35} = {1:F2} => {2:F2}' -f 'Total (INR)', $Total_INR, $Total_INR_New)" -ForegroundColor Cyan;

    Write-Host "`n`n";
    $str_Total_USD = "document.body.innerHTML = document.body.innerHTML.replace($('/{0:F2}/g,' -f $Total_USD) '$('{0:F2}' -f $Total_USD_New)')";
    $str_TripFare_USD = "document.body.innerHTML = document.body.innerHTML.replace($('/{0:F2}/g,' -f $TripFare_USD) '$('{0:F2}' -f $TripFare_USD_New)')";
    #$str_Extras_USD = "document.body.innerHTML = document.body.innerHTML.replace($('/{0:F2}/g,' -f $Extras_USD) '$('{0:F2}' -f $Extras_USD_New)')";

    Write-Host "console.log(`"Update Total`");";
    Write-Host $str_Total_USD;
    Write-Host "console.log(`"Update Trip Fare`");";    
    Write-Host $str_TripFare_USD;
    #Write-Host "console.log(`"Update Tolls, Surcharges, and Fees`");";
    #Write-Host $str_Extras_USD;
    
    <#
    if($Miles -eq 0.0) {
        $Miles_New = ($Miles * $PercentageIncrement) + $Miles;
        Write-Host "console.log(`"Update Miles`");";
        $str_Miles = "document.body.innerHTML = document.body.innerHTML.replace($('/{0:F2}/g,' -f $Miles) '$('{0:F2}' -f $Miles_New)')";
        Write-Host $str_Miles;
    }
    #>

    Write-Host "`n";

    if(-not ([string]::IsNullOrEmpty($Time_UberTravel))) {
        $str_Time_UberTravel = "document.body.innerHTML = document.body.innerHTML.replace($('/{0:F2}/g,' -f $Time_UberTravel) '$('{0:F2}' -f $Time_UberTravel)')";
        Write-Host "console.log(`"Update Day/Date for Uber Travel`");";
        Write-Host $str_Time_UberTravel;
    }
    if(-not ([string]::IsNullOrEmpty($Time_GmailReceipt))) {
        $str_Time_UberTravel = "document.body.innerHTML = document.body.innerHTML.replace($('/{0:F2}/g,' -f $Time_GmailReceipt) '$('{0:F2}' -f $Time_GmailReceipt)')";
        Write-Host "console.log(`"Update Day/Date/Time for Uber Travel Gmail Receipt`");";
        Write-Host $str_Time_UberTravel;
    }

    Write-Host "`n";
}

cls
$Params = @{ Total_USD = 7.25
             Extras_USD = 2.65
             Total_INR = 537.32
             PercentageIncrement = 0.5
}

Get-UberBill_USA @Params
                 #-Time_UberTravel 'Tue, Oct 01, 2019' -Time_GmailReceipt 'Tue, Oct 1, 2019 at 9:34 PM'
