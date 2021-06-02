<#
=======================================================================================================================================================
 
Microsoft PowerShell Source File -- Created with Windows PowerShell ISE
 
NAME: systemDriveCleanup.ps1
 
AUTHOR: Ted Sdoukos
DATE  : 10/2013
 
COMMENT: Clears system drive of temp, log, and patch cache files.

SUMMARY
===========
Removes files and folders that are known to be safe to remove to preserve space on the system drive.

DEPENDENCIES
==============
Network and WMI connectivity from source server to destination.  Assumed this is run either locally or on a management server.
If running on 2003, verify that PowerShell exists.

RESULTS
========
Results will be emailed to the team with details and also generated in the application logs on the server run against.
If errors occur, a log file with the server name and date run will be generated.

LEGAL DISCLAIMER:
===========
This Sample Code is provided for the purpose of illustration only and is not
intended to be used in a production environment.  THIS SAMPLE CODE AND ANY
RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.  We grant You a
nonexclusive, royalty-free right to use and modify the Sample Code and to
reproduce and distribute the object code form of the Sample Code, provided
that You agree: (i) to not use Our name, logo, or trademarks to market Your
software product in which the Sample Code is embedded; (ii) to include a valid
copyright notice on Your software product in which the Sample Code is embedded;
and (iii) to indemnify, hold harmless, and defend Us and Our suppliers from and
against any claims or lawsuits, including attorneys’ fees, that arise or result
from the use or distribution of the Sample Code.
         
=======================================================================================================================================================
#>

#Requires -Version 2.0


#region Script Variables
#Define Script Variables
$Script:fileCount = 0; $Script:errCount = 0; $Script:totalSpace = 0; $Script:pageFileLoc = ""; $Script:arrTooBig = @()
$Script:isoSpace = 0; $Script:isoCount = 0; $Script:arrISO = @()

#Define script variables for date thresholds
$Script:patchCacheThreshold = (Get-Date).AddDays(-180); $Script:logFileThreshold = (Get-Date).AddDays(-10); $Script:ProfSize = "100"
#endregion

#region Functions
Function Write-Log{
[CmdletBinding(SupportsShouldProcess=$true)]
Param ([parameter(Mandatory=$true,
        HelpMessage="Log text must contain data")]
        [string]$logstring
        )
    Add-Content -Path $script:LogFile -Value $logstring
}#End Write-Log

Function Verify-Access{
<#
.Synopsis
   Verify Access to target computer
.DESCRIPTION
   Verify Access to target computer by testing administrative share
.EXAMPLE
   Verify-Access -Computer MyComputer
.EXAMPLE
   Verify-Access -MachineName MyComputer
.EXAMPLE
   Verify-Access -Target MyComputer
.INPUTS
   Hostname of target
.OUTPUTS
   Returns boolean value of access verification
#>
[CmdletBinding(SupportsShouldProcess=$true,
               ConfirmImpact='Medium')]
Param ([parameter(Mandatory=$true)]
        [alias("Computer","MachineName","Target")]
        [string]$server
        )
    If (Test-Path "\\$server\C$"){$accessVerification = $true}
    Else{
        Write-Host -ForegroundColor Yellow "Error accessing C$ on $server."
        Write-Log -logstring "Error accessing C$ share on $server.`nVerify connectivity and spelling of $server."
        $accessVerification = $false
        $Script:errCount++
        }
    Return $accessVerification

}#End Verify-Access

Function Send-Mail{
[CmdletBinding(SupportsShouldProcess=$true,
               ConfirmImpact='Medium')]
Param ([parameter(Mandatory=$true,
        HelpMessage="Enter body of email")]
        [string]$body,
        [parameter(Mandatory=$true,
        HelpMessage="Enter domain name")]
        [string]$domain,
        [parameter(Mandatory=$true,
        HelpMessage="Enter logon server")]
        [string]$logonServer)
#Determine Email Host
Switch ($logonServer){
    "CONTOSO"{ $EmailHost = "relay.contoso.com" }
    "TAILSPINTOYS"{ $EmailHost = "relay.tailspintoys.com" }
    "FABRIKAM"{ $EmailHost = "relay.fabrikam.com" }
    Default { $EmailHost = "relay.MyMailServer.com" }
    }

$EmailFrom = 	"Automation@contoso.com"
$EmailTos = 	"ted.sdoukos@contoso.com"
$EmailSubject = "System Drive Cleanup on $server"

#Send email to team
    foreach($EmailTo in $EmailTos){
        Try{
            Send-MailMessage -SmtpServer $EmailHost -To $EmailTo -From $EmailFrom -Subject $EmailSubject -Body $body -ErrorAction Stop
            }
        Catch{
            Write-Host -ForegroundColor Blue "ERROR sending mail to $EmailTo :  $($_.Exception.Message)"
            Write-Log "ERROR sending mail to $EmailTo :  $($_.Exception.Message)"; $Script:errCount ++ ; $Error.Clear()
            }
        }
}#End Send-Mail

Function Get-OS{
[CmdletBinding(SupportsShouldProcess=$true,               
               ConfirmImpact='Medium')]
Param ([parameter(Mandatory=$true,
        HelpMessage="Target server must be specified")]
        [alias("Computer","MachineName","Target")]
        [string]$server
        )
    Get-WmiObject win32_OperatingSystem -ComputerName $server | Select-Object -ExpandProperty caption
    }#End Get-OS

Function Clear-PatchCache{
[CmdletBinding(SupportsShouldProcess=$true,
               ConfirmImpact='Medium')]
Param ([parameter(Mandatory=$true,
        HelpMessage="Target server must be specified")]
        [alias("Computer","MachineName","Target")]
        [string]$server
        )
#Path to patch cache
$space = 0

$arrPaths = @()
#Adding 2008/2012 patch cache path
$arrPaths += "\\$server\" + 'C$\Windows\Installer\$PatchCache$\Managed'
#Adding 2000/2003 paths
$arrPaths += "\\$server\" + 'C$\Windows\$hf_mig$'
$arrPaths += "\\$server\" + 'C$\Windows\ie' + "*" + "updates"
$arrPaths += "\\$server\" + 'C$\WINDOWS\SoftwareDistribution\Download'
$arrPaths += "\\$server\" + 'C$\WINDOWS\ServicePackFiles'

$size = 0; $space = 0;

foreach($path in $arrPaths){
    If (Test-Path $path){
        $items = Get-ChildItem $path -Directory -Recurse -Force -ErrorAction SilentlyContinue
    
        foreach($item in $items){
            If ($item.LastWriteTime -lt $Script:patchCacheThreshold)
                {   
                    $subFolderItems = (Get-ChildItem $item.FullName | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue )
                    $size = $subFolderItems.Sum
                        If(Test-Path $item.FullName -ErrorAction SilentlyContinue){
                            Try{
                                Remove-Item -Path $item.FullName -Force -Recurse -ErrorAction Stop
                                $space += $size
                                $Script:fileCount ++
                                }
                            Catch{
                                Write-Host -ForegroundColor Blue "ERROR removing $($item.FullName) on $server `nMessage:  $($_.Exception.Message)"
                                Write-Log -logstring "ERROR removing $($item.FullName) on $server `nMessage:  $($_.Exception.Message)"; $Script:errCount ++ ; $Error.Clear()
                                }
                            }
                    }
            }
            $Script:totalSpace += $space
        }
    }

#Server 2000 and 2003 specific NT Uninstall folders
If((Get-OS -server $server) -like ("*2000*" -or "*2003*")){
    $path = "\\$server\" + 'C$\Windows\'
    }
If (Test-Path $path){
    $items = Get-ChildItem $path -Directory -Recurse -Force -ErrorAction SilentlyContinue
    
    foreach($item in $items){
        If ($item.LastWriteTime -lt $Script:patchCacheThreshold -and $item.Name -like '$NT'+"*"+'$' )
                {   
                    $size = ($item.FullName | Measure-Object -Property Length -Sum).Sum
                    Try{
                        Remove-Item -Path $item.FullName -Force -ErrorAction Stop
                        $space += $size
                        $Script:fileCount ++
                        }
                    Catch {
                        Write-Host -ForegroundColor Red "ERROR removing $($item.FullName) on $server `nMessage:  $($_.Exception.Message)" `
                        Write-Log -LogString "ERROR removing $($item.FullName) on $server `nMessage:  $($_.Exception.Message)"; $Script:errCount ++ ; $Error.Clear()
                        }
                }
        }
        $Script:totalSpace += $space
    }
}#End Clear-PatchCache

Function Clear-Logs{
[CmdletBinding(SupportsShouldProcess=$true,
               ConfirmImpact='Medium')]
Param ([parameter(Mandatory=$true,
        HelpMessage="Target server must be specified")]
        [alias("Computer","MachineName","Target")]
        [string]$server
        )
#Declare empty array for log paths
$arrLogPath = @()
$space = 0
#Checking if IIS is installed
If(Get-Service W3SVC -ComputerName $server -ErrorAction SilentlyContinue){
    #Querying for IIS log file location
    Try{
        $Location = [adsi]"IIS://$server/w3svc" | select LogFileDirectory | ForEach-Object {$_.LogFileDirectory} -ErrorAction SilentlyContinue
        $Location = $Location = "\\$server\" + $Location -replace ":","$"
        #Adding IIS log path
        $arrLogPath += $Location
        }
    Catch{
        Write-Host -ForegroundColor Red "Unable to query IIS log file location on $server `n $($_.Exception.Message)"
        Write-Log -logstring "Unable to query IIS log file location on $server `nMessage:  $($_.Exception.Message)";$Error.Clear()
        }
    }
#Adding Windows log path
$arrLogPath += "\\$server\" + 'C$\Windows\System32\LogFiles'
$arrLogPath += "\\$server\" + 'C$\Windows\SoftwareDistribution'
$arrLogPath += "\\$server\" + 'C$\inetpub\logs\LogFiles'
$arrLogPath += "\\$server\" + 'C$\Perflogs'
$arrLogPath += "\\$server\" + 'C$\CFusionMX7\Mail\Undelivr'

foreach($path in $arrLogPath){
If(Test-Path $path){
     $items = Get-ChildItem $path -File -Recurse -ErrorAction SilentlyContinue
        foreach($item in $items){
            #Iterate and look for .log items older than 10 days
            If ( ($item.LastWriteTime -lt $Script:logFileThreshold) -and (-not $item.PsIsContainer) -and ($item.Extension -eq ".log") -and ($item.Name -notlike "*RTBackup*"))
            {
                $size = $item.Length
                Try{
                    Remove-Item -Path $item.FullName -Force -ErrorAction Stop
                    $space += $size
                    $Script:fileCount ++
                    }
                Catch {
                    Write-Host -ForegroundColor Red "ERROR removing $($item.FullName) on $server`nMessage:  $($_.Exception.Message)"; `
                    Write-Log -logstring "ERROR removing $($item.FullName) on $server`nMessage:  $($_.Exception.Message)"; $Script:errCount ++ ; $Error.Clear()
                    }
            }
        }
        $Script:totalSpace += $space
        }
    }
    
}#End Clear-Logs

Function Clear-ErrorReports{
[CmdletBinding(SupportsShouldProcess=$true,
               ConfirmImpact='Medium')]
Param ([parameter(Mandatory=$true,
        HelpMessage="Target server must be specified")]
        [alias("Computer","MachineName","Target")]
        [string]$server
        )
$arrPath = @()
$space = 0
#Add error report possible paths
$arrPath += "\\$server\" + 'C$\Windows\PCHealth\ErrorRep\QSIGNOFF\QSIGNOFF'
$arrPath += "\\$server\" + 'C$\Windows\PCHealth\ErrorRep\QSIGNOFF\UserDumps'
$arrPath += "\\$server\" + 'C$\ProgramData\Microsoft\Windows\WER\ReportArchive'
$arrPath += "\\$server\" + 'C$\ProgramData\Microsoft\Windows\WER\ReportQueue'

ForEach($path in $arrPath){

    If (Test-Path $path){
        $items = Get-ChildItem $path -Recurse -Force -ErrorAction SilentlyContinue
    
        foreach($item in $items){
            If ($item.LastWriteTime -lt $Script:logFileThreshold)
                    {   
                        $size = $item.Sum
                        If(Test-Path $item.FullName -ErrorAction SilentlyContinue ){
                            Try{
                                Remove-Item -Path $item.FullName -Force -Recurse -ErrorAction Stop
                                $space += $size
                                $Script:fileCount ++ 
                                }
                            Catch {
                                Write-Host -ForegroundColor Red "ERROR removing $($item.FullName) on $server `nMessage:  $($_.Exception.Message)"
                                Write-Log -logstring "ERROR removing $($item.FullName) on $server `nMessage:  $($_.Exception.Message)"; $Script:errCount ++ ; $Error.Clear()
                                }
                            }                        
                    }
            }
            $Script:totalSpace += $space
        }
    }
}#End Clear-ErrorReports

Function Clear-Dumps{
[CmdletBinding(SupportsShouldProcess=$true,
               ConfirmImpact='Medium')]
Param ([parameter(Mandatory=$true,
        HelpMessage="Target server must be specified")]
        [alias("Computer","MachineName","Target")]
        [string]$server
        )
$space = 0
$dmpPath = "\\$server\" + 'C$\Windows'
If(Test-Path $dmpPath){
     $items = Get-ChildItem $dmpPath -Recurse -ErrorAction SilentlyContinue
        foreach($item in $items){
            #Iterate and look for old dump files
            If ($item.LastWriteTime -lt $Script:logFileThreshold -and -not $item.PsIsContainer -and $item.Extension -eq (".mdmp" -or ".dmp" -or ".hdmp") -and $item.Name -notlike "*RTBackup*" )
            {
                $size = $item.Length
                If(Test-Path $item.FullName -ErrorAction SilentlyContinue ){
                    Try{
                        Remove-Item -Path $item.FullName -Force -ErrorAction Stop
                        $space += $size
                        $Script:fileCount ++
                        }
                    Catch {
                        Write-Host -ForegroundColor Red "ERROR removing $($item.FullName) on $server `nMessage:  $($_.Exception.Message)"
                        Write-Log "ERROR removing $($item.FullName) on $server `nMessage:  $($_.Exception.Message)"; $Script:errCount ++ ; $Error.Clear()
                        }
                    }
            }
        }
        $Script:totalSpace += $space
    }

}#End Clear-Dumps

Function Clear-Recycler{
[CmdletBinding(SupportsShouldProcess=$true,
               ConfirmImpact='Medium')]
Param ([parameter(Mandatory=$true,
        HelpMessage="Target server must be specified")]
        [alias("Computer","MachineName","Target")]
        [string]$server
        )
$space = 0
If( ((Get-OS -server $server) -like "*2008*") -or ((Get-OS -server $server) -like "*2012*")){$RecyclePath = "\\$server\" + 'C$\$Recycle.Bin'}else{$RecyclePath = "\\$server\" + 'C$\recycler'}
If(Test-Path $RecyclePath){
    Try{
        Remove-Item -Path $RecyclePath -Force -Recurse -Confirm:$false -ErrorAction Stop
        $space += $size
        $Script:fileCount ++
        }
    Catch {
        Write-Host -ForegroundColor Red "ERROR removing $($item.FullName) on $server `nMessage:  $($_.Exception.Message)"
        Write-Log -logstring "ERROR removing $($item.FullName) on $server `nMessage:  $($_.Exception.Message)"; $Script:errCount ++ ; $Error.Clear()
        }
      }
        $Script:totalSpace += $space
}#End Clear-Recycler

Function Clear-Temp{
[CmdletBinding(SupportsShouldProcess=$true,
               ConfirmImpact='Medium')]
Param ([parameter(Mandatory=$true,
        HelpMessage="Target server must be specified")]
        [alias("Computer","MachineName","Target")]
        [string]$server
        )
$arrPath = @()
$space = 0
$arrPath += "\\$server\" + 'C$\windows\temp'
ForEach($tempPath in $arrPath){
    If(Test-Path $tempPath){
         $items = Get-ChildItem $tempPath -Recurse -ErrorAction SilentlyContinue
            foreach($item in $items){
                #Iterate and look for .log items older than 10 days
                If ($item.LastWriteTime -lt $Script:logFileThreshold -and $item.FullName -notlike "*vmware*" )
                {
                    $size = $item.Length
                    If(Test-Path $item.FullName -ErrorAction SilentlyContinue){
                        Try{
                            Remove-Item -Path $item.FullName -Force -Recurse -ErrorAction Stop
                            $space += $size
                            $Script:fileCount ++
                            }
                        Catch {
                           Write-Host -ForegroundColor Red "ERROR removing $($item.FullName) on $server `nMessage:  $($_.Exception.Message)"
                           Write-Log -logstring "ERROR removing $($item.FullName) on $server `nMessage:  $($_.Exception.Message)"; $Script:errCount ++ ; $Error.Clear()
                            }
                          }                
                }
            }
            $Script:totalSpace += $space
        }
    }
}#End Clear-Temp

Function Clear-Capture{
[CmdletBinding(SupportsShouldProcess=$true,
               ConfirmImpact='Medium')]
Param ([parameter(Mandatory=$true,
        HelpMessage="Target server must be specified")]
        [alias("Computer","MachineName","Target")]
        [string]$server
        )
$capPath = ("\\$server\" + 'C$\')
$space = 0
If(Test-Path $capPath){
     $items = Get-ChildItem $capPath -Recurse -ErrorAction SilentlyContinue
        foreach($item in $items){
            #Iterate and look for old .log files
            If ($item.LastWriteTime -lt $Script:logFileThreshold -and -not $item.PsIsContainer -and ($item.Extension -eq ".cap" -or $item.Extension -eq ".pcap"))
            {
                $size = $item.Length
                If(Test-Path $item.FullName -ErrorAction SilentlyContinue ){
                    Try{
                        Remove-Item -Path $item.FullName -Force -ErrorAction Stop
                        $space += $size
                        $Script:fileCount ++
                        }
                    Catch {
                        Write-Host -ForegroundColor Red "ERROR removing $($item.FullName) on $server `nMessage:  $($_.Exception.Message)" 
                        Write-Log -logstring "ERROR removing $($item.FullName) on $server `nMessage:  $($_.Exception.Message)"; $Script:errCount ++ ; $Error.Clear()
                        }
                    }
            }
        }
        $Script:totalSpace += $space
        
    }
    
}#End Clear-Capture

Function Get-PageFile{
[CmdletBinding(SupportsShouldProcess=$true,
               ConfirmImpact='Medium')]
Param ([parameter(Mandatory=$true,
        HelpMessage="Target server must be specified")]
        [alias("Computer","MachineName","Target")]
        [string]$server
        )
    $pageFile = Get-WmiObject Win32_PageFileUsage -ComputerName $server
    $Script:pageFileLoc = $pageFile.Name
}#End Get-PageFile

Function Clear-SP1Files{
[CmdletBinding(SupportsShouldProcess=$true,
               ConfirmImpact='Medium')]
Param ([parameter(Mandatory=$true,
        HelpMessage="Target server must be specified")]
        [alias("Computer","MachineName","Target")]
        [string]$server
        )
    #No good way to measure this so we're going to query before and after to calculate space saved.
    #Find Starting Free Space
    $disk = Get-WmiObject Win32_LogicalDisk -ComputerName $server -Filter "DeviceID='C:'"
    $startingFreeSpace = $disk.FreeSpace
    
    Try{
        Start-Process -FilePath "C:\Windows\System32\cmd.exe" -ArgumentList " /c DISM.exe /online /Cleanup-Image /SpSuperseded" -Wait -ErrorAction Stop
        }
    Catch {
        Write-Host -ForegroundColor Red "ERROR Clearing service pack files on $server | Message:  $($_.Exception.Message)" 
        Write-Log "ERROR Clearing service pack files on $server | Message:  $($_.Exception.Message)"; $Script:errCount ++ ; $Error.Clear()
        }
    Finally{
        $ErrorActionPreference = "Continue"
        }

    #Find Ending Free Space
    $disk = Get-WmiObject Win32_LogicalDisk -ComputerName $server -Filter "DeviceID='C:'"
    $endingFreeSpace = $disk.FreeSpace

    #Adding to total sapce saved
    $Script:totalSpace += ($endingFreeSpace - $startingFreeSpace)
}#End Clear-SP1Files

Function Get-ProfileSizes{
[CmdletBinding(SupportsShouldProcess=$true,
               ConfirmImpact='Medium')]
Param ([parameter(Mandatory=$true,
        HelpMessage="Target server must be specified")]
        [alias("Computer","MachineName","Target")]
        [string]$server
        )
    #Had to do it this way because 2003 doesn't suport Get-WMIObject Win32_UserProfile

    #Determining user profile path
    If( ((Get-OS -server $server) -like "*2008*") -or ((Get-OS -server $server) -like "*2012*") ){
        $arrUsers = Get-ChildItem "\\$server\C$\Users" -ErrorAction SilentlyContinue
        }
    ElseIf( ((Get-OS -server $server) -like "*2003*") -or ((Get-OS -server $server) -like "*2000*") ){
        $arrUsers = Get-ChildItem "\\$server\C$\Documents and Settings" -ErrorAction SilentlyContinue
        }
    
    #Building profile path for each user
    foreach($user in $arrUsers){
        If( ((Get-OS -server $server) -like "*2008*") -or ((Get-OS -server $server) -like "*2012*") ){
            $userPath = "\\$server\C$\Users\$user"
            }
        ElseIf( ((Get-OS -server $server) -like "*2003*") -or ((Get-OS -server $server) -like "*2000*") ){
            $userPath = "\\$server\C$\Documents and Settings\$user"
            }
        $profileSize = (Get-ChildItem $userPath -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -property length -sum)
        $profileSizeShort = "{0:N0}" -f $($profileSize.Sum /1MB)
        If( (($profileSize.Sum / 1MB) -ge $Script:ProfSize) -and ($user -notlike "*user*")-and ($user -notlike "*public*")){ $Script:arrTooBig += "$user | $profileSizeShort MB"}
        }
}#End Get-ProfileSizes

Function Clear-Profiles{
[CmdletBinding(SupportsShouldProcess=$true,
               ConfirmImpact='Medium')]
Param ([parameter(Mandatory=$true,
        HelpMessage="Target server must be specified")]
        [alias("Computer","MachineName","Target")]
        [string]$server
        )
    $space = 0
    If( ((Get-OS -server $server) -like "*2008*") -or ((Get-OS -server $server) -like "*2012*") ){
        $arrUsers = Get-ChildItem "\\$server\C$\Users" -ErrorAction SilentlyContinue
        }
    ElseIf( ((Get-OS -server $server) -like "*2003*") -or ((Get-OS -server $server) -like "*2000*") ){
        $arrUsers = Get-ChildItem "\\$server\C$\Documents and Settings" -ErrorAction SilentlyContinue
        }
    
    foreach($user in $arrUsers){
    If (($user -notlike "*system*") -and ($user -notlike  "*service*") -and ($user -notlike  "*Public*") -and ($user -notlike  "*default*") -and ($user -notlike  "*$*")){
        If( ((Get-OS -server $server) -like "*2008*") -or ((Get-OS -server $server) -like "*2012*") ){
            $user = "\\$server\C$\Users\$user"
            }
        ElseIf( ((Get-OS -server $server) -like "*2003*") -or ((Get-OS -server $server) -like "*2000*") ){
            $user = "\\$server\C$\Documents and Settings\$user"
            }
        #$user = "\\$server\C$\$user"        
        $arrPath = @()
        If( ((Get-OS -server $server) -like "*2008*") -or ((Get-OS -server $server) -like "*2012*") ){
            $arrPath += "$user\AppData\Local\Microsoft\Windows\WER\ReportArchive"
            $arrPath += "$user\AppData\Local\Microsoft\Windows\WER\ReportQueue"
            $arrPath += "$user\AppData\Local\Temp"
            $arrPath += "$user\AppData\Local\Temporary Internet Files"
            $arrPath += "$user\AppData\LocalLow\Sun\Java\Deployment\cache\6.0"
            }
        If( ((Get-OS -server $server) -like "*2003*") -or ((Get-OS -server $server) -like "*2000*") ){
            $arrPath += "$user\Local Settings\Application Data\PCHealth\ErrorRep\QSIGNOFF\QSIGNOFF"
            $arrPath += "$user\Local Settings\Application Data\PCHealth\ErrorRep\QSIGNOFF\UserDumps"
            $arrPath += "$user\Local Settings\Application Data\Temp"
            $arrPath += "$user\Local Settings\Application Data\Temporary Internet Files"
            $arrPath += "$user\Application Data\Sun\Java\Deployment\cache\6.0"
            }
        ForEach($path in $arrPath){
            If(Test-Path $path){
            $items = Get-ChildItem $path -Recurse -Force -ErrorAction SilentlyContinue
                foreach($item in $items){
                #Iterate and look for old items
                If ($item.LastWriteTime -lt $Script:logFileThreshold)
                    {
                        $size = $item.Length
                        If(Test-Path $item.FullName -ErrorAction SilentlyContinue){
                            Try{
                                Remove-Item -Path $item.FullName -Force -Recurse -ErrorAction Stop
                                $space += $size
                                $Script:fileCount ++
                                }
                            Catch {
                                Write-Host -ForegroundColor Red "ERROR removing $($item.FullName) on $server `nMessage:  $($_.Exception.Message)"
                                Write-Log -logstring "ERROR removing $($item.FullName) on $server `nMessage:  $($_.Exception.Message)"; $Script:errCount ++ ; $Error.Clear()
                                }                           
                            }                        
                    }
                }
                $Script:totalSpace += $space
            }
        }
        }
     }
}#End Clear-Profiles

Function Write-Event{
[CmdletBinding(SupportsShouldProcess=$true,
               ConfirmImpact='Medium')]
Param ([parameter(Mandatory=$true,
        HelpMessage="Target server must be specified")]
        [alias("Computer","MachineName","Target")]
        [string]$server,
        [parameter(Mandatory=$true,
        HelpMessage="Event Log text must contain data.")]
        [alias("event")]
        [string]$body
        )

#Check to see if custom event exists
$customEvent = Get-EventLog Application -ComputerName $server | Group-Object -Property Source | Where-Object {$_.name -eq "System Drive Clearup Script"}
If (-not($customEvent)) {
    New-EventLog -LogName Application -Source "System Drive Clearup Script"
    }

#Add entry to application log on server
If ($Script:errCount -gt 0){
    Try{
        Write-EventLog -ComputerName $server Application -Source "System Drive Clearup Script" -EventId 1 -Message $body -EntryType Error -ErrorAction Stop
        }
    Catch{
        Write-Host -ForegroundColor Red "ERROR writing to event log on $server `nMessage:  $($_.Exception.Message)" 
        Write-Log -logstring "ERROR writing to event log on $server `nMessage:  $($_.Exception.Message)"; $Script:errCount ++ ; $Error.Clear()        
        }
    }
Else{
    Try{
        Write-EventLog -ComputerName $server Application -Source "System Drive Clearup Script" -EventId 0 -Message $body -EntryType Information -ErrorAction Stop
        }
    Catch{
        Write-Host -ForegroundColor Red "ERROR writing to event log on $server `nMessage:  $($_.Exception.Message)" 
        Write-Log -logstring "ERROR writing to event log on $server `nMessage:  $($_.Exception.Message)"; $Script:errCount ++ ; $Error.Clear()
        }
    }
}#End Write-Event

Function Find-ISO{
[CmdletBinding(SupportsShouldProcess=$true,
               ConfirmImpact='Medium')]
Param ([parameter(Mandatory=$true,
        HelpMessage="Target server must be specified")]
        [alias("Computer","MachineName","Target")]
        [string]$server)
    $space = 0
    $items = Get-ChildItem "\\$server\C$" -Recurse -Force -Filter "*.iso" -ErrorAction SilentlyContinue
        foreach($item in $items){
            $size = $item.Length
            Write-Host -ForegroundColor Yellow "ISO Found: $($item.FullName) on $server"; $Script:arrISO += $item.FullName; $Script:isoCount ++
            Write-Log -logstring "ISO Found: $($item.FullName) on $server"
            $space += $size
            }
        $Script:isoSpace += $space
}#End Find-ISO

Function Create-Report{
[CmdletBinding(SupportsShouldProcess=$true,
               ConfirmImpact='Medium')]
Param ([parameter(Mandatory=$true,
        HelpMessage="Target server must be specified")]
        [alias("Computer","MachineName","Target")]
        [string]$server)
    #Create report subject and body
    $body = "======================================================================= `n"
    $body += "Date Run:  $(Get-Date) `n"
    $body += "Run by: $env:USERNAME `n"
    $body += "Server: $($server) `n"
    $body += "Operating System: $(Get-OS -server $server) `n"
    $body += "Service Pack Level: $((Get-OS -server $server).ServicePackMajorVersion) `n"
    $body += "Page File Location: $Script:pageFileLoc `n"
    $body += "Items removed:  $Script:fileCount `n"
    $body += "Total space saved:  $([math]::Truncate($Script:totalSpace / 1MB)) MB `n"
    $body += "Total errors:  $Script:errCount `n"
    If ($Script:errCount -gt 0){
        $body += "Error log file location on $($env:COMPUTERNAME):  $Logfile `n"
        }
    If ($Script:isoCount -gt 0){
        $body += "Total ISOs found:  $Script:isoCount `n"
        $body += "Total ISOs size:  $([math]::Truncate($Script:isoSpace / 1MB)) MB `n"
        $body += "ISO locations can be found on $($env:COMPUTERNAME) in the following locations: `n"
        foreach($iso in $Script:arrISO){
            $body += "$iso `n"
            }
        }
    #List large profiles
    $body += "Profiles larger than $($Script:ProfSize) MB: $(($Script:arrTooBig).count) `n"
    Foreach($tooBig in $Script:arrTooBig){
        $body += "$tooBig `n"
        }
    $Script:body = $body
}#End Create-Report
#endregion

#region Script Execution
#Set log file path for error handling purposes
    If(-not(Test-Path C:\Temp)){
        Try{
            New-Item -ItemType Directory -Path C:\Temp -Force -ErrorAction Stop
            $Prefix = "C:\Temp"
            }
        Catch{
            Write-Host -ForegroundColor Red "ERROR creating C:\Temp directory locally.`nMessage:  $($_.Exception.Message)"
            $Prefix = Read-Host "Type path where you'd like the log file saved. (Ex. C:\Temp)"
            }
        }

$servers = Read-Host 'Please give the server name(s) that you would like to Clear in the following format. (ServerA,ServerB,ServerC)'
$servers = $servers.Split(',')
ForEach($server in $servers){
    
  If(Verify-Access $server){
    #Clear all variables
    $Script:fileCount = 0; $Script:errCount = 0; $Script:totalSpace = 0; $Script:pageFileLoc = ""; $Script:arrTooBig = @()
    $Script:isoSpace = 0; $Script:isoCount = 0; $Script:arrISO = @(); $body = ""
    $Script:LogFile = Join-Path $Prefix, "systemDriveCleanup_$server"+"_$(Get-Date -UFormat "%m-%d-%Y").log"
    Write-Host -ForegroundColor Green "Clearing Patch Cache on $server"
    Clear-PatchCache -server $server
    Write-Host -ForegroundColor Green "Clearing log files on $server"
    Clear-Logs -server $server
    Write-Host -ForegroundColor Green "Clearing dump files on $server"
    Clear-Dumps -server $server
    Write-Host -ForegroundColor Green "Clearing Recycler on $server"
    Clear-Recycler -server $server
    Write-Host -ForegroundColor Green "Clearing Temp on $server"
    Clear-Temp -server $server 
    Write-Host -ForegroundColor Green "Clearing Error Reports on $server"
    Clear-ErrorReports -server $server
    Write-Host -ForegroundColor Green "Clearing up profiles on $server"
    Clear-Profiles -server $server 
    Write-Host -ForegroundColor Green "Looking for large profiles on $server"
    Get-ProfileSizes -server $server
    Write-Host -ForegroundColor Green "Getting page file locaion on $server"
    Get-PageFile $server
    Write-Host -ForegroundColor Green "Searching for ISOs on $server"
    Find-ISO -server $server
    If ( ((Get-OS -server $server) -like "*2008 R2*") -and ((Get-OS -server $server).ServicePackMajorVersion -eq "1") ){
        Write-Host -ForegroundColor Yellow "Cleaning SP1 files.  Please Note:  Process can take up to ten minutes"
        Clear-SP1Files $server
        }
    Write-Host -ForegroundColor Green "Generating report for $server"
    Create-Report -server $server
    Write-Host -ForegroundColor Green "Writing to event log on $server"
    Write-Event -server $server -body $Script:body
    Write-Host -ForegroundColor Green "Sending email report for $server"
    Send-Mail -body $Script:body -domain $env:USERDOMAIN -logonServer $env:LOGONSERVER
    Write-Host "System drive Cleanup on $server is complete" -ForegroundColor Green
    Write-Host $Script:body
    }
  }

Write-Host "All servers are complete.  Review log files written at $Logfile for summary and errors." -ForegroundColor Green
#endregion