$loc = Get-AzLocation | Where-Object GeographyGroup -Like 'us' | Select-Object location, displayname, PhysicalLocation
[System.Collections.ArrayList]$Quotas = @()
foreach ($l in $loc) {
    try {
        Get-AzVMUsage -Location $l.Location -ErrorAction Ignore  | Where-Object -FilterScript { ($_.CurrentValue / $_.Limit) -gt .7 } | ForEach-Object {
            $threshold = $_.CurrentValue / $_.Limit
            $null = $Quotas.Add([PSCustomObject]@{
                'Name'         = $_.Name.LocalizedValue
                'Location'     = $l.Location
                'CurrentValue' = $_.CurrentValue
                'Limit'        = $_.Limit
                'Unit'         = $_.Unit
                'Utilization' =  $threshold
            })
        }
    }
    catch {
        #Safe to ignore this.  Added the try/catch to account for a terminating CannotDivideByZeroError
    }
    
}

$Quotas | Sort-Object -Property 'Utilization' -Descending | 
    Select-Object -Property Name,Location,CurrentValue,Limit,Unit,@{N='Utilization';e={'{0:P0}' -f $_.Utilization}} 