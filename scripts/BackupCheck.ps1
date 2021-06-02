#Requires -Version 3
<#
.NOTES
Microsoft PowerShell Source File -- Created with Windows PowerShell ISE

FILENAME: CheckBackup.ps1
VERSION:  1.7.1 
AUTHOR: Geoff Scott
DATE:  15JUN17   

DISCLAIMER:
===========
This Sample Code is provided for the purpose of illustration only and is 
not intended to be used in a production environment.  
THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT
WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT 
LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS
FOR A PARTICULAR PURPOSE.  

We grant You a nonexclusive, royalty-free
right to use and modify the Sample Code and to reproduce and distribute
the object code form of the Sample Code, provided that You agree:
(i) to not use Our name, logo, or trademarks to market Your software
product in which the Sample Code is embedded; (ii) to include a valid
copyright notice on Your software product in which the Sample Code is
embedded; and (iii) to indemnify, hold harmless, and defend Us and
Our suppliers from and against any claims or lawsuits, including
attorneys' fees, that arise or result from the use or distribution
of the Sample Code.
#>



Param (
  [string] $Path = "$PSScriptRoot\ServerList.txt",
  [string] $OutputFile = "$PSScriptRoot\output.csv",
  [string] $errorLog = "$PSScriptRoot\errorLog.txt"
)

function Test-PsRemoting 
{ 
# http://www.leeholmes.com/blog/2009/11/20/testing-for-powershell-remoting-test-psremoting/
    param([string]$computername)  
    try {  
        $result = Invoke-Command -ComputerName $computername { 1 } -ErrorAction Stop
    } 
    catch { 
        Write-Verbose $_ 
        return $false 
    } 
     
    ## I’ve never seen this happen, but if you want to be thorough…. 
    if($result -ne 1) { 
        Write-Verbose "Remoting to $computerName returned an unexpected result." 
        return $false 
    } 
    $true     
} 

Try
{
    $ServerList = Get-Content -Path $Path -ErrorAction Stop
}
Catch
{
    Write-Warning "$path not found."
    Exit
}

$cred = Get-Credential
$ServerList = Get-Content $Path
ForEach($Servers in ($ServerList))
{
$summary = $null #Assigned this to null for each iteration in case something errant is still in there.
If(-not(Test-PsRemoting -computername $Servers)){
    Write-Warning -Message "Unable to contact $Servers"
    Add-Content -Path $errorLog -Value "Unable to contact $Servers`r`n"
    Continue
    }
  Try
  {
    $session = New-PSSession -ComputerName $Servers -Credential $cred -ErrorAction Stop
    $summary = Invoke-Command -Session $session -ScriptBlock `
    {
      if(!(Get-Command Get-WBSummary -ErrorAction Ignore))
      {
        [pscustomObject] @{
          'Server' = $env:computername
          'LastBackupTaken' = 'WSB Not Installed'
          'BackupsAvailable' = '0'
        }
      }
      else
      {
        Get-WBSummary | 
            Select-Object -Property `
                @{n ='Server' ; e = {$env:computername}}, 
                @{n = 'LastBackupTaken';e = {$_.lastsuccessfulbackuptime}}, 
                @{n = 'BackupsAvailable'; e = {$_.numberofversions}}
      }
    }
  }
  Catch 
  {
    # $_ refers to the most recent error, it's the equivalent of $error[0]
    Write-Warning "Unable to retrieve data from $Servers"
    "ERROR: Unable to retrieve data from $Servers`r`n`tMESSAGE: $($_.exception.message)`r`n" | Out-File -FilePath $errorLog -Append
    $summary = [PSCustomObject] @{
      'Server' = $Servers
      'LastBackupTaken' = 'Unable to retrieve data'
      'BackupsAvailable' = '0'
    }

  }
  Finally
  {
  $summary |
    Select-Object -Property Server, LastBackupTaken, BackupsAvailable |
    Export-Csv -Path "$OutputFile" -Append -NoTypeInformation
  Write-Output -InputObject $summary

    If($session)
    {
      Remove-PSSession -Session $session
    }
  }
}                                   
