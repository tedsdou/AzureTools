<#
.Synopsis
   SCRIPT HELP
.DESCRIPTION
   Long descriptionSCRIPT HELP
.EXAMPLE
   Example of how to use this cmdletSCRIPT HELP
.EXAMPLE
   Another example of how to use this cmdletSCRIPT HELP
#>


Function Do-Stuff
{
<#
.Synopsis
   Short description of do stuff
.DESCRIPTION
   Long description
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
#>
Param($proc,$comp)
    Get-Process -Name $proc -ComputerName $comp
}

Do-Stuff -proc lsass -Comp win10
