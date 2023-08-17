$RG = 'rg-S2S-VPN'
$VNet = 'VNet-S2S-HUB'
$Location = 'North Central US'
New-AzResourceGroup -Name $RG -Location $Location
$frontendSubnet = New-AzVirtualNetworkSubnetConfig -Name 'sn-FrontEnd' -AddressPrefix '10.1.0.0/24'
New-AzVirtualNetwork -Name $VNet -Location $Location -ResourceGroupName $RG -AddressPrefix '10.1.0.0/16' -Subnet $frontendSubnet


$subnet = New-AzVirtualNetworkSubnetConfig -Name 'gatewaysubnet' -AddressPrefix '10.254.0.0/27'
    
$ngwpip = New-AzPublicIpAddress -Name ngwpip -ResourceGroupName "vnet-gateway" -Location "UK West" -AllocationMethod Dynamic
$vnet = New-AzVirtualNetwork -AddressPrefix "10.254.0.0/27" -Location "UK West" -Name vnet-gateway -ResourceGroupName "vnet-gateway" -Subnet $subnet
$subnet = Get-AzVirtualNetworkSubnetConfig -name 'gatewaysubnet' -VirtualNetwork $vnet
$ngwipconfig = New-AzVirtualNetworkGatewayIpConfig -Name ngwipconfig -SubnetId $subnet.Id -PublicIpAddressId $ngwpip.Id

New-AzVirtualNetworkGateway -Name myNGW -ResourceGroupName vnet-gateway -Location "UK West" -IpConfigurations $ngwIpConfig  -GatewayType "Vpn" -VpnType "RouteBased" -GatewaySku "VpnGw4" -VpnGatewayGeneration "Generation2"
New-AzVirtualNetworkGateway -Name vnet-gw -Location $Location -GatewayType Vpn -GatewaySku VpnGw2 -VpnGatewayGeneration Generation2
