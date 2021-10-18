<#
.SYNOPSIS
    Creates home drives and sets permissions
.DESCRIPTION
    Creates home drives and sets permissions
.NOTES
    Author: Ted Sdoukos (Ted.Sdoukos@Microsoft.com)
    
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


#Establish $users parameter from text file Put a comment # to comment out what you don't want
$Users = Get-Content "c:\PublicPC_Users.txt" #Read in from file
$Users = Read-Host "What is the username of the H drive that needs to be created?" #Prompt for input
$users = (Get-ADUser -SearchBase 'OU=Greece,OU=Lab Accounts,DC=contoso,DC=local' -Filter {Enabled -eq $true}).SamAccountName #Search OU
$users = 'a720839' #specific user
$domain = 'Contoso.Local' #Domain name
$DfsPath = 'C:\DFSRoot\Home' #Typically this would be in the form of DFS share ex. \\contoso.local\Home
ForEach ($user in $Users)
{
    #Find the user in AD
    try {
        Get-ADUser -Identity $user
    }
    catch {
        Write-Warning -Message "$user not found in Active Directory"
        Continue
    }
    #create new folder
    $newPath = Join-Path $DfsPath -childpath $user
    #First verify that folder does not exist
    If (-not(Test-Path $newPath))
        {
        Write-Output -InputObject "Creating $newPath"
        $null = New-Item $newPath -Type Directory
        }
    Else 
        {
        Write-Output -Message "$newPath exists.  Re-applying security permissions."
        }
        #set permissions
        $acl = Get-Acl $newPath
        $permission = "$domain\$user",@('DeleteSubdirectoriesAndFiles', 'Write', 'ReadAndExecute', 'Synchronize'), "ContainerInherit, ObjectInherit", "None", "Allow"
        $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule $permission
        $acl.SetAccessRule($accessRule)
        $acl | Set-Acl $newpath
}