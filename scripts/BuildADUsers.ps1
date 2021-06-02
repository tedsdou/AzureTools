$users = import-csv C:\temp\UserDmp.csv
foreach($u in $users){
$samaccountname = $u.Sam
$name = $u."GivenName"
#write-host $samaccountname
New-aduser -name $samaccountname -SamAccountName $samaccountname -path "OU=Hendrickson,DC=Contoso,DC=Com"
#Remove-ADUser $samaccountname -Confirm:$false
}
