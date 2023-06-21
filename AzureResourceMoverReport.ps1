$CSVSupport = "$ENV:Temp\moveSupport.csv"
$OutFile = "$ENV:Temp\AzureResourceMove$((Get-Date -Format s) -replace ":","_").xlsx" #Change as needed
Remove-Item -Path $CSVSupport -ErrorAction Ignore

#Module checker
'AZ','ImportExcel' | ForEach-Object {
    $ModName = $_
    Write-Host "Validating $ModName Module.."
    if (-not (Get-InstalledModule -Name $ModName -ErrorAction SilentlyContinue)) {
        Write-Host "Trying to install $ModName Module.."
        try {
            Install-Module -Name $ModName -Force
        }
        catch {
            Read-Host "Error while installing $ModName Module.`n`rERROR: $($_.Exception.Message)`n`rPress <Enter> to finish script"
            Exit
        }
    }
}



If (-not(Get-AzContext)) {
    Write-Warning -Message "No Azure Context Found!`nLogging you in"
    Login-AzAccount
}

$Tenant = Get-AzTenant | Out-GridView -PassThru -Title "Choose the tenant you wish to evaluate"

$null = Invoke-WebRequest -Uri "https://raw.githubusercontent.com/tfitzmac/resource-capabilities/main/move-support-resources-with-regions.csv" -OutFile $CSVSupport
$info = Import-Csv -Path $CSVSupport
If (-not(Get-AzContext)) {
    Write-Warning -Message "You are not logged into Azure.  Use "Login-AzAccount" to login."
    exit
}
$Subscription = Get-AzSubscription -TenantId $Tenant.Id | Out-GridView -PassThru -Title "Choose the subscription(s) you wish to evaluate"
[System.Collections.ArrayList]$ResArr = @()
foreach ($Sub in $Subscription) {
    try {
        $null = Set-AzContext -Subscription $Sub.Name -WarningAction Ignore
    }
    catch {
        Write-Warning -Message "Unable to connect to Azure Subscription: $($Sub.Name)`nERROR: $($_.Exception.Message)"
    }
    foreach ($R in Get-AzResource) {
        $lineItem = $info | Where-Object { $_.Resource -eq $R.ResourceType }
        <#
        Add comment if present.
        TODO: Add dynamic read of this based off markdown: https://github.com/MicrosoftDocs/azure-docs/blob/main/articles/azure-resource-manager/management/move-support-resources.md?plain=1
        #>
        switch ($r.ResourceType) {
            { $_ -match "classic" } { 
                $Comment = "See Classic deployment move guidance. Classic deployment resources can be moved across subscriptions with an operation specific to that scenario. https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/move-limitations/classic-model-move-limitations" 
                Continue
            }
            { $_ -match "^Microsoft.AppService" } { 
                $Comment = "See App Service move guidance. https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/move-limitations/app-service-move-limitations" 
                if ($_ -eq "Microsoft.AppService/apiapps") {
                    $RegionComment = "`nMove an App Service app to another region. https://learn.microsoft.com/en-us/azure/app-service/manage-move-across-regions"
                }
                Continue
            }
            { $_ -match "^Microsoft.ApiManagement" } { 
                $Comment = "An API Management service that is set to the Consumption SKU cannot be moved." 
                if ($_ -eq "Microsoft.ApiManagement/service") { 
                    $RegionComment = "`nMove API Management across regions. https://learn.microsoft.com/en-us/azure/api-management/api-management-howto-migrate"
                }
                Continue  
            }
            { $_ -match "^Microsoft.Automation" } { 
                $Comment = "Runbooks must exist in the same resource group as the Automation Account. The movement of System assigned managed identity, and User-assigned managed identity takes place automatically with the Automation account. For information, see: https://learn.microsoft.com/en-us/azure/automation/how-to/move-account?toc=/azure/azure-resource-manager/toc.json" 
                if ($_ -eq "Microsoft.Automation/automationaccounts") {
                    $RegionComment = "`nPowerShell Script. https://learn.microsoft.com/en-us/azure/automation/automation-disaster-recovery"
                }
                Continue
            }
            { $_ -eq "Microsoft.Batch/batchaccounts" } { 
                $RegionComment = "`nBatch accounts can't be moved directly from one region to another, but you can use a template to export a template, modify it, and deploy the template to the new region. Learn about moving a Batch account across regions. https://learn.microsoft.com/en-us/azure/batch/account-move" 
                Continue
            }
            { $_ -eq "Microsoft.Blockchain/blockchainmembers" } { 
                $RegionComment = "`nThe blockchain network can't have nodes in different regions." 
                Continue
            }
            { $_ -match "^Microsoft.Cache" } { 
                $Comment = "If the Azure Cache for Redis instance is configured with a virtual network, the instance cannot be moved to a different subscription. See https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/move-limitations/networking-move-limitations" 
                Continue
            }
            { $_ -match "^Microsoft.CertificateRegistration" } { 
                $Comment = "See https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/move-limitations/app-service-move-limitations" 
                Continue
            }
            { $_ -eq "Microsoft.CognitiveServices/Cognitive Search" } { 
                $RegionComment = "`nSupported with manual steps. Learn about moving your Azure Cognitive Search service to another region. https://learn.microsoft.com/en-us/azure/search/search-howto-move-across-regions"
                Continue
            }
            { $_ -eq "Microsoft.Communication/communicationservices" } { 
                $SubComment = "`nNote that resources with attached phone numbers cannot be moved to subscriptions in different data locations, nor subscriptions that do not support having phone numbers." 
                Continue
            }
            { $_ -match "^Microsoft.Compute" } { 
                $Comment = "See Virtual Machines move guidance. https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/move-limitations/virtual-machines-move-limitations" 
                if ($_ -eq "Microsoft.Compute/availabilitysets") {
                    $RegionComment = "`nUse Azure Resource Mover to move availability sets. https://learn.microsoft.com/en-us/azure/resource-mover/tutorial-move-region-virtual-machines"
                }
                if ($_ -eq "Microsoft.Compute/disks") {
                    $RegionComment = "`nUse Azure Resource Mover to move Azure VMs and related disks. https://learn.microsoft.com/en-us/azure/resource-mover/tutorial-move-region-virtual-machines"
                }
                if ($_ -eq "Microsoft.Compute/snapshots") {
                    $RGComment = "`nYes - Full`nNo - Incremental"
                    $RegionComment = "`nYes - Full`nNo - Incremental"
                    $SubComment = = "`nNo - Full`nYes - Incremental"
                }
                if ($_ -eq "Microsoft.Compute/virtualmachines") {
                    $RegionComment = "`nUse Azure Resource Mover to move Azure VMs. https://learn.microsoft.com/en-us/azure/resource-mover/tutorial-move-region-virtual-machines"
                }
                Continue
            }
            { $_ -eq "Microsoft.DataProtection/backupvaults" } {
                $RGComment = "`nhttps://learn.microsoft.com/en-us/azure/backup/backup-vault-overview#use-azure-portal-to-move-backup-vault-to-a-different-resource-group"
                $SubComment = "`nhttps://learn.microsoft.com/en-us/azure/backup/backup-vault-overview#use-azure-portal-to-move-backup-vault-to-a-different-subscription"
                Continue
            }
            { $_ -eq "Microsoft.DBforMariaDB/servers" } { 
                $RegionComment = "`nYou can use a cross-region read replica to move an existing server. Learn more. https://learn.microsoft.com/en-us/azure/postgresql/howto-move-regions-portal`nIf the service is provisioned with geo-redundant backup storage, you can use geo-restore to restore in other regions. Learn more. https://learn.microsoft.com/en-us/azure/mariadb/concepts-business-continuity#recover-from-an-azure-regional-data-center-outage" 
                Continue
            }
            { $_ -eq "Microsoft.DBforMySQL/servers" } { 
                $RegionComment = "`nYou can use a cross-region read replica to move an existing server. Learn more. https://learn.microsoft.com/en-us/azure/mysql/howto-move-regions-portal" 
                Continue
            }
            { $_ -eq "Microsoft.DBforPostgreSQL/servers" } { 
                $RegionComment = "`nYou can use a cross-region read replica to move an existing server. Learn more. https://learn.microsoft.com/en-us/azure/postgresql/howto-move-regions-portal" 
                Continue
            }
            { $_ -eq "Microsoft.Devices/iothubs" } { 
                $RegionComment = "`nLearn More. https://learn.microsoft.com/en-us/azure/iot-hub/iot-hub-how-to-clone" 
                Continue
            }
            { $_ -eq "Microsoft.DevSpaces/AKS cluster" } { 
                $RegionComment = "`nLearn more about moving to another region. https://learn.microsoft.com/en-us/previous-versions/azure/dev-spaces/" 
                Continue
            }
            { $_ -eq "Microsoft.DigitalTwins/digitaltwinsinstances" } { 
                $RegionComment = "`nRecreating resources in new region. Learn more. https://learn.microsoft.com/en-us/azure/digital-twins/how-to-move-regions" 
                Continue
            }
            { $_ -eq "Microsoft.EventGrid/eventsubscriptions" } {
                $RGComment = "`ncan't be moved independently but automatically moved with subscribed resource."
                $SubComment = "`ncan't be moved independently but automatically moved with subscribed resource."
                Continue
            }
            { $_ -eq "Microsoft.EventHub/namespaces" } { 
                $RegionComment = "`nMove an Event Hub namespace to another region. https://learn.microsoft.com/en-us/azure/event-hubs/move-across-regions" 
                Continue
            }
            { $_ -match "^Microsoft.HDInsight" } {
                $Comment = "You can move HDInsight clusters to a new subscription or resource group. However, you can't move across subscriptions the networking resources linked to the HDInsight cluster (such as the virtual network, NIC, or load balancer). In addition, you can't move to a new resource group a NIC that is attached to a virtual machine for the cluster. When moving an HDInsight cluster to a new subscription, first move other resources (like the storage account). Then, move the HDInsight cluster by itself."
                Continue
            }
            { $_ -match "^Microsoft.Insights" } { 
                $Comment = "Make sure moving to new subscription doesn't exceed subscription quotas. https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/azure-subscription-service-limits#azure-monitor-limits`nMoving or renaming any Application Insights resource changes the resource ID. When the ID changes for a workspace-based resource, data sent for the prior ID is accessible only by querying the underlying Log Analytics workspace. The data will not be accessible from within the renamed or moved Application Insights resource." 
                if ($_ -eq "Microsoft.Insights/accounts") {
                    $RegionComment = "`nLearn More. https://learn.microsoft.com/en-us/azure/azure-monitor/faq#how-do-i-move-an-application-insights-resource-to-a-new-region-"
                }
                Continue
            }
            { $_ -eq "Microsoft.IoTHub/iothub" } { 
                $RegionComment = "`nClone an IoT hub to another region. Clone an IoT hub to another region" 
                Continue
            }
            { $_ -match "^Microsoft.KeyVault" } { 
                $Comment = "Key Vaults used for disk encryption can't be moved to a resource group in the same subscription or across subscriptions." 
                Continue
            }
            { $_ -eq "Microsoft.Maintenance/configurationassignments" } { 
                $RegionComment = "`nLearn More. https://learn.microsoft.com/en-us/azure/virtual-machines/move-region-maintenance-configuration" 
                Continue
            }
            { $_ -eq "Microsoft.Maintenance/maintenanceconfigurations" } { 
                $RegionComment = "`nLearn More. https://learn.microsoft.com/en-us/azure/virtual-machines/move-region-maintenance-configuration-resources" 
                Continue
            }
            { $_ -eq "Microsoft.Maps/accounts" } { 
                $RegionComment = "`nAzure Maps is a geospatial service." 
                Continue
            }
            { $_ -match "^Microsoft.MobileNetwork" } { 
                $RegionComment = "`nMove your private mobile network resources to a different region. https://learn.microsoft.com/en-us/azure/private-5g-core/region-move-private-mobile-network-resources" 
                Continue
            }
            { $_ -match "^Microsoft.Network" } { 
                $Comment = "See Networking move guidance. https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/move-limitations/networking-move-limitations" 
                if ($_ -eq "Microsoft.Network/loadbalancers") {
                    $RGComment = "`nYes - Basic SKU`nYes - Standard SKU"
                    $SubComment = "`nYes - Basic SKU`nYes - Standard SKU"
                    $RegionComment = "`nUse Azure Resource Mover to move internal and external load balancers. https://learn.microsoft.com/en-us/azure/resource-mover/tutorial-move-region-virtual-machines"
                }
                if ( $_ -eq "Microsoft.Network/networkinterfaces") {
                    $RegionComment = "`nUse Azure Resource Mover to move NICs. https://learn.microsoft.com/en-us/azure/resource-mover/tutorial-move-region-virtual-machines" 
                }
                if ($_ -eq "Microsoft.Network/networksecuritygroups" ) {
                    $RegionComment = "`nUse Azure Resource Mover to move network security groups (NSGs). https://learn.microsoft.com/en-us/azure/resource-mover/tutorial-move-region-virtual-machines" 
                }
                if ($_ -eq "Microsoft.Network/privateendpoints" ) {
                    $RGComment = "`nYes - for supported private-link resources. https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/move-limitations/networking-move-limitations#private-endpoints`nNo - for all other private-link resources"  
                    $SubComment = $RGComment
                }
                if ($_ -eq "Microsoft.Network/publicipaddresses") {
                    $SubComment = "`nSee Networking move guidance. https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/move-limitations/networking-move-limitations"
                    $RegionComment = "`nUse Azure Resource Mover to move public IP address configurations (IP addresses are not retained). https://learn.microsoft.com/en-us/azure/resource-mover/tutorial-move-region-virtual-machines"
                }
                if ($_ -eq "Microsoft.Network/virtualnetworkgateways" ) {
                    $RGComment = "`nYes except Basic SKU - see Networking move guidance. https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/move-limitations/networking-move-limitations"
                    $SubComment = $RGComment
                }
                Continue
            }
            { $_ -match "^Microsoft.OperationalInsights" } {
                $Comment = "Make sure that moving to a new subscription doesn't exceed subscription quotas.`nWorkspaces that have a linked automation account can't be moved. Before you begin a move operation, be sure to unlink any automation accounts.`nhttps://learn.microsoft.com/en-us/azure/azure-resource-manager/management/azure-subscription-service-limits#azure-monitor-limits"
                Continue
            }
            { $_ -match "^Microsoft.RecoveryServices" } { 
                $Comment = "See Recovery Services move guidance. https://learn.microsoft.com/en-us/azure/backup/backup-azure-move-recovery-services-vault?toc=/azure/azure-resource-manager/toc.json`nSee Continue backups in Recovery Services vault after moving resources across regions. https://learn.microsoft.com/en-us/azure/backup/azure-backup-move-vaults-across-regions?toc=/azure/azure-resource-manager/toc.json" 
                Continue
            }
            { $_ -eq "Microsoft.RecoveryServices/vaults" } { 
                $RegionComment = "`nMoving Recovery Services vaults for Azure Backup across Azure regions isn't supported. In Recovery Services vaults for Azure Site Recovery, you can disable and recreate the vault in the target region. https://learn.microsoft.com/en-us/azure/site-recovery/move-vaults-across-regions" 
                Continue
            }
            { $_ -eq "Microsoft.Resources/deploymentscripts" } { 
                $RegionComment = "`nMove Microsoft.Resources resources to new region. https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/microsoft-resources-move-regions" 
                Continue
            }
            { $_ -eq "Microsoft.Resources/templatespecs" } { 
                $RegionComment = "`nMove Microsoft.Resources resources to new region. https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/microsoft-resources-move-regions" 
                Continue
            }
            { $_ -match "^Microsoft.SaaS" } { 
                $Comment = "Marketplace offerings that are implemented through the Microsoft.Saas resource provider support resource group and subscription moves. These offerings are represented by the resources type below. For example, SendGrid is implemented through Microsoft.Saas and supports move operations. However, limitations defined in the move requirements checklist may limit the supported move scenarios. For example, you can't move the resources from a Cloud Solution Provider (CSP) partner.`nhttps://learn.microsoft.com/en-us/azure/azure-resource-manager/management/move-resource-group-and-subscription#checklist-before-moving-resources" 
                Continue
            }
            { $_ -match "^Microsoft.Search" } { 
                $Comment = "You can't move several Search resources in different regions in one operation. Instead, move them in separate operations." 
                Continue
            }
            { $_ -match "^Microsoft.Sql" } { 
                $Comment = "A database and server must be in the same resource group. When you move a SQL server, all its databases are also moved. This behavior applies to Azure SQL Database and Azure Synapse Analytics databases." 
                if ($_ -eq "Microsoft.Sql/managedinstances") {
                    $RegionComment = "`nLearn more about moving managed instances across regions. https://learn.microsoft.com/en-us/azure/azure-sql/database/move-resources-across-regions" 
                }
                if ($_ -eq "Microsoft.Sql/servers/databases") {
                    $RegionComment = "`nLearn more about moving databases across regions. https://learn.microsoft.com/en-us/azure/azure-sql/database/move-resources-across-regions`nLearn more about using Azure Resource Mover to move Azure SQL databases. https://learn.microsoft.com/en-us/azure/resource-mover/tutorial-move-region-sql"
                }
                if ($_ -eq "Microsoft.Sql/servers/elasticpools" ) {
                    $RegionComment = "`nLearn more about moving elastic pools across regions. https://learn.microsoft.com/en-us/azure/azure-sql/database/move-resources-across-regions`nLearn more about using Azure Resource Mover to move Azure SQL elastic pools. https://learn.microsoft.com/en-us/azure/resource-mover/tutorial-move-region-sql"
                }
                Continue
            }
            { $_ -eq "Microsoft.Storage/storageaccounts" } { 
                $RegionComment = "`nMove an Azure Storage account to another region. https://learn.microsoft.com/en-us/azure/storage/common/storage-account-move" 
                Continue
            }
            { $_ -match "^Microsoft.StreamAnalytics" } { 
                $Comment = "Stream Analytics jobs can't be moved when in running state." 
                Continue
            }
            { $_ -match "^Microsoft.VisualStudio" } { 
                $Comment = "To change the subscription for Azure DevOps, see change the Azure subscription used for billing.`nhttps://learn.microsoft.com/en-us/azure/devops/organizations/billing/change-azure-subscription?toc=/azure/azure-resource-manager/toc.json" 
                Continue
            }
            { $_ -match "^Microsoft.Web" } { 
                $Comment = "See App Service move guidance.`nhttps://learn.microsoft.com/en-us/azure/azure-resource-manager/management/move-limitations/app-service-move-limitations" 
                Continue
            }
        }
        $null = $ResArr.Add([PSCustomObject]@{
            "Name"              = $R.Name
            "ResourceType"      = $R.ResourceType
            "Location"          = $R.Location
            "SubID"             = (Get-AzSubscription | Where-Object { $_.Id -eq $R.SubscriptionID }).Name
            "ResourceGroupName" = $R.ResourceGroupName
            "MoveResourceGroup" = if ($lineItem."Move Resource Group" -eq 0) { "No$RGComment" }elseif ($lineItem."Move Resource Group" -eq 1) { "Yes$RGComment" }else { "N/A" }
            "MoveSubscription"  = if ($lineItem."Move Subscription" -eq 0) { "No$SubComment" }elseif ($lineItem."Move Subscription" -eq 1) { "Yes$SubComment" }else { "N/A" }
            "MoveRegion"        = if ($lineItem."Move Region" -eq 0) { "No$RegionComment" }elseif ($lineItem."Move Region" -eq 1) { "Yes$RegionComment" }else { "N/A" }
            "Comment"           = If ($Comment) { $Comment }else { "N/A" }
        })
        $RGComment = $SubComment = $RegionComment = $Comment = $null
    }
}
$ResArr | Export-Excel -Path $OutFile -WorksheetName 'ResourceMoveAnalysis' -TableStyle Medium16 -Title 'ResourceMoveAnalysis' -TitleBold