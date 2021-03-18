#region Functions
Function Get-AzModuleInfo {
    [CmdletBinding()]
    Param($ModuleName)
    $PsGalleryApiUrl = 'https://www.powershellgallery.com/api/v2'
    $ModuleUrlFormat = "$PsGalleryApiUrl/Search()?`$filter={1}&searchTerm=%27{0}%27&targetFramework=%27%27&includePrerelease=false&`$skip=0&`$top=40"
    $CurrentModuleURL = $ModuleUrlFormat -f $ModuleName, 'IsLatestVersion'
    $SearchID = Invoke-RestMethod -Method Get -Uri $CurrentModuleURL -UseBasicParsing | 
    Where-Object -FilterScript { $_.Title.InnerText -eq $moduleName }
    $packageDetails = Invoke-RestMethod -Method Get -UseBasicParsing -Uri $SearchID.id
    $packageDetails
}

Function Get-AzModuleDependancy {
    [CmdletBinding()]
    Param($ModuleName)
    $output = $(Get-AZModuleInfo -ModuleName $ModuleName).entry.properties.Dependencies
    $output -replace ':\[\d+\.\d+\.\d, \d*\.*\d*\.*\d*\]*\)*:' -split '\|'
}

Function Install-AzModuleDependancy {
    [CmdletBinding()]
    Param(
        $ModuleName,
        $ResourceGroupName,
        $AutomationAccountName,
        $ModuleVersion
    )
    $PsGalleryApiUrl = 'https://www.powershellgallery.com/api/v2'
    foreach ($M in $ModuleName) {
        Write-Verbose -Message "Getting information for $M"
        $module = (Get-AzModuleInfo -ModuleName $M).Entry.Properties
        If ($ModuleVersion) {
            $link = "$PsGalleryApiUrl/package/$($module.id)/$($module.Version)"
        }
        else {
            $link = "$PsGalleryApiUrl/package/$($module.id)"
        }
        # Find the actual blob storage location of the module
        do {
            $Link = (Invoke-WebRequest -Uri $link -MaximumRedirection 0 -UseBasicParsing -ErrorAction Ignore).Headers.Location 
        } until ($link.Contains('.nupkg'))
        $status = Get-AzAutomationModule -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName -Name $module.id -ErrorAction SilentlyContinue

        If ( (-Not($status)) -or ($status.Version -ne $module.Version)) {
            Write-Verbose -Message "Currently installing the $($module.id) - Version-$($module.version) dependancy"
            $null = New-AzAutomationModule -AutomationAccountName $automationAccountName -Name $module.id -ContentLinkUri $link -ResourceGroupName $resourceGroupName
            Do {
                $State = Get-AzAutomationModule -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName -Name $module.id
                Start-Sleep -Seconds 1
                Write-Verbose -Message "Waiting on install of $($module.id)"
                Write-Progress -Activity "Installing $($module.id)" -Status "Current status is: $($state.ProvisioningState)"
            }
            While ($state.ProvisioningState -eq 'Creating')
        }
        If ($state.ProvisioningState -eq 'Failed') { Throw "Unable to install $($module.id)" }
        While ($state.ProvisioningState -ne 'Succeeded') {
            $State = Get-AzAutomationModule -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName -Name $module.id
            Start-Sleep -Seconds 1
        }
        If ($state.ProvisioningState -eq 'Succeeded') { 
            Write-Progress -Activity "Installing $($module.id)" -Status "Current status is: $($state.ProvisioningState)"
            Write-Verbose -Message "Installation of $($module.id) successful" 
        }
    }
}

Function Install-AzAutomationModule {
    <#
    .Synopsis
        Installs Az modules in your azure automation account
    .DESCRIPTION
        Long description
    .EXAMPLE
        Install-AzAutomationModule -ResourceGroupName 'ContosoResourceGroup' -AutomationAccountName 'ContosoAutomationAccount' -All
    .EXAMPLE
        I'll do more examples later
    .NOTES
        Author: Ted Sdoukos (Ted.Sdoukos@Microsoft.com)
        Credit to: https://stackoverflow.com/questions/60847861/how-to-import-modules-into-azure-automation-account-using-powershell
        Credit to: https://github.com/microsoft/AzureAutomation-Account-Modules-Update
        REQUIEMENTS: Az.Automation module, PowerShell v5 or better
    
    #>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    Param(
        [Parameter(Mandatory)]$ResourceGroupName,
        [Parameter(Mandatory)]$AutomationAccountName,
        [Parameter(ParameterSetName = 'Some')][ValidateNotNullOrEmpty()][string[]]$AzModule,
        [Parameter(ParameterSetName = 'Some')][ValidateNotNullOrEmpty()][string[]]$ModuleVersion,
        [Parameter(ParameterSetName = 'All')][switch]$All,
        [Switch]$Wait
    )

    If ($PSCmdlet.ParameterSetName -eq 'All') {
        $AzModule = 'Az'
    }
    
    $DepList = New-Object -TypeName System.Collections.ArrayList
    $List = $AzModule | ForEach-Object { Get-AzModuleDependancy -ModuleName $_ }
    foreach ($item in $List) {
        Get-AzModuleDependancy -ModuleName $item | ForEach-Object {
            If (($_ -ne '') -and ($DepList -notcontains $_)) {
                $null = $DepList.Add($_)
            }
        }
    }

    If ($DepList) { Install-AzModuleDependancy -ModuleName $DepList -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName }
    $PsGalleryApiUrl = 'https://www.powershellgallery.com/api/v2' #'https://www.powershellgallery.com/api/v2'
    If ($PSCmdlet.ParameterSetName -eq 'All') {
        $AzModule = Get-AzModuleDependancy -ModuleName 'Az'
    }
    $AzModule | ForEach-Object {
        if (($_) -notin $DepList) {
            $InstallState = Get-AzAutomationModule -AutomationAccountName $automationAccountName -ResourceGroupName $resourceGroupName `
                -Name $_ -ErrorAction SilentlyContinue
            If (($InstallState.ProvisioningState -ne 'Succeeded') -or (-not($InstallState))) {
                $module = (Get-AzModuleInfo -ModuleName $_).Entry.Properties
                
                If ($ModuleVersion) {
                    $link = "$PsGalleryApiUrl/package/$($_)/$($module.Version)"
                }
                else {
                    $link = "$PsGalleryApiUrl/package/$($_)"
                }
                do {
                    $TryCount = 0
                    $Link = (Invoke-WebRequest -Uri $link -MaximumRedirection 0 -UseBasicParsing -ErrorAction Ignore).Headers.Location 
                    $TryCount++
                } until ($link.Contains('.nupkg') -or $TryCount -gt 10)
                
                $ModName = $Module.Id
                Write-Verbose -Message "Currently installing $ModName"
                Write-Progress -Activity "Installing $ModName"
                $null = New-AzAutomationModule -AutomationAccountName $automationAccountName -Name $ModName -ContentLinkUri $link -ResourceGroupName $resourceGroupName
                If ($Wait) {
                    Do {
                        $Status = Get-AzAutomationModule -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name $_ 
                        Start-Sleep -Seconds 1
                    }
                    While ($Status.ProvisioningState -eq 'Creating')
                    Write-Verbose -Message "Provisioning of $_ is complete.  Current status is $($Status.ProvisioningState)"
                }
                #Added a sleep in here to alleviate errors
                # Most common error: Index was out of range. Must be non-negative and less than the size of the collection.
                Start-Sleep -Seconds 2
            }
        }
    }
    $AzModule | ForEach-Object {
        Get-AzAutomationModule -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name $_ |
        Select-Object -Property Name, ProvisioningState
    }
}
#EndRegion Functions


# #Make sure you are logged in and set to the proper context.
#Connect-AzAccount -Subscription 'Visual Studio Enterprise'
#Set-AzContext -Subscription 'Visual Studio Enterprise'

$ResourceGroupName = 'ContosoResourceGroup' #Change this to your rg
$AutomationAccountName = 'ContosoAutomationAccount' #Change this to your automation account name
    
$StopWatch = [System.Diagnostics.Stopwatch]::StartNew()
Install-AzAutomationModule -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -All -Verbose

$failCheck = Get-AzAutomationModule -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName | 
Where-Object -FilterScript { $_.ProvisioningState -eq 'Failed' }
If ($failCheck) {
    Write-Warning -Message "The following modules failed to install: $($failCheck.Name | ForEach-Object {"`n$_"})"
    Write-Warning -Message `
        "Type the following to retry: `nInstall-AzAutomationModule -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -AzModule $($failCheck.name -join ', ') -Wait"
} 

$StopWatch.Stop()
Write-Output -InputObject "Done installing Az Modules`n`rExecutionTime: $($StopWatch.Elapsed)"

<# #region Cleanup (Testing)
Get-AzAutomationModule -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName | 
    Where-Object Name -match 'az\.' | Remove-AzAutomationModule -Force
#endregion #>
