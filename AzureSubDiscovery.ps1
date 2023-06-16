<#
  .SYNOPSIS
  This is a read-only script used for Azure-to-Azure migrations.  It is not intended for use with any other type of migrations  
  (e.g., AWS-to-Azure, On-prem-to-Azure, etc.).
  
  This script does not make any changes to an Azure subscription.  The purpose is to discover the resources in one or
  more Azure subscriptions to assess the complexity of the environment and highlight any potential migration challenges.
  
  The script calls three PowerShell functions to gather resource information in one or more subscriptions.  The detailed resource output for 
  each subscription (sub) is sent to a text file in JSON format.  It is readable in any text editor (e.g., Notepad).


  .DIRECTIONS
  1.  Save the text version of the script with a .ps1 extension to your local system – you do not have to run this from a system in Azure.
  2.  Ensure you have a c:\temp folder on your system.
  3.  Open PowerShell, browse to the location of the saved script, and run AzureSubDiscovery.ps1.
  4.  Enter a username that has at least read-only permissions to the subscription(s) you want to gather info, and click Next.

      NOTE: If a subscription contains Classic Cloud Services, a second Login prompt will appear. The user account must have 
      'Co-Administrator' permissions (See the REQUIREMENTS section below for guidance).

  5.  Enter a password and click Sign-in.
  6.  Click a subscription or CTRL-CLICK to select multiple subscriptions, and then click OK.
  7.  Go to the C:\temp folder, and email the output file to your sales contact.


  .REQUIREMENTS
  * DO NOT run this script in the Azure Cloud Shell because it doesn't have the ability to output the discovery output file.  
  
  * If the source subscription(s) includes Classic Cloud Services, you must have the Co-Administrator role. 
    Browse to the link below for guidance on setting this access level.  

        https://docs.microsoft.com/en-us/azure/role-based-access-control/rbac-and-directory-admin-roles

  * Your PowerShell settings must be set to allow the running of scripts

    NOTE: If you receive an error stating, "AzureSubDiscovery.ps1 cannot be loaded because running scripts is disabled on this system", 
    run the two commands below to temporarily enable running scripts.

            Write-Host "Setting session scope to 'RemoteSigned'.  This setting is removed upon closing the PowerShell window." -ForegroundColor Cyan
            Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned -Force
           
  * Azure RM Module 5.7.0+ OR Azure Az 0.7.0+
  
  * PowerShell 5.1 or higher on Windows, or PowerShell 6 on any platform
    
    NOTE: If you are using PowerShell 5 on Windows, you also need .NET Framework 4.7.2 installed. 
    For instructions on updating or installing a new version of .NET Framework, see the .NET Framework installation guide at
    
        https://docs.microsoft.com/en-us/dotnet/framework/install . 

    Reference:
    https://docs.microsoft.com/en-us/powershell/azure/overview?view=Azps-6.13.0            
    
  
  .DESCRIPTION
  The script grants itself execute permissions if not explicitly granted. 
  
  The script checks to see if there are any older Az modules installed.  If so, the script executes normally.

  The script checks to see if Azure Az module is installed.  If so, it enables compatibility mode.

  If Az or Azure Az modules are not loaded, the script attempts to install the Azure Az module and enable
  compatibility mode.

  If the script detects Classic Cloud Services, it checks to see if the Azure module is installed.  If not, it installs the module.
  
  The script calls the four functions below.
    • Get-SourceSubs – This function generates a login-prompt and requests the user to pick one or more source subs.
    • Get-Resources – This function gathers all the resources in a sub and outputs them into a JSON-formatted text file in the output directory (by default C:\temp).
    • Get-SourceSummary - This function performs numerous checks including:
        o Discovers all resources in a sub.
        o Evaluates each resource group and skips those that are empty.
        o Evaluates Load Balancers to see if any are deployed under the STANDARD SKU.
        o Evaluates all VMs to see if any have 'Plan Info' and/or are deployed in an Availability zone.
        o Evaluates all Virtual Networks to see if any have vNet Peering enabled.
        o Evaluates all Public IP addresses to see if any are deployed under the STANDARD SKU.
        o Evaluates if there are any Classic Cloud Serivces.  If so, it notes if the deployments are empty, configured in a Web/Worker (PaaS) role, or configured in an IaaS Role.
    • Set-Header - This function creates the JSON-formatted output file and adds the header information.

            
  In the event the script encounters a Disabled subscription, it will skip gathering resources and move on.  


  .OUTPUT
  The script generates one output file similar to the one below:
    • Discovery_Output_v3_4_02042020T223543.json - This is a JSON-formatted text file that contains all the resource details found in the sub(s).
  
  
  .VERSION
  Version 3.5 Created 4/24/2020 by Kyle Rhynerson (kyle.rhynerson@techdata.com)
    Corrected line 610 to call the legacy Get-AzVirtualNetwork instead of the modern Get-AzVirtualNetwork.  This only impacted those still running the old Az Azure module.

  .DISCLAIMER
  Tech Data retains all rights, title and interest in any pre-existing materials and intellectual property that is owned by Tech Data. 
  Tech Data will provide to the Customer a limited and revocable license to use the pre-existing intellectual property utilized in providing Services as specified in the SOW.

#>

#Set Version #
$scriptVersion = '3_5'
$scriptRun = $false
$SubCounter = 0

If ((Get-ExecutionPolicy) -notmatch 'RemoteSigned') {
    Write-Host "Setting session scope to 'RemoteSigned'.  This setting is removed upon closing the PowerShell window." -ForegroundColor Cyan
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned -Force
}


#Check for Az PowerShell Module 
if (Get-InstalledModule -Name Az -AllVersions -ErrorAction SilentlyContinue) {
    Write-Host "`nAzure RM module(s) installed, running native script commands."-ForegroundColor Cyan
    
} 
else {
    Write-Host "`nNo Azure PowerShell modules installed!  Attempting to install Azure Az." -ForegroundColor Cyan
    Write-Host 'By default, PowerShell gallery is not configured as a trusted repository for PowerShellGet.' -ForegroundColor Cyan
    Write-Host "If you get a message about an 'Untrusted repository', click Yes or Yes to All." -ForegroundColor Yellow
    Install-Module -Name Az -AllowClobber -Scope CurrentUser
}


#Begin Get-SourceSubs Function Region

Function Get-SourceSubs
{ <#
  .SYNOPSIS
  Prompts for login credentials and allows the user to select one or more subscriptions upon which to perform resource discovery.

  .DESCRIPTION
  This advanced function runs Login-AzAccount, which pops up a window to input Azure credentials.

  It then generates a pop-up window showing all the subscriptions tied to the login account, and then prompts the user to select  
  one or more source subscriptions.

  The function outputs the $sourceSubs variable, which is an arry containing the name and subscription ID for all the selected subscriptions.
   
  .EXAMPLE
  Get-SourceSubs
  #>
    [CmdletBinding()]
    param ()
    Begin {
        Write-Host "`nLog-in with an account that can see the source subscription(s)." -ForegroundColor Yellow
        #Login-AzAccount -Environment AzureUSGovernment
    
        Login-AzAccount


    }

    Process {
        [array]$sourceSubs = @()
    
        Write-Host "When the pop-up window appears, click a subscription or CTRL-CLICK to select multiple subscriptions. Then click OK.`r`n" -ForegroundColor Yellow
        $sourceSubs = Get-AzSubscription | Select-Object Name, SubscriptionId, TenantId `
        | Out-GridView -OutputMode Multi -Title `
            'Click a subscription or CTRL-CLICK to select multiple subscriptions.  Then click the OK button (bottom right of window).'
    }

    End {
       
        $script:sourceSubs = $sourceSubs
    }
}

#End Get-SourceSubs Function Region

#Begin Get-Resources Function Region

Function Get-Resources
{
    <#
  .SYNOPSIS
  This advanced function gathers all the resources in a subscription.
  
  .DESCRIPTION
  This function executes the Get-AzResource cmdlet, which literally finds every resource
  in a subscription.  To make the data accessible for manipulation in a calling script, the 
  function creates a PSCustomObject and puts properties in for each resource.  Finally, it outputs 
  an array with all the objects.

  The function generates an output variable named $resources, that contains the information below.
    * Name -              The name of the resource.
    * ResourceId -        This is a long string that includes the subscription, resource group, provider,
                          and the type of resource. 
    * ResourceName -      This appears to be the same as the 'Name' value, but Azure includes it here, so
                          perhaps it could be different than the 'Name' in some cases.
    * ResourceType -      This is the type of resource (e.g., Microsoft.Compute/disks).
    * ResourceGroupName - Where the resource is stored.
    * Location -          What Azure location the resource is in (e.g., uksouth).
    * SubscriptionId -    The subscription that owns the resource

   The function optionally generates an output variable named $outputPresent and sets it to $true if it generated an output file.

   Finally, the function generates an output CSV file that contains the same information that is in the $resources variable.  It will be named
   something like "9fee63f4-c8ca-4182-b800-702b083ecd27_resources_04102018T131456.csv"
   
  .EXAMPLE
  Get-Resources -subId "9fee63f4-c8ca-4182-b800-702b083ecd27" -output "C:\temp"

  .PARAMETER subId
  This is the source subscription Id.

  .PARAMETER output
  This is the folder where we are outputting the results.
    
  #>
    [CmdletBinding()]
    param (
        [parameter(Position = 0,
            Mandatory = $true)]
        [string]$subId,

        [parameter(Position = 1,
            Mandatory = $true)]
        [string]$output
    )

    Begin {
        [System.Collections.ArrayList]$resources = @()
        $resourceCounter = 0

        Write-Verbose "Passed input 'subId' = $subId"
        Write-Verbose "Passed input 'output' = $output"

    }

    Process {
        $allResources = Get-AzResource 

        Write-Verbose "'allResources' = $allResources"
        
        if (!$allResources) {
            Write-Output "`n"

        }
        Else {
                    
            ForEach ($r in $allResources) {

                $eval = $r.Name
                Write-Verbose "Evaluating $eval"

                $resourceCounter++

                Write-Verbose "ResourceCounter set to $resourceCounter"

                $resource = "resource$resourceCounter"

                Write-Verbose "Resource Object Id set to $resource"

                $resource = [PSCustomObject]@{
                    Name              = $r.Name; 
                    ResourceId        = $r.ResourceId;
                    ResourceName      = $r.ResourceName;
                    ResourceType      = $r.ResourceType;
                    ResourceGroupName = $r.ResourceGroupName;
                    Location          = $r.Location;
                    SubscriptionId    = $r.SubscriptionId;
                }

                $resources += $resource

            }
                     
        }
    }

    End {
        if (!$allResources) {
            $script:resources = $resources

        }
        Else {

            Write-Output "`n    Discovered $resourceCounter resource(s)"
   
            $script:resources = $resources
            $script:outputPresent = $true
        }    

    }
}

#End Get-Resources Function Region


#Begin Get-SourceSummary Function Region

Function Get-SourceSummary {
    <#
  .SYNOPSIS
  This advanced function gathers summary information for a subscription.  
  
  .DESCRIPTION
  This function leverages the $resources output variable from the Get-Resources function, runs some additional discovery commands, and outputs the results
  into a JSON-formatted text file.
   
  .EXAMPLE
  Get-SourceSummary -subId $subId -subName $subName -output $outputDir -resources $resources

  .PARAMETER subId
  This is the source subscription Id (e.g., 9fee63f4-c8ca-4182-b800-702b083ecd27)

  .PARAMETER subName
  This is the source subscription Name (e.g., Visual Studio Enterprise – MPN).

  .PARAMETER tenantId
  This is the tenantId for the source subscription (e.g., 7004f8b7-5a8f-4a6f-b308-5aa32326ec9d)

  .PARAMETER outputDirFile
  This is the location and name of the output file where we the results are stored (e.g., C:\temp\Discovery_Output_04102018T131456.json)

  .PARAMETER resources
  This is an array contianing the results output from the Get-Resources funtion.

  .PARAMETER bypass
  This is a value to indicate if we've logged into the ASM toolset (if needed)
  
  #>
    [CmdletBinding()]
    param (
        [parameter(Position = 0,
            Mandatory = $true)]
        [string]$subId,

        [parameter(Position = 1,
            Mandatory = $true)]
        [string]$subName,

        [parameter(Position = 2,
            Mandatory = $true)]
        [string]$tenantId,

        [parameter(Position = 3,
            Mandatory = $true)]
        [string]$output,
    
        [parameter(Position = 4,
            Mandatory = $true)]
        [array]$resources,

        [parameter(Position = 5,
            Mandatory = $true)]
        [array]$bypass
    )
    Begin {

        $resourceCount = $resources.Count

        Write-Verbose "Total resources passed in from Get-Resources = $resourceCount"

    }

    Process {
        #Discovered Load Balancers
        $allLBs = Get-AzLoadBalancer
        $lbCounter = 0

        Write-Host "`n    Evaluating Load Balancers"

        foreach ($lb in $allLbs) {
            $lbname = $lb.Name
            Write-Host "`n        Evaluating $lbname Load Balancer"
            If ($lb.sku.Name -eq 'Standard') {
                $lbCounter ++
            }
        }

        If ($lbCounter.count -le 0) { $lbCounter = '0' }
        $dataLbs = $lbCounter

        #Evaluate Standard Sku Public IP Addresses
        #Instantiate a blank arry
        $piPips = @()
        $piWarning = $false

        #Set a counter to zero
        $pipCounter = 0

        #Get all Standard SKU Public IPs in the sub
        $standardSKkuPips = Get-AzPublicIpAddress | Select-Object -Property IpAddress, Name, ResourceGroupName, `
            PublicIpAllocationMethod, IpConfiguration, Sku | Where-Object { $_.Sku.Name -match 'Standard' }

    
        #Iterate through the VMs
        foreach ($pip in $standardSKkuPips) {
            $pipCounter++
            $mypip = "PublicIP$pipCounter"                     
                                       
            #Cast Pip info into an object for later recall
            $piPip = [PSCustomObject]@{
                ID       = $mypip;
                PIP_Name = $pip.Name; 
                RG_Name  = $pip.ResourceGroupName;
            }
            #Add the Pip info to the array
            $piPips += $piPip
                
            $TotalPiPips = $piPips.Count
        }
        $pipCounter = $piPips.count

        #Resource Group totals
        Write-Host "`n    Evaluating resource groups to filter out empty ones"
        $rgCounter = 0
        $dataRGs = Get-AzResourceGroup

        foreach ($rg in $dataRGs) {
            $rgName = $rg.ResourceGroupName
            $thisRg = Get-AzResource | Where-Object { $_.ResourceGroupName -eq "$rgName" }
            $thisRgCount = $thisRg.count
 
            Write-Host "`n        Evaluating $rgName resource group"

            If ($thisRgCount -gt 0) {
                If ($rgName -contains 'NetworkWatcherRG') {
                    Write-Host "            $rgName is a default Network Watcher RG, SKIPPPING"
                }
                Else {
                    $rgCounter ++
                }
            }
            Else {
                Write-Host "            $rgName is empty, SKIPPPING"
            }

        }
        Write-Host "`n    Total resource groups with resources = $rgCounter"

        $typeBucket = @()
        $typeTotal = $resources 
        $typeCounter = 0


        #Gather totals for each of the resource types
        $resourcesByTypes = $resources | Select-Object ResourceType | Sort-Object ResourceType -Unique

        Foreach ($type in $resourcesByTypes) {
            $typeItem = $typeTotal | Where-Object { $_.ResourceType -eq $type.ResourceType }
            #Write-Host $type "=" $typeItem.Count -ForegroundColor Cyan

            $typeCount = $typeItem | Measure-Object

            $typeCounter++
            $resCounter = "Resource$typeCounter"

            $typeInfo = [PSCustomObject]@{
                ID    = $resCounter;
                Name  = $type.ResourceType; 
                Total = $typeCount.Count;
            }

            $typeBucket += $typeInfo
        }

        # Check if VMs have plan info and/or is in an Availablity Zone, and if so output details
        #Instantiate a blank arry
        $piVMs = @()
        $azVMs = @()
        $piWarning = $false
        $TotalAzVMs = 0
        $TotalPiVMs = 0

        #Set a counter to zero
        $piCounter = 0
        $azCounter = 0

        #Get all VMs in the sub
        $allVMs = Get-AzVM

        Write-Host "`n    Evaluating VMs"

        #Iterate through the VMs
        foreach ($vm in $allVMs) {
            $thisVmName = $vm.Name
            Write-Host "`n        Evaluating $thisVmName VM"
            $thisVm = Get-AzVM -Name $vm.Name -ResourceGroupName $vm.ResourceGroupName
            If ($thisVm.plan -ne $nul) {
                $piCounter++

                $pi = "PlanInfoVM$piCounter"

                $osType = $thisVm.StorageProfile.OsDisk.OsType

                If ($thisVm.DiagnosticsProfile.BootDiagnostics.Enabled -match 'True') {
                    $bdState = 'Enabled'
                    $bdSa = $thisVm.DiagnosticsProfile.BootDiagnostics.StorageUri

                    $bdSAStrip = $bdSa.Split('/')[2]
                    $bdSaName = $bdSAStrip.Split('.')[0]
                }
                else {
                    $bdState = 'Disabled'
                    $bdSaName = 'Not set'
                }
                
                #Check if the image/SKU/Plan is still available, which is a requirement to deploy the VM in the target sub
                $vmLoc = $thisVm.Location
                $vmPublisher = $thisVM.Plan.Publisher
                $vmOffer = $thisVM.Plan.Product
                $vmPlan = $thisVM.Plan.Name

                Try { 
                    $getPlan = Get-AzVMImage -Location $vmLoc -PublisherName $vmPublisher -Offer $vmOffer -Skus $vmPlan -ErrorAction Stop
                    If ($getPlan.Skus -match $vmPlan) {
                        $planAvailable = 'Yes'
                    }
    
    
                }
                Catch {
                    If ($_ -match 'Artifact: VMImage was not found') {
                        Write-Host "`n        VMImage was not found" -ForegroundColor Red
                        $planAvailable = 'No'
                        $piWarning = $true

                    }
                    ElseIf ($_ -match "Publisher: $vmPublisher was not found") {
                        Write-Host "`n        Plan Publisher Not found!" -ForegroundColor Red
                        $planAvailable = 'No'
                        $piWarning = $true
                    }
                    Else {
                        Write-Host "`n        Error processing Get-AzVMImage request!" -ForegroundColor Red
                        $planAvailable = 'No'
                        $piWarning = $true
                    }
                }                
                                        
                #Cast VM info into an object for later recall
                $piVM = [PSCustomObject]@{
                    ID              = $pi;
                    VM_Name         = $thisVm.Name; 
                    VM_Loc          = $thisVm.Location; 
                    RG_Name         = $thisVm.ResourceGroupName;
                    Size            = $thisVm.HardwareProfile.VmSize;
                    OS_Type         = $osType;
                    Boot_Diag_State = $bdState;
                    Boot_Diag_SA    = $bdSaName;
                    Plan_Name       = $thisVM.Plan.Name;
                    Plan_Publisher  = $thisVM.Plan.Publisher;
                    Plan_Product    = $thisVM.Plan.Product;
                    Plan_Available  = $planAvailable;

                }
                #Add the VM w/ plan info to the array
                $piVMs += $piVM
            }
            $TotalPiVMs = $piVMs.Count


            If ($thisVm.Zones -ne $nul) {
                $azCounter++

                $az = "AvailabilityZoneVM$azCounter"

                
                #Cast VM info into an object for later recall
                $azVM = [PSCustomObject]@{
                    ID      = $az;
                    VM_Name = $thisVm.Name; 
                    VM_Loc  = $thisVm.Location; 
                    RG_Name = $thisVm.ResourceGroupName;
                    Zone    = $thisVm.Zones;

                }
                #Add the VM w/ plan info to the array
                $azVMs += $azVM
            }
            $TotalAzVMs = $azVms.Count

        }

        # Check for any Virtual networks where vNet peering is enabled
        $vNetCounter = 0
        $TotalVnets = 0

        #Instantiate a blank arry
        $vNetPeers = @()

        $getNetworks = Get-AzVirtualNetwork

        Write-Host "`n    Evaluating Virtual Networks for Peerings"

        foreach ($network in $getNetworks) {
            $vNetName = $network.name
            Write-Host "`n        Evaluating $vNetName vNet"

            If ($network.VirtualNetworkPeerings.Count -gt 0) {
                $vNetCounter++
                $vNet = "vNetPeer$vNetCounter"

                #Cast VM info into an object for later recall
                $vNetPeer = [PSCustomObject]@{
                    ID        = $vNet;
                    VNET_Name = $network.Name; 
                    RG_Name   = $network.ResourceGroupName;
                }
                #Add the VM w/ plan info to the array
                $vNetPeers += $vNetPeer
            }
        }
        $TotalVnets = $vNetPeers.Count

        # Check for Classic Cloud Services - ClassicCompute/domainNames
        $csSkip = $false
        $classicCsPaaS = $null
        $classicCsPaaSNames = $null

        $classicCloudServices = $resources | Where-Object { $_.ResourceType -eq 'Microsoft.ClassicCompute/domainNames' } | Measure-Object
        $classicCsCount = $classicCloudServices.Count

        If ($classicCsCount -gt 0) {
            Write-Host "`n    Discovered $classicCsCount Classic Cloud Services"
          
            $classicCsPaaS = 0
    
            #Put on the ASM "toolbelt"
            If ($asmLoginBypass -match $false) {
                #Check for Azure PowerShell Module to run Classic (ASM) cmdlets
                if (Get-InstalledModule -Name Azure -AllVersions -ErrorAction SilentlyContinue) {
                    Write-Host "`n    Classic (ASM) Azure PowerShell module installed, running native script cmdlets."-ForegroundColor Cyan
                }
                else {
                    Write-Host "`n    Classic (ASM) Azure PowerShell module NOT installed!  Attempting to install Azure module." -ForegroundColor Cyan
                    Write-Host '    By default, PowerShell gallery is not configured as a trusted repository for PowerShellGet.' -ForegroundColor Cyan
                    Write-Host "    If you get a message about an 'Untrusted repository', click Yes or Yes to All." -ForegroundColor Yellow
                    Install-Module -Name Azure -AllowClobber -Scope CurrentUser
                }
        
                Write-Host "`n    Generating a logon prompt for the Classic (ASM) cmdlets." -ForegroundColor yellow
                        
                Try { 
                    Add-AzureAccount -ErrorAction Stop
                    $asmLoginBypass = $true
                    $script:asmLoginBypass = $asmLoginBypass
                }
                Catch {
                    If ($_ -match 'No subscriptions are associated with the logged in account') {
                        Write-Host "`n        User account doesn't have co-administrator access - see script REQUIREMENTS section." -ForegroundColor Red
                        $classicCsCount = 'ERROR_unable to calculate'
                        $csSkip = $true
                    }
                }
            }

            If ($csSkip -inotmatch $true) {
                Try { 
                    #Set the context to the source subscription using the ASM "tool belt"
                    Select-AzureSubscription -SubscriptionId $subId -ErrorAction Stop
                    $asmProcess = $true
                }
                Catch {
                    If ($_ -match "doesn't exist") {
                        Write-Host '        Failed to select the ASM subscription context, so unable to evaluate Cloud Services' -ForegroundColor Red
                        $classicCsCount = 'ERROR_unable to calculate'
                        $asmProcess = $False
                    }
                }

                If ($asmProcess -match $true) {
                    $classicCloudServices = $resources | Where-Object { $_.ResourceType -eq 'Microsoft.ClassicCompute/domainNames' } 

                    foreach ($cs in $classicCloudServices) {
                        $serviceName = $cs.ResourceName

                        Write-Host "`n        Evaluating $serviceName Cloud Service"

                        Try { 
                            $deployment = Get-AzureDeployment -ServiceName $serviceName -ErrorAction Stop
                            $deploymentName = $deployment.DeploymentName
                        }
                        Catch {
                            If ($_ -match 'ResourceNotFound') {
                                Write-Host "            $serviceName is an empty deployment, SKIPPING"
                                $classicCsCount--
                                $rgCounter--
                                $csSkip = $true
                            }
                        }

                        If ($csSkip -inotmatch $true) {
                            Try {
                                $validate = Move-AzureService -Validate -ServiceName $serviceName `
                                    -DeploymentName $deploymentName -CreateNewVirtualNetwork -ErrorAction Stop
                                $validate.ValidationMessages
                            }
                            Catch {
                                If ($_ -match 'PaaS deployment') {
                                    Write-Host "        $serviceName is configured in a Web/Worker (PaaS) role"
                                    $classicCsPaaS ++
                            
                                    $classicCsPaaSNames = [string]::Concat($classicCsPaaSNames, '"')
                                    $classicCsPaaSNames = [string]::Concat($classicCsPaaSNames, $serviceName)
                                    $classicCsPaaSNames = [string]::Concat($classicCsPaaSNames, '", ')
                                                        
                                    $classicCsCount--
                                    $rgCounter--
                                }
                                ElseIf ($_ -match 'InternalError') {
                                    Write-Host "        Assuming $serviceName is configured in a Web/Worker (PaaS) role"
                                    $classicCsPaaS ++
                                
                                    $classicCsPaaSNames = [string]::Concat($classicCsPaaSNames, '"')
                                    $classicCsPaaSNames = [string]::Concat($classicCsPaaSNames, $serviceName)
                                    $classicCsPaaSNames = [string]::Concat($classicCsPaaSNames, '", ')
                                
                                    $classicCsCount--
                                    $rgCounter--
                                }
                                Else {
                                    Write-Host '    Detected an error, which means we were unable to validate the Classic Cloud Service.' -ForegroundColor red
                                    $classicCsCount = 'ERROR_unable to calculate'
                                    $_
                                }
                            }
                        }
                    }              
                }
                Else {
                    $classicCsCount = 'ERROR_unable to calculate'
                }
            }
        }

        If ($classicCsCount.count -le 0) { $classicCsCount = '0' }
        If ($classicCsPaaS.count -le 0) { $classicCsPaaS = '0' }
        If ($classicCsPaaSNames.count -le 0) {
            $classicCsPaaSNames = '0'
            $TotalclasicCsPaaSNames = '0'
        }
        Else {

            $classicCsPaaSNames = $classicCsPaaSNames.Substring(0, $classicCsPaaSNames.Length - 2)
         
            $clasicCsPaaSNamesString = '[ '
            $clasicCsPaaSNamesString = [string]::Concat($clasicCsPaaSNamesString, $classicCsPaaSNames)
            $clasicCsPaaSNamesString = [string]::Concat($clasicCsPaaSNamesString , ' ]')
        }

        $TotalclassicCs = $classicCsCount
        $TotalclasicCsPaaS = $classicCsPaaS
                
    }

    End {

        $dataRGs = $rgCounter

        #Output the summary information to a text file
        $summaryOutput = '       {'
        $summaryOutput = [string]::Concat($summaryOutput, "`r`n")
        $summaryOutput = [string]::Concat($summaryOutput, '       "SubName": "')
        $summaryOutput = [string]::Concat($summaryOutput, "$subname")
        $summaryOutput = [string]::Concat($summaryOutput, '"')
        $summaryOutput = [string]::Concat($summaryOutput, ",`r`n")
        $summaryOutput = [string]::Concat($summaryOutput, '       "SubId": "')
        $summaryOutput = [string]::Concat($summaryOutput, "$subId")
        $summaryOutput = [string]::Concat($summaryOutput, '"')
        $summaryOutput = [string]::Concat($summaryOutput, ",`r`n")
        $summaryOutput = [string]::Concat($summaryOutput, '       "TenantId": "')
        $summaryOutput = [string]::Concat($summaryOutput, "$tenantId")
        $summaryOutput = [string]::Concat($summaryOutput, '"')
        $summaryOutput = [string]::Concat($summaryOutput, ",`r`n")
        $summaryOutput = [string]::Concat($summaryOutput, '       "SubStatus"')
        $summaryOutput = [string]::Concat($summaryOutput, ': "Active"')
        $summaryOutput = [string]::Concat($summaryOutput, ",`r`n")
        $summaryOutput = [string]::Concat($summaryOutput, '       "ResourceGroups": "')
        $summaryOutput = [string]::Concat($summaryOutput, "$dataRgs")
        $summaryOutput = [string]::Concat($summaryOutput, '"')
        $summaryOutput = [string]::Concat($summaryOutput, ",`r`n")

        If ($dataLbs -gt 0) {

            #DEBUG
            #Write-Host "Writing LB info to file" -foreground DarkYellow

            $summaryOutput = [string]::Concat($summaryOutput, '       "Load_Balancers_STANDARD_SKU": "')
            $summaryOutput = [string]::Concat($summaryOutput, "$dataLbs")
            $summaryOutput = [string]::Concat($summaryOutput, '"')
            $summaryOutput = [string]::Concat($summaryOutput, ",`r`n")
        }

        If ($TotalclassicCs -gt 0) {

            #DEBUG
            #Write-Host "Writing IaaS ASM info to file" -foreground DarkYellow

            $summaryOutput = [string]::Concat($summaryOutput, '       "Classic_Cloud_Services_IaaS": "')
            $summaryOutput = [string]::Concat($summaryOutput, "$TotalclassicCs")
            $summaryOutput = [string]::Concat($summaryOutput, '"')
            $summaryOutput = [string]::Concat($summaryOutput, ",`r`n")
        }

        If ($TotalclasicCsPaaS -gt 0) {

            #DEBUG
            #Write-Host "Writing PaaS ASM info to file" -foreground DarkYellow

            $summaryOutput = [string]::Concat($summaryOutput, '       "Classic_Cloud_Services_PaaS": "')
            $summaryOutput = [string]::Concat($summaryOutput, "$TotalclasicCsPaaS")
            $summaryOutput = [string]::Concat($summaryOutput, '"')
            $summaryOutput = [string]::Concat($summaryOutput, ",`r`n")
            $summaryOutput = [string]::Concat($summaryOutput, '       "Classic_Cloud_Services_PaaSNames": ')
            $summaryOutput = [string]::Concat($summaryOutput, "$clasicCsPaaSNamesString")
            $summaryOutput = [string]::Concat($summaryOutput, ",`r`n")
        }

        $summaryOutput | Out-File "$summaryOut" -Append


        If ($TotalVnets -gt 0) {
    
            $outputVnet = '       "vNetPeers":['
    
            foreach ($outvnet in $vNetPeers) {
                #DEBUG
                #Write-Host "Writing PIP info to file" -foreground DarkYellow

                $outvnetName = $outvnet.VNET_Name 
                $outvnetRg = $outvnet.RG_Name 

                $outputVnet = [string]::Concat($outputVnet, "`n`r")
                $outputVnet = [string]::Concat($outputVnet, '         {')
                $outputVnet = [string]::Concat($outputVnet, '"VNET_Name": ')
                $outputVnet = [string]::Concat($outputVnet, '"')
                $outputVnet = [string]::Concat($outputVnet, $outvnetName)
                $outputVnet = [string]::Concat($outputVnet, '",')
                $outputVnet = [string]::Concat($outputVnet, "`n`r")
                $outputVnet = [string]::Concat($outputVnet, '          "RG_Name": ')
                $outputVnet = [string]::Concat($outputVnet, '"')
                $outputVnet = [string]::Concat($outputVnet, $outvnetRg) 
                $outputVnet = [string]::Concat($outputVnet, '"')
                $outputVnet = [string]::Concat($outputVnet, "`n`r")
                $outputVnet = [string]::Concat($outputVnet, '         },')
            }
        
            $outputVnetClean = $outputVnet.Substring(0, $outputVnet.Length - 1)

            $outputVnetFooter = $outputVnetClean
            $outputVnetFooter = [string]::Concat($outputVnetFooter, "`n`r")
            $outputVnetFooter = [string]::Concat($outputVnetFooter, '       ],')

            $outputVnetFooter | Out-File "$summaryOut" -Append
        }



        If ($pipCounter -gt 0) {

            $pipOutput = '       "PublicIPs":['
    
            foreach ($outputpip in $piPips) {
                #DEBUG
                #Write-Host "Writing PIP info to file" -foreground DarkYellow

                $outPipName = $outputpip.PIP_Name 
                $outPipRg = $outputpip.RG_Name 

                $pipOutput = [string]::Concat($pipOutput, "`n`r")
                $pipOutput = [string]::Concat($pipOutput, '         {')
                $pipOutput = [string]::Concat($pipOutput, '"PIP_Name": ')
                $pipOutput = [string]::Concat($pipOutput, '"')
                $pipOutput = [string]::Concat($pipOutput, $outPipName)
                $pipOutput = [string]::Concat($pipOutput, '",')
                $pipOutput = [string]::Concat($pipOutput, "`n`r")
                $pipOutput = [string]::Concat($pipOutput, '          "RG_Name": ')
                $pipOutput = [string]::Concat($pipOutput, '"')
                $pipOutput = [string]::Concat($pipOutput, $outPipRg) 
                $pipOutput = [string]::Concat($pipOutput, '"')
                $pipOutput = [string]::Concat($pipOutput, "`n`r")
                $pipOutput = [string]::Concat($pipOutput, '         },')
            }
        
            $pipOutputClean = $pipOutput.Substring(0, $pipOutput.Length - 1)

            $pipOutputFooter = $pipOutputClean
            $pipOutputFooter = [string]::Concat($pipOutputFooter, "`n`r")
            $pipOutputFooter = [string]::Concat($pipOutputFooter, '       ],')

            $pipOutputFooter | Out-File "$summaryOut" -Append
        }


        If ($TotalAzVMs -gt 0) {
            $azOutput = '       "AvailibilityZoneVMs":['
     
            foreach ($outputaz in $azVMs) {
        
                #DEBUG
                #Write-Host "Writing AZ info to file" -foreground DarkYellow
        
                $azoutputName = $outputaz.VM_Name 
                $azoutputLoc = $outputaz.VM_Loc
                $azoutputRg = $outputaz.RG_Name
                $azoutputZone = $outputaz.Zone

                $azOutput = [string]::Concat($azOutput, "`n`r")
                $azOutput = [string]::Concat($azOutput, '         {')
                $azOutput = [string]::Concat($azOutput, "`n`r")
                $azOutput = [string]::Concat($azOutput, '         "VM_Name": ')
                $azOutput = [string]::Concat($azOutput, '"')
                $azOutput = [string]::Concat($azOutput, $azoutputName)
                $azOutput = [string]::Concat($azOutput, '",')
                $azOutput = [string]::Concat($azOutput, "`n`r")
                $azOutput = [string]::Concat($azOutput, '         "VM_Loc": ')
                $azOutput = [string]::Concat($azOutput, '"')
                $azOutput = [string]::Concat($azOutput, $azoutputLoc) 
                $azOutput = [string]::Concat($azOutput, '",')
                $azOutput = [string]::Concat($azOutput, "`n`r")
                $azOutput = [string]::Concat($azOutput, '         "RG_Name": ')
                $azOutput = [string]::Concat($azOutput, '"')
                $azOutput = [string]::Concat($azOutput, $azoutputRg) 
                $azOutput = [string]::Concat($azOutput, '",')
                $azOutput = [string]::Concat($azOutput, "`n`r")
                $azOutput = [string]::Concat($azOutput, '         "Zone": ')
                $azOutput = [string]::Concat($azOutput, '"')
                $azOutput = [string]::Concat($azOutput, $azoutputZone) 
                $azOutput = [string]::Concat($azOutput, '"')
                $azOutput = [string]::Concat($azOutput, "`n`r")
                $azOutput = [string]::Concat($azOutput, '         },')
            }    
        
            $azOutputClean = $azOutput.Substring(0, $azOutput.Length - 1)

            $azOutputFooter = $azOutputClean
            $azOutputFooter = [string]::Concat($azOutputFooter, "`n`r")
            $azOutputFooter = [string]::Concat($azOutputFooter, '       ],')

            $azOutputFooter | Out-File "$summaryOut" -Append
        } 


        If ($TotalPiVMs -gt 0) {
            $piOutput = '       "PlanInfoVMs":['       

            foreach ($outputpi in $piVMs) {
        
                #DEBUG
                #Write-Host "Writing Plan info to file" -foreground DarkYellow

                $pioutputName = $outputpi.VM_Name 
                $pioutputLoc = $outputpi.VM_Loc
                $pioutputRg = $outputpi.RG_Name
                $pioutputSize = $outputpi.Size
                $pioutputOS = $outputpi.OS_Type
                $pioutputBdState = $outputpi.Boot_Diag_State
                $pioutputBdSa = $outputpi.Boot_Diag_SA
                $pioutputPlanName = $outputpi.Plan_Name 
                $pioutputPlanPublisher = $outputpi.Plan_Publisher
                $pioutputPlanProduct = $outputpi.Plan_Product 
                $pioutputPlanAvailable = $outputpi.Plan_Available 

                $piOutput = [string]::Concat($piOutput, "`n`r")
                $piOutput = [string]::Concat($piOutput, '         {')
                $piOutput = [string]::Concat($piOutput, "`n`r")
                $piOutput = [string]::Concat($piOutput, '         "VM_Name": ')
                $piOutput = [string]::Concat($piOutput, '"')
                $piOutput = [string]::Concat($piOutput, $pioutputName)
                $piOutput = [string]::Concat($piOutput, '",')
                $piOutput = [string]::Concat($piOutput, "`n`r")
                $piOutput = [string]::Concat($piOutput, '         "VM_Loc": ')
                $piOutput = [string]::Concat($piOutput, '"')
                $piOutput = [string]::Concat($piOutput, $pioutputLoc) 
                $piOutput = [string]::Concat($piOutput, '",')
                $piOutput = [string]::Concat($piOutput, "`n`r")
                $piOutput = [string]::Concat($piOutput, '         "VM_Size": ')
                $piOutput = [string]::Concat($piOutput, '"')
                $piOutput = [string]::Concat($piOutput, $pioutputSize) 
                $piOutput = [string]::Concat($piOutput, '",')
                $piOutput = [string]::Concat($piOutput, "`n`r")
                $piOutput = [string]::Concat($piOutput, '         "VM_OS": ')
                $piOutput = [string]::Concat($piOutput, '"')
                $piOutput = [string]::Concat($piOutput, $pioutputOS) 
                $piOutput = [string]::Concat($piOutput, '",')
                $piOutput = [string]::Concat($piOutput, "`n`r")
                $piOutput = [string]::Concat($piOutput, '         "RG_Name": ')
                $piOutput = [string]::Concat($piOutput, '"')
                $piOutput = [string]::Concat($piOutput, $pioutputRg) 
                $piOutput = [string]::Concat($piOutput, '",')
                $piOutput = [string]::Concat($piOutput, "`n`r")
                $piOutput = [string]::Concat($piOutput, '         "Boot_Diag_State": ')
                $piOutput = [string]::Concat($piOutput, '"')
                $piOutput = [string]::Concat($piOutput, $pioutputBdState) 
                $piOutput = [string]::Concat($piOutput, '",')
                $piOutput = [string]::Concat($piOutput, "`n`r")
                $piOutput = [string]::Concat($piOutput, '         "Boot_Diag_SA": ')
                $piOutput = [string]::Concat($piOutput, '"')
                $piOutput = [string]::Concat($piOutput, $pioutputBdSa) 
                $piOutput = [string]::Concat($piOutput, '",')
                $piOutput = [string]::Concat($piOutput, "`n`r")
                $piOutput = [string]::Concat($piOutput, '         "Plan_Name": ')
                $piOutput = [string]::Concat($piOutput, '"')
                $piOutput = [string]::Concat($piOutput, $pioutputPlanName) 
                $piOutput = [string]::Concat($piOutput, '",')
                $piOutput = [string]::Concat($piOutput, "`n`r")
                $piOutput = [string]::Concat($piOutput, '         "Plan_Publisher": ')
                $piOutput = [string]::Concat($piOutput, '"')
                $piOutput = [string]::Concat($piOutput, $pioutputPlanPublisher) 
                $piOutput = [string]::Concat($piOutput, '",')
                $piOutput = [string]::Concat($piOutput, "`n`r")
                $piOutput = [string]::Concat($piOutput, '         "Plan_Product": ')
                $piOutput = [string]::Concat($piOutput, '"')
                $piOutput = [string]::Concat($piOutput, $pioutputPlanProduct) 
                $piOutput = [string]::Concat($piOutput, '",')
                $piOutput = [string]::Concat($piOutput, "`n`r")
                $piOutput = [string]::Concat($piOutput, '         "Plan_Available": ')
                $piOutput = [string]::Concat($piOutput, '"')
                $piOutput = [string]::Concat($piOutput, $pioutputPlanAvailable) 
                $piOutput = [string]::Concat($piOutput, '"')
                $piOutput = [string]::Concat($piOutput, "`n`r")
                $piOutput = [string]::Concat($piOutput, '         },')

            }         
            $piOutputClean = $piOutput.Substring(0, $piOutput.Length - 1)

            $piOutputFooter = $piOutputClean
            $piOutputFooter = [string]::Concat($piOutputFooter, "`n`r")
            $piOutputFooter = [string]::Concat($piOutputFooter, '       ],')

            $piOutputFooter | Out-File "$summaryOut" -Append    

        }    


        If ($typeBucket.count -gt 0) {
            $outputCounter = 0
            $resOutput = '       "Resources":['       

            #DEBUG
            #Write-Host "Writing Resource info to file" -foreground DarkYellow

            foreach ($outputRes in $typeBucket) {
                $outputCounter++
                $resOutputType = $outputRes.Name
                $resOutputTotal = $outputRes.Total 

                $resOutput = [string]::Concat($resOutput, "`n`r")
                $resOutput = [string]::Concat($resOutput, '         {')
                $resOutput = [string]::Concat($resOutput, "`n`r")
                $resOutput = [string]::Concat($resOutput, '         "Resource_Type": ')
                $resOutput = [string]::Concat($resOutput, '"')
                $resOutput = [string]::Concat($resOutput, $resOutputType)
                $resOutput = [string]::Concat($resOutput, '",')
                $resOutput = [string]::Concat($resOutput, "`n`r")
                $resOutput = [string]::Concat($resOutput, '         "Resource_Total": ')
                $resOutput = [string]::Concat($resOutput, '"')
                $resOutput = [string]::Concat($resOutput, $resOutputTotal) 
                $resOutput = [string]::Concat($resOutput, '"')
                $resOutput = [string]::Concat($resOutput, "`n`r")
                $resOutput = [string]::Concat($resOutput, '          },')
            }         

            $resOutputClean = $resOutput.Substring(0, $resOutput.Length - 1)

            $resOutputFooter = $resOutputClean
            $resOutputFooter = [string]::Concat($resOutputFooter, "`n`r")
            $resOutputFooter = [string]::Concat($resOutputFooter, '         ]')

            $resOutputFooter | Out-File "$summaryOut" -Append    

            #Add sub counter check so can end this Subscription block
            If ($SubCounter -eq $sourceSubs.count) {
                #DEBUG
                #Write-host "Writing end bracket to end current sub, no more subs left" -ForegroundColor DarkYellow
                    
                $resend = "`n`r         }"
                $resend | Out-File "$summaryOut" -Append                     

            }
            Else {
                #DEBUG
                #Write-host "Writing end bracket to current sub, there are one or more subs left" -ForegroundColor DarkYellow
                $resend = "`n`r         },"
                $resend | Out-File "$summaryOut" -Append                      
            }

        }

        Write-Output "`n    Output subscription summary details to $summaryOut"

    }
}

#End Get-SourceSummary Function Region

#Start Set-Header Function Region

Function Set-Header
{
    <#
  .SYNOPSIS
  This advanced function generates the otuput file and the header information.
  
  .DESCRIPTION
  This function checks to see if the output file with initial header informaiton was created.  
  If not, it generates the file.

  The function generates an output variable named $resources, that contains the information below.
       
  .EXAMPLE
  Set-Header

  .PARAMETER output
  This is the folder where we are outputting the results.
    
 #>
    [CmdletBinding()]
    param ()
    Begin {}
    Process {

        #Create output file and set header info for first time run through of script
        If ($scriptRun -eq $false) {
            $summaryStart = "{`n`r"
            $summaryStart = [string]::Concat($summaryStart, '     "Subscriptions": [')
            $summaryStart = [string]::Concat($summaryStart, "`n`r")
            $summaryStart | Out-File "$summaryOut" -Append
            $scriptRun = $true 
            $script:scriptRun = $scriptRun 
        }
    }
    End {}
}

#End Set-Header FUnction Regions

## Execute the various functions to analyze the source subscription(s).
#Set Output directory
$outputDir = 'C:\temp'
$outputPresent = $false


#Call the function to get the source subscription(s)
Get-SourceSubs 

#Generate a unique output file name based on the date/time
$timeStamp = (Get-Date -Format MMddyyyyTHHmmss)
$summaryOut = $outputDir + '\' + 'Discovery_Output_v' + $scriptVersion + '_' + $timeStamp + '.json'

#Set Login bypass to false
$asmLoginBypass = $false

#Iterate through the selected subcription(s)
Foreach ($sub in $sourceSubs) {

    $subCounter ++
    $script:SubCounter = $subCounter

    $subId = $sub.subscriptionId
    $subName = $sub.Name
    $tenantId = $subDetails.TenantId

    $subDetails = Get-AzSubscription -SubscriptionId $subId
                   
    $subStatus = $subDetails.State

    #Check to see if the Sub is disabled, if so skip it
    If ($subStatus -eq 'Disabled') {
    
        #Call Function to generate the output file and header
        Set-Header
    
        #DEBUG
        #Write-Host "Writing Disabled sub info to file" -foreground DarkYellow
    
        Write-Host "`n"
        Write-Warning "Sub ID $subId is disabled, skipping detailed inventory`r`n"

        $summaryOutput = '       {'
        $summaryOutput = [string]::Concat($summaryOutput, "`r`n")
        $summaryOutput = [string]::Concat($summaryOutput, '       "SubName": "')
        $summaryOutput = [string]::Concat($summaryOutput, "$subname")
        $summaryOutput = [string]::Concat($summaryOutput, '"')
        $summaryOutput = [string]::Concat($summaryOutput, ",`r`n")
        $summaryOutput = [string]::Concat($summaryOutput, '       "SubId": "')
        $summaryOutput = [string]::Concat($summaryOutput, "$subId")
        $summaryOutput = [string]::Concat($summaryOutput, '"')
        $summaryOutput = [string]::Concat($summaryOutput, ",`r`n")
        $summaryOutput = [string]::Concat($summaryOutput, '       "TenantId": "')
        $summaryOutput = [string]::Concat($summaryOutput, "$tenantId")
        $summaryOutput = [string]::Concat($summaryOutput, '"')
        $summaryOutput = [string]::Concat($summaryOutput, ",`r`n")
        $summaryOutput = [string]::Concat($summaryOutput, '       "SubStatus"')
        $summaryOutput = [string]::Concat($summaryOutput, ': "Subscription_Disabled"')
        $summaryOutput = [string]::Concat($summaryOutput, "`r`n")


        If ($SubCounter -eq $sourceSubs.count) {
            #No more subs, so close out subscription key
            $summaryOutput = [string]::Concat($summaryOutput, '       }')
        }
        Else {
            #More subs, so just close out this subscription and put a comma
            $summaryOutput = [string]::Concat($summaryOutput, '       },')
        }
            
        $summaryOutput | Out-File "$summaryOut" -Append

    }
    Else {
    
        $totalSubs = $sourceSubs.count
     
        #Set the context to the current subscription under evaluation  
        $context = Set-AzContext -SubscriptionId $subId
        Write-Host "`nProcessing Sub $subCounter of $totalSubs subs" -foreground cyan
        Write-Host "Azure cmdlet working context set to SubId $subId" -foreground cyan
    
        Write-Output $context

        $tenantId = $context.Tenant.Id
    
        #Call the function to get the resource details
        Get-Resources -subId $subId -output $outputDir
        
        #Check to see if the sub had any resources before running the summary function
        if ($resources.Count -lt 1) {
            #Call Function to generate the output file and header
            Set-Header
            
            #DEBUG
            #Write-Host "Writing sub w/ no resoruces to file" -foreground DarkYellow
            
            Write-Output "`n"
            Write-Warning "Sub ID $subId contains no resources, skipping detailed inventory"

            $summaryOutput = '       {'
            $summaryOutput = [string]::Concat($summaryOutput, "`r`n")
            $summaryOutput = [string]::Concat($summaryOutput, '       "SubName": "')
            $summaryOutput = [string]::Concat($summaryOutput, "$subname")
            $summaryOutput = [string]::Concat($summaryOutput, '"')
            $summaryOutput = [string]::Concat($summaryOutput, ",`r`n")
            $summaryOutput = [string]::Concat($summaryOutput, '       "SubId": "')
            $summaryOutput = [string]::Concat($summaryOutput, "$subId")
            $summaryOutput = [string]::Concat($summaryOutput, '"')
            $summaryOutput = [string]::Concat($summaryOutput, ",`r`n")
            $summaryOutput = [string]::Concat($summaryOutput, '       "TenantId": "')
            $summaryOutput = [string]::Concat($summaryOutput, "$tenantId")
            $summaryOutput = [string]::Concat($summaryOutput, '"')
            $summaryOutput = [string]::Concat($summaryOutput, ",`r`n")
            $summaryOutput = [string]::Concat($summaryOutput, '       "SubStatus"')
            $summaryOutput = [string]::Concat($summaryOutput, ': "Subscription_Has_No_Resources"')
            $summaryOutput = [string]::Concat($summaryOutput, "`r`n")

            If ($SubCounter -eq $sourceSubs.count) {
                #No more subs, so close out subscription key
                $summaryOutput = [string]::Concat($summaryOutput, '       }')

            }
            Else {
                #More subs, so just close out this subscription and put a comma
                $summaryOutput = [string]::Concat($summaryOutput, '       },')
            }

            $summaryOutput | Out-File "$summaryOut" -Append
            
        }
        Else {
            #Call Function to generate the output file and header
            Set-Header
            
            #Call function to get resoruces 
            Get-SourceSummary -subId $subId -subName $subName -tenantId $tenantId -output $summaryOut -resources $resources -bypass $asmLoginBypass
        }
    } 
}


#Add a footer to close out the JSON file
#DEBUG
#Write-Host "Writing footer info to file" -foreground DarkYellow

$footer = "`r`n"
$footer = [string]::Concat($footer, '        ]')
$footer = [string]::Concat($footer, "`r`n")
$footer = [string]::Concat($footer, '}')
$footer | Out-File "$summaryOut" -Append

#Cleanup output file by removing empty lines
(Get-Content $summaryOut) | Where-Object { $_.trim() -ne '' } | Set-Content $summaryOut

Write-Host "`nFinished evaluating subscription(s).  Please send the $summaryOut file to your sales contact." -ForegroundColor Cyan