$comps = (Get-ADComputer -Filter {operatingsystem -like '*server*'}).name
$cred = Get-Credential contoso\administrator
foreach($c in $comps)
{ 
    Invoke-Command -ComputerName $c  -ScriptBlock {
        New-PSDrive -Name Z -PSProvider FileSystem -Root '\\win8-ws\c$\Temp\SysinternalsSuite' -Credential $using:cred
        Copy-Item -Path 'Z:\Sysmon.exe' -Destination 'c:\Windows\temp\sysmon.exe'
        Invoke-Expression 'C:\Windows\Temp\Sysmon.exe -acceptEula -i'
    }
}
