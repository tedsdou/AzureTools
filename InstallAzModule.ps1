<#PSScriptInfo

.VERSION 1.6

.GUID 70e6f41b-5941-4ec7-b797-60b96a301319

.AUTHOR Ted Sdoukos

.COMPANYNAME

.COPYRIGHT

.TAGS AzureAutomation,Runbook

.LICENSEURI

.PROJECTURI

.ICONURI

.EXTERNALModuleDEPENDENCIES 

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES
v1.6 Changelog
    *Corrected bug from v1.5 
        *Missing $All and $Wait Parameter definitions in Install-AzAutomationModule

.PRIVATEDATA

#>

<#
.SYNOPSIS
Installs Az Modules to automation account.

.DESCRIPTION
This Azure Automation runbook installs the Az Modules selected into an
Azure Automation account with the Module versions published to the PowerShell Gallery.
Prerequisite: an Azure Automation account with an Azure Run As account credential.

.PARAMETER ResourceGroupName
The Azure resource group name.

.PARAMETER AutomationAccountName
The Azure Automation account name.

.PARAMETER All
This will install the Az Module and all dependancies.

.PARAMETER AzModule
This will install selected Module and dependancies.

.PARAMETER Wait
This will wait for the install of each Module.

.NOTES
Credit to: https://stackoverflow.com/questions/60847861/how-to-import-Modules-into-azure-automation-account-using-powershell
Credit to: https://github.com/microsoft/AzureAutomation-Account-Modules-Update
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory)]$ResourceGroupName,
    [Parameter(Mandatory)]$AutomationAccountName,
    [string]$AzModule,
    [string]$ModuleVersion,
    [bool]$All,
    [bool]$Wait
)
#region Functions
Function Get-AzModuleInfo {
    [CmdletBinding()]
    Param(
        $ModuleName,
        $PsGalleryApiUrl
        )
    Write-Verbose -Message "Finding Module information for $ModuleName within Get-AzModuleInfo"
    $ModuleUrlFormat = "$PsGalleryApiUrl/Search()?`$filter={1}&searchTerm=%27{0}%27&targetFramework=%27%27&includePrerelease=false&`$skip=0&`$top=40"
    $CurrentModuleURL = $ModuleUrlFormat -f $ModuleName, 'IsLatestVersion'
    Write-Verbose -Message $CurrentModuleURL
    $SearchID = Invoke-RestMethod -Method Get -Uri $CurrentModuleURL -UseBasicParsing | 
    Where-Object -FilterScript { $_.Title.InnerText -eq $ModuleName }
    Invoke-RestMethod -Method Get -UseBasicParsing -Uri $SearchID.id
}

Function Get-AzModuleDependency {
    [CmdletBinding()]
    Param($ModuleName)
    Write-Verbose -Message "Finding Dependent Modules for $ModuleName from within Get-AzModuleDependency"
    $Output = (Get-AzModuleInfo -ModuleName $ModuleName -PsGalleryApiUrl $PsGalleryApiUrl).entry.properties.Dependencies
    if ($Output) {
        ($Output -split '\|' | ForEach-Object { $_ -replace ':.*:' }).Trim()
    }
}

Function Install-AzModuleDependency {
    [CmdletBinding()]
    Param(
        $ModuleName,
        $ModuleVersion,
        $PsGalleryApiUrl
    )
    foreach ($M in $ModuleName) {
        Write-Verbose -Message "Calling Get-AzModuleInfo for module $M"
        $Module = (Get-AzModuleInfo -ModuleName $M -PsGalleryApiUrl $PsGalleryApiUrl).Entry.Properties
        If ($ModuleVersion) {
            $Link = "$PsGalleryApiUrl/package/$($Module.id)/$($Module.Version)"
        }
        else {
            $Link = "$PsGalleryApiUrl/package/$($Module.id)"
        }
        # Find the actual blob storage location of the Module
        do {
            $Link = (Invoke-WebRequest -Uri $Link -MaximumRedirection 0 -UseBasicParsing -ErrorAction Ignore).Headers.Location 
        } until ($Link.Contains('.nupkg'))
        $Status = Get-AzureRmAutomationModule -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName -Name $Module.id -ErrorAction SilentlyContinue

        If ( (-Not($Status)) -or ($Status.Version -ne $Module.Version)) {
            Write-Verbose -Message "Currently installing the $($Module.id) - Version-$($Module.version) dependency"
            $null = New-AzureRmAutomationModule -AutomationAccountName $AutomationAccountName -Name $Module.id -ContentLink $Link -ResourceGroupName $ResourceGroupName
            Do {
                $State = Get-AzureRmAutomationModule -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name $Module.id
                Start-Sleep -Seconds 1
                Write-Verbose -Message "Waiting on install of $($Module.id)"
                Write-Progress -Activity "Installing $($Module.id)" -Status "Current Status is: $($state.ProvisioningState)"
            }
            While ($state.ProvisioningState -eq 'Creating')
        }
        If ($state.ProvisioningState -eq 'Failed') { Throw "Unable to install $($Module.id)" }
        While ($state.ProvisioningState -ne 'Succeeded') {
            $State = Get-AzureRmAutomationModule -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name $Module.id
            Start-Sleep -Seconds 1
        }
        If ($state.ProvisioningState -eq 'Succeeded') { 
            Write-Progress -Activity "Installing $($Module.id)" -Status "Current Status is: $($state.ProvisioningState)"
            Write-Verbose -Message "Installation of $($Module.id) successful" 
        }
    }
}

Function Install-AzAutomationModule {
    <#
    .Synopsis
        Installs Az Modules in your azure automation account
    .DESCRIPTION
        Intalls the Az Modules selected into your desired automation account.  This will search for and install any Dependent Modules as well.
    .EXAMPLE
        Install-AzAutomationModule -ResourceGroupName 'ContosoResourceGroup' -AutomationAccountName 'ContosoAutomationAccount' -All

        This example will install the Az Module along with latest versions of Dependent Modules.
    .EXAMPLE
        Install-AzAutomationModule -ResourceGroupName 'ContosoResourceGroup' -AutomationAccountName 'ContosoAuto1' -AzModule 'Az.Blueprint'

        This example will install the Az.Blueprint Module along with latest versions of any Dependent Modules.
    .NOTES
        Author: Ted Sdoukos
        Credit to: https://stackoverflow.com/questions/60847861/how-to-import-Modules-into-azure-automation-account-using-powershell
        Credit to: https://github.com/microsoft/AzureAutomation-Account-Modules-Update
        REQUIREMENTS: AzureRM Automation Module or Az.Automation Module with aliases enabled.
    #>
    [CmdletBinding()]
    Param(
        $AzModule,
        $ResourceGroupName,
        $AutomationAccountName,
        $All,
        $Wait
    )

    If ($All) {
        $AzModule = 'Az'
    }
    $DepList = New-Object -TypeName System.Collections.ArrayList
    $List = New-Object -TypeName System.Collections.ArrayList
    Write-Verbose -Message "Finding Dependent modules for $AzModule"
    Get-AzModuleDependency -ModuleName $AzModule | ForEach-Object {
        $null = $List.Add($_)
    }
    Write-Verbose -Message "Current value of List is: $List | AzModule: $AzModule"
    foreach ($Item in $List) {
        Get-AzModuleDependency -ModuleName $Item | ForEach-Object {
            If ($DepList -notcontains $_) {
                $null = $DepList.Add($_)
            }
        }
    }
    Write-Verbose -Message "List = $List`r`nDepList = $DepList"
    If ($List -and -not $DepList) {
        $List | ForEach-Object { $null = $DepList.Add($_) }
    }
    $null = $List.Add($AzModule)
    If ($List -contains 'Az') {
        $null = $List.Remove('Az')
    }
    $AzModule = $List
    Write-Verbose -Message "FINAL Dependent List:`n$DepList"
   
    If ($DepList) { Install-AzModuleDependency -ModuleName $DepList -PsGalleryApiUrl $PsGalleryApiUrl }
    $AzModule | ForEach-Object {
        if (($_) -notin $DepList) {
            $InstallState = Get-AzureRmAutomationModule -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName -Name $_ -ErrorAction SilentlyContinue
            If (($InstallState.ProvisioningState -ne 'Succeeded') -or (-not($InstallState))) {
                $Module = (Get-AzModuleInfo -ModuleName $_ -PsGalleryApiUrl $PsGalleryApiUrl).Entry.Properties
                If ($ModuleVersion) {
                    $Link = "$PsGalleryApiUrl/package/$($_)/$($Module.Version)"
                }
                else {
                    $Link = "$PsGalleryApiUrl/package/$($_)"
                }
                do {
                    $TryCount = 0
                    $Link = (Invoke-WebRequest -Uri $Link -MaximumRedirection 0 -UseBasicParsing -ErrorAction Ignore).Headers.Location 
                    $TryCount++
                } until ($Link.Contains('.nupkg') -or $TryCount -gt 10)
                
                $ModName = $Module.Id
                Write-Verbose -Message "Currently installing $ModName"
                Write-Progress -Activity "Installing $ModName"
                $null = New-AzureRmAutomationModule -AutomationAccountName $AutomationAccountName -Name $ModName -ContentLink $Link -ResourceGroupName $ResourceGroupName
                If ($Wait) {
                    Do {
                        $Status = Get-AzureRmAutomationModule -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name $_ 
                        Start-Sleep -Seconds 1
                    }
                    While ($Status.ProvisioningState -eq 'Creating')
                    Write-Verbose -Message "Provisioning of $_ is complete.  Current Status is $($Status.ProvisioningState)"
                }
                #Added a sleep in here to alleviate errors
                # Most common error: Index was out of range. Must be non-negative and less than the size of the collection.
                Start-Sleep -Seconds 2
            }
        }
    }
    $AzModule | ForEach-Object {
        Get-AzureRmAutomationModule -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name $_ |
        Select-Object -Property Name, ProvisioningState
    }
}

function Connect-AzureAutomation {
    try {
        $RunAsConnection = Get-AutomationConnection -Name 'AzureRunAsConnection'
        $RunAsConnection | Select-Object -Property *
        Write-Verbose -Message "Logging in to Azure ($AzureEnvironment)..."
        
        if (!$RunAsConnection.ApplicationId) {
            $ErrorMessage = "Connection 'AzureRunAsConnection' is incompatible type."
            throw $ErrorMessage            
        }
        Add-AzureRmAccount -ServicePrincipal -TenantId $RunAsConnection.TenantId -ApplicationId $RunAsConnection.ApplicationId `
            -CertificateThumbprint $RunAsConnection.CertificateThumbprint 

        Select-AzureRmSubscription -SubscriptionId $RunAsConnection.SubscriptionID | Write-Verbose
    }
    catch {
        if (!$RunAsConnection) {
            $_.Exception
            $ErrorMessage = "Connection 'AzureRunAsConnection' not found."
            throw $ErrorMessage
        }

        throw $_.Exception
    }
}
#EndRegion Functions

#region main script
$PsGalleryApiUrl = 'https://www.powershellgallery.com/api/v2'
If (Get-Module -Name Az.Automation -ListAvailable) {
    Try { Enable-AzureRmAlias }catch {}
}
$null = Connect-AzureAutomation 
Write-Verbose -Message "Bound Params: rgName - $ResourceGroupName`n`rauName: $AutomationAccountName`n`rModule: $AzModule"
Install-AzAutomationModule @PSBoundParameters
$failCheck = Get-AzureRmAutomationModule -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName | 
Where-Object -FilterScript { $_.ProvisioningState -eq 'Failed' }
If ($failCheck) {
    Write-Warning -Message "The following Modules failed to install: $($failCheck.Name | ForEach-Object {"`n$_"})"
    Write-Warning -Message `
        "Type the following to retry: `nInstall-AzAutomationModule -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -AzModule $($failCheck.name -join ', ') -Wait"
}
#endRegion