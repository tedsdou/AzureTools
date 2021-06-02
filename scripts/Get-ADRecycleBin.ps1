#requires -Version 3

Function Get-ADRecycleBin{
<#
.Synopsis
   Search contents of the Active Directory Recycle Bin
.DESCRIPTION
   Search contents of the Active Directory Recycle Bin
.PARAMETER Name
    Specifies the object to search for
.PARAMETER Property
    Specifies the properties to include.  Tab-Complete will work to populate.
.PARAMETER StartTime
    Specifies the start time to retrieve output object.
.PARAMETER EndTime
	Specifies the end time to retrieve output object.
.EXAMPLE
    Get-ADRecycleBin
    With no arguments, it will return all objects with all properties
.EXAMPLE
   Get-ADRecycleBin -Name "TestUser1","TestUser2" -Property "Name","LastKnownParent"
   This example searches for multiple users and only specific properties
.EXAMPLE
   "TestUser1","TestUser2" | Get-ADRecycleBin
   This example binds two users to the Name property of the object we're searching for.
#>
[CmdletBinding(DefaultParameterSetName='Name')]
Param(
    [Parameter(Mandatory=$false,
               ValueFromPipeline=$true,
               ValueFromPipelineByPropertyName=$true,
               ParameterSetName='Name'
               )]
    [String[]]$Name,
    [Parameter(Mandatory=$false,
               ParameterSetName='Time'
               )]
    [DateTime]$StartTime,
    [Parameter(Mandatory=$false,
               ParameterSetName='Time'
               )]
    [DateTime]$EndTime
)
# Adding in possible values for properties of object
<#
DynamicParam {
        $attributes = New-Object System.Management.Automation.ParameterAttribute
        $attributes.ParameterSetName = "__AllParameterSets"
        $attributes.Mandatory = $false
        $attributeCollection = New-Object -Type System.Collections.ObjectModel.Collection[System.Attribute]
        $attributeCollection.Add($attributes)
        $_Values = @("*")
        $_Values += (Get-ADObject -LDAPFilter:"(msDS-LastKnownRDN=*)" -IncludeDeletedObjects -Properties * | Get-Member -MemberType Properties).Name      
        $ValidateSet = New-Object System.Management.Automation.ValidateSetAttribute($_Values)
        $attributeCollection.Add($ValidateSet)
        $dynParam1 = New-Object -Type System.Management.Automation.RuntimeDefinedParameter("Property", [string[]], $attributeCollection)
        $paramDictionary = New-Object -Type System.Management.Automation.RuntimeDefinedParameterDictionary
        $paramDictionary.Add("Property", $dynParam1)
        return $paramDictionary 
        }
        #>

    Begin{
        # Verify domain connectivity
        Try { Get-ADDomain | Out-Null } Catch { Write-Warning "ERROR: $($_.Exception.Message)"; return }
        #Verify the AD recycle bin is enabled
        If (-not(Get-ADOptionalFeature -Filter "Name -eq 'Recycle Bin Feature'").EnabledScopes){
            Write-Warning "Active Directory Recycle Bin is not enabled!"  ; Return
            }
    }

    Process{
        $Property = $PSBoundParameters.property
        If(-not($Property)){$Property="*"}
        If($StartTime -and $EndTime){
            Try{
                $user = Get-ADObject -LDAPFilter:"(msDS-LastKnownRDN=*)" -IncludeDeletedObjects -Properties $Property | `
                    Where-Object {$_.Deleted -and $_.whenChanged -ge $StartTime -and $_.whenChanged -le $EndTime} -ErrorAction Stop | `
                    Format-List -Property $Property
            } Catch { Write-Warning "$($_.Exception.Message)" }

            If(-not($user)){ 
                    Write-Warning "No objects found in the AD recycle bin" 
                    } Else { $user }
        }            
        
        ElseIf($Name){
            Foreach ($n in $Name){
                Try{
                    $user = Get-ADObject -LDAPFilter:"(msDS-LastKnownRDN=*)" -IncludeDeletedObjects -Properties $Property | `
                        Where-Object {$_.Deleted -and ($_.Name -like "$n*")} -ErrorAction Stop | Format-List -Property $Property
                } Catch { Write-Warning "$($_.Exception.Message)"; return }

                If(-not($user)){ 
                    Write-Warning "`"$n`" not found in the AD recycle bin" 
                    } Else { $user }
            }
        } 
        Else {
            Try{
                $user = Get-ADObject -LDAPFilter:"(msDS-LastKnownRDN=*)" -IncludeDeletedObjects -Properties $Property | `
                    Where-Object {$_.Deleted} -ErrorAction Stop | Format-List -Property $Property
            } Catch { Write-Warning "$($_.Exception.Message)" }

            If(-not($user)){ 
                    Write-Warning "No objects found in the AD recycle bin" 
                    } Else { $user }
         }
    }
    End{}
}
