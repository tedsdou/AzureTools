function Get-RemoteLocalGroupMember
{
    param(
        [string]$group,
        $computer
    )
    ([ADSI]"WinNT://$computer/$group").psbase.Invoke('Members') | ForEach-Object {
        (([ADSI]$_).InvokeGet('AdsPath') -split '/')[-1]
        'OR'
        ([ADSI]$_).InvokeGet('AdsPath')
    }
} 

Get-RemoteLocalGroupMember -computer MS -group 'Administrators'