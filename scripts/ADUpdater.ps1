$ADUserDump = "C:\Temp\UserDmp.csv"
$logFile = "C:\Temp\ADUserUpdateLog-$(Get-Date -Format ddMMMyy).log"

Import-Csv $ADUserDump | #Where-Object {$_.SAM -EQ "mpeters"} |
    ForEach-Object { 
        $hshChanges = $null
        $samaccountname = ($_.SAM).trim()

        # Pull in user's information from Active Directory
        $currentUser = Get-ADUser -Identity $samaccountname -Properties samaccountname,title,city,streetaddress,mobilephone,manager,department,country,state,officephone,fax,postalcode,office

        # Pull in corresponding information from csv file.
        
        $title = ($_."Job Title").trim()
        $city = ($_."Employee Office Location City").trim()
        $streetAddress = ($_."Employee Office Location Street Address").trim()
        $mobilePhone = ($_."Employee Cell Phone").trim()
        $mgrMail = ($_."Manager Email Address").trim()
        Try {$manager = (Get-ADUser -identity ($mgrMail -split "@")[0]).distinguishedname} catch {$manager = $null}
        $department = ($_."Employee Department").trim()
        $country = ($_."Employee Office Location Country/Region").trim()
        $state = ($_."Employee Office Location State/Province").trim()
        $officePhone = ($_."Employee Business Phone").trim()
        $fax = ($_."Employee Fax").trim()
        $postalCode = ($_."Employee Office Location Postal Code").trim()
        $office = $city + $state
        
        #See if they need updating and update
        $hshChanges = @{}
        If(($currentUser.City -ne $city) -and ($city -ne "")){$hshChanges.city = $city}
        If(($currentUser.Title -ne $title) -and ($title -ne "")){$hshChanges.Title = $title}
        If(($currentUser.StreetAddress -ne $streetAddress) -and ($streetAddress -ne "")){$hshChanges.StreetAddress = $streetAddress}
        If(($currentUser.MobilePhone -ne $mobilePhone) -and ($mobilePhone -ne "")){$hshChanges.MobilePhone = $mobilePhone}
        If(($currentUser.Manager -ne $manager) -and ($manager -ne "")){$hshChanges.Manager = $manager}
        If(($currentUser.Department -ne $department) -and ($department -ne "")){$hshChanges.Department = $department}
        If(($currentUser.Country -ne $country) -and ($country -ne "")){$hshChanges.Country = $country}
        If(($currentUser.State -ne $state) -and ($state -ne "")){$hshChanges.State = $state}
        If(($currentUser.OfficePhone -ne $officePhone) -and ($officePhone -ne "")){$hshChanges.OfficePhone = $officePhone}
        If(($currentUser.Fax -ne $fax) -and ($fax -ne "")) {$hshChanges.Fax = $fax}
        If(($currentUser.PostalCode -ne $postalCode) -and ($postalCode -ne "")){$hshChanges.PostalCode = $postalCode}
        If(($currentUser.Office -ne $office) -and ($office -ne "")){$hshChanges.Office = $office}

        # Create body of log file
        $changLog = $hshChanges.GetEnumerator() | ForEach-Object {"`r`n`t$($_.Key) - $($_.Value)"}

        # Make required changes if required
        If ($hshChanges.Count -gt 0){
            Try{
                Set-ADUser -Identity $samaccountname @hshChanges
                Add-Content -Path $logFile -Value "SUCCESS: The following changes were made to username $samaccountname : $changLog"       
            }
            Catch{
                Write-Host $_.exception.gettype().fullname
                Add-Content -Path $logFile -Value "ERROR:  The following changes were NOT made to username $samaccountname due to `n`r`t Error: $($_.Exception.GetType().FullName) `n`r`t Error Message: $($_.Exception.Message) :  $changLog"
            }
        }
        Else{
            Add-Content -Path $logFile -Value "NOCHANGES: username $samaccountname `n`r"   
        }
       
    }    
