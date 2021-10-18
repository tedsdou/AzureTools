#region Users
#Get count of current users in AD
(Get-ADUser -Filter *).count

#Open up the csv to examine
Invoke-Item C:\Temp\testAccounts.csv

# Example build of AD Users
Import-Csv "C:\Temp\testAccounts.csv" | New-ADUser

# Now let's measure the commands to see how long they take to build
Measure-Command -Expression {Import-Csv "C:\Temp\testAccounts.csv" | New-ADUser} | 
    Select-Object -Property TotalSeconds | Format-Table -AutoSize

#Lets verify they've been built
Get-ADUser -Filter {Name -like "test*"} | select Name

# Get another count
(Get-ADUser -Filter *).count

# setting passwords
Set-ADAccountPassword -NewPassword 'PowerShell4' -Identity danpark

Set-ADAccountPassword -NewPassword (Get-Credential -UserName danpark -Message 'Provide Password').Password -Identity danpark

#exploring other attributes to change
Get-Command Set-AD*

Get-Help Set-ADUser -ShowWindow

#endregion users
#region OUs/Groups

#Building AD OUs
'IT', 'Finance', 'HR' | ForEach-Object { New-ADOrganizationalUnit -Name $_ }

#Build sub-OUs
$path = (Get-ADOrganizationalUnit -Filter {Name -eq 'IT'}).DistinguishedName
'HelpDesk', 'DesktopSupport','Networking','ServerTeam' | ForEach-Object {New-ADOrganizationalUnit -Name $_ -Path $path }

#building groups
'HelpDesk', 'DesktopSupport','Networking','ServerTeam' | ForEach-Object {New-ADGroup -Name $_ -GroupScope Global -Path 'OU=Groups,DC=Contoso,DC=Com'}

Add-ADGroupMember -Identity HelpDesk -Members danpark

# Removing OUs
# First turn off ProtectFromAccidentalDeletion
'IT', 'Finance', 'HR','HelpDesk', 'DesktopSupport','Networking','ServerTeam' | ForEach-Object {
    Get-ADOrganizationalUnit -Filter {Name -eq $_} | Set-ADObject -ProtectedFromAccidentalDeletion:$false}

# Remove OUs
'IT', 'Finance', 'HR','HelpDesk', 'DesktopSupport','Networking','ServerTeam' | ForEach-Object {
    Get-ADOrganizationalUnit -Filter {Name -eq $_} | Remove-ADOrganizationalUnit -Confirm:$false}

#now let's remove the test accounts
Get-ADUser -Filter {Name -like "test*"} | Remove-ADUser -Confirm:$false
#endregion OUs/Groups
