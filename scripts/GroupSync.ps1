<#
    .SYNOPSIS
    Syncs users in Office365* OUs with respective DUO_* security groups

    .OUTPUTS
    Results will be written to a log file specified in the $LogFile parameter.

    .NOTES
    AUTHOR: Ted Sdoukos (Ted.Sdoukos@Microsoft.com)
    DATE  : 12MAR2020

    DEPENDENCIES
    ==============
    This script requires the following:
        ActiveDirectory Module
        PowerShell version 3.0 or greater

    LEGAL DISCLAIMER:
    ===========
    This Sample Code is provided for the purpose of illustration only and is not
    intended to be used in a production environment.  THIS SAMPLE CODE AND ANY
    RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
    EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF
    MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.  We grant You a
    nonexclusive, royalty-free right to use and modify the Sample Code and to
    reproduce and distribute the object code form of the Sample Code, provided
    that You agree: (i) to not use Our name, logo, or trademarks to market Your
    software product in which the Sample Code is embedded; (ii) to include a valid
    copyright notice on Your software product in which the Sample Code is embedded;
    and (iii) to indemnify, hold harmless, and defend Us and Our suppliers from and
    against any claims or lawsuits, including attorneys' fees, that arise or result
    from the use or distribution of the Sample Code.
#>
#Requires -Module ActiveDirectory -Version 3 
$LogFile = "$(Split-Path -Path $MyInvocation.MyCommand.Path -Parent)\O365-GroupSync.log"
If(-not(Get-Module -Name ActiveDirectory)){
    Import-Module -Name ActiveDirectory
}

Add-Content -Path $LogFile -Value "`n`nScript started by $($env:USERNAME) at $(Get-Date)`n$('='*50)"
try {
    $OUs = Get-ADOrganizationalUnit -Filter 'Name -like "Office365*"'
}
catch {
    $Message = "ERROR: Unable to find Office365 groups | Message: $($_.Exception.Message)"
    Add-Content -Path $LogFile -Value $Message
    Throw $Message
}

foreach ($OU in $OUs) {
    $groupName = ($OU.DistinguishedName -split ',')[0] -replace 'OU=Office365-'
    try {
        $groupDN = Get-ADGroup -Identity "DUO_$groupName"  
    }
    catch {
        $Message = "ERROR: Group DUO_$groupName was not found in Active Directory"
        Write-Warning -Message $Message
        Add-Content -Path $LogFile -Value $Message
        Continue 
        #Alternative Option would be to create the group
        #New-ADGroup -Name "DUO_$groupName" -GroupCategory Security -GroupScope Global
    }
     
    $usrList = Get-ADUser -SearchBase $OU.DistinguishedName -Filter * -Properties MemberOf
    #Adding to proper DUO security group
    $usrList | ForEach-Object {
        If($_.MemberOf -notcontains $groupDN.DistinguishedName){
            try {
                Add-ADGroupMember -Identity $groupDN -Members $_.DistinguishedName
                Add-Content -Path $LogFile -Value "SUCCESS:  Added $($_.DistinguishedName) to $groupName"    
            }
            catch {
                $Message = "ERROR: Unable to add $($_.DistinguishedName) to group | MESSAGE: $($_.Exception.Message)"
                Write-Warning -Message $Message
                Add-Content -Path $LogFile -Value $Message
            }
        }
    }
    #Removing from other DUO Security Groups
    $usrList | ForEach-Object{
        $removeList = $_.memberOf | Where-Object {($_ -match 'DUO_') -and ($_ -notmatch $groupDN.DistinguishedName)}
        $userID = $_.DistinguishedName
            $removeList | ForEach-Object {
                try {
                    Remove-ADGroupMember -Identity $_ -Members $userID -Confirm:$false
                    Add-Content -Path $LogFile -Value "SUCCESS:  Removed $userID from $_"    
                }
                catch {
                    $Message = "ERRROR: Unable to remove $userID from group | MESSAGE: $($_.Exception.Message)"
                    Write-Warning -Message $Message
                    Add-Content -Path $LogFile -Value $Message
                }
            }
    }
}