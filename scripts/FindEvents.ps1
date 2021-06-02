#region function defs
Function Get-EventsByID
{
Param($log = 'system',$id = 6013,$comp = $env:COMPUTERNAME)
    Get-WinEvent -FilterHashtable @{'LogName'=$log;'ID'=$id} -ComputerName $comp
}

Get-EventsByID | Select-Object -First 10
#endregion function defs

#Explore get-eventlog
Get-Help Get-EventLog -ShowWindow

Get-EventLog -LogName System -EntryType Error -Newest 10

#Explore get-winevent

Get-Help Get-WinEvent -ShowWindow

Get-WinEvent -ListLog '*dhcp*'

Get-WinEvent -ListProvider '*dhcp*'

Get-WinEvent -LogName 'Microsoft-Windows-Dhcp-Client/Admin'
