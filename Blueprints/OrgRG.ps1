function Add-ResourceGroupName {
    [CmdletBinding()]
    param (
        [ValidateSet('PROD','TEST','SANDBOX','QA')]
        $Environment,
        $AppName,
        $ContactEmail,
        $BillTo,
        [ValidateSet('Critical','Key','Standard')]
        $Criticality,
        [ValidateSet( 'Confidential','Highly Sensitive','Internal','Public')]
        $DataClass,
        $Project,
        $OrgShortName,
        [ValidateSet('Good','NotAvailable')]
        $ServiceNowCI
    )
    
        If($Environment -eq 'PROD'){
            $Location = 'centralus'
        }else {
            $Location = 'eastus2'
        }
        if ($Location -eq 'centralus') {
            $RegionName = 'CU'
        }else {
            $RegionName = 'E2'
        }
        $AppRGName = $AppName.ToUpper()

        $Tags =  @{
            'BillTo' = $BillTo
            'Application' = $AppName
            'ContactEmail' = $ContactEmail
            'BusinessCriticality' = $Criticality
            'DataClassification' = $DataClass
            'Project' = $Project
            'ServiceNowCI' = $ServiceNowCI
          }
          $Name = "$OrgShortName-$RegionName-$Environment-$AppRGName-RG"

        #Build hash table to convert to json
        @{
            'properties' =  @{
                'description' = ''
                'targetScope' =  'subscription'
                'parameters' = @{}
                'resourceGroups' = @{
                    "$OrgShortName-$AppName-ResourceGroup" =  @{
                        'description' =  "$OrgShortName $AppName Resource Group"
                        "name" = $Name
                        "tags" =  $Tags
                        "location" = $location.ToLower()
                    }
                }
            }
        } 
}

try {
    $null = Get-AzContext -ErrorAction Stop
}
catch {
    Login-AzAccount
}

$params = @{
        'Environment' = 'TEST'
        'AppName' = 'TCU'
        'ContactEmail' = 'WhiskeyTango@Foxtrot.com'
        'BillTo' = 'Tango'
        'Criticality' = 'Standard'
        'DataClass' = 'Internal'
        'Project' = 'ProjectTango'
        'OrgShortName' = 'LAB'
        'ServiceNowCI' = 'Good'
}
$rg = Add-ResourceGroupName @params 
$BluePrintPath = "C:\Blueprint\$($params.OrgShortName)-$($params.AppName)-BluePrint"
$BluePrintPath,"$BluePrintPath\artifacts" | ForEach-Object {
    if (-not(Test-Path -Path $_ -ErrorAction ignore)) {
        $null = New-Item -ItemType Directory -Path $_
    }
}

$rg | ConvertTo-Json -Depth 100 | Out-File -FilePath "$BluePrintPath\blueprint.json" -Force
If(-not(Get-Command -Name New-AzBlueprint -ListAvailable -ErrorAction SilentlyContinue)){Install-Module -Name Az.Blueprint -Force}

#When you have everything populated in your $BluePrintPath\Artifacts directory, load it into Azure
Import-AzBlueprintWithArtifact -Name "$($params.OrgShortName)-Blueprint" -SubscriptionId ((Get-AzContext).Subscription.Id) -InputPath $BluePrintPath
