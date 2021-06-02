#Requires -Version 3 -Modules ActiveDirectory
# Report on Affected Accounts; added -ResultSetSize to limit number of accounts changed at once
$userCount = 0
If(-not(Test-Path -Path "$PSScriptRoot\FIX_PASSWD_NOTREQD.csv")){
    Add-Content -Path "$PSScriptRoot\FIX_PASSWD_NOTREQD.csv" -Value "Status,Messsage,Account"
    }
DO
{
    $UAC = Get-ADUser -Filter 'useraccountcontrol -band 32' -Properties 'passwordnotrequired', 'useraccountcontrol', 'msDS-LastSuccessfulInteractiveLogonTime', 'lastLogonTimestamp' -ResultSetSize 10
    $UAC | Select-Object -Property DistinguishedName, Enabled, PasswordNotRequired, 'msDS-LastSuccessfulInteractiveLogonTime', 'lastLogonTimestamp',SamAccountName |
    Out-GridView -PassThru -Title "Control-click to choose and attempt to remove PASSWD_NOTREQD from accounts OR click 'Cancel' to exit" | 
    # Attempt to remediate and log output
    ForEach-Object {
           $User = Get-ADUser -Identity $_.DistinguishedName
           Try
            {l
                Set-ADUser -Identity $user.DistinguishedName -PasswordNotRequired $False
                Write-Host -Object "Succesfully removed PASSWD_NOTREQD from $($user.SamAccountName)" -ForegroundColor Green
                Add-Content -Path "$PSScriptRoot\FIX_PASSWD_NOTREQD.csv" -Value "SUCCESS,Removed PASSWD_NOTREQD,$($user.SamAccountName)"
                
            }
            Catch
            {
                Write-Host -Object "Failed to remove PASSWD_NOTREQD from $($user.SamAccountName)`n`rERROR: $($_.Exception.Message)" -ForegroundColor Red
                Add-Content -Path "$PSScriptRoot\FIX_PASSWD_NOTREQD.csv" -Value "ERROR,$($_.Exception.Message),$($user.SamAccountName)"
               
            }
           
            $userCount++
        }
    #Start-Sleep -Seconds 15 #Not sure you need the sleep here unless you're seeing strange issues
}
until ( @($UAC).count -le 1 )
Write-Host "$userCount accounts processed. Refer to $PSScriptRoot\FIX_PASSWD_NOTREQD.csv for full details"
