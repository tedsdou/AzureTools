$Vault = Get-AzKeyVault
$Threshold = (Get-Date).AddDays(30)
[System.Collections.ArrayList]$List = @()
foreach ($V in $Vault) {
    Get-AzKeyVaultCertificate -VaultName $V.VaultName | Where-Object ($_.Expires -lt $Threshold) | ForEach-Object {
        $null = $List.Add([PSCustomObject]@{
                'Name'       = $_.Name
                'Expiration' = $_.Expires
                'VaultName'  = $V.VaultName
                'Type'       = 'Certificate'
            })
    }
    Get-AzKeyVaultKey -VaultName $V.VaultName | Where-Object ($_.Expires -lt $Threshold) | ForEach-Object {
        $null = $List.Add([PSCustomObject]@{
                'Name'       = $_.Name
                'Expiration' = $_.Expires
                'VaultName'  = $V.VaultName
                'Type'       = 'Key'
            })
    }
    Get-AzKeyVaultSecret -VaultName $V.VaultName | Where-Object ($_.Expires -lt $Threshold) | ForEach-Object {
        $null = $List.Add([PSCustomObject]@{
                'Name'       = $_.Name
                'Expiration' = $_.Expires
                'VaultName'  = $V.VaultName
                'Type'       = 'Secret'
            })
    }

}

If ($List) {
    $Header = @'
    <style>
    TABLE {border-width: 1px; border-style: solid; border-color: black; border-collapse: collapse;}
    TH {border-width: 1px; padding: 3px; border-style: solid; border-color: black; background-color: #6495ED;}
    TD {border-width: 1px; padding: 3px; border-style: solid; border-color: black;}
    </style>
'@ #No whitespace allowed before terminating here string
    
    $HTMLBody = $List | ConvertTo-Html -Property Name, Expiration, VaultName, Type -Head $Header | Out-String
    #Send Email
    $Body = [PSCustomObject]@{
        To      = $EmailTo
        Subject = "Azure Automation Expiring Certificate Report for $((Get-AzContext).Subscription.Name)"
        Body    = $HTMLBody
    }
    Write-Verbose $Body
    # Create a line that creates a JSON from this object
    $JSONBody = $Body | ConvertTo-Json 
    $URL = 'LogicAppURL'
    Invoke-RestMethod -Method POST -Uri $URL -Body $JSONBody -ContentType 'application/json'
}
