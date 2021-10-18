Function Add-TestADUsers{
[CmdletBinding()]
Param($number)
1..$number | ForEach-Object{
    $Surname = ("Smith","Neo","Trinity","Morpheus","Cipher","Tank","Dozer","Switch","Mouse") | Get-Random
    [pscustomobject]@{
        SamAccountName = "test$_"
        Name = "test$_ $Surname"
        Surname = $Surname
        DisplayName = "$Surname, Test$_"
        Enabled = "TRUE"
        Office = ("Chicago","Athens","New York","San Diego","Miami","Boston","Philadelphia") | Get-Random
       }
    } | Export-Csv -Path "$env:TEMP\testAccounts.csv"
    write-host "something"
    Import-Csv -Path "$env:TEMP\testAccounts.csv" | New-ADUser 
    Write-Warning -Message "Successfully built: $number test users"
    Remove-Item -Path "$env:TEMP\testAccounts.csv" -Force
}
