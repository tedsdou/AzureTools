<#
.Synopsis
   Adds computers to AD group
   Updates remote computer
   Reboots remote computer
.DESCRIPTION
   Adds computers to AD group
   Updates remote computer
   Reboots remote computer
.EXAMPLE
   .\adCompUpdate.ps1 -FileName C:\Temp\comp.txt -GroupName 'it' -ShowProgress

   This examples shows the use of the ShowProgress switch.  This will display the progress of the job.
.EXAMPLE
   .\adCompUpdate.ps1 -FileName C:\Temp\comp.txt -GroupName 'it'

   This example shows basic useage of the script with the two required parameters.
.OUTPUTS
   Exports information to CSV
.NOTES
   ScriptName:  ADCompUpdate.ps1
   Author:  George Akin / Ted Sdoukos
   Version:  .09
   Date:  22MAY18
#>

#requires -Version 3
Param(
  [Parameter(Mandatory)]
  [ValidateScript({Test-Path -Path $_})] #<-- eliminates the need to validate within the script
  [string]$FileName,
  [Parameter(Mandatory)]
  [ValidateScript({Get-ADGroup -Identity $_})] #<-- eliminates the need to validate within the script
  [string]$GroupName,
  [switch]$ShowProgress
)

$Machines = (Get-Content -Path $FileName)
$i = 0

foreach ($Machine in $Machines)
{
    If($ShowProgress){
        $i++
        $percent = (($i / $Machines.Count)  * 100)
        Write-Progress -Activity "Working on $Machine" -Status "Completed: $i of $($Machines.Count)" `
            -PercentComplete $percent -CurrentOperation "$(([math]::Round($percent)))% complete"
    }
<# Try/Catch notes.
Try/Catch only works with terminating errors.
To convert to a terminating error use -ErrorAction Stop
You cannot convert back to non-terminating (i.e. get-aduser foo -erroraction silentlycontinue) from within a Try block.
See help file for more info:  Get-Help about_Try_Catch_Finally -ShowWindow
#>
  Try 
  { 
    $null = Get-ADComputer -Identity $Machine 
    Add-ADGroupMember -Identity $GroupName -Members (Get-ADComputer -Identity $Machine)
    Invoke-GPUpdate -Computer $Machine -Boot
    $Valid = 'TRUE'
  }
  Catch
  {
    $Valid = 'FALSE'
  }
  Finally
  {
  # Construct custom object and export to csv.  You can add more properties to this as well within the @{}
  [pscustomobject]@{'ComputerName' = $Machine
                    'Valid' = $Valid
                    'Date' = (Get-Date -Format g)
                    } | 
    Export-Csv -Path "$PSScriptRoot\ComputerReport.csv" -Append -NoTypeInformation
  }
}
