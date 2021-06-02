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
    Specifies the properties to include
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
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$false,
               ValueFromPipeline=$true,
               ValueFromPipelineByPropertyName=$true)]
    [String[]]$Name,
    [Parameter(Mandatory=$false,
               ValueFromPipelineByPropertyName=$true)]
    [String[]]$Property="*"
)

    Begin{
        # Verify domain connectivity
        Try { Get-ADDomain | Out-Null } Catch { Write-Warning "ERROR: $($_.Exception.Message)"; return }
        #Verify the AD recycle bin is enabled
        If (-not(Get-ADOptionalFeature -Filter "Name -eq 'Recycle Bin Feature'").EnabledScopes){
            Write-Warning "Active Directory Recycle Bin is not enabled!"  ; Return
            }
    }

    Process{
        If($Name){
            Foreach ($n in $Name){
                Try{
                    $user = Get-ADObject -LDAPFilter:"(msDS-LastKnownRDN=*)" -IncludeDeletedObjects -Properties $Property | `
                        Where-Object {$_.Deleted -and ($_.Name -like "$n*")} -ErrorAction Stop | Format-List -Property $Property
                } Catch { Write-Warning "$($_.Exception.Message)" }

                If(-not($user)){ 
                    Write-Warning "`"$n`" not found in the AD recycle bin" 
                    } Else { $user }
            }
        } Else {
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
