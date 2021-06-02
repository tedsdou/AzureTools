#Check for AD Recycle Bin
Get-ADOptionalFeature -Filter {Name -like '*recycle*'}

#If disabled, EnabledScopes will be empty
# Let's enable it if it isn't already.
Get-ADOptionalFeature -Filter {Name -like '*recycle*'} | Enable-ADOptionalFeature -Scope ForestOrConfigurationSet -Target 'contoso\.local' -Verbose

#Viewing deleted users
Get-ADObject -Filter {objectClass -eq 'user' -and isDeleted -eq $true} -IncludeDeletedObjects -Properties samaccountname

#Restore via SamAccountName
Get-ADObject -Filter {samAccountName -eq 'test1000'} -IncludeDeletedObjects | Restore-ADObject 

#Empty recycle bin - not required, but good to know
Get-ADObject -Filter {isDeleted -eq $true -and Name -like '*DEL:*'} -IncludeDeletedObjects | Remove-ADObject -Confirm:$false
