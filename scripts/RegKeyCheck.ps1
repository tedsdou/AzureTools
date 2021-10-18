#requires -Version 3
$serverlist = Import-Csv c:\scripts\serverlist.csv # <-- $PSScriptRoot means the folder where the script lives
$regkey = 'HKLM:\SYSTEM\CurrentcontrolSet\Services\SymEvent'
#$regKey = 'HKLM:\SYSTEM\CurrentControlSet\Services\3Ware'

# $serverList.Name is referring to the name column.  If you have a different 
Invoke-Command -ComputerName $serverList.Name -ScriptBlock { 
        # Refer to help file Get-Help about_Try_Catch_Finally - Error handling
        Try{
            $regValue = (Get-ItemProperty -Path $using:regkey -ErrorAction Stop).Tag # <-- assuming you're looking for Tag
            }
        Catch{ $regValue = 'NULL' }
        Finally{
            [PSCustomObject]@{'Regkey' = $Using:regkey; 
                              'StartValue' = $regvalue}
        }
} | Select-Object -Property RegKey,StartValue,PSComputerName | Export-Csv -Path 'C:\Scripts\export.csv'
