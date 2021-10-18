#requires -Version 3
$users = Import-Csv -Path C:\temp\accounts.csv
$count = 0
foreach ($a in $users){

        $SAM = $a.samaccountname
        $Props = Get-ADUser -Identity $SAM -Properties enabled,pwdlastset,LastLogonDate,samaccountname
        if(($Props.LastLogonDate -eq $null) -and ($Props.Enabled)){
            if ($Props.PWDlastset -ne '0'){            
                Try{
                    Set-ADUser -Identity $SAM -ChangePasswordAtLogon $true
                    $status = 'Success'
                    $count++
                }
                Catch{
                    $status = "Failed: $($_.Exception.Message)"
                }
            }
        }

        else{
            $Status = "Enabled or logged in previously"
        }
        [PSCustomObject]@{
            SamAccountName = $SAM
            Enabled = $Props.Enabled
            PWDLastSet = $Props.pwdLastSet
            LastLogon = $Props.LastLogonDate
            Status = $status
            } | Export-Csv -Path C:\Temp\ForcePasswordChange.csv -NoTypeInformation -Append
}

Write-Host "$count accounts set to change password at next logon. Refer to ForcePasswordChange.csv for full details"
