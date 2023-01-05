#Requires -Version 7
$resourceGroup = 'ContosoResourceGroup'
Get-AzVMSize -ResourceGroupName $resourceGroup -VMName TGSTestBox2
foreach ($VM in (Get-AzVM -ResourceGroupName $resourceGroup)) {
    $vm.HardwareProfile.VmSize = 'Standard_D2as_v4'
    Update-AzVM -VM $vm -ResourceGroupName $resourceGroup 
}

Get-AzVM -ResourceGroupName $resourceGroup | ForEach-Object -Parallel {
    $_.HardwareProfile.VmSize = 'Standard_D2as_v4'
    Update-AzVM -VM $_ -ResourceGroupName $using:resourceGroup -Verbose
}

# Choose between Standard_LRS, StandardSSD_LRS and Premium_LRS based on your scenario
$storageType = 'StandardSSD_LRS'
# Premium capable size 
$size = 'Standard_DS2_v2'

# Get parent VM resource
Get-AzDisk | ForEach-Object -ThrottleLimit 5 -Parallel {
    try {
        $vmResource = Get-AzResource -ResourceId $_.ManagedBy
        Stop-AzVM -ResourceGroupName $vmResource.ResourceGroupName -Name $vmResource.Name -Force 
        $vm = Get-AzVM -ResourceGroupName $vmResource.ResourceGroupName -Name $vmResource.Name 
        $vm.HardwareProfile.VmSize = $using:size 
        Update-AzVM -VM $vm -ResourceGroupName $vmResource.ResourceGroupName 
    }
    catch {
        Write-Warning -Message "ERROR: $($_.Exception.Message)"
    }
    Finally{
        $_.Sku = [Microsoft.Azure.Management.Compute.Models.DiskSku]::new($using:storageType)
        $_ | Update-AzDisk 
    }
    If ($vmResource) {
        Start-AzVM -ResourceGroupName $vmResource.ResourceGroupName -Name $vmResource.Name
    }
}
