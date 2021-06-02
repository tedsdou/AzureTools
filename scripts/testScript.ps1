<#
.Synopsis
   Does Stuff - SCRIPT
.DESCRIPTION
   Long description - does more stuff - SCRIPT
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
.NOTES
    Author: Me
    Version: .009
#>


Function do-stuff
{
<#
.Synopsis
   Does Stuff
.DESCRIPTION
   Long description - does more stuff
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
.NOTES
    Author: Me
    Version: .009
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'low', PositionalBinding=$false)]
Param($proc, $comp)
    If($PSCmdlet.ShouldProcess($proc,"Checking for $proc on $comp"))
    {
        Get-Process -Name $proc -ComputerName $comp
    }
}


