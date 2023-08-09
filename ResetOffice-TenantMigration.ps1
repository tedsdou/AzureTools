<#
.SYNOPSIS
    Resets Office Applications to accommodate Tenant Migration
.DESCRIPTION
    Intended to be run under each user's profile.  Once completed, they will need to sign back into Office applications.
.NOTES
    Author: Ted Sdoukos (Ted.Sdoukos@it1.com)
    Date: August 7, 2023
    
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
$Log = "$env:TEMP\ResetOffice.log"
#Closes Teams, OneDrive, and Outlook.
Stop-Process -Name Teams, OUTLOOK, OneDrive -ErrorAction Ignore

#Captures current OneDrive tenants keys for synced folders.
Add-Content -Path $Log -Value (Get-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\OneDrive\Accounts\*\Tenants')

#Remove folders/profiles
$Paths = 'HKCU:\Software\Microsoft\Office\16.0\Common\Identity', 'HKCU:\Software\Microsoft\Office\16.0\Outlook\Profiles', 'HKCU:\Software\Microsoft\OneDrive', "$env:USERPROFILE\AppData\Local\Microsoft\Teams", "$env:USERPROFILE\AppData\Roaming\Microsoft\Teams", "$env:USERPROFILE\AppData\Roaming\Microsoft Teams"
foreach ($Path in $Paths) {
    try {
        Remove-Item -Path $Path -Recurse -ErrorAction Stop
        Add-Content -Path $Log -Value "Registry key '$Path' and all its contents have been deleted."
    }
    catch{
        Write-Warning -Message "ERROR: $($_.Exception.Message)" | Tee-Object -FilePath $Log -Append
    }
}

#Leaves the Azure AD join from the Crew2 tenant.
Start-Process -FilePath 'dsregcmd.exe' -ArgumentList '/leave'

#Removes the AAD credential cache.
Remove-Item -Path "$env:LocalAppData\Packages\Microsoft.AAD.BrokerPlugin*" -Recurse -Force

#Sign out
logoff.exe