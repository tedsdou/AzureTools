<#
.NOTES
    DISCLAIMER:
    ===========
    This Sample Code is provided for the purpose of illustration only and is 
    not intended to be used in a production environment.  
    THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT
    WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT 
    LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS
    FOR A PARTICULAR PURPOSE.  

    We grant You a nonexclusive, royalty-free
    right to use and modify the Sample Code and to reproduce and distribute
    the object code form of the Sample Code, provided that You agree:
    (i) to not use Our name, logo, or trademarks to market Your software
    product in which the Sample Code is embedded; (ii) to include a valid
    copyright notice on Your software product in which the Sample Code is
    embedded; and (iii) to indemnify, hold harmless, and defend Us and
    Our suppliers from and against any claims or lawsuits, including
    attorneys' fees, that arise or result from the use or distribution
    of the Sample Code.
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