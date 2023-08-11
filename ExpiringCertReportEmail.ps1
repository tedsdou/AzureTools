Param($EmailTo)
#Enable the AZ cmdlets if they exist in the automation account
Enable-AzureRMAlias -ErrorAction Ignore
$connectionName = "AzureRunAsConnection" 
try
{
    # Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName         
    $null = Add-AzureRmAccount -ServicePrincipal -TenantId $servicePrincipalConnection.TenantId -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
    Write-Output -InputObject 'SUCCESS: Logged into Azure'
}
catch {
    if (!$servicePrincipalConnection)
    {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    } else{
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}

$AutomationAccounts = Get-AzureRMAutomationAccount 
Write-Verbose -Message "CurrentDate: $(Get-Date)"
$StaleDate = (Get-Date).AddMonths(1) 
$Export = @()
foreach ($Account in $AutomationAccounts){
    Write-Verbose -Message "Finding information for $($Account.AutomationAccountName)"
    $certDate = (Get-AzureRMAutomationCertificate -ResourceGroupName $Account.ResourceGroupName -AutomationAccountName $Account.AutomationAccountName).ExpiryTime.Date
    If(($certDate) -and ($certDate -le $StaleDate)){
        $Export += [PSCustomObject]@{
                'AutomationAccountName' = $Account.AutomationAccountName
                'ResourceGroupName'     = $Account.ResourceGroupName
                'CertificateExpriation' = $certDate
                'SubscriptionName'      = (Get-AzContext).Subscription.Name
            }
    }
}
If($Export){
$Header = @"
<style>
TABLE {border-width: 1px; border-style: solid; border-color: black; border-collapse: collapse;}
TH {border-width: 1px; padding: 3px; border-style: solid; border-color: black; background-color: #6495ED;}
TD {border-width: 1px; padding: 3px; border-style: solid; border-color: black;}
</style>
"@ #No whitespace allowed before terminating here string

    $HTMLBody = $Export | ConvertTo-Html -Property AutomationAccountName, ResourceGroupName, CertificateExpriation -Head $Header  | Out-String
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
Else{
    Write-Output 'No stale certificates found'
}