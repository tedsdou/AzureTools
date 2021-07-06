#Requires -Version 7
$count = 5
$projectName = "PoSh-$env:USERNAME"
$ResourceGroupName = "rg-$projectName"
$NetworkName = "vnet-$projectName"
$SubnetName = "snet-$projectName"
$SubnetAddressPrefix = '10.0.0.0/24'
$VnetAddressPrefix = '10.0.0.0/16'
$LocationName = 'northcentralus'
try {
    $null = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction Stop
}
catch {
    $null = New-AzResourceGroup -Name $ResourceGroupName -Location $LocationName
}
try {
    $Vnet = Get-AzVirtualNetwork -ResourceGroupName $ResourceGroupName -ErrorAction Stop -Name $NetworkName
}
catch {
    $SingleSubnet = New-AzVirtualNetworkSubnetConfig -Name $SubnetName -AddressPrefix $SubnetAddressPrefix
    $Vnet = New-AzVirtualNetwork -Name $NetworkName -ResourceGroupName $ResourceGroupName -Location $LocationName -AddressPrefix $VnetAddressPrefix -Subnet $SingleSubnet
}

Measure-Command {
    1..$count | ForEach-Object -Parallel {
        $VMLocalAdminUser = 'LabAdmin'
        $VMLocalAdminSecurePassword = ConvertTo-SecureString  -AsPlainText -Force -String 'Pa$$w0rd'
        $LocationName = 'northcentralus'
        $ComputerName = $VMName = "vm-$Env:USERNAME-$_"
        $VMSize = 'Standard_DS1'
        $NICName = "nic-$VMName"
        
        $NIC = New-AzNetworkInterface -Name $NICName -ResourceGroupName $using:ResourceGroupName -Location $LocationName -SubnetId $using:Vnet.Subnets[0].Id

        $Credential = New-Object System.Management.Automation.PSCredential ($VMLocalAdminUser, $VMLocalAdminSecurePassword);

        $VirtualMachine = New-AzVMConfig -VMName $VMName -VMSize $VMSize
        $VirtualMachine = Set-AzVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $ComputerName -Credential $Credential -ProvisionVMAgent -EnableAutoUpdate
        $VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $NIC.Id
        $VirtualMachine = Set-AzVMSourceImage -VM $VirtualMachine -PublisherName 'MicrosoftWindowsServer' -Offer 'WindowsServer' -Skus '2019-Datacenter' -Version latest

        New-AzVM -ResourceGroupName $using:ResourceGroupName -Location $LocationName -VM $VirtualMachine
    } -ThrottleLimit 20
}