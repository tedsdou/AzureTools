try{

    $NoEmail = Get-ADUser -Filter {(company -like 'Allianz Life*') -and (mail -notlike "*")} -Properties samaccountname,mail,company -ErrorAction Stop
    }

catch{

    $ErrorMessage = $_.Exception.Message
    Write-Host -Object $ErrorMessage -ForegroundColor Red
    Exit
    }

try{

    $usrDump = Import-Csv -Path C:\temp\UsrMail.csv -Delimiter '|' -ErrorAction Stop
    }

catch{

    $ErrorMessage = $_.Exception.Message
    Write-Host -Object $ErrorMessage -ForegroundColor Red
    Exit
    }

<#
    Query AD for user accounts with no email address.
    Take the SAMaccountname for those results, and search for each of them in a CSV, under the PreferredLogonName column.
    If there’s a match, take the value of the DefaultEmailAddress column and search AD for a contact object with that email address.
    Then dump any matches to a csv.

#>

$NoEmail | ForEach-Object {
    if($usrDump.PerferredLogonName -contains $_.SAMAccountName){
        $SAM = $_.SamAccountName
        $result = Get-ADObject -Filter {objectClass -eq 'contact'} -Properties mail | Where-Object {$_.mail -in $usrDump.DefaultEmailAddress}
            If($result){$contact = 'True'
            $email = ($usrDump | Where-Object { $_.DefaultEmailAddress -match $SAM }).DefaultEmailAddress
                Foreach($r in $result){

                [PSCustomObject]@{
                            Email = $r.mail
                            SAM   = $_.SAMAccountName
                            Contact = $contact
                            }
                }
            }
            else {$contact = 'False'
            [PSCustomObject]@{
                        Email = $_.mail
                        SAM   = $_.SAMAccountName
                        Contact = $contact
                        }
            
            }
        }
    } | Out-GridView
