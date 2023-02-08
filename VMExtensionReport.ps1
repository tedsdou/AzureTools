#Requires -Version 7 -Modules Az.Accounts, Az.Compute, Az.OperationalInsights, Az.Resources
Param($SubscriptionName)

If ($SubscriptionName){$Subs = Get-AzSubscription -SubscriptionName $SubscriptionName -WarningAction Ignore}
Else {$Subs = Get-AzSubscription -WarningAction Ignore}
$ErrorLog = 'C:\Temp\MMA-ErrorLog.txt'
foreach ($Sub in $Subs) {
    $null = Set-AzContext -Subscription $Sub.Name -WarningAction Ignore
    #get all the Log Analytics Workspace
    $all_workspace = Get-AzOperationalInsightsWorkspace

    #for windows vm, the value is fixed as below
    $extension_name = 'MicrosoftMonitoringAgent'
    $VMList = (Get-AzResourceGroup).ResourceGroupName | ForEach-Object -Parallel {
        try {
            Get-AzVM -ResourceGroupName $_ -ErrorAction Stop -WarningAction Ignore | Select-Object -Property Name, ResourceGroupName
        }
        catch {
            Add-Content -Path $using:ErrorLog -Value "Failed to get VM list in resource group $_ `n`rERROR: $($_.Exception.message)"
        }
    }
    If ($VMList) {
        $VMList | ForEach-Object -Parallel {
            $VMName = $_.Name
            $ResourceGroupName = $_.ResourceGroupName
            try {
                $myvm = Get-AzVMExtension -ResourceGroupName $ResourceGroupName -VMName $VMName -Name $using:extension_name -ErrorAction Stop -WarningAction Ignore
                $workspace_id = ($myvm.PublicSettings | ConvertFrom-Json).workspaceId
                foreach ($w in $using:all_workspace) {
                    if ($w.CustomerId.Guid -eq $workspace_id) {
                        [PSCustomObject]@{
                            'Subscription'      = $Using:sub.Name
                            'VMName'            = $VMName
                            'ResourceGroupName' = $ResourceGroupName
                            'WorkspaceName'     = $w.name
                        }
                    }
                }
            }
            catch {
                #This is a catch block
                Add-Content -Path $using:ErrorLog -Value "Failed to get VM extension for VM: $VM - RG: $ResourceGroupName - Subscription: $using:Sub `n`rERROR: $($_.Exception.message)"
            }
        }
    }
}