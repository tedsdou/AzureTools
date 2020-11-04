#for Jerome's Mac
$now = Get-Date -UFormat "%Y-%m-%d_%H-%M-%S"
$filepath = "/Users/u13873/Desktop/$now.csv"
$filepath = 'C:\Temp\vnetInfo.csv'

<# 
I need to go deeper into 'VnetAddressPrefixes'   = (($VNET).AddressSpace.AddressPrefixes -join ' ')
I want it to also discover available addresses. Usage?

Find number of available IPs, like how it is in the gui
#>

#Login-AzAccount
$Subscription = Get-AzSubscription | Where-Object {$_.Name -match 'tgs|visual'} 
foreach ($S in $Subscription) {
  $null = Set-AzContext -SubscriptionName $S.Name
  $VNET = Get-AzVirtualNetwork
  foreach ($V in $VNET) {
    $subnets = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $V
    foreach ($subnet in $Subnets) {
        #Region Find how many address in this space 
            # Get prefix length to find total number of IPs in a subnet and Address prefix
            $PrefixLength = $subnet.AddressPrefix.Split('/')[-1]
            # Total IPs and total available IPs in count
            $TotalIPs = [math]::Pow(2, (32 - $PrefixLength))
            $TotalAvailableIPs = $TotalIPs - 5 - $subnet.IPConfigurations.Count # Remove Azure reserved IPS
        #EndRegion
        [PSCustomObject]@{
          'SubscriptionName'      = $S.Name
          'VnetName'              = $V.Name 
          'VnetAddressPrefixes'   = ($V).AddressSpace.AddressPrefixes | Out-String
          'VnetLocation'          = $V.location
          'SubnetName'            = $subnet.name
          'SubnetAddressPrefixes' = "$($subnet.AddressPrefix) ($($TotalAvailableIPs) Available)"
          'ResourceGroupName'     = $V.ResourceGroupName
          'DhcpOptions'           = ($V).DhcpOptions.DnsServers | Out-String
          'VirtualNetworkPeerings'= ($V).VirtualNetworkPeerings.name | Out-String
        } | Export-Csv  -Path $filepath -NoTypeInformation -append
    }
  }
}
