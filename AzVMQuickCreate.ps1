<#
.NOTES
    Copyright (c) Microsoft Corporation.

    MIT License

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED *AS IS*, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
#>
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