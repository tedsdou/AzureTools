<#
Microsoft PowerShell Source File -- Created with Windows PowerShell ISE

FILENAME: ADUserUpdater.ps1
VERSION:  1.00 
AUTHOR: Ted Sdoukos (v-tesdou@microsoft.com)
DATE:   July 2015 
UPDATE:  March 2016 - added in email, SFTP and revert functions

SUMMARY
===========
Script updates users based off csv and user input

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
        [Parameter(Mandatory, ValueFromPipelineByPropertyName=$true)]
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
            Get-ADUser -Identity $samaccountname -Properties samaccountname,title,city,streetaddress,mobilephone,manager,department,country,state,officephone,fax,postalcode,office | Export-Csv -Path $orgField -Append
            }
        Catch{
            $currentUser = $null
            Add-Content -Path $logFile -Value "ERROR: Unable to find $samaccountname in AD"       
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
        Write-Verbose -Message $logContent
    }
    }
    End
    {
        Write-Verbose "AD User Update Process has been completed."
    }
}    

Function Revert-ADUsers{
<#
.Synopsis
   Revert AD Users
.DESCRIPTION
  Revert AD Users in bulk via log file
.EXAMPLE
   Revert-ADUsers -source "C:\updates\scripts\sourceAD\SourceAD-11Mar16.csv"
#>
[CmdletBinding()]
Param($source)
$users = Import-Csv -Path $source
$logFile = "C:\updates\scripts\logs\ADUserREVERT-Log-$(Get-Date -Format ddMMMyy).log"
    foreach($user in $users){
    $samaccountname = $user.SamAccountName
    If($user.title){$title = $user.title}else{$title = $null}
    If($user.city){$city = $user.city}else{$city = $null}
    If($user.StreetAddress){$StreetAddress = $user.StreetAddress}else{$StreetAddress = $null}
    If($user.mobilephone){$mobilephone = $user.mobilephone}else{$mobilephone = $null}
    If($user.manager){$manager = $user.manager}else{$manager = $null}
    If($user.department){$department = $user.department}else{$department = $null}
    If($user.country){$country = $user.country}else{$country = $null}
    If($user.state){$state = $user.state}else{$state = $null}
    If($user.officephone){$officephone = $user.officephone}else{$officephone = $null}
    If($user.Fax){$Fax = $user.Fax}else{$Fax = $null}
    If($user.postalcode){$postalcode = $user.postalcode}else{$postalcode = $null}
    If($user.office){$office = $user.office}else{$office = $null}
        Try{
            $currentUser = Get-ADUser -Identity $samaccountname -Properties samaccountname,title,city,streetaddress,mobilephone,manager,department,country,state,officephone,fax,postalcode,office -ErrorAction Stop
            Set-ADUser -Identity $samaccountname -Title $title -City $city -StreetAddress $streetaddress `
                -MobilePhone $mobilephone -Manager $manager -Department $department `
                -Country $country -State $state -OfficePhone $officephone `
                -Fax $fax -PostalCode $postalcode -Office $office -ErrorAction Stop
            $logContent =  "SUCCESS: Reverted $samaccountname in AD based on file: $orgField" 
            }
        Catch{
            $currentUser = $null
            $logContent =  "ERROR: Unable to make changes to $samaccountname `r`n`t$($Error[0].Exception.Message)"       
            }
        Add-Content -Path $logFile -Value $logContent
        Write-Verbose -Message $logContent
    }  
}

Function Send-Mail{
<#
.Synopsis
   Send email message
.DESCRIPTION
  Send email message
.EXAMPLE
   Send-Mail -body $body
#>
    <# O365
    $credential = Get-Credential 'v-tesdou@microsoft.com'
    Send-MailMessage -smtpServer 'smtp.office365.com' -Credential $credential -UseSsl `
        -From 'v-tesdou@microsoft.com' -to 'v-tesdou@microsoft.com' -subject "testing" `
        -Body "test" -Port 587
    #>
[CmdletBinding(SupportsShouldProcess=$true,
               ConfirmImpact='Medium')]
Param ([string]$body = "Oracle AD Sync - $(Get-Date -Format ddMMMyy)")

$EmailHost = '172.20.1.232'
$EmailFrom = "oracleADSync@hendrickson-intl.com"
$EmailTos = 'ws_OracleADSyncAlerts@hendrickson-intl.com'
$EmailSubject = "Oracle AD Sync - $(Get-Date -Format ddMMMyy)"

#Send email to team
    foreach($EmailTo in $EmailTos){
    
    If (test-path $logFile -ErrorAction SilentlyContinue){
        $sending = Send-MailMessage -SmtpServer $EmailHost -To $EmailTo -From $EmailFrom -Subject $EmailSubject -Body $body -Attachments $logfile -ErrorAction Stop
        }
    Else{
        $sending = Send-MailMessage -SmtpServer $EmailHost -To $EmailTo -From $EmailFrom -Subject $EmailSubject -Body $body -ErrorAction Stop
        }
        Try{
            $sending
            $logContent = "SUCCESS sending mail to $EmailTo"
            }
        Catch{
            $logContent = "ERROR sending mail to $EmailTo :  $($_.Exception.Message)"
            }
            Add-Content -Path $logFile -Value $logContent
            Write-Verbose -Message $logContent
        }
}

Function Get-File {
[CmdletBinding()]
Param()
$user = 'us200283'
$pass = 'Graywolf%0915'
$secPass = $pass | ConvertTo-SecureString -AsPlainText -Force
$Credentials = New-Object pscredential -ArgumentList $user, $secPass
$Session = New-SFTPSession -ComputerName "sftp.us2.cloud.oracle.com" -Credential $Credentials 
Get-SFTPFile -SFTPSession $Session -RemoteFile "/E_1/AD/ActiveDirIntfLayout.csv" -LocalPath "C:\updates\scripts\sourceOracle" -Overwrite

If(-not(Test-Path C:\updates\scripts\ActiveDirIntfLayout.csv)){
   Move-Item -path C:\updates\scripts\sourceOracle\ActiveDirIntfLayout.csv -destination C:\updates\scripts\ActiveDirIntfLayout.csv -Confirm:$false
   $same = $false
   }
Else{  

    $orgFile = (Get-FileHash -Path C:\updates\scripts\ActiveDirIntfLayout.csv).Hash
    $updFile = (Get-FileHash -Path C:\updates\scripts\sourceOracle\ActiveDirIntfLayout.csv).Hash

    If($orgFile -eq $updFile) { 
        Send-Mail -body "Oracle file not updated on SFTP server.  Please contact support." 
        $same = $true
        }
    Else{ 
        Remove-Item -Path C:\updates\scripts\ActiveDirIntfLayout.csv -Confirm:$false
        Move-Item -Path C:\updates\scripts\sourceOracle\ActiveDirIntfLayout.csv -Destination C:\updates\scripts\ActiveDirIntfLayout.csv -Confirm:$false
        $same = $false
        }
}

Return $same
}

# Copy file from SFTP server
If (Get-File) {Exit}

# Path to AD User Export CSV file.
$ADUserDump = "C:\Updates\scripts\ActiveDirIntfLayout.csv"

#Path to desired log file
$logFile = "C:\updates\scripts\logs\ADUserUpdateLog-$(Get-Date -Format ddMMMyy).log"

# Path to original file
$orgField = "C:\updates\scripts\sourceAD\SourceAD-$(Get-Date -Format ddMMMyy).csv"
# $orgField = "C:\updates\scripts\sourceAD\SourceAD-11Mar16.csv" # EDIT DATE TO REVERT TO

# Test domain connectivity
If (-not(Test-DomainConnectivity)){Throw "Unable to query domain. Verify that AD Web Services is running on the domain controller(s)."}

# Remove the pound sign on the next line to run in simulation mode
Update-ADUsers -UserFile $ADUserDump -WhatIf

# Remove the pound sign on the next line to run in realtime
#Update-ADUsers -UserFile $ADUserDump

# Revert to prior run
#Revert-ADUsers -source $orgField

# Send email to users
#Send-Mail 
