$VMList = 'VMList'
$TenantID = 'TenantID'

$null = Login-AzAccount -Tenant $TenantID -WarningAction Ignore

$VMList | ForEach-Object -Parallel {
    $vmConfig = Get-AzVM -Name $_
    $vmConfig.StorageProfile.OsDisk.DeleteOption = 'Delete'
    $vmConfig.StorageProfile.DataDisks | ForEach-Object { $_.DeleteOption = 'Delete' }
    $vmConfig.NetworkProfile.NetworkInterfaces | ForEach-Object { $_.DeleteOption = 'Delete' }
    $null = $vmConfig | Update-AzVM
    [PSCustomObject]@{
        'Name'                 = $_
        'OSDiskDeleteOption'   = $vmConfig.StorageProfile.OsDisk.DeleteOption
        'DataDiskDeleteOption' = $vmConfig.StorageProfile.DataDisks | ForEach-Object { $_.DeleteOption }
        'NICDeleteOption'      = $vmConfig.NetworkProfile.NetworkInterfaces | ForEach-Object { $_.DeleteOption }
    } 
    Remove-AzVM -Name $_ -ResourceGroupName $vmConfig.ResourceGroupName -Force
}

##Search for any orphaned resources
foreach ($VM in $VMList) {
    $Orphaned = Search-AzGraph -Query "Resources | where name contains '$VM'"
    if ($Orphaned) {
        foreach ($O in $Orphaned) {
            [PSCustomObject]@{
                'DeletedVM'     = $VM
                'Name'          = $O.Name
                'ResourceGroup' = $O.resourceGroup
                'Location'      = $O.location
                'Type'          = $O.type
                'ResourceId'    = $O.ResourceId
            }
        }
    }
}