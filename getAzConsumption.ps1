Connect-AzAccount
$null = Get-AzSubscription | Out-GridView -PassThru | Set-AzContext
$usageDetails = Get-AzConsumptionUsageDetail -StartDate ((Get-Date).AddDays(-90)) -EndDate (Get-Date)
$usageDetails | Group-Object -Property MeterCategory | Select-Object @{Name='Subscription';E={$_.Group[0].SubscriptionName}}, @{Name='Cost';Expression={($_.Group | Measure-Object -Property PretaxCost -Sum).Sum}}