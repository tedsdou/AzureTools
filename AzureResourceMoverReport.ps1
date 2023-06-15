#Requires -Version 7 -Modules AZ

$CSVSupport = "$ENV:Temp\moveSupport.csv"
$OutFile = "$ENV:Temp\AzureResourceMove.csv"
Remove-Item -Path $CSVSupport,$OutFile -ErrorAction Ignore

$null = Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/tfitzmac/resource-capabilities/main/move-support-resources-with-regions.csv' -OutFile $CSVSupport
$info = Import-Csv -Path $CSVSupport
If (-not(Get-AzContext)) {
    Write-Warning -Message "You are not logged into Azure.  Use 'Login-AzAccount' to login and 'Set-AzContext' to choose your subscription."
    exit
}
foreach ($Sub in Get-AzSubscription) {
    try {
        $null = Set-AzContext -Subscription $Sub.Name
    }
    catch {
        Write-Warning -Message "Unable to connect to Azure Subscription: $($Sub.Name)`n`rERROR: $($_.Exception.Message)"
    }
    foreach ($R in Get-AzResource) {
        $lineItem = $info | Where-Object { $_.Resource -eq $R.ResourceType }
        [PSCustomObject]@{
            'Name'              = $R.Name
            'ResourceType'      = $R.ResourceType
            'Location'          = $R.Location
            'SubID'             = (Get-AzSubscription | Where-Object { $_.Id -eq $R.SubscriptionID }).Name
            'ResourceGroupName' = $R.ResourceGroupName
            'MoveResourceGroup' = if ($lineItem.'Move Resource Group' -eq 0) { 'FALSE' }elseif ($lineItem.'Move Resource Group' -eq 1) { 'TRUE' }else { 'N/A' }
            'MoveSubscription'  = if ($lineItem.'Move Subscription' -eq 0) { 'FALSE' }elseif ($lineItem.'Move Subscription' -eq 1) { 'TRUE' }else { 'N/A' }
            'MoveRegion'        = if ($lineItem.'Move Region' -eq 0) { 'FALSE' }elseif ($lineItem.'Move Region' -eq 1) { 'TRUE' }else { 'N/A' }
        } | Export-Csv -Path $OutFile -Append
    }
}