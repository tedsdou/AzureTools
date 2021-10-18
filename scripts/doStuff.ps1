#requires -version 5
Function Do-Stuff
{
<#
.Synopsis
   Short description
.DESCRIPTION
   Long description
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
#>
Param($proc,$comp = 'localhost')
    Get-Process -Name $proc -ComputerName $comp
}
