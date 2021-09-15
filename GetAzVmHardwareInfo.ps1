function Get-AzVMInformation {
    param (
        $VM
    )
    if (-not($VM)) {
        $VM = Get-AzVM -Status
    }
    else {
        $VM = Get-AzVM -Status -Name $VM
    }

    foreach ($V in $VM) {
        $Size = Get-AzVMSize -VMName $V.Name -ResourceGroupName $V.ResourceGroupName | Where-Object { $_.Name -eq $V.HardwareProfile.VmSize } 
        [PSCustomObject]@{
            'Name'            = $V.Name
            'Subscription'    = (Get-AzContext).Subscription.Name
            'ResourceGroup'   = $V.ResourceGroupName
            'Location'        = $V.Location
            'Publisher'       = $V.StorageProfile.ImageReference.Publisher
            'OperatingSystem' = $V.StorageProfile.ImageReference.Sku
            'Status'          = $V.PowerState
            'Size'            = $V.HardwareProfile.VmSize
            'Cores'           = $size.NumberOfCores
            'Disks'           = ($V.StorageProfile.OsDisk.Count) + ($V.StorageProfile.DataDisks.Count)
        } 
    } 
}
