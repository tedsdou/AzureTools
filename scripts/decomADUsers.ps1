<#
.Synopsis
    Disable user accounts in AD and O365
.DESCRIPTION
    Will disable an account as well as give access to shared mailbox and forward email
.NOTES
    Microsoft PowerShell Source File -- Created with Windows PowerShell ISE

    FILENAME: decomADUsers.ps1
    VERSION:  .09
    AUTHOR: v-TeSdou@microsoft.com
    DATE:   Thursday, June 30, 2016


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

#requires -version 3 -modules ActiveDirectory, MSOnline


#region  Functions

function Disable-UserAccount
{
[CmdletBinding()]
param($termuser,$logfile)

    try
    {
        $desc = (Get-ADUser -Identity $termuser -Properties description).description 
        Set-ADUser -Identity $termuser -Enabled $false -Description "$desc - disabled by $env:USERNAME on $(Get-Date -Format ddMMMyyyy)"
        Add-Content -Path $logfile -Value "USERNAME: $termuser has been disabled by $env:USERNAME on $(Get-Date -Format ddMMMyyyy)`r"
    }
    catch
    {
        Add-Content -Path $logfile -Value "ERROR: Unable to disable $termuser `rError Message: $($_.Exception.Message)"
    }
}

function Move-DisabledUser
{
[CmdletBinding()]
param($termuser,$logfile,$TargetOU)

    try
    {
        $dname = (Get-ADUser -Identity $termuser).DistinguishedName
        Move-ADObject -Identity $dname -TargetPath $TargetOU
        Add-Content -Path $logfile -Value "USERNAME: $termuser has been moved to $TargetOU on $(Get-Date -Format ddMMMyyyy) by $env:USERNAME`r"
    }
    catch
    {
        Add-Content -Path $logfile -Value "ERROR: Unable to move $termuser `rError Message: $($_.Exception.Message)"
    }
}

function Clear-Membership
{
[CmdletBinding()]
param($termuser,$logfile)

        $groups = (Get-ADUser $termuser -Properties MemberOf).MemberOf
        foreach($group in $groups)
        {
            try
            {
                Remove-ADGroupMember -Identity $group -Members $termuser -Confirm:$false
                Add-Content -Path $logfile -Value "SUCCESS: Removed $termuser from $group`r"
            }
             catch
            {
                Add-Content -Path $logfile -Value "ERROR: Unable to remove $termuser from $group`rError Message: $($_.Exception.Message)"
            }
        }        
}

function Clear-Attributes
{
[CmdletBinding()]
param($termuser,$logfile,[string[]]$attributes)
 
        foreach($attribute in $attributes)
        {
            try
            {
                Set-ADUser -identity $termuser -Clear $attribute
                Add-Content -Path $logfile -Value "SUCCESS: Cleared $attribute for $termuser`r"
            }
             catch
            {
                Add-Content -Path $logfile -Value "ERROR: Unable to clear $attribute for $termuser`rError Message: $($_.Exception.Message)"
            }

        }
}

function Add-Attributes
{
[CmdletBinding()]
param($termuser,$logfile,[hashtable]$attributes)
    
    $attributes.GetEnumerator() | 
        ForEach-Object `
        {
            try
            {
                Set-ADUser -identity $termuser -Add @{$_.key=$_.value}
                Add-Content -Path $logfile -Value "SUCCESS: Added $($_.key) for $termuser`r"
            }
             catch
            {
                Add-Content -Path $logfile -Value "ERROR: Unable to add $($_.key) for $termuser`rError Message: $($_.Exception.Message)"
            }
        }   
}

function Connect-Office365
{
[CmdletBinding()]
param($logfile)

    Try
    {
        $O365Cred = Get-Credential
        Connect-MsolService –Credential $O365Cred
        $O365Session = New-PSSession -ConfigurationName Microsoft.Exchange `
            -ConnectionUri 'https://outlook.office365.com/powershell-liveid/' -Credential $O365Cred `
            -Authentication 'Basic' -AllowRedirection
        Import-PSSession $O365Session -AllowClobber | Out-Null
    }
    Catch
    {
        Write-Warning -Message "ERROR: Unable to connect to O365.`n`rMESSAGE: $($_.Exception.Message)"
        Add-Content -Path $logfile -Value "ERROR: Unable to connect to O365.`nMESSAGE: $($_.Exception.Message)"
    }
}

function Test-Retention
{
[CmdletBinding()]
param($termuser,$logfile)
    
    try
    {
        $retention = Get-mailbox $termuser | Select-Object -Property LitigationHoldEnabled, RetentionHoldEnabled, InPlaceHolds
        if ( ($retention.LitigationHoldEnabled) -or ($retention.RetentionHoldEnabled)  -or ($retention.InPlaceHolds -ne $null) ) 
        {
            Add-Content -Path $logfile -Value "WARNING: $termuser is on legal hold, please contact management"
            Write-Warning -Message "$termuser is on legal hold, please contact management"
            $result = $false
        } 
        else 
        {
            $result = $true
        }
    }
    catch
    {
        Add-Content -Path $logfile -Value "ERROR: Unable to determine if $termuser is on legal hold`rError Message: $($_.Exception.Message)"
        $result = $false
    }
    return $result    
}

function Remove-Office365License
{
[CmdletBinding()]
param($termuser,$logfile)
    
    try
    {
        $user = (Get-ADUser -Identity $termuser).UserPrincipalName
        $skus = (Get-MsolUser -UserPrincipalName $user).Licenses.accountskuid
        Set-MsolUserLicense -UserPrincipalName $user -RemoveLicenses $skus
        Add-Content -Path $logfile -Value "SUCCESS: Removed licenses $skus from user $termuser"
    }
    catch
    {
        Add-Content -Path $logfile -Value "ERROR: Unable to remove the licenses $skus from $termuser`rError Message: $($_.Exception.Message)"
    }   
}

function ConvertTo-SharedMailbox
{
[CmdletBinding()]
param($termuser,$logfile)

Write-Warning -Message 'Process may take time depending on size of mailbox'    
    try
    {
        Set-Mailbox -Identity (Get-ADUser -Identity $termuser).UserPrincipalName -Type shared -ErrorAction Stop
        Add-Content -Path $logfile -Value "SUCCESS: Converted $termuser to a shared mailbox"
    }
    catch
    {
        Add-Content -Path $logfile -Value "ERROR: Unable to Convert $termuser to a shared mailbox`rError Message: $($_.Exception.Message)"
    }   
}

function Push-Email
{
[CmdletBinding()]
param($termuser,$logfile,$shareuser)

    try
    {
        Set-Mailbox -Identity (Get-ADUser -Identity $termuser).UserPrincipalName `
            -ForwardingAddress (Get-ADUser -Identity $shareuser).UserPrincipalName  -ErrorAction Stop `
            -DeliverToMailboxAndForward $false
        Add-Content -Path $logfile -Value "SUCCESS: Email for user $termuser has been forwarded to $shareuser"
    }
    catch
    {
        Add-Content -Path $logfile -Value "ERROR: Unable to forward email for user $termuser to $shareuser`rError Message: $($_.Exception.Message)"
    }   
}

function Set-MailboxPermissions
{
[CmdletBinding()]
param($termuser,$logfile,$fwduser)
 
    try
    {
        Add-MailboxPermission -Identity $termuser -User $fwduser -AccessRights fullaccess -InheritanceType all
        Add-Content -Path $logfile -Value "SUCCESS: Gave full access for $termuser mailbox to $fwduser"
    }
    catch
    {
        Add-Content -Path $logfile -Value "ERROR: Unable to give full access for $termuser mailbox to $fwduser`rError Message: $($_.Exception.Message)"
    }   
}

function Remove-Mailbox
{
[CmdletBinding()]
param($termuser,$logfile)

    try
    {
        Connect-MsolService
        Remove-MsolUser -UserPrincipalName (Get-ADUser -Identity $termuser).UserPrincipalName -Force
        Add-Content -Path $logfile -Value "SUCCESS: Removed $termuser mailbox from the server"
    }
    catch
    {
        Add-Content -Path $logfile -Value "ERROR: Unable to remove $termuser mailbox`rError Message: $($_.Exception.Message)"
    }   
}

function Send-Mail
{
[CmdletBinding()]
param($smtp,$logfile,$To,$From,$Subject)

    try
    {
        Send-MailMessage -Attachments $logfile -SmtpServer $smtp -To $To -From $From `
            -Subject $Subject -ErrorAction Stop
        Add-Content -Path $logfile -Value "SUCCESS: Sent email to $To for termed user $termuser"
    }
    catch
    {
        Add-Content -Path $logfile -Value "ERROR: Unable to Send email to $To for termed user $termuser`rError Message: $($_.Exception.Message)"
    }   
}
#endregion Funtions.


#region Getting information to disable account
Do
{
    $IncidentNumber = Read-Host 'What is the Incident Number?'
}until ($IncidentNumber -match '^IR\d{1,}$')

Do{
    $termuser = Read-Host "`r`nWho is the user to be disabled? (Please provide username)" 
    Try
    {
        $user = Get-ADUser -Identity $termuser -Properties office,mail
        Do
        {
            $confirm = Read-Host "`r`nDisplayName: $($user.name)`r`nUPN: $($user.UserPrincipalName)`r`nOffice: $($user.office)`r`nPrimarySMTP: $($user.mail)`r`n`r`nIs this the correct user?(yes/no)"
        }until ($confirm -match '^(Yes|No|n|y)$')  #regular expressions: ^ is start of string, $ is end of string, () is a group, | is logical OR
        
    }
    Catch 
    {
        Write-Warning -Message "$termuser not found. Please try again"; $confirm ='no'
    }
} While ($confirm -like 'n*') 
 
Do
{
    $sharemailbox = Read-Host 'Does the mailbox need to be kept? (yes/no)'
}until ($sharemailbox -match '^(Yes|No|n|y)$')

if($sharemailbox -like 'y*')
    {
        Do
        {
        $shareuser = Read-Host 'Who is the user that needs access to the mailbox? (Please provide username)'
            Try
            {
                $user = Get-ADUser -Identity $shareuser -Properties office,mail
                Do
                {
                    $confirm = Read-Host "`r`nDisplayName: $($user.name)`r`nUPN: $($user.UserPrincipalName)`r`nOffice: $($user.office)`r`nPrimarySMTP: $($user.mail)`r`n`r`nIs this the correct user? (yes/no)"
                }until ($confirm -match '^(Yes|No|n|y)$')
            }
            Catch 
            {
                Write-Warning -Message "$shareuser not found. Please try again"; $confirm ='no'
            }
        } While ($confirm -like 'n*') 
       
    }

Do
{
    $fwdmail = Read-Host 'Does mail need to be forwarded? (yes/no)'
}until ($fwdmail -match '^(Yes|No|n|y)$')

if($fwdmail -like 'y*')
    {

        Do
        {
        $fwduser = Read-Host 'Who will mail be forwarded to? (Please provide username)'
            Try
            {
                $user = Get-ADUser -Identity $fwduser -Properties office,mail
                Do
                {
                    $confirm = Read-Host "`r`nDisplayName: $($user.name)`r`nUPN: $($user.UserPrincipalName)`r`nOffice: $($user.office)`r`nPrimarySMTP: $($user.mail)`r`n`r`nIs this the correct user? (yes/no)"
                }until ($confirm -match '^(Yes|No|n|y)$')
            }
            Catch 
            {
                Write-Warning -Message "$fwduser not found. Please try again"; $confirm ='no'
            }
        } While ($confirm -like 'n*') 
        
    }
#endregion  Getting information to disable account

#region Script Execution

$logfile = "$PSScriptRoot\$termuser-DisabledUser-$(Get-Date -Format ddMMMyyyy)-$IncidentNumber.log"

# Disable user account either way
Disable-UserAccount -termuser $termuser -logfile $logfile

# Connect to Office365
Connect-Office365  # when the authentication box pops use UPN to login


# If the user is on retention exit script, if the user is not on retention then it will continue script
if (-not (Test-Retention -termuser $termuser -logfile $logfile) ) 
{
    exit
}


# Do you wanna preserve the mailbox or not
if ($sharemailbox -match '^(No|n)$') # Not keeping the mailbox
{
    # Clear attribs from users AD profile
    Clear-Attributes -termuser $termuser -logfile $logfile -attributes 'showInAddressBook','targetAddress','ProxyAddresses','mail','mailnickname'
    
    # Add some attribute that is needed for the AD profile if we are not removing the mailbox
    Add-Attributes -termuser $termuser -logfile $logfile -attributes @{msExchHideFromAddressLists='TRUE'} #if you wanna add more values, sparate with semicolon

    #delete the mailbox     Not using this because dont want to accidently hard delete an account, should do it manually.        
    # Remove-Mailbox -termuser $termuser -logfile $logfile
    # or
    # Remove-Mailbox -Identity $termuser -Confirm:$false
}
else # preserving the mailbox, forwarding email, and converting the shared mailbox and providing manager with access to the mailbox
{
    # Converting mailbox to share
    ConvertTo-SharedMailbox -termuser $termuser -logfile $logfile
    
    # Provide manager with access to mailbox
    Set-MailboxPermissions -termuser $termuser -logfile $logfile -fwduser $fwduser
}

If($fwdmail -match '^(y|yes)$')
{
    # Forward email to manager
    Push-Email -termuser $termuser -logfile $logfile -shareuser $shareuser
}
    
    # Remove licenses from the Office 365 user
    Remove-Office365License -termuser $termuser -logfile $logfile
    
    # Move disabled user ot he a Disabled Users OU
    Move-DisabledUser -logfile $logfile -termuser $termuser -TargetOU 'OU=Disabled_Users,DC=Contoso,DC=Com'

    # Remove user from all the groups
    Clear-Membership -logfile $logfile -termuser $termuser

    Send-Mail -smtp 'intrelay.contoso.local' -logfile $logfile -To 'ITSupport@contoso\.local' `
        -From 'ADMEmail@contoso\.local' -Subject "Attaching log file [$IncidentNumber]"

    Write-Warning -Message "Please check log file located in $logfile" 
    Start-Sleep -Seconds 5

#endregion Script Execution
