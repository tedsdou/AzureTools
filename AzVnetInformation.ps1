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

$filepath = 'C:\Temp\vnetInfo.csv'
If(-Not(Get-AzContext)){
  Connect-AzAccount
}
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
