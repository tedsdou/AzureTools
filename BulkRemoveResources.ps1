$VMList = 'Comma-Separated List of VMs'
$RGList = 'Comma-Separated List of RGs'
$TenantID = '<TenantID>'

Login-AzAccount -Tenant $TenantID

$VMList | ForEach-Object -Parallel {
    $vmConfig = Get-AzVM $_
    $vmConfig.StorageProfile.OsDisk.DeleteOption = 'Delete'
    $vmConfig.StorageProfile.DataDisks | ForEach-Object { $_.DeleteOption = 'Delete' }
    $vmConfig.NetworkProfile.NetworkInterfaces | ForEach-Object { $_.DeleteOption = 'Delete' }
    $vmConfig | Update-AzVM
    [PSCustomObject]@{
        'Name' = $_
        'OSDiskDeleteOption' = $vmConfig.StorageProfile.OsDisk.DeleteOption
        'DataDiskDeleteOption' = $vmConfig.StorageProfile.DataDisks | ForEach-Object { $_.DeleteOption}
        'NICDeleteOption' = $vmConfig.NetworkProfile.NetworkInterfaces | ForEach-Object { $_.DeleteOption}
    }
    Remove-AzVM -Name $_ -ResourceGroupName $vmConfig.ResourceGroupName -WhatIf
}

foreach ($RG in $RGList) {
    Get-AzResource -ResourceGroupName $RG | ForEach-Object -Parallel {
        Remove-AzResource -ResourceId $_.ResourceId -Force
    }
    Remove-AzResourceGroup -Name $RG
}


