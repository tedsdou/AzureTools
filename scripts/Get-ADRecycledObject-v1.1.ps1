#requires -Version 3

Function Get-ADRecycledObject{
<#
.Synopsis
   Search contents of the Active Directory Recycle Bin
.DESCRIPTION
   Search contents of the Active Directory Recycle Bin
.PARAMETER Name
    Specifies the object to search for
.PARAMETER Property
    Specifies the properties to include. Tab-Complete will work to populate.
.PARAMETER StartTime
    Specifies the start time to retrieve output object.
.PARAMETER EndTime
	Specifies the end time to retrieve output object.
.EXAMPLE
    Get-ADRecycledObject
    With no arguments, it will return all objects with all properties
.EXAMPLE
   Get-ADRecycledObject -Name "TestUser1","TestUser2" -Property "Name","LastKnownParent"
   This example searches for multiple users and only specific properties
.EXAMPLE
   "TestUser1","TestUser2" | Get-ADRecycledObject
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
               ValueFromPipelineByPropertyName=$true
               )]
    [String[]]$Property="*",
    [Parameter(Mandatory=$false,
               ParameterSetName='Time'
               )]
    [DateTime]$StartTime,
    [Parameter(Mandatory=$false,
               ParameterSetName='Time'
               )]
    [DateTime]$EndTime
)

    Begin{
        # Verify domain connectivity
        Try { Get-ADDomain | Out-Null } Catch { Write-Warning "$($_.Exception.Message)"; return }
        #Verify the AD recycle bin is enabled
        If (-not(Get-ADOptionalFeature -Filter "Name -eq 'Recycle Bin Feature'").EnabledScopes){
            Write-Warning "Active Directory Recycle Bin is not enabled!"  ; Return
            }
    }

    Process{
        If($StartTime -and $EndTime){
            Try{
                $user = Get-ADObject -LDAPFilter:"(msDS-LastKnownRDN=*)" -IncludeDeletedObjects -Properties $Property | `
                    Where-Object {$_.Deleted -and $_.whenChanged -ge $StartTime -and $_.whenChanged -le $EndTime} -ErrorAction Stop | `
                    Format-List -Property $Property
            } Catch { Write-Warning "$($_.Exception.Message)" }

            If(-not($user)){ Write-Warning "No objects found in the AD recycle bin" }
        }            
        
        ElseIf($Name){
            Foreach ($n in $Name){
                Try{
                    $u = Get-ADObject -LDAPFilter:"(msDS-LastKnownRDN=*)" -IncludeDeletedObjects -Properties $Property | `
                        Where-Object {$_.Deleted -and ($_.DistinguishedName -imatch "CN=$n\\0ADEL:.+")} -ErrorAction Stop | Format-List -Property $Property
                } Catch { Write-Warning "$($_.Exception.Message)"; return }

                If(-not($u)){ Write-Warning "`"$n`" not found in the AD recycle bin" } Else { $user += $u }
            }
        } 
        Else {
            Try{
                $user = Get-ADObject -LDAPFilter:"(msDS-LastKnownRDN=*)" -IncludeDeletedObjects -Properties $Property | `
                    Where-Object {$_.Deleted} -ErrorAction Stop | Format-List -Property $Property
            } Catch { Write-Warning "$($_.Exception.Message)" }

            If(-not($user)){ Write-Warning "No objects found in the AD recycle bin" }
         }
    }
    End{
        $user
    }
}
