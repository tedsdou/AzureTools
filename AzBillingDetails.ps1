<#
.SYNOPSIS
    Generates Azure Billing Report
.DESCRIPTION
    Generates full Azure billing report.  Includes 1/3 year RI recommendations, VM/Storage/Orphaned resource info with 30-day billing.
.EXAMPLE
    .\AzureBillingDetails.ps1 -TenantId '000-000-000' -SubscriptionID '000-000-000'
    This example targets a single subscription in the specified tenant

     .\AzureBillingDetails.ps1 -TenantId '000-000-000' -ExportPath 'C:\Temp\Contoso-CostOp.xlsx'
    This example targets all subscriptions in the specified tenant and customizes the export path to reflect the customer name

     .\AzureBillingDetails.ps1 -TenantId '000-000-000','111-111-111' -ExportPath 'C:\Temp\Litware-CostOp-2023_10_04.xlsx'
     This example targets all subscriptions in the specified tenants and customizes the export path to reflect the customer name
.NOTES
    Author: Ted Sdoukos
    Date: September 27, 2023
    Updated: October 10, 2023
    Version: 1.05
    Module Requirements: ImportExcel, Az.Accounts, Az.CostManagement, Az.ResourceGraph, Az.Monitor 
    Version Requirements: PowerShell 7+
    You must be a part of the Cost Management Readers in order to successfully run this.

    Input File Requirments:
    You will need to provide the last month's detailed bill for each subscription (Cost Management->Cost Analysis->Change view to 'Cost by resource', 'Last month' ). 
    The file must be named "<SubscriptionID>.csv" for example 'f00d8383-a5fe-4f12-aae4-0004a4881a7f.csv'
    This csv will need to be in the same directory of the script under a folder called 'MonthDetailBill'.  If the file does not exist, the script will prompt you for the location.
#>

#requires -Modules ImportExcel, Az.Accounts, Az.ResourceGraph, Az.Monitor, Az.CostManagement -Version 7
[CmdletBinding()]
Param(
    $ExportPath = "C:\Temp\Customer-CostOp-$(Get-Date -Format 'yyyy-MM-dd_HH.mm').xlsx",
    #[Parameter(Mandatory)]
    $TenantId,
    $SubscriptionID
)
Function Get-LastMonthBillDetail {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        $SubId
    )
    $DataAgg = @{
        'totalCost'    = @{
            'name'     = 'Cost'
            'function' = 'Sum'
        }
        'totalCostUSD' = @{
            'name'     = 'CostUSD'
            'function' = 'Sum'
        }
    }
    $Grouping = @(
        @{
            'name' = 'ResourceID'
            'type' = 'Dimension'
        },
        @{
            'name' = 'ResourceType'
            'type' = 'Dimension'
        },
        @{
            'name' = 'ResourceLocation'
            'type' = 'Dimension'
        },
        @{
            'name' = 'ChargeType'
            'type' = 'Dimension'
        },
        @{
            'name' = 'ResourceGroupName'
            'type' = 'Dimension'
        },
        @{
            'name' = 'PublisherType'
            'type' = 'Dimension'
        },
        @{
            'name' = 'ServiceName'
            'type' = 'Dimension'
        },
        @{
            'name' = 'Meter'
            'type' = 'Dimension'
        }
    )
    $StartDate = (Get-Date).AddMonths(-1).ToString('yyyy-MM-01')
    $lastDay = [datetime]::DaysInMonth((Get-Date).Year, (Get-Date).AddMonths(-1).Month)
    $EndDate = (Get-Date).AddMonths(-1).ToString("yyyy-MM-$lastDay")
    $CostParam = @{
        'Scope'              = "/subscriptions/$SubId"
        'Timeframe'          = 'Custom'
        'Type'               = 'ActualCost'
        'DatasetGranularity' = 'Daily'
        'DatasetAggregation' = $DataAgg
        'DatasetGrouping'    = $Grouping
        'TimePeriodFrom'     = $StartDate
        'TimePeriodTo'       = $EndDate
    }
    try {
        $LastMonth = Invoke-AzCostManagementQuery @CostParam -ErrorAction Stop
        If (($LastMonth.Row.Count -gt 0) -and ($LastMonth.Column.Name.Count -gt 0)) {
            0..($LastMonth.Row.Count - 1) | ForEach-Object {
                $HTable = [Ordered]@{}
                $RowCount = $_
                0..($LastMonth.Column.Name.Count - 1) | ForEach-Object {
                    $HTable.Add($LastMonth.Column.Name[$_], $LastMonth.Row[$RowCount][$_])
                }
                $null = $Hold.Add([PSCustomObject]$HTable)
            }
        }
        else {
            Write-Warning "No Monthly data found for: $((Get-AzSubscription -SubscriptionId $subId).Name) | $SubId"
        }
    }
    catch {
        Write-Warning "Error while processing: $((Get-AzSubscription -SubscriptionId $subId).Name) | $SubId"
        Write-Warning "ERROR: $($_.Exception.Message)"
    }    
}

Function Get-LastYearBillSummary {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        $SubId
    )
    $DataAgg = @{
        'PreTaxCost' = @{
            'name'     = 'Cost'
            'function' = 'Sum'
        }
    }
    $StartDate = (Get-Date).AddYears(-1).ToString('yyyy-MM-01')
    $lastDay = [datetime]::DaysInMonth((Get-Date).Year, (Get-Date).AddMonths(-1).Month)
    $EndDate = (Get-Date).AddMonths(-1).ToString("yyyy-MM-$lastDay")
    $CostParam = @{
        'Scope'              = "/subscriptions/$SubId"
        'Timeframe'          = 'Custom'
        'Type'               = 'ActualCost'
        'DatasetGranularity' = 'Monthly'
        'DatasetAggregation' = $DataAgg
        'TimePeriodFrom'     = $StartDate
        'TimePeriodTo'       = $EndDate
    }
    try {
        $LastYear = Invoke-AzCostManagementQuery @CostParam -ErrorAction Stop
        If (($LastYear.Row.Count -gt 0) -and ($LastYear.Column.Name.Count -gt 0)) {
            0..($LastYear.Row.Count - 1) | ForEach-Object {
                $HTable = [Ordered]@{}
                $RowCount = $_
                0..($LastYear.Column.Name.Count - 1) | ForEach-Object {
                    $HTable.Add($LastYear.Column.Name[$_], $LastYear.Row[$RowCount][$_])
                }
                [PSCustomObject]$HTable
            }
        }
        else {
            Write-Warning "No yearly data found for: $((Get-AzSubscription -SubscriptionId $subId).Name) | $SubId"
        }
    }
    catch {
        Write-Warning "Error while processing: $((Get-AzSubscription -SubscriptionId $subId).Name) | $SubId"
        Write-Warning "ERROR: $($_.Exception.Message)"
    }
    
}

$StopWatch = [System.Diagnostics.Stopwatch]::new()
$StopWatch.Start()

[System.Collections.ArrayList]$TotalBillInfo = @()
[System.Collections.ArrayList]$TotalAverages = @()
[System.Collections.ArrayList]$Storage = @()
[System.Collections.ArrayList]$VMInfo = @()
[System.Collections.ArrayList]$Orphaned = @()
[System.Collections.ArrayList]$UnattachedDisk = @()
[System.Collections.ArrayList]$Advisory = @()
[System.Collections.ArrayList]$RI_1Year = @()
[System.Collections.ArrayList]$RI_3Year = @()

foreach ($Tenant in $TenantID) {
    $null = Login-AzAccount -TenantID $Tenant -WarningAction Ignore
    If ($SubscriptionID) {
        $Subscription = Get-AzSubscription -SubscriptionId $SubscriptionID -WarningAction Ignore
    }
    else {
        $Subscription = Get-AzSubscription -TenantId $Tenant -WarningAction Ignore
    }
    foreach ($Sub in $Subscription) {
        $null = Set-AzContext -Subscription $Sub.Id -WarningAction Ignore
        $YearlyBill = Get-LastYearBillSummary -SubId $Sub.Id
        if ((-not($YearlyBill)) -and (-not(Test-Path -Path "$PSScriptRoot\MonthDetailBill\$((Get-AzContext).Subscription.Id).csv"))) {
            Write-Warning -Message "No billing data found in the Tenant: $((Get-AzTenant | Where-Object id -EQ (Get-AzContext).Tenant.Id).name) for Subscription: $((Get-AzContext).Subscription.Name)"
            Continue
        }
        $YearlyBill | ForEach-Object {
            $null = $TotalBillInfo.Add([PSCustomObject]@{
                    'SubscriptionName' = $Sub.Name
                    'SubscriptionId'   = $Sub.Id
                    'MonthName'        = $_.BillingMonth
                    'MonthlyBill'      = $_.Cost
                })
        }
                
        $Average = ($YearlyBill | Measure-Object -Property Cost -Average).Average
        
        $null = $TotalAverages.Add([PSCustomObject]@{
                'SubscriptionName' = $Sub.Name
                'SubscriptionId'   = $Sub.Id
                'PastYearAverage'  = $Average
            })
        if (($TotalAverages.pastYearAverage -lt 50) -and (-not(Test-Path -Path "$PSScriptRoot\MonthDetailBill\$((Get-AzContext).Subscription.Id).csv"))) {
            Write-Warning -Message "Usage average is less than `$50 for Tenant: $((Get-AzTenant | Where-Object id -EQ (Get-AzContext).Tenant.Id).name) for Subscription: $((Get-AzContext).Subscription.Name)`nSKIPPING Evaluation"
            Continue
        }
        #$BillDetail = Get-LastMonthBillDetail -SubId $Sub.Id
        if (Test-Path -Path "$PSScriptRoot\MonthDetailBill\$((Get-AzContext).Subscription.Id).csv") {
            $BillDetail = Import-Csv -Path "$PSScriptRoot\MonthDetailBill\$((Get-AzContext).Subscription.Id).csv"
        }
        else {
            do {
                $FilePath = Read-Host "Please provide the path to the CSV file for $((Get-Date).AddMonths(-1).Month)/$((Get-Date).Year) bill for $((Get-AzContext).Subscription.Name) in the tenant $((Get-AzTenant | Where-Object id -EQ (Get-AzContext).Tenant.Id).name)`nGenerate it from the portal under Cost Analysis`nTo skip this subscription type 'SKIP'"
            }
            until((Test-Path -Path $FilePath) -and ($FilePath -match 'csv$') -or ($FilePath -eq 'SKIP'))
            if ($FilePath -eq 'SKIP') {
                Continue
            }
            else {
                $BillDetail = Import-Csv -Path $FilePath
            }
        }
                       
        #region Storage Information
        $storAcc = Search-AzGraph -Query "resources | where type =~ 'microsoft.storage/storageaccounts'" -Subscription $Sub.Id
        $storAcc | ForEach-Object -Parallel {
            $stor = $_
            $storConsume = $using:BillDetail | Where-Object { $_.ResourceID -eq $stor.id } 
            $storCost = [System.Math]::Round((($storConsume | Measure-Object -Property Cost -Sum).Sum), 2)
            
            $null = ($using:Storage).Add([PSCustomObject]@{
                    'Subscription'   = $using:Sub.Name
                    'Name'           = $stor.name
                    'Type'           = $stor.type
                    'ResourceGroup'  = $stor.resourceGroup
                    'Location'       = $stor.location
                    'AccessTier'     = $stor.properties.accessTier
                    'StorageVersion' = If ($stor.kind -match 'v2$') { 'V2' }elseif ($stor.kind -eq 'Storage') { 'V1' }else { $stor.kind }
                    'CostUSD'        = $storCost
                })

        }
        foreach ($stor in $storAcc) {
        }
        #EndRegion
        
        #Region VM Information
        $CostData = @()
        $AllVMLoc = Search-AzGraph -Query "resources | where type =~ 'microsoft.compute/virtualmachines' | summarize count() by location | project location" -Subscription $(Get-AzContext).Subscription.Id
        (Get-AzLocation | Where-Object { $_.Location -in $AllVMLoc.location }).Location | ForEach-Object {
            $Cost = "https://prices.azure.com/api/retail/prices?`$filter=serviceName eq 'Virtual Machines' and type eq 'Consumption' and armRegionName eq '$_'"# and armSkuName eq 'Standard_DS12_v2_Promo'"
            $Result = Invoke-RestMethod -Uri $Cost -ContentType 'application/json'
            $CostData += $Result.Items
            while ($Result.NextPageLink) {
                $Result = Invoke-RestMethod -Uri $Result.NextPageLink  -ContentType 'application/json'
                $CostData += $Result.Items 
            }
        }
        $VM = Search-AzGraph -Query "resources | where type =~ 'microsoft.compute/virtualmachines'" -Subscription $(Get-AzContext).Subscription.Id
        $VM | ForEach-Object -Parallel {
            $V = $_
            ##Uptime 
            $upMetrics = @{
                'TimeGrain'       = '1:00:00:00'
                'ResourceId'      = $v.id
                'StartTime'       = ((Get-Date).AddMonths(-1).AddDays(-1)) 
                'EndTime'         = (Get-Date) 
                'WarningAction'   = 'Ignore'
                'MetricName'      = 'VMAvailabilityMetric'
                'AggregationType' = 'Minimum'
            }
            $upTime = Get-AzMetric @upMetrics
            $LastDownTimeStamp = ($upTime.data.Where({ $_.Minimum -ne 1 }) | Select-Object -Last 1).TimeStamp
            $FirstUpTimeStamp = ($upTime.data.Where({ $_.Minimum -eq 1 }) | Select-Object -First 1).TimeStamp
            If ($LastDownTimeStamp) {
                $DaysUp = (New-TimeSpan -Start $LastDownTimeStamp -End (Get-Date)).Days
            }
            elseif ($FirstUpTimeStamp) {
                $DaysUp = (New-TimeSpan -Start $FirstUpTimeStamp -End (Get-Date)).Days
            }
            else {
                $DaysUp = 'N/A'
            }
            if ($DaysUp -eq 'N/A') {
                $upTimePct = 0
            }
            else {
                $upTimePct = '{0:P2}' -f ($uptime.Data.Where({ $_.Minimum -eq 1 }).count / $uptime.Data.Count)
            }
           
            $metrics = @{
                'TimeGrain'     = '01:00:00'
                'ResourceId'    = $v.id
                'StartTime'     = ((Get-Date).AddMonths(-1)) 
                'EndTime'       = (Get-Date) 
                'WarningAction' = 'Ignore'
                'MetricName'    = 'Percentage CPU', 'Available Memory Bytes'
            }
            ##Metrics
            $Count = 1
            do {
                try {
                    $MaxMetrics = Get-AzMetric -AggregationType Maximum @metrics
                }
                catch {
                    if ($_.Exception.InnerException.Message -match '529') {
                        Start-Sleep -Seconds 5
                    }
                    $Count++
                }
            } until (
                $MaxMetrics -ne $null -or $count -ge 10
            )
    
            $Count = 1
            do {
                try {
                    $AvgMetrics = Get-AzMetric -AggregationType Average @metrics
                }
                catch {
                    if ($_.Exception.InnerException.Message -match '529') {
                        Start-Sleep -Seconds 5
                    }
                    $Count++
                }
            } until (
                $AvgMetrics -ne $null -or $count -ge 10
            )
    
            $CPUMax = $MaxMetrics.where{ $_.ID -match 'CPU' }
            $CPUAvg = $AvgMetrics.where{ $_.ID -match 'CPU' }
            $RAMMax = $MaxMetrics.where{ $_.ID -match 'Memory' }
            $RAMAvg = $AvgMetrics.where{ $_.ID -match 'Memory' } 
    
            #Hybrid Info
            $Lic = switch ($V.Properties.licenseType) {
                'Windows_Server' { 'Azure Hybrid Benefit for Windows' }
                'Windows_Client' { 'Windows client with multi-tenant hosting' }
                'RHEL_BYOS' { 'Azure Hybrid Benefit for Redhat' }
                'SLES_BYOS' { 'Azure Hybrid Benefit for SUSE' }
                default { 'Not Enabled' }
            }

            $VMConsume = $using:BillDetail | Where-Object { $_.ResourceID -eq $V.id }
            $VMCost = [System.Math]::Round((($VMConsume | Measure-Object -Property Cost -Sum).Sum), 2)
            $VMSpec = Get-AzVMSize -VMName $V.name -ResourceGroupName $V.resourceGroup | Where-Object { $_.Name -eq $V.Properties.hardwareProfile.vmSize }
            $vRamAvg = ((($RAMAvg.Data.Average | Measure-Object -Average).Average / 1GB)) / ($VMSpec.MemoryInMB / 1024)
            $vRamAvgPct = '{0:P2}' -f ($vRamAvg)
            #Region Find Right-size recommendations
            $rsQuery = "AdvisorResources | where type == 'microsoft.advisor/recommendations' | where properties.category == 'Cost' | extend resources = tostring(properties.resourceMetadata.resourceId), solution = tostring(properties.shortDescription.solution) | where resources contains '$($V.name)' and solution contains 'Right-size'"
            $rs = Search-AzGraph -Query $rsQuery
            If ($rs.id) {
                $tSku = $rs.properties.extendedProperties.targetSku 
                $Result = $using:CostData | Where-Object { ($_.armRegionName -eq $v.location) -and ($_.armSkuName -eq $tSku) }
                if ($V.properties.storageProfile.osDisk.osType -match 'Windows') {
                    $tSkuCostph = ($Result.where({ $_.productName -match 'Windows$' -and $_.skuName -notmatch 'Spot|low' })).retailPrice
                }
                else {
                    $tSkuCostph = ($Result.where({ $_.productName -notmatch 'Windows$' -and $_.skuName -notmatch 'Spot|low' })).retailPrice
                }
            }
            else {
                $tSkuCostph = 0
                $tSku = 'N/A'
            }
            #endRegion
            #Region Cost per hour
            $Result = $using:CostData | Where-Object { ($_.armRegionName -eq $v.location) -and ($_.armSkuName -eq $V.Properties.hardwareProfile.vmSize) }
            if ($V.Properties.hardwareProfile.vmSize -match 'Promo$') {
                $CostPerHour = $Result.retailPrice
            }
            elseif ($V.properties.storageProfile.osDisk.osType -match 'Windows') {
                $CostPerHour = ($Result.where({ $_.productName -match 'Windows$' -and $_.skuName -notmatch 'Spot|low' })).retailPrice
            }
            else {
                $CostPerHour = ($Result.where({ $_.productName -notmatch 'Windows$' -and $_.skuName -notmatch 'Spot|low' })).retailPrice
            }
            #endRegion
            #Region Right-Size Manual
            $CPUAvgPct = ($CPUAvg.Data.Average | Measure-Object -Average).Average
            if (((($CPUAvgPct -le 40) -and ($vRamAvg -le .6)) -or ( $CPUAvgPct -ge 80)) -and ( $tSku -eq 'N/A')) {
                if ($CPUAvgPct -ge 80) {
                    $targetCPU = ($VMSpec.NumberOfCores * 2)
                }
                else {
                    if ($VMSpec.NumberOfCores -eq 1) {
                        $targetCPU = $VMSpec.NumberOfCores
                    }
                    else {
                        $targetCPU = ($VMSpec.NumberOfCores / 2) 
                    }
                }
                ##Get target SKU Family
                $VMSource = Get-AzComputeResourceSku -Location $v.location | Where-Object { $_.ResourceType -eq 'virtualMachines' }
                $VMFamily = $vmSource.where({ $_.Name -eq $V.Properties.hardwareProfile.vmSize }).Family
                $VMSearchList = $VMsource.Where({ $_.Family -eq $VMFamily }).name
                #if ($vRamAvgPct -le 50) { $targetRAM = ($VMSpec.MemoryInMB / 2) } else {$targetRAM = $VMSpec.MemoryInMB}
                $Token = Get-AzAccessToken
                $Headers = @{'Authorization' = "Bearer $($Token.Token)" }
                $URI = "https://management.azure.com/subscriptions/$((Get-AzContext).Subscription.Id)/resourceGroups/$($V.resourceGroup)/providers/Microsoft.Compute/virtualMachines/$($V.name)/vmSizes?api-version=2023-07-01"
                $Resize = Invoke-RestMethod -Method Get -Uri $URI -ContentType 'application/json' -Headers $Headers
                $null = $VMSpec.Name -match '(Standard_\w{1,2})(\d)(.*)'
                $skuMatchStart = $Matches[1]
                if ([string]::IsNullOrEmpty($Matches[3])) { $skuMatchEnd = $Matches[2] }else { $skuMatchEnd = $Matches[3] }
                #$tSku = $Resize.value.Where({ ($_.numberOfCores -eq $targetCPU) -and ($_.Name -match "^$skuMatchStart") })
                if (($Resize.value.Where({ ($_.numberOfCores -eq $targetCPU) -and ($_.Name -in $VMSearchList) })).count -ge 1) {
                    $tSku = $Resize.value.Where({ ($_.numberOfCores -eq $targetCPU) -and ($_.Name -in $VMSearchList) })
                }
                else {
                    $tSku = $Resize.value.Where({ ($_.numberOfCores -eq $targetCPU) })
                }
       
                if ($tSku.count -gt 1) {
                    if ($VMSpec.Name -match 'v\d$|promo$' -and ($VMSpec.NumberOfCores.Length -eq $targetCPU.ToString().Length)) {
                        if (($tSku.Where({ $_.Name -match "$skuMatchEnd$" })).count -eq 1) { 
                            $tSku = $tSku.Where({ $_.Name -match "$skuMatchEnd$" }) 
                        }
                        elseif (($tSku.Where({ $_.Name -match "$skuMatchEnd$" -and $_.Name.Length -eq $VMSpec.Name.Length })).count -eq 1) {
                            $tSku = $tSku.Where({ $_.Name -match "$skuMatchEnd$" -and $_.Name.Length -eq $VMSpec.Name.Length })
                        }
                        elseif (($tsku.Where({ $_.Name -match "^$skuMatchStart" })).count -ge 1) {
                            $tSku = $tsku.Where({ $_.Name -match "^$skuMatchStart" }) | Select-Object -First 1
                        }
                    }
                    elseif ($VMSpec.Name -match "^$skuMatchStart\d*$" ) {
                        if (($tSku.Where({ $_.Name -match "^$skuMatchStart\d*$" })).count -eq 1) { $tSku = $tSku.Where({ ($_.Name -match "^$skuMatchStart\d*$") }) }
                        elseif (($tSku.Where({ ($_.Name -match "^$skuMatchStart\d*$") -and ($_.Name.Length -eq $VMSpec.Name.Length) })).count -ge 1) {
                            $tsku = $tSku.Where({ ($_.Name -match "^$skuMatchStart\d*$") -and ($_.Name.Length -eq $VMSpec.Name.Length) }) | Select-Object -First 1
                        }
                    }
                    elseif (($VMSpec.NumberOfCores.Length -eq 2 -and $targetCPU.ToString().Length -eq 1)) {
                        $tSku = $tSku.Where({ $_.Name -match "$skuMatchEnd$" -and $_.Name -match "^$skuMatchStart\d[a-zA-Z]*" })
                    }
                    elseif ($VMSpec.NumberOfCores.Length -eq $targetCPU.ToString().Length) {
                        if (($tSku.Where({ $_.Name.Length -eq $VMSpec.Name.Length }) ).count -eq 1) {
                            $tSku = $tSku.Where({ $_.Name.Length -eq $VMSpec.Name.Length }) 
                        }
                        elseif (($tSku.Where({ ($_.Name.Length -eq $VMSpec.Name.Length) -and ($_.Name -match "$skuMatchEnd$") })).count -ge 1) {
                            $tSku = $tSku.Where({ ($_.Name.Length -eq $VMSpec.Name.Length) -and ($_.Name -match "$skuMatchEnd$") }) | Select-Object -First 1
                        } 
                    }
                    elseif ($VMSpec.NumberOfCores.Length -eq 2 -and $targetCPU.ToString().Length -eq 1) {
                        $tSku = $tSku.Where({ $_.Name -match "^$skuMatchStart\d[a-zA-Z]*" })
                    }            
                    else {
                        $tSku = $tSku | Select-Object -First 1
                    }
                }
        
                $Matches = $null
                $Result = $using:CostData | Where-Object { ($_.armRegionName -eq $v.location) -and ($_.armSkuName -eq $tSku.name) }
                if ($tSku.name -match 'Promo$') {
                    $tSkuCostph = $Result.retailPrice
                }
                elseif ($V.properties.storageProfile.osDisk.osType -match 'Windows') {
                    $tSkuCostph = ($Result.where({ $_.productName -match 'Windows$' -and $_.skuName -notmatch 'Spot|low' })).retailPrice
                }
                else {
                    $tSkuCostph = ($Result.where({ $_.productName -notmatch 'Windows$' -and $_.skuName -notmatch 'Spot|low' })).retailPrice
                }
                $tSku = $tsku.name
            }
            #EndRegion
    
            $null = ($using:VMInfo).Add([PSCustomObject]@{
                    'Subscription'      = $using:Sub.Name
                    'ResourceGroup'     = $V.resourceGroup
                    'Name'              = $V.name
                    'State'             = ($V.Properties.extended.instanceview.powerState.code -replace 'PowerState/')
                    #'Type'              = $V.type
                    'Location'          = $V.location
                    'SKU'               = $V.Properties.hardwareProfile.vmSize
                    'vCPU'              = $VMSpec.NumberOfCores
                    'RAM GB'            = '{0:N2}' -f ($VMSpec.MemoryInMB / 1024)
                    'OS Type'           = $V.properties.storageProfile.osDisk.osType
                    'OS Version'        = $V.Properties.storageProfile.imageReference.sku
                    'Licensing Benefit' = $Lic
                    'Uptime'            = $DaysUp
                    'UptimePct'         = $upTimePct
                    'CostUSD'           = $VMCost
                    'CostPerHour'       = $CostPerHour
                    'Avg vCPU'          = [System.Math]::Round(($CPUAvg.Data.Average | Measure-Object -Average).Average, 2)
                    'Max vCPU'          = [System.Math]::Round(($CPUMax.Data.Maximum | Measure-Object -Maximum).Maximum, 2)
                    'Avg RAM GB'        = [System.Math]::Round((($RAMAvg.Data.Average | Measure-Object -Average).Average / 1GB), 2)
                    'Avg RAM Pct'       = $vRamAvgPct
                    'Max RAM GB'        = [System.Math]::Round((($RAMMax.Data.Maximum | Measure-Object -Maximum).Maximum / 1GB), 2)
                    'TargetSku'         = $tSku
                    'TSkuCostPH'        = '{0:n3}' -f $tSkuCostph
                })
    
        }
        #EndRegion  
    
        #Region Orphaned Resources
        $NICQuery = 'Resources | where type has "microsoft.network/networkinterfaces" | where "{nicWithPrivateEndpoints}" !has id | where properties !has "virtualmachine" | project name,id, resourceGroup, location, subscriptionId,type'
        $DiskQuery = 'Resources | where type has "microsoft.compute/disks" | where (properties.diskState) == "Unattached" or isnull(managedBy)'
        $PipQuery = 'Resources | where type has "Microsoft.Network/publicIPAddresses" | where isnull(properties.ipConfiguration) and isnull(properties.natGateway) | project name,id, resourceGroup, location, subscriptionId, type'
        $NSGQuery = 'Resources | where type =~ "microsoft.network/networksecuritygroups" and isnull(properties.networkInterfaces) and isnull(properties.subnets) | project name,id, resourceGroup, location, subscriptionId, type'
        $Nic = Search-AzGraph -Query $NICQuery -Subscription $Sub.Id
        $Disk = Search-AzGraph -Query $DiskQuery -Subscription $Sub.Id
        $Pip = Search-AzGraph -Query $PipQuery -Subscription $Sub.Id
        $NSG = Search-AzGraph -Query $NSGQuery -Subscription $Sub.Id 
        
        #Region DiskInfo
        $Disk | ForEach-Object -Parallel {
            $D = $_
            $metrics = @{
                'ResourceID'      = $D.id
                'MetricName'      = 'Composite Disk Read Bytes/sec', 'Composite Disk Write Bytes/sec'
                'AggregationType' = 'Average'
                'StartTime'       = ((Get-Date).AddDays(-90))
                'EndTime'         = (Get-Date)
                'WarningAction'   = 'Ignore'
                'TimeGrain'       = '01:00:00'
            }
            $DData = Get-AzMetric @metrics -DetailedOutput
            $readData = $DData | Where-Object { $_.Id -match $DiskRead }
            $writeData = $DData | Where-Object { $_.Id -match $DiskWrite }
            if ($readData.Data) {
                $last90Read = ($readData.Data.Average | Measure-Object -Average).Average
                $readTStamp = ($readData.Data | Where-Object { $_.Average -gt 0 } | Sort-Object -Property TimeStamp -Descending | Select-Object -First 1).TimeStamp
            }
            else {
                $last90Read = $readTStamp = 'N/A'
            }
            if ($writeData.Data) {
                $last90Write = ($writeData.Data.Average | Measure-Object -Average).Average
                $writeTStamp = ($writeData.Data | Where-Object { $_.Average -gt 0 } | Sort-Object -Property TimeStamp -Descending | Select-Object -First 1).TimeStamp
            }
            else {
                $last90Write = $writeTStamp = 'N/A'
            }
            $DConsume = $using:BillDetail | Where-Object { $_.ResourceID -eq $d.id }
            $DCost = [System.Math]::Round((($DConsume | Measure-Object -Property Cost -Sum).Sum), 2)
           
            if ($D.tags) {
                $TagList = ($D.tags | Get-Member -MemberType NoteProperty).Name
            }
            $DiskObj = [ordered] @{
                'Subscription'    = $using:Sub.Name
                'ResourceGroup'   = $D.resourceGroup
                'Name'            = $D.name 
                'SKU'             = $D.sku.name
                'Cost-Last30Days' = $DCost
                'TimeCreated'     = $D.Properties.timeCreated 
                'DiskSizeGB'      = $D.Properties.diskSizeGB
                'DiskSizeBytes'   = $D.properties.diskSizeBytes
                'Generation'      = $D.Properties.hyperVGeneration
                'DiskState'       = $D.Properties.diskState
                'Last90_ReadAvg'  = $last90Read
                'LastRead'        = $readTStamp
                'Last90_WriteAvg' = $last90Write
                'LastWrite'       = $writeTStamp
            }
            foreach ($Tag in $TagList) {
                $DiskObj.Add($Tag, $D.tags.$Tag)
            }
            $null = ($using:UnattachedDisk).Add([PSCustomObject]$DiskObj)
            $TagList = $null
        }
        #EndRegion

        $arr = $Nic + $Pip + $NSG
        $arr | ForEach-Object -Parallel {
            $a = $_
            $orphanedConsume = $using:BillDetail | Where-Object { $_.ResourceID -eq $a.id }
            $OrphanedCost = [System.Math]::Round((($orphanedConsume | Measure-Object -Property Cost -Sum).Sum), 2) 
            $null = ($using:Orphaned).Add( [PSCustomObject]@{
                    'ID'             = $a.id;
                    'Subscription'   = $using:Sub.Name
                    'SubID'          = $a.subscriptionID
                    'Resource Group' = $a.resourceGroup
                    'Location'       = $a.location                
                    'Name'           = $a.name
                    'ResourceType'   = $a.type
                    'CostUSD'        = $OrphanedCost
                }
            )
        }
        #EndRegion
    
        #Region Advisories
        $ri = "AdvisorResources | where type == 'microsoft.advisor/recommendations' | where properties.category == 'Cost' | extend resources = tostring(properties.resourceMetadata.resourceId), solution = tostring(properties.shortDescription.solution)"
        $riQuery = Search-AzGraph -Query $ri -Subscription $Sub.Id
        $riQuery | ForEach-Object -Parallel {
            $r = $_ 
            $data = $r.properties
            if ($data.impactedField -match 'subscriptions$') { $Name = ($using:Sub).Name }else { $Name = $data.impactedValue }
            $null = ($using:Advisory).Add(
                [PSCustomObject]@{
                    'ResourceGroup'          = $r.resourceGroup;
                    'Affected Resource Type' = ($data.impactedField.Split('/'))[-1]
                    'Name'                   = $Name
                    'Category'               = $data.category;
                    'Impact'                 = $data.impact;
                    'Problem'                = $r.solution;
                    'Savings Currency'       = $data.extendedProperties.savingsCurrency
                    'Annual Savings'         = $data.extendedProperties.annualSavingsAmount
                    'Savings Region'         = $data.extendedProperties.location;   
                    'Current SKU'            = $data.extendedProperties.currentSku;
                    'Target SKU'             = $data.extendedProperties.targetSku
                    'LookBack'               = $data.extendedProperties.lookbackPeriod
                    'RI-Term'                = $data.extendedProperties.term
                    'RI-ResourceType'        = $data.extendedProperties.reservedResourceType
                    'RI-SKU'                 = $data.extendedProperties.displaySKU
                    'RI-VMSize'              = $data.extendedProperties.vmSize
                    'RI-Quantity'            = $data.extendedProperties.displayQty
                }
            )
            If ($data.extendedProperties.term -eq 'P1Y') {
                $null = ($using:RI_1Year).Add(
                    [PSCustomObject]@{
                        'Name'            = $Name
                        'Problem'         = $r.solution
                        'Annual Savings'  = $data.extendedProperties.annualSavingsAmount
                        'Savings Region'  = $data.extendedProperties.location
                        'LookBack'        = $data.extendedProperties.lookbackPeriod
                        'RI-Term'         = (($data.extendedProperties.term) -replace 'P1Y', 'One-Year')
                        'RI-ResourceType' = $data.extendedProperties.reservedResourceType
                        'RI-SKU'          = $data.extendedProperties.displaySKU
                        'RI-Quantity'     = $data.extendedProperties.displayQty
                    }
                )
            }
            If ($data.extendedProperties.term -eq 'P3Y') {
                $null = ($using:RI_3Year).Add(
                    [PSCustomObject]@{
                        'Name'            = $Name
                        'Problem'         = $r.solution
                        'Annual Savings'  = $data.extendedProperties.annualSavingsAmount
                        'Savings Region'  = $data.extendedProperties.location
                        'LookBack'        = $data.extendedProperties.lookbackPeriod
                        'RI-Term'         = (($data.extendedProperties.term | Where-Object { $_ -eq 'P3Y' }) -replace 'P3Y', 'Three-Year')
                        'RI-ResourceType' = $data.extendedProperties.reservedResourceType
                        'RI-SKU'          = $data.extendedProperties.displaySKU
                        'RI-Quantity'     = $data.extendedProperties.displayQty
                    }
                )
            }
        }   
        #EndRegion
    }
}



$Style = New-ExcelStyle -HorizontalAlignment Center -AutoSize -NumberFormat '0'
$TableStyle = 'Light20'
$SheetNames = 'RI_1Year', 'RI_3Year', 'Storage', 'VMInfo', 'Orphaned', 'UnattachedDisk', 'Advisory', 'BillDetail', 'TotalAverages', 'TotalBillInfo', 'UnattachedDisk'
foreach ($Sheet in $SheetNames) {
    if ((Get-Variable -Name $Sheet).Value) {
        $ConditionalText = @()
        If ($Sheet -eq 'VMInfo') {
            $ConditionalText += New-ConditionalText -ConditionalType LessThanOrEqual -Text 6 -Range "P2:P$($VMInfo.Count + 1)"
            $ConditionalText += New-ConditionalText -ConditionalType GreaterThanOrEqual -Text 80 -Range "P2:P$($VMInfo.Count + 1)"
            $ConditionalText += New-ConditionalText -Text 'Not Enabled' -Range 'K:K'
            #$ConditionalText += New-ConditionalText -ConditionalType GreaterThanOrEqual -Text 80 -Range "Q2:Q$($VMInfo.Count + 1)"
        }
        If ($Sheet -eq 'Storage') {
            $ConditionalText += New-ConditionalText -Text 'V1' -Range 'G:G'
        }
        (Get-Variable -Name $Sheet -ErrorAction Ignore).Value | Export-Excel -Path $ExportPath -WorksheetName $Sheet -AutoSize -MaxAutoSizeRows 100 -TableName $Sheet -TableStyle $tableStyle -Style $Style -Numberformat '0' -ConditionalText $ConditionalText    
    }
}

$excel = Open-ExcelPackage $ExportPath 
if ($RI_1Year) { 
    Set-ExcelRange -Address $excel.Workbook.Worksheets['RI_1Year'].Cells['C:C'] -NumberFormat '$#,##0.#00' -WrapText -HorizontalAlignment Center
    Set-ExcelRange -Address $excel.Workbook.Worksheets['RI_1Year'].Cells["C$($RI_1Year.Count + 2)"] -Formula "=SUM(C2:C$($RI_1Year.Count + 1))"
}
if ($RI_3Year) { 
    Set-ExcelRange -Address $excel.Workbook.Worksheets['RI_3Year'].Cells['C:C'] -NumberFormat '$#,##0.#0' -WrapText -HorizontalAlignment Center
    Set-ExcelRange -Address $excel.Workbook.Worksheets['RI_3Year'].Cells["C$($RI_3Year.Count + 2)"] -Formula "=SUM(C2:C$($RI_1Year.Count + 1))"
}
if ($Storage) { 
    Set-ExcelRange -Address $excel.Workbook.Worksheets['Storage'].Cells['H:H'] -NumberFormat '$#,##0.#0' -WrapText -HorizontalAlignment Center 
    Set-ExcelRange -Address $excel.Workbook.Worksheets['Storage'].Cells["H$($Storage.Count + 2)"] -Formula "=SUM(H2:H$($Storage.Count + 1))"
}
if ($UnattachedDisk) {
    Set-ExcelRange -Address $excel.Workbook.Worksheets['UnattachedDisk'].Cells['E:E'] -NumberFormat '$#,##0.#0' -WrapText -HorizontalAlignment Center
    Set-ExcelRange -Address $excel.Workbook.Worksheets['UnattachedDisk'].Cells["E$($UnattachedDisk.Count + 2)"] -Formula "=SUM(E2:E$($UnattachedDisk.Count + 1))"
    Set-ExcelRange -Address $excel.Workbook.Worksheets['UnattachedDisk'].Cells['F:F'] -NumberFormat 'Date-Time' -WrapText -HorizontalAlignment Center
}
if ($VMInfo) {
    Set-ExcelRange -Address $excel.Workbook.Worksheets['VMInfo'].Cells['N:N'] -NumberFormat '$#,##0.#00' -WrapText -HorizontalAlignment Center
    Set-ExcelRange -Address $excel.Workbook.Worksheets['VMInfo'].Cells["N$($VMInfo.Count + 2)"] -Formula "=SUM(N2:N$($VMInfo.Count + 1))"
    Set-ExcelRange -Address $excel.Workbook.Worksheets['VMInfo'].Cells['O:O'] -NumberFormat '$#,##0.#00' -WrapText -HorizontalAlignment Center
    Set-ExcelRange -Address $excel.Workbook.Worksheets['VMInfo'].Cells["O$($VMInfo.Count + 2)"] -Formula "=SUM(O2:O$($VMInfo.Count + 1))"
    Set-ExcelRange -Address $excel.Workbook.Worksheets['VMInfo'].Cells['V:V'] -NumberFormat '$#,##0.#00' -WrapText -HorizontalAlignment Center
    Set-ExcelRange -Address $excel.Workbook.Worksheets['VMInfo'].Cells["V$($VMInfo.Count + 2)"] -Formula "=SUM(V2:V$($VMInfo.Count + 1))"
    'P', 'Q', 'R', 'T' | ForEach-Object {
        Set-ExcelRange -Address $excel.Workbook.Worksheets['VMInfo'].Cells["$_`:$_"] -NumberFormat '0.00' -WrapText -HorizontalAlignment Center
    }
    Set-ExcelRange -Address $excel.Workbook.Worksheets['VMInfo'].Cells['S:S'] -NumberFormat '0.00%' -WrapText -HorizontalAlignment Center
    Set-ExcelRange -Address $excel.Workbook.Worksheets['VMInfo'].Cells['M:M'] -NumberFormat '0.00%' -WrapText -HorizontalAlignment Center
}
if ($Orphaned) { 
    Set-ExcelRange -Address $excel.Workbook.Worksheets['Orphaned'].Cells['H:H'] -NumberFormat '$#,##0.#0' -WrapText -HorizontalAlignment Center
    Set-ExcelRange -Address $excel.Workbook.Worksheets['Orphaned'].Cells["H$($Orphaned.Count + 2)"] -Formula "=SUM(H2:H$($Orphaned.Count + 1))"
}
if ($Advisory) { 
    Set-ExcelRange -Address $excel.Workbook.Worksheets['Advisory'].Cells['H:H'] -NumberFormat '$#,##0.#0' -WrapText -HorizontalAlignment Center
    Set-ExcelRange -Address $excel.Workbook.Worksheets['Advisory'].Cells["H$($Advisory.Count + 2)"] -Formula "=SUM(H2:H$($Advisory.Count + 1))"
}
if ($BillDetail) { 
    Set-ExcelRange -Address $excel.Workbook.Worksheets['BillDetail'].Cells['I:J'] -NumberFormat '$#,##0.#0' -WrapText -HorizontalAlignment Center 
}
if ($TotalAverages) { 
    Set-ExcelRange -Address $excel.Workbook.Worksheets['TotalAverages'].Cells['C:C'] -NumberFormat '$#,##0.#0' -WrapText -HorizontalAlignment Center
}
if ($TotalBillInfo) { 
    Set-ExcelRange -Address $excel.Workbook.Worksheets['TotalBillInfo'].Cells['D:D'] -NumberFormat '$#,##0.#0' -WrapText -HorizontalAlignment Center
}
Close-ExcelPackage $excel -ErrorAction Ignore

$StopWatch.Stop()

[PSCustomObject]@{
    'OutputFile' = $ExportPath
    'Minutes'    = $StopWatch.Elapsed.TotalMinutes
    #'Seconds'    = $StopWatch.Elapsed.TotalSeconds
}
