<#
.Synopsis
   SCRIPT: Resets Active Directory Password
.EXAMPLE
   SCRIPT: Reset-ADPass -user danpark -domain contoso\.local
.NOTES
   Author:  Ted Sdoukos
   Date:    3OCT18
   Version: 1.0
#>


Function Reset-ADPass
{
<#
.Synopsis
   Resets Active Directory Password
.EXAMPLE
   Reset-ADPass -user danpark -domain contoso\.local
.NOTES
   Author:  Ted Sdoukos
   Date:    3OCT18
   Version: 1.0
#>
Param($user,$domain = 'contoso\.local')
    $secPass = Read-Host -Prompt 'What is the new password?' -AsSecureString
    Set-ADAccountPassword -Identity $user -NewPassword $secPass -Server $domain
}
