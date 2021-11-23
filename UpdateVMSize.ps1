$resourceGroup = 'rg-StrtStp'
$vmNames = (Get-AzVM -ResourceGroupName $resourceGroup).Name
$NewVMSize = 'Standard_B1s'

foreach ($vmName in $vmNames) {
    $vm = Get-AzVM -ResourceGroupName $resourceGroup -VMName $vmName
    $vm.HardwareProfile.VmSize = $NewVMSize
    Update-AzVM -VM $vm -ResourceGroupName $resourceGroup

   <#  Stop-AzVM -ResourceGroupName $resourceGroup -Name $vmName -Force
    $vm = Get-AzVM -ResourceGroupName $resourceGroup -VMName $vmName
    $vm.HardwareProfile.VmSize = $NewVMSize
    Update-AzVM -VM $vm -ResourceGroupName $resourceGroup
    Start-AzVM -ResourceGroupName $resourceGroup -Name $vmName #>
}
