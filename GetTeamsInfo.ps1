function Get-TeamsUserInfo {
<#
.SYNOPSIS
    Short description
.DESCRIPTION
    Long description
.EXAMPLE
    PS C:\> Get-TeamsUserInfo | Out-GridView 
    Gets all user information that is licensed in Teams along with their role assignments.
.NOTES
    Author: Ted Sdoukos (Ted.Sdoukos@Microsoft.com)
    Date Created: November 8, 2021
    Module Requirements: MSOnline, MicrosoftTeams
    
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
    [CmdletBinding()]
    param ()
    begin {
        'MicrosoftTeams','MSOnline' | ForEach-Object {
            If (-not(Get-Module -ListAvailable -Name $_)) {
                Write-Warning -Message "$_ Module is not installed. Please install it and try again."
                Exit
            }
        }
        if (-not (Get-MsolCompanyInformation -ErrorAction SilentlyContinue)) {
            Write-Warning -Message 'You are not connected to Office 365, please login'
            Connect-MsolService
        }
        if (-not (Get-CsPolicyPackage -ErrorAction SilentlyContinue)) {
            Write-Warning -Message 'You are not connected to Microsoft Teams, please login'
            Connect-MicrosoftTeams
        }
    }
    process {
        $Users = Get-MsolUser -All | Where-Object { $_.Licenses.ServiceStatus.ServicePlan.ServiceName -Match 'teams' -and $_.Licenses.ServiceStatus.ProvisioningStatus -eq 'Success' }
        foreach ($User in $Users) {
            $TeamsInfo = $User.Licenses.ServiceStatus | Where-Object { $_.ServicePlan.ServiceName -eq 'TEAMS1' -and $_.ProvisioningStatus -eq 'Success' }
            $hTable = [Ordered]@{
                'UserPrincipalName'  = $User.UserPrincipalName
                'DisplayName'        = $User.DisplayName
                'isLicensed'         = $User.isLicensed
                'ServiceName'        = $TeamsInfo.ServicePlan.ServiceName
                'ProvisioningStatus' = $TeamsInfo.ProvisioningStatus
            }
            $PolicyInfo = Get-CsUserPolicyAssignment -Identity $User.UserPrincipalName 
            for ($i = 0; $i -lt $PolicyInfo.Count; $i++) {
                $hTable."PolicyName$($i+1)" = $PolicyInfo[$i].PolicyName
                $hTable."PolicySource$($i+1)" = $PolicyInfo[$i].PolicySource
                $hTable."PolicyType$($i+1)" = $PolicyInfo[$i].PolicyType
            }
            New-Object -TypeName PSCustomObject -Property $hTable 
        }
    }
}
