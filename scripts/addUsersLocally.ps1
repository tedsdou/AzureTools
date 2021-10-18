Function Add-DomGroupToLGroup
{
<#
    .SYNOPSIS
    Add a domain group to a local group
    
    .EXAMPLE
    Add-DomGroupToLGroup -domGroup testgroup1 -comp 2012r2-ms

    .NOTES
    You can hard set domain name if you wish.
#>
 [CmdletBinding()]
 Param($domGroup,$group = 'Remote Desktop Users',[string[]]$comps)

$DomainName = $env:USERDNSDOMAIN
    foreach($comp in $comps){
        $AdminGroup = [ADSI]"WinNT://$comp/$group,group"
        $gName = [ADSI]"WinNT://$DomainName/$domGroup,group"
        $AdminGroup.Add($gName.Path)
    }
}

Function Add-DomUserToLGroup
{
<#
    .SYNOPSIS
    Add a domain user to a local group
    
    .EXAMPLE
    Add-DomUserToLGroup -UserName danpark -comp 2012r2-ms

    .NOTES
    You can hard set domain name if you wish.
#>
 [CmdletBinding()]
 Param( 
        $UserName,
        $Group = 'Remote Desktop Users',
        $Computer,
        $Domain = 'Contoso.Local'
        )

    try {
        $AdminGroup = [ADSI]"WinNT://$comp/$group,group"
        $User = [ADSI]"WinNT://$DomainName/$UserName,user"
        $AdminGroup.Add($User.Path)
        Write-Verbose -Message "Added $User to $Group on $Computer"
    }
    catch {
        Write-Warning -Message "Unable to add $User to $Group on $Computer because of $($_.Exception.Message)"
    }
}
