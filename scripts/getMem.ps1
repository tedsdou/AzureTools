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


Function Get-Memory
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
Param($comp)
    Get-CimInstance -ClassName CIM_ComputerSystem -ComputerName $comp | 
        select-Object -Property name,totalphysicalmemory
}
