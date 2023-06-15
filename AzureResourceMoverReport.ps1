#Requires -Version 7 -Modules AZ

#Move Support CSV File
$CSVSupport = "$ENV:Temp\moveSupport.csv"
If(Test-Path -Path $CSVSupport){Remove-Item -Path $CSVSupport -Force}
$null = Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/tfitzmac/resource-capabilities/main/move-support-resources-with-regions.csv' -OutFile $CSVSupport
$info = Import-Csv -Path $CSVSupport
#$Resource = Get-AzResource | Select-Object name, resourcetype, location, subscriptionid, resourcegroupname
$Resource = (Search-AzGraph -Query "Resources | project name, type, location, subscriptionId, resourceGroup").GetEnumerator()
foreach ($R in $Resource){
    $lineItem = $info | Where-Object {$_.Resource -eq $R.ResourceType}
    [PSCustomObject]@{
        'Name' = $R.Name
        'ResourceType' = $R.type
        'Location' = $R.Location
        'SubID' = (Get-AzSubscription | Where-Object {$_.Id -eq $R.SubscriptionID}).Name
        'ResourceGroupName' = $R.ResourceGroup
        'MoveResourceGroup' = if($lineItem.'Move Resource Group' -eq 0){'FALSE'}elseif($lineItem.'Move Resource Group' -eq 1){'TRUE'}else{'N/A'}
        'MoveSubscription' = if($lineItem.'Move Subscription' -eq 0){'FALSE'}elseif($lineItem.'Move Subscription' -eq 1){'TRUE'}else{'N/A'}
        'MoveRegion' = if($lineItem.'Move Region' -eq 0){'FALSE'}elseif($lineItem.'Move Region' -eq 1){'TRUE'}else{'N/A'}
    } | Export-Csv -Path "$ENV:Temp\AzureResourceMove.csv" -Append
}