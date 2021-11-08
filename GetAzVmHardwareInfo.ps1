function Get-AzVMInformation {
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
