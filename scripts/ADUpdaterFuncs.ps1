<#
=======================================================================================================================================================
 
Microsoft PowerShell Source File -- Created with Windows PowerShell ISE
 
FILENAME: ADUserUpdater.ps1
VERSION:  .9 Beta
AUTHOR: Ted Sdoukos (v-tesdou@microsoft.com)
DATE:   July 2015

SUMMARY
===========
Script updates users based off csv and user input
Uncomment line 51 for viewing Verbose messages

DEPENDENCIES
==============.
All domain controllers must either be running at minimum 2008 R2 or have the Active Directory Web Services pack installed. 
http://www.microsoft.com/en-us/download/details.aspx?id=2852 (for 2003/2008 domain controllers)


RESULTS
========
Results will be entered into log file based on value of $logFile

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
         
=======================================================================================================================================================
#>

#Requires -Version 3

#$VerbosePreference = "Continue"

Function Test-DomainConnectivity{
<#
.Synopsis
   Tests for connectivity to domain
.DESCRIPTION
  Tests for connectivity to domain
.EXAMPLE
   Test-DomainConnectivity
#>
[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='Medium')]
Param()
    Try{ $domains = @(Get-ADForest).Domains }
    Catch{}
    Finally{$status = $?}
Return $status
}

Function Update-ADUsers
{
<#
.Synopsis
   Update AD Users
.DESCRIPTION
  Update AD Users in bulk via csv file
.EXAMPLE
   Update-ADUsers -UserFile C:\Temp\UserDmp.csv
#>
    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='Medium')]
    Param
    (
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [ValidateScript({Test-Path -Path $_})]
        [ValidatePattern("\w*.csv")] #Regular Expression pattern is \w (word character [a-zA-Z_0-9]) followed by any amount of characters.
        $UserFile
    )

    Begin
    {
       Write-Verbose "Starting AD User Update Process" 
    }
    Process
    {
      Import-Csv $UserFile |
        ForEach-Object { 
        $hshChanges = $null; $hshOld = $null
        $samaccountname = ($_.SAM).trim()
        # Pull in user's information from Active Directory
        Try{
            $currentUser = Get-ADUser -Identity $samaccountname -Properties samaccountname,title,city,streetaddress,mobilephone,manager,department,country,state,officephone,fax,postalcode,office -ErrorAction Stop
            }
        Catch{
            $currentUser = $null
            Add-Content -Path $script:logFile -Value "ERROR: Unable to find $samaccountname in AD"
            Continue
            }
        # Pull in corresponding information from csv file.
        $title = ($_."Job Title").trim()
        $city = ($_."Employee Office Location City").trim()
        $streetAddress = ($_."Employee Office Location Street Address").trim()
        $mobilePhone = ($_."Employee Cell Phone").trim()
        $mgrMail = ($_."Manager Email Address").trim()
        Try {$manager = (Get-ADUser -identity ($mgrMail -split "@")[0]).distinguishedname} catch {$manager = $null}
        $department = ($_."Employee Department").trim()
        $country = ($_."Employee Office Location Country/Region").trim()
        $state = ($_."Employee Office Location State/Province").trim()
        $officePhone = ($_."Employee Business Phone").trim()
        $fax = ($_."Employee Fax").trim()
        $postalCode = ($_."Employee Office Location Postal Code").trim()
        $office = $city + $state
        
        #See if they need updating and update
        $hshChanges = @{}; $hshOld = @{}
        If(($currentUser.City -ne $city) -and ($city -ne "")){$hshChanges.city = $city; $hshOld.city = $currentUser.City}
        If(($currentUser.Title -ne $title) -and ($title -ne "")){$hshChanges.Title = $title; $hshOld.Title = $currentUser.Title}
        If(($currentUser.StreetAddress -ne $streetAddress) -and ($streetAddress -ne "")){$hshChanges.StreetAddress = $streetAddress; $hshOld.StreetAddress = $currentUser.StreetAddress}
        If(($currentUser.MobilePhone -ne $mobilePhone) -and ($mobilePhone -ne "")){$hshChanges.MobilePhone = $mobilePhone; $hshOld.MobilePhone = $currentUser.MobilePhone}
        If(($currentUser.Manager -ne $manager) -and ($manager -ne "")){$hshChanges.Manager = $manager; $hshOld.Manager = $currentUser.Manager}
        If(($currentUser.Department -ne $department) -and ($department -ne "")){$hshChanges.Department = $department; $hshOld.Department = $currentUser.Department}
        If(($currentUser.Country -ne $country) -and ($country -ne "")){$hshChanges.Country = $country; $hshOld.Country = $currentUser.Country}
        If(($currentUser.State -ne $state) -and ($state -ne "")){$hshChanges.State = $state; $hshOld.State = $currentUser.State}
        If(($currentUser.OfficePhone -ne $officePhone) -and ($officePhone -ne "")){$hshChanges.OfficePhone = $officePhone; $hshOld.OfficePhone = $currentUser.OfficePhone}
        If(($currentUser.Fax -ne $fax) -and ($fax -ne "")) {$hshChanges.Fax = $fax; $hshOld.Fax = $currentUser.Fax}
        If(($currentUser.PostalCode -ne $postalCode) -and ($postalCode -ne "")){$hshChanges.PostalCode = $postalCode; $hshOld.PostalCode = $currentUser.PostalCode}
        If(($currentUser.Office -ne $office) -and ($office -ne "")){$hshChanges.Office = $office; $hshOld.Office = $currentUser.Office}
        
        # Check to see if any changes are required
        If ($hshChanges.Count -gt 0){
            # Create body of log file
            $changLog = $hshOld.GetEnumerator() | ForEach-Object -Begin {"`r`nORIGINAL FIELDS:"} -Process {"`r`n`t$($_.Key) - $($_.Value)"} -End {"`r`n"}
            $changLog += $hshChanges.GetEnumerator() | ForEach-Object -Begin {"UPDATED FIELDS:"} -Process {"`r`n`t$($_.Key) - $($_.Value)"} -End {"`r`n"}
            
            # Make Required Changes
            if ($pscmdlet.ShouldProcess($samaccountname, $changLog))
            {
                Try{
                    Set-ADUser -Identity $samaccountname @hshChanges -ErrorAction Stop
                    $logContent = "SUCCESS: The following changes were made to username $samaccountname : $changLog"       
                }
                Catch{
                    $logContent = "ERROR:  The following changes were NOT made to username $samaccountname due to `n`r`t Error: $($_.Exception.GetType().FullName) `n`r`t Error Message: $($_.Exception.Message) :  $changLog"
                }
            }
        }
        Else{
            $logContent = "NOCHANGES: username $samaccountname `n`r"   
        }
        Add-Content -Path $logFile -Value $logContent    
        Write-Verbose $logContent
    }
    }
    End
    {
        Write-Verbose "AD User Update Process has been completed."
    }
}       

# Path to AD User Export CSV file.
$ADUserDump = "C:\Temp\UserDmp.csv"

#Path to desired log file
$logFile = "C:\Temp\ADUserUpdateLog-$(Get-Date -Format ddMMMyy).log"

# Test Domain Connectivity
If(-not(Test-DomainConnectivity)){Throw "Unable to query domain. Verify AD Web Services is running."}

# Remove the pound sign on the next line to run in simulation mode
Update-ADUsers -UserFile $ADUserDump -WhatIf

# Remove the pound sign on the next line to run in realtime
#Update-ADUsers -UserFile $ADUserDump
