# http://pauerschell.blogspot.com/2010/03/powershell-and-network-drives.html
# This is a v2 way to do it.  V3 and above, use *-PSDrive

<#
    V3+ Use this
    New-PSDrive -Name P -PSProvider FileSystem -Root \\2012R2-MS\C$

$old = "2012R2-MS"
$new = "2012R2-DC"

$drives = Get-PSDrive | Where-Object {$_.Root -like "*2012R2-MS*"}
foreach($d in $drives){
    $d
    Remove-PSDrive -Name $d.Name -Force
    New-PSDrive  -Name $d.Name -PSProvider FileSystem -Root ($d.Root).Replace($old,$new)
    Get-PSDrive -Name $d.Name
}
#>
function New-NetworkDrive            
{            
<#
.synopsis  
    A function to create Networkdrives
.Example
    New-NetworkDrive 'x' '\\localhost\C$'
.Example
    New-NetworkDrive 'Y:' '\\localhost\C$\Windows'      
#>            
    Param(            
        [string]$Drive,            
        [string]$Unc            
        )            
    $net = New-Object -ComObject WScript.Network            
    if ($Drive.Length -eq 1) { $Drive = $Drive +':' }          
    $net.MapNetworkDrive($Drive, $Unc)               
}            
            
            
function Get-NetworkDrive            
{            
<#
.synopsis  
    A function to list the currently mapped Networkdrives
.Example
    Get-NetworkDrives
#>            
    $mappedDrives = @{}            
    $net = New-Object -ComObject WScript.Network             
    $a = $net.EnumNetworkDrives()            
    $anz = $a.count()            
                
    for ($i = 0; $i -lt $anz; $i = $i + 2)            
    {            
        $drive = $a.item($i)            
        $path = $a.item($i+1)            
        $mappedDrives[$drive] = $path            
    }            
    $script:mappings = $mappedDrives            
}            
            
function Remove-NetworkDrive           
{            
<#
.SYNOPSIS  
    A function to remove Networkdrives
.EXAMPLE
    Remove-NetworkDrive X
.EXAMPLE
    Remove-NetworkDrive Y:      
#> 
Param([string]$Drive)            
    $net = New-Object -ComObject WScript.Network            
    if ($Drive.Length -eq 1) { $Drive += ':' }            
    $net.RemoveNetworkDrive($Drive,1)            
    Invoke-Expression "Net Use $Drive /delete" -ErrorAction SilentlyContinue
}  

$netDrives = Gwmi Win32_LogicalDisk -Filter "DriveType = 4"
foreach($drive in $netDrives){
    if($drive.DeviceID -eq $netDriveLetter){
        $net.RemoveNetworkDrive($netDriveLetter)
    }
}

# Script Execution

$oldSrvr = "nsct-sfile"
$newSrvr = "brconfilsrv1"
$errLog = "$env:TEMP\driveMapping.log"

Get-WmiObject -Class Win32_LogicalDisk -Filter "DriveType=4" | Where-Object {$_.ProviderName -like "*$oldSrvr*"} | `
ForEach-Object {
        # If found, remove it
        Try{
            Remove-NetworkDrive -Drive $_.Name
            }Catch{
            Add-Content -Path $errLog -Value "Unable to remove drive: $($_.Name) due to $($_.Exception.Message)"
            }
        $newVal = $_.Value -replace $oldSrvr,$newSrvr
        Try{
            New-NetworkDrive -Drive $_.Name -Unc $newVal
            }Catch{
            Add-Content -Path $errLog -Value "Unable to add drive: $($_.Name) due to $($_.Exception.Message)"
            }
        }
    
    }          
