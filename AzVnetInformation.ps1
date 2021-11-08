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
