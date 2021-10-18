Remove-Item -Path C:\Temp\EmailOutput.csv -Force -ErrorAction Ignore
$users = Import-Csv C:\temp\emails4.csv

ForEach($u in $users){
    $mail = $u.mail
    $addy = Get-ADUser -Filter {mail -eq $mail} -Properties mail,samaccountname
    #$addy = Get-ADUser -Filter "mail -eq `"$($u.mail)`"" -Properties mail,samaccountname 
    
    [PSCustomObject]@{
                    Email = $addy.mail
                    SAM   = $addy.samaccountname
              } | Export-Csv c:\temp\EmailOutput.csv -NoTypeInformation -Append
    
} 
 
 Invoke-Item C:\Temp\EmailOutput.csv
