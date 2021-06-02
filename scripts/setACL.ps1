$tACL = Import-Clixml C:\Temp\dpark.xml
Get-ADObject 'CN=mpeters,OU=Hendrickson,DC=contoso,DC=com'
$tACL2 = get-Acl 'AD:\CN=mpeters,OU=Hendrickson,DC=contoso,DC=com'
Try{
    $TACL2 | Set-Acl $tACL
    }
    catch{
    Write-Host "Error: $($_.exception.gettype().fullname) `n`r Message: $($_.exception.message)"
    }
if ($tACL -eq $tACL2)
{
  Write-Output "True"
} 
