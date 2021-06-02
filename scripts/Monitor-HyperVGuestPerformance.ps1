#requires -Version 3
<#

        .NOTES  

        File Name  	: Monitor-HyperVGuestPerformance.ps1  
        Version		: 0.97
        Author     	: Ruud Borst - ruud@ruudborst.nl
        Reviewer	: Darryl van der Peijl - darrylvanderpeijl@outlook.com
        Requires   	: PowerShell V3+

        .LINK  

        http://www.ruudborst.nl
        
        .LINK  

        https://gallery.technet.microsoft.com/Show-Hyper-V-Virtual-652fdd54
	
        .SYNOPSIS

        This GUI based Hyper-V VM Guest Performance monitoring tool collects and processes VM Guest Performance Statistics over a specified period of time from discovered or manually specified Hyper-V hosts.

        .DESCRIPTION

        Retrieve, show or export realtime Hyper-V Guest VM Performance Statistics. This GUI-based tool retrieves cpu,memory,disk i/o and network statistiscs from inside the guest. 
        All information is retrieved via WMI and ADSI, no modules required, run on any domain or cluster joined server.
        After collecting all host information the script opens up a PowerShell runspacepool and creates a local runspace job executing 'get-counter' for each Hyper-V host found.
        Finally a gridview output will be presented with a overview of all VM's and associated counters plus all _totals on the platform. 
        Each counter counter represents performance data from inside the guest itself, CPU is the actual total CPU usage in the VM. 
        The same applies for the disk and network values they are representing the total sum of all disks/interfaces combined. 
        Specify the '-ExportToCsv' parameter for exporting the statistics to file and -PSobjects for returning all objects in the console for further processing.

        All information is retrieved via WMI and ADSI is used for Hyper-V host discovery using global catalog queries. 
        No modules required whatsoever, script can be executed on any domain or cluster joined member server.

        .PARAMETER Name
         Enter one or more Hyper-V Hosts to collect VM Guest Performance Statistics from, used with '-PSobjects' parameter. 
        
        .PARAMETER ExportToCsv
         Supply this switch parameter without value for exporting the data to CSV instead.
        
        .PARAMETER ExportToCSVPath
         Enter the directory path to export the CSV file in, defaults to current directory.
        
        .PARAMETER PSobjects
         Use this parameter to return PSobjects as output instead, GUI is not used so '-Name' parameter is required to enter the Hyper-V hosts manually.
        
        .PARAMETER MaxSamples
         Enter the number of samples to take, defaults to 1. 
       
        .PARAMETER Interval
         Enter the interval to wait between the samples, defaults to 1.

        .EXAMPLE 
         .\Monitor-HyperVGuestPerformance.ps1
         Runs GUI by default with configurable samples, interval and select or add Hyper-V Hosts.

         .EXAMPLE 
         .\Monitor-HyperVGuestPerformance.ps1 -PSobjects
         Returns PSobjects as output instead of running the GUI. 
         Great for parsing and logging, -name parameter is optional, defaults to automatic discovery of hosts.

        .EXAMPLE 
         .\Monitor-HyperVGuestPerformance.ps1 -Interval 2 -MaxSamples 5 -PSobjects
         The '-Interval' and '-Maxsamples' parameters are optional and default to 1 when not specified.
         
        .EXAMPLE 
         .\Monitor-HyperVGuestPerformance.ps1  -Name Host1,Host2 -PSobjects
         Specify Hyper-V hosts manually instead of the deault automatic discovery of hosts.

         .EXAMPLE 
         'Host1','Host2' | .\Monitor-HyperVGuestPerformance.ps1 -PSobjects
         Script accepts pipeline input, input is processed as the name parameter.

        .EXAMPLE 
         Monitor-HyperVGuestPerformance.ps1 -ExportToCsv -ExportToCSVPath 'd:\export'
         Export results to CSV when clicking 'Collect' in the GUI instead of displaying the results in 'Out-GridView'.
         The '-ExportToCSVPath' is optional and defaults to current working directory when not specified.

#>

[CmdletBinding(SupportsShouldProcess = $true,DefaultParameterSetName = 'PSobjects')]
Param(
    [Parameter(ParameterSetName = 'PSobjects',ValueFromPipeline = $true,ValueFromPipelineByPropertyName = $true,HelpMessage = 'Enter one or more Hyper-V Hosts to collect
    VM performance statistics from.')] 
    [Alias('ComputerName')] 
    [ValidateLength(2,200)]      
    [string[]]$Name,
    [Parameter(ParameterSetName = 'Csv',HelpMessage = 'Supply this switch parameter without value
    for exporting the data to csv instead.')]  
    [switch]$ExportToCsv,
    [Parameter(ParameterSetName = 'Csv',HelpMessage = 'Enter the directory path to export the CSV file in,
    defaults to current directory.')]  
    [ValidateScript({
                Test-Path $_
    })]
    [string]$ExportToCSVPath = '.',
    [Parameter(ParameterSetName = 'PSobjects')] 
    [switch]$PSobjects, 
    [Parameter(HelpMessage = 'Enter the number of samples to take, defaults to 1.')] 
    [ValidateRange(1,99999)]
    [int]$MaxSamples = 1,
    [Parameter(HelpMessage = 'Enter the interval to wait between the samples, defaults to 1.')] 
    [ValidateRange(1,99999)]
    [int]$Interval = 1
)

BEGIN {

    # 
    # Prerequisites check
    ##

    if (!([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) 
    {
        Write-error -Message "`nThis session is running under non-admin priviliges.`nPlease restart with Admin priviliges (runas Administrator)." 
        break
    } # end if admin check


    # 
    # Functions
    ##

    # Find hosts in AD,Cluster or LocalHost configuration.
    Function Find-Hosts 
    {

    [CmdletBinding()]

        $Hosts = @()

        # Retrieve Hyper-V hosts from AD and store them in the Hosts array

        try 
            {

        if ([System.DirectoryServices.ActiveDirectory.Domain]::GetComputerDomain())
        {
            
                $ComputerDomain = [System.DirectoryServices.ActiveDirectory.Domain]::GetComputerDomain()
                $objDomain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
                $Root = [ADSI]"GC://$($objDomain.Name)"
                $Searcher = New-Object -TypeName System.DirectoryServices.DirectorySearcher -ArgumentList ($Root)
                $Searcher.PageSize = 1000
                $Searcher.filter = '(&(objectClass=computer)(serviceprincipalname=*Microsoft Virtual Console Service*))'
   
                $Searcher.findall() |
                Sort-Object |
                ForEach-Object -Process {
                    $Hosts += $_.properties.dnshostname
                } # end foreach hosts 
            } # end if getcomputerdomain
          }
          catch 
          {
            # do nothing, proceed
          }

        if ($Hosts.count -gt 0)
        {
            Write-Verbose -Message ' Found Hyper-V hosts in Active Directory.'
        }

        # Retrieve hosts from local cluster information when they could not be found in AD

        $ClusterModule = Get-Module -Name FailoverClusters -ListAvailable

        if ($ClusterModule -and $Hosts.count -eq 0) 
        {
            Write-Warning -Message 'Could not retrieve Hyper-V hosts from Active Directory.'
            Import-Module $ClusterModule
            Write-Verbose -Message 'Cluster Module found and imported, trying to retrieve active Hyper-V hosts from cluster information.' 
        
            Start-Sleep -Seconds 1

            $Nodes = get-clustergroup |
            Where-Object -FilterScript {
                $_.grouptype -eq 'VirtualMachine'
            } |
            Select-Object -Property ownernode -Unique 
            if ($Nodes) 
            {
                $Nodes | ForEach-Object -Process {
                    $Hosts += $_.ownernode
                }
            } # end if hosts

            if ($Hosts.count -eq 0)
            {
                Write-Warning -Message 'Couldn''t retrieve Hyper-V hosts from Cluster information'
            }
            else 
            {
                Write-Verbose -Message 'Hyper-V hosts found in cluster information.'
            }
        }
        elseif ($Hosts.count -eq 0) 
        {
            Write-Warning -Message 'Could not retrieve any Hyper-V host from AD or Cluster information. Trying localhost ...'

            if (!$Name){
            $cluswarningmessage = 'Could not retrieve any Hyper-V host from LocalHost, AD or Cluster information, specify hosts manually.'
            } else {
            $cluswarningmessage = 'Could not retrieve any Hyper-V host from LocalHost, AD or Cluster information, using ''-Name'' parameter input only.'
            }

            try 
            { 
                if ((Get-WindowsOptionalFeature -FeatureName Microsoft-Hyper-V -Online).state -eq 'enabled') 
                {
                    $Hosts += $env:computername
                    Write-Verbose -Message 'Found standalone Hyper-V host on localhost.'
                }
                else 
                {
                    Write-Warning -Message $cluswarningmessage
                }
            }
            catch 
            {
                Write-Warning -Message $_.exception.message
                Write-Warning -Message $cluswarningmessage
            }
        } # end if clustermodule

        return $Hosts
    } # end function find-hosts

    # Get Performance Statistics samples from supplied Hyper-V hosts through WMI
    Function Get-VMGuestSamples 
    {
        [CmdletBinding(SupportsShouldProcess = $true)]
        Param(
            [Parameter(ValueFromPipeline = $true,ValueFromPipelineByPropertyName = $true,HelpMessage = 'Enter one or more hosts')] 
            [Alias('ComputerName','Server','Host')]     
            [ValidateLength(2,200)]
            [string[]]$Name = 'localhost',
            [Parameter(HelpMessage = 'Enter the number of samples to take.')] 
            [ValidateRange(1,99999)]
            [int]$MaxSamples = 1,
            [Parameter(HelpMessage = 'Enter the interval to wait between the samples.')] 
            [ValidateRange(1,99999)]
            [int]$Interval = 1
        )

        # Instantiate hash tables
        $InstanceToVM = @{}
        $VMToLoc = @{}
        $DiskPathToLoc = @{}
        $VMHDPaths = @{}
        $Hosts = @()
        $ElementNametoMASinfo = @{}
        $HVContainer = @{}
        $HostToBuild = @{}
	
    ## 1. First process each host in -Name parameter variable and retrieve/populate all VM and diskpath information in virtualization namespace to match counter information against

        $hostcount = $Name.count
        $Name | ForEach-Object -Process {

        $HypervHost = $_

            $net = new-object net.sockets.tcpclient

            try {
            $net.Connect($HypervHost,135)
            } catch {
            write-warning "[$HypervHost]`nCould not connect to TCP port 135, ensure network connectivity, skipping host ..."
            }

            if ($net.Connected){
		    
            # Generate progress bar
            $Index = [array]::IndexOf($Name,$_) 
            $Percentage = $Index / $hostcount
            $Message = "Pulling Hyper-V VM and Disk information ($Index of $hostcount)"
            Write-Progress -Activity $Message -PercentComplete ($Percentage * 100) -CurrentOperation $HypervHost

            # WMI query matching VM with elementname
            $VMQuery = 'Select name,elementname From Msvm_ComputerSystem'

            $WMIDiskPaths = $null
            $VMwmi = $null
            $V2Namespace = 'root\virtualization\v2'
            $V1Namespace = 'root\virtualization'
            
            # Retrieve all vhd(x) disk paths from Hyper-V host using V2 virtualization namespace (2012 R2+)
            # Try/catch used for access denied errors, silentlycontinue doesn't prevent these errors so we have to catch them
            try {
            $WMIDiskPaths = Get-WmiObject -Namespace $V2Namespace -Query "select instanceid,HostResource from Msvm_StorageAllocationSettingData where ResourceSubType = 'Microsoft:Hyper-V:Virtual Hard Disk'" -ErrorAction SilentlyContinue -ComputerName $_
            } catch {
            }

            # Try another namespace (before 2012 R2) when disk virtualization information could not be obtained through WMI and retrieve all VM to elementname information
            if (!$WMIDiskPaths)
            {
                try {
                $WMIDiskPaths = Get-WmiObject -Namespace $V1Namespace -Query "select instanceid,connection from Msvm_ResourceAllocationSettingData where ResourceSubType = 'Microsoft Virtual Hard Disk'" -ErrorAction SilentlyContinue -ComputerName $_
                } catch {
                }
                # Issue a warning when the older namespace could not be retrieved, when it is there continue and retrieve all VM's.
                if (!$WMIDiskPaths){
                Write-warning "[$_] Could not retrieve virtualization information via WMI, be sure the Host has the Hyper-V role enabled and the account running this script has administrative access. Skipping host ..." 
                } else {
                $VMwmi = Get-WmiObject -Namespace $V1Namespace -Query $VMQuery -ComputerName $_
                } # end if

            } else {
                $VMwmi = Get-WmiObject -Namespace $V2Namespace -Query $VMQuery -ComputerName $_
            } # end if  
            
            # Populate hash table with instance/elementname to VM reference
            if ($VMwmi){
            $hosts+=$HypervHost
                $VMwmi | ForEach-Object -Process {
                $InstanceToVM[$_.name] = $_.elementname
                } # end foreach
            
              $OSBuild = (gwmi win32_operatingsystem -ComputerName $_).buildnumber
              $HostToBuild[$_] = $OSBuild

             # Detect Windows Server 2016 before executing unnecessary Azure Stack and Hyper-V Container queries

             if ($OSBuild -ge 14393) {

              # Detect Microsoft Azure Stack VM's and populate ElementNametoMASinfo hash
              
               if ($VMwmi.elementname -match '^(\{|\()?[A-Za-z0-9]{4}([A-Za-z0-9]{4}\-?){4}[A-Za-z0-9]{12}(\}|\()?$') {

                Get-WmiObject -Namespace 'root\virtualization\v2' -Query "select elementname,notes from Msvm_VirtualSystemSettingData where VirtualSystemType = 'Microsoft:Hyper-V:System:Realized'"  -ComputerName $_ | % { 
	            $notes   = $_.notes            
                
                # Detect MAS info note
	            if ($notes -match 'ResourceGroup'){
                $MASinfo = ($notes -split ', ') -replace '.*?:.'
                $ElementNametoMASinfo[$_.elementname] = $MASinfo
                    } # end if notes
              } # end foreach
            
            } # end if Vmwi guid match

            # Detect running Hyper-V containers and store scratchvhd to hash

            $HKLM = [UInt32] "0x80000002"
            $registry = [WMIClass] "\\$_\root\default:StdRegProv"

            $Instances = ($registry.EnumKey($HKLM, "SOFTWARE\Microsoft\Windows NT\CurrentVersion\HostComputeService\VolatileStore\ComputeSystem")).snames
            $Instances | % { 
            $ScratchVHD = ($registry.GetStringValue($HKLM, "SOFTWARE\Microsoft\Windows NT\CurrentVersion\HostComputeService\VolatileStore\ComputeSystem\$_","ScratchVhd")).sValue
            
                if ($ScratchVHD) {

                $HVContainer[$_]=$ScratchVHD

                $ScratchVHDR = $ScratchVHD -replace '\\', '-' 
                $ScratchVHDR = $ScratchVHDR -replace '\(', '['
                $ScratchVHDR = $ScratchVHDR -replace '\)', ']'
                $ScratchVHDR = $ScratchVHDR -replace '-volume\d{1,2}', ''
                $VMHDPaths[$ScratchVHDR] = $_
               

                        if ($ScratchVHD -match 'volume\d{1,2}')
                        {
                            $VMToLoc[$_] += @($matches[0])
                            $DiskPathToLoc[$ScratchVHDR] = $matches[0]
                        }
                        else
                        {
                            try {$VMToLoc[$_] += @($matches[2])}catch{}
                            $DiskPathToLoc[$ScratchVHDR] = 'LocalDisk'
                        }
            
                } # end if scratchvhd

            } # end foreach instance

          } # end Windows Server 2016 check

		    # Populate hash tables referencing VM to location(s), diskpath to location and diskpath to VM's
            $VMi = $null
            $WMIDiskPaths | ForEach-Object -Process {
                [string]$DiskPath = $psitem.connection
                if (!$DiskPath)
                {
                    $DiskPath = $psitem.HostResource
                }
                $instance = $_.instanceid -match ':(.*?)\\'
                $instance = $matches[1]
                $VMi = $InstanceToVM[$instance]

                # Find the disks parent config to retrieve the VM intanceid when the disk can't be associated with the VM by using getrelated WMI method (associaters of)

                if (!$VMi -and $DiskPath){
                $instance = ($psitem.getRelated('Msvm_VirtualSystemSettingData') | select-object -Unique).VirtualSystemIdentifier
                $VMi = $InstanceToVM[$instance]
                }


                if ($DiskPath) 
                {
                    $DiskPathN = $DiskPath -replace '\\', '-' 
                    $DiskPathN = $DiskPathN -replace '\(', '['
                    $DiskPathN = $DiskPathN -replace '\)', ']'
                    $DiskPathN = $DiskPathN -replace '-volume\d{1,2}', ''

                    if ($DiskPath -match 'volume\d{1,2}' -and $VMi)
                    {
                        $VMToLoc[$VMi] += @($matches[0])
                        $DiskPathToLoc[$DiskPathN] = $matches[0]
                    }
                    elseif($DiskPath -match '\\\\(.*?)\\(.*?)\\')
                    {
                        $VMToLoc[$VMi] += @($matches[2])
                        $DiskPathToLoc[$DiskPathN] = $matches[2]
                    }
                    elseif($VMi)
                    {
                        $VMToLoc[$VMi] += @($matches[2])
                        $DiskPathToLoc[$DiskPathN] = 'LocalDisk'
                    }

                    $VMHDPaths[$DiskPathN] = $VMi
                } # end if diskpath
            } # end foreach wmidiskpaths

           } # end if virtualization
          } # end if net.connected
        } # end foreach name




    ## 2. Create parallel threads for the get-counter cmdlet containg the Hyper-V Guest counters locally and run it against each Hyper-V host found in the -Name parameter variable.



        # Create the PS RunspacePool and create a thread (runspace) for each host
        # We will be using the runspacepool to process jobs, native PS jobs have problems with outputting counter perf object data

        $Name = $Hosts

        if ($Name.Count -eq 1)
        {
            $MaxThreads = $Name.Count + 1
        }
        elseif ($Name.Count -lt 1)
        {
           Write-error 'No hosts left to retrieve perfomance samples from, please fix any issues or specify other hosts to the -Name parameter. Aborting script ...'
        }  else 
        {
            $MaxThreads = $Name.Count
        }

        if ($RunspacePool) 
        {
            $RunspacePool.Dispose()
            $RunspacePool = $null
        }
        $RunspacePool = [RunspaceFactory]::CreateRunspacePool(1, $MaxThreads)
        $RunspacePool.Open()

        # Executes the built-in cmdlet 'get-counter' as a job with multiple perfmon counters and does that for each Hyper-V host. 
        # Each job is executed on the machine where this script is started from. This machine makes a connection to each host via the -computername paramater 

        $Jobs = @()
        $Name | ForEach-Object -Process {
            $HypervHost = $_
            $Counterscriptblock = {
                param ($HypervHost,$MaxSamples,$Interval)
                $Counters = @('\Hyper-V Virtual Storage Device(*)\Queue Length','\Hyper-V Virtual Storage Device(*)\Write Operations/sec','\Hyper-V Virtual Storage Device(*)\Read Operations/sec','\Hyper-V Virtual Storage Device(*)\Write Bytes/sec', '\Hyper-V Virtual Storage Device(*)\Read Bytes/sec', '\Hyper-V Hypervisor Virtual Processor(*)\% Total Run Time', '\Hyper-V Dynamic Memory VM(*)\Physical Memory', '\Hyper-V Dynamic Memory VM(*)\Guest Visible Physical Memory', '\Hyper-V Virtual Network Adapter(*)\Bytes Received/sec', '\Hyper-V Virtual Network Adapter(*)\Bytes Sent/sec')
                
                $Splat = @{
                Counter = $Counters
                ComputerName = $HypervHost
                MaxSamples = $MaxSamples
                SampleInterval = $Interval
                }

                if ($HyperVHost -match "localhost|$($env:computername)"){
                $Splat.Remove('ComputerName')
                }

                Get-Counter @Splat

            } # end scriptblock

            $Job = [powershell]::Create().AddScript($Counterscriptblock).AddArgument($HypervHost).AddArgument($MaxSamples).AddArgument($Interval)
            $Job.RunspacePool = $RunspacePool
            $Jobs += New-Object -TypeName PSObject -Property @{
                Pipe   = $Job
                Result = $Job.BeginInvoke()
            }
        } # end foreach host

        # Defining waittext based on seconds or minutes.
        $WaitTime = $Interval * $MaxSamples
        $WaitTimetext = "Collecting samples for $WaitTime seconds."  
        if ($WaitTime -gt 60)
        {
            $WaitTimeM = [Math]::Round(($WaitTime / 60),2)
            $WaitTimetext = "Collecting samples for $WaitTimeM minutes."
        }

        # Shows the progress bar until the execution time in $Waittime (seconds) passes
        $datestart = Get-Date
        $i = 0
        while ($i -le $WaitTime)
        {
            $Percentage = $i / $WaitTime
            $Remaining = New-TimeSpan -Seconds ($WaitTime - $i)
            $Message = '{0:p0} complete, remaining time {1}' -f $Percentage, $Remaining
            Write-Progress -Activity $Message -PercentComplete ($Percentage * 100) -CurrentOperation $WaitTimetext
            Start-Sleep -Seconds 1
            $i++
        } # end while 
        $dateend = Get-Date

        # Checks if all jobs have returned, if not show the progress bar again and countdown the running jobs
        $Message = 'Waiting for all jobs to return.'
        do 
        {
            $Jobcount = $Jobs.count
            $ActiveJobCount = ($Jobs.Result.IsCompleted | Where-Object -FilterScript {
                    $_ -contains $false
            }).count
            if ($ActiveJobCount -gt 0)
            {
                Write-Progress -Activity $Message -PercentComplete 100 -CurrentOperation "$ActiveJobCount out of $Jobcount runspaces are still running.."
                $Message += '.'
                Start-Sleep -Seconds 1
            } # end if
        }
        While ($Jobs.Result.IsCompleted -contains $false)

        # Collect all job results and store the results in a array
        $Results = @() 
        $Jobs | ForEach-Object -Process {
            $Results += $_.Pipe.EndInvoke($_.Result)
        }

        # Disposes and clears the RunSpacepool
        $RunspacePool.Dispose()
        $RunspacePool = $null

    ## 3. Processing the samples in the $results array, matching them with the VM's retrieved from the virtualization info and storing all information in speedy hashtables

        $VMIOHash = @{}
        $VMHostHash = @{}
        $VMCPUHash = @{}
        $VMMemHash = @{}
        $VMNicHash = @{}
        $SharedVHDX = @()

        # Matching and disecting countersamples based on CPU,Disk and NIC input/output values, code needs refactoring, feel free :)

        $Results | ForEach-Object -Process {

            Write-Progress -Activity 'Processing sample results from jobs...'  -CurrentOperation "This can take several minutes and is dependent on the number of VM's combined with the number of samples taken." 
            $_.countersamples | ForEach-Object -Process {

                $Path = $_.path
                $Value = $_.CookedValue
                $VMnameFromPath = $null
                $Volume = $null

                # processing IO samples
                if ($Path -match '[\\]+(.*?)[\\]+hyper-v virtual storage device\((.*)\)[\\]+(.*)' -eq $true) 
                {
                    $HypervHost = $matches[1]
                    $IOmetric = $matches[3]
                    [string]$DiskPath = $matches[2]

                    if ($DiskPath -match 'volume\d{1,2}')
                    {
                        $loc = $matches[0]
                        $DiskPathM = $DiskPath -replace '-volume\d{1,2}', ''
                    }
                    elseif ($DiskPath -match '.*?unc-')
                    {
                        $DiskPathM = $DiskPath -replace '.*?unc-', '--' 
                        $loc = 'SMB'
                    }
                    else 
                    {
                        $DiskPathM = $DiskPath
                        $loc = 'LocalDisk'
                    } # end volume match

                    $VMnameFromPath = $VMHDPaths[$DiskPathM]

                    if (!$VMnameFromPath)
                    {
                        $VMname = $DiskPathM 

                        if ($DiskPathM -match '^-\?\?-')
                        {
                            $SharedVHDX += $VMname
                        }
                    }
                    else 
                    {
                        $VMname = $VMnameFromPath
                        $loc = $DiskPathToLoc[$DiskPathM]
                    }
                
                    # matching volume or shared disk 
                    $Iohash = $VMIOHash[$VMname]

                    if (!$Iohash)
                    {
                        $Iohash = @{}
                    }

                    if ($Iohash[$loc])   
                    {
                        $IOArr = $Iohash[$loc]
                    }
                    else 
                    {
                        $IOArr = @($HypervHost, $loc, 0, 0, 0, 0, 0)
                    }
            
                    switch ($IoMetric){
                        'Read Bytes/sec' { $IOArr[2] += $Value }
                        'Write Bytes/sec' { $IOArr[3] += $Value }
                        'Read Operations/sec' { $IOArr[4] += $Value }
                        'Write Operations/sec' { $IOArr[5] += $Value }
                        'Queue Length' { $IOArr[6] += $Value }
                        }
                    
                    $Iohash[$loc] = $IOArr
                    $VMIOHash[$VMname] = $Iohash
                } elseif ($Path -match '[\\]+(.*?)[\\]+hyper-v hypervisor virtual processor\((.*):hv vp.(.*)\)' -eq $true) 
                {
                    [string]$VMname = $matches[2]
                    $HypervHost = $matches[1]
                    $Proc = $matches[3]
                    if ($VMCPUHash[$VMname])
                    {
                        $VMCPUHash[$VMname][$Proc] += $Value
                    }
                    else
                    {
                        $VMCPUHash[$VMname] = @{
                            $Proc = $Value
                        }
                    }
                    $VMHostHash[$VMname] = $HypervHost
                } elseif ($Path -match '[\\]+(.*?)[\\]+Hyper-V Dynamic Memory VM\((.*)\)(.*)' -eq $true) 
                {
                    [string]$VMname = $matches[2]
                    $HypervHost = $matches[1]
                    $Memcounter = $matches[3]
                    if ($VMMemHash[$VMname])
                    {
                        $MemArr = $VMMemHash[$VMname]
                    }
                    else
                    {
                        $MemArr = @($HypervHost, 0, 0)
                    }
                    if ($Memcounter -match 'guest visible physical memory') 
                    {
                        $MemArr[1] += $Value
                    }
                    elseif($Memcounter -match 'physical memory')
                    {
                        $MemArr[2] += $Value
                    }
                    $VMMemHash[$VMname] = $MemArr
                } elseif ($Path -match '[\\]+(.*?)[\\]+Hyper-V Virtual Network Adapter\((.*)_.*\)(.*)' -eq $true) 
                {
                    [string]$VMname = $matches[2]
                    $index = $VMname.split("_").count -2
                    $VMname = $VMname.split('_')[0..$index] -join '_'

                    $HypervHost = $matches[1]
                    $NicCounter = $matches[3]
                    if ($VMNicHash[$VMname])
                    {
                        $NicArr = $VMNicHash[$VMname]
                    }
                    else
                    {
                        $NicArr = @($HypervHost, 0, 0)
                    }
                    if ($NicCounter -match 'bytes sent') 
                    {
                        $NicArr[1] += $Value
                    }
                    elseif($NicCounter -match 'bytes received')
                    {
                        $NicArr[2] += $Value
                    }
                    $VMNicHash[$VMname] = $NicArr
                } # end if samples match		
            } # end foreach countersamples
        } # end foreach results


    ## 4. Combining all data in the Hash tables and construct a PSobject for each VM. Additional '_Total' objects are added for the all VM's combined plus totals per location (volumes/smb shares).

        $LocationIORead = @{}
        $LocationIOWrite = @{}
        $LocationIOpsRead = @{}
        $LocationIOpsWrite = @{}
        $LocationIOQueuelength = @{}

        # Building up the output array with VM statistics stored in the relevant hash tables
        $VMarr = @() 
        $VMHostHashCount = $VMHostHash.keys.count

        # Constructing VM psobjects
        $VMHostHash.keys  | ForEach-Object -Process {
            # Retrieving IO statistics
            $MatchIO = $null
            $VM = $_
            $VMHost = $VMHostHash[$VM]
            $MatchIO = $vmiohash.keys | ? { $_ -eq $VM -or $_ -match "-$VM-" }

            $Index = [array]::IndexOf($VMHostHash.keys,$_) 
            $Percentage = $Index / $VMHostHashCount
            $Message = "Building up output ($Index of $VMHostHashCount)"
            $CurrentOperation = 'Generating VM PerfMon statistics data ...'

            Write-Progress -Activity $Message -PercentComplete ($Percentage * 100) -CurrentOperation $CurrentOperation
		
            $Volume = @()
            $ReadValue = $null
            $WriteValue = $null
            $ReadIopsValue = $null
            $WriteIopsValue = $null
            $QueueLengthIOValue = $null
            $MASvm = $null
            $cObject = $null

            if ($MatchIO)
            {
                $MatchIO | ForEach-Object -Process {
                    $Iohash = $VMIOHash[$_]

                    $Iohash.keys | ForEach-Object -Process {
                        $arr = $Iohash[$_]

                        $loc = $arr[1]

                        $readio = [Math]::Round(($arr[2]/$MaxSamples/1kb),0)
                        $writeio = [Math]::Round(($arr[3]/$MaxSamples/1kb),0)
                        $readiops = [Math]::Round(($arr[4]/$MaxSamples),0)
                        $writeiops = [Math]::Round(($arr[5]/$MaxSamples),0)
                        $queuelength = [Math]::Round(($arr[6]/$MaxSamples),0)

                        $LocationIORead[$loc] += $readio
                        $LocationIOWrite[$loc] += $writeio
                        $LocationIOpsRead[$loc] += $readiops
                        $LocationIOpsWrite[$loc] += $writeiops
                        $LocationIOQueuelength[$loc] += $queuelength

                        $Volume += $loc
                        $ReadValue += $readio
                        $WriteValue += $writeio
                        $ReadIopsValue += $readiops
                        $WriteIopsValue += $writeiops
                        $QueueLengthIOValue += $queuelength

                    } # end foreach iohash

                    $VMIOHash.Remove($_)
                } # end foreach matchio
            }
            else 
            {
                $Volume = 'NoDisks'
            } # end if matchio

            # Retrieving CPU statistics
            $ProcPer = $null
            $VMCPUHash[$VM].values | ForEach-Object -Process {
                $ProcPer += [Math]::Round(($_/$MaxSamples),0)
            }
            $ProcPerTotal = $ProcPer / $VMCPUHash[$VM].count

            # Retrieving MEM statistics
            $MemVM = $null
            $MemHyperv = $null
            $MemArr = $VMMemHash[$VM]
            if ($MemArr)
            {
                $MemHyperv = $MemArr[2] / $MaxSamples 
                $MemVM = $MemArr[1] / $MaxSamples
            }

            # Retrieving NIC statistics
            $BytesReceived = $null
            $BytesSent = $null
            $NicArr = $VMNicHash[$VM]
            if ($NicArr)
            {
                $BytesSent = [Math]::Round(($NicArr[1]/$MaxSamples/1kb),0)
                $BytesReceived = [Math]::Round(($NicArr[2]/$MaxSamples/1kb),0)
            }
            
            ## identify hyper-v containers when one or more hosts are running Windows Server 2016

                if ($HostToBuild.values -ge 14393) {

                ## identify hyperv container template VM
                if ($VM -match '(^[A-Za-z0-9]{8}\-?)([A-Za-z0-9]{4}\-?)([A-Za-z0-9]{4}\-?)([A-Za-z0-9]{4}\-?)([A-Za-z0-9]{12}\-?)$' -and $Volume -eq 'NoDisks' )
                {  $VM = '_Hyper-V Container Template - ' + $VM}

                ## identify hyperv containers
                if ($HVContainer[$VM]){ $VM = '_Hyper-V Container - ' + $VM}

            } # end if WS2016 check

            $cObject = [pscustomobject]@{
                VM               = $VM
                HOST             = $VMHost
                CPU              = [int]$ProcPerTotal
                'MemConfigured(M)' = $MemVM
                'MemUsed(M)'     = $MemHyperv
                Location         = [string]::Join(',',($Volume | Select-Object -Unique))
                'NICSent(K)'     = $BytesSent
                'NICReceived(K)' = $BytesReceived
                'DiskRead(K)'    = [int]$readvalue
                'DiskRead(IOPS)' = [int]$ReadIopsValue
                'DiskWrite(K)'   = [int]$writevalue
                'DiskWrite(IOPS)'= [int]$WriteIopsValue
                'DiskQueueLength'= [int]$QueueLengthIOValue
            }

            $MASvm = $ElementNametoMASinfo[$VM]

            if ($MASvm) {
            $cObject.VM = $MASvm[3]
             $cObject | Add-Member -MemberType NoteProperty -Name ResourceGroup -Value $MASvm[2]
             $cObject | Add-Member -MemberType NoteProperty -Name Region -Value $MASvm[0]
             $cObject | Add-Member -MemberType NoteProperty -Name SubscriptionID -Value $MASvm[1]
             $cObject | Add-Member -MemberType NoteProperty -Name VMGuid -Value $VM
             }

            $VMarr += $cObject 

        } # end foreach vmhostshash

        Write-Progress -Activity $Message -PercentComplete 100 -CurrentOperation $CurrentOperation -Completed


        # Constructing psobject for _total VM's and _total locations

        
        $VMIOHash.keys |
        Where-Object -FilterScript {
          # filtering out ISO files
            $_ -notmatch '\.iso$|^iso'
        } |
        ForEach-Object -Process {

            $ReadValue = $null
            $WriteValue = $null
            $ReadIopsValue = $null
            $WriteIopsValue = $null
            $QueueLengthIOValue = $null
            $MASvm = $null
            $cObject = $null
        
            $VM = $_
            $Volume = @()
            $Iohash = $VMIOHash[$_]

            $Iohash.keys |
            ForEach-Object -Process {
                $arr = $Iohash[$_]

                $loc = $arr[1]

                        $readio = [Math]::Round(($arr[2]/$MaxSamples/1kb),0)
                        $writeio = [Math]::Round(($arr[3]/$MaxSamples/1kb),0)
                        $readiops = [Math]::Round(($arr[4]/$MaxSamples),0)
                        $writeiops = [Math]::Round(($arr[5]/$MaxSamples),0)
                        $queuelength = [Math]::Round(($arr[6]/$MaxSamples),0)

                        $LocationIORead[$loc] += $readio
                        $LocationIOWrite[$loc] += $writeio
                        $LocationIOpsRead[$loc] += $readiops
                        $LocationIOpsWrite[$loc] += $writeiops
                        $LocationIOQueuelength[$loc] += $queuelength

                        $Volume += $loc
                        $ReadValue += $readio
                        $WriteValue += $writeio
                        $ReadIopsValue += $readiops
                        $WriteIopsValue += $writeiops
                        $QueueLengthIOValue += $queuelength
            }

            $MASvm = $ElementNametoMASinfo[$VM]

             if ($SharedVHDX -contains $VM)
            {
                $VMdiskname = "[SharedVHDX] $VM" -replace '-??-',''
                if ($MASvm) { $VMdiskname = "[SharedVHDX]  $($MASvm[3])" -replace '-??-',''}
            }
            else
            {
                $VMdiskname = "[UnMatchedDisk] $VM"
                if ($MASvm) { $VMdiskname = "[UnMatchedDisk] $($MASvm[3])" }
            }

            $cObject = [pscustomobject]@{
                VM               = $VMdiskname
                HOST             = $arr[0]
                CPU              = $null
                'MemConfigured(M)' = $null
                'MemUsed(M)'     = $null
                Location         = [string]::Join(',',($Volume |
                Select-Object -Unique))
                'NICSent(K)'     = $null
                'NICReceived(K)' = $null
                'DiskRead(K)'    = [int]$readvalue
                'DiskRead(IOPS)' = [int]$ReadIopsValue
                'DiskWrite(K)'   = [int]$writevalue
                'DiskWrite(IOPS)'= [int]$WriteIopsValue
                'DiskQueueLength'= [int]$QueueLengthIOValue
            }

             if ($MASvm) {
             $cObject | Add-Member -MemberType NoteProperty -Name ResourceGroup -Value $MASvm[2]
             $cObject | Add-Member -MemberType NoteProperty -Name Region -Value $MASvm[0]
             $cObject | Add-Member -MemberType NoteProperty -Name SubscriptionID -Value $MASvm[1]
             $cObject | Add-Member -MemberType NoteProperty -Name VMGuid -Value $VM
             }

            $VMarr += $cObject 

        } # end vmiohash

        $Volumearr = @()


        $LocationIORead.keys | ForEach-Object -Process {

            $loc = $_
            $read = $LocationIORead[$loc]
            $write = $LocationIOWrite[$loc]
            $readiops = $LocationIOpsRead[$loc]
            $writeiops = $LocationIOpsWrite[$loc]
            $queuelength = $LocationIOQueuelength[$loc]


            $VMarr += [pscustomobject]@{
                VM               = "__Total ($loc)"
                HOST             = $null
                CPU              = $null
                'MemConfigured(M)' = $null
                'MemUsed(M)'     = $null
                Location         = $null
                'NICSent(K)'     = $null
                'NICReceived(K)' = $null
                'DiskRead(K)'    = [int]$read
                'DiskRead(IOPS)' = [int]$readiops
                'DiskWrite(K)'   = [int]$write
                'DiskWrite(IOPS)'= [int]$writeiops
                'DiskQueueLength'= [int]$queuelength
            }


            $TotalVolumeRead += $read
            $TotalVolumeWrite += $write
            $TotalVolumeReadIops += $readiops
            $TotalVolumeWriteIops += $writeiops
            $TotalVolumeQueue += $queuelength

        } # end LocationIORead



        $VMarr | ForEach-Object -Process {
            $TotalNICreceived += $_.'NICReceived(K)'
            $TotalNICsent += $_.'NICSent(K)'
            $TotalMemVisible += $_.'MemConfigured(M)'
            $TotalMemused += $_.'MemUsed(M)'
        }

        $VMarr += [pscustomobject]@{
            VM               = '__Total (All)'
            HOST             = $null
            CPU              = $null
            'MemConfigured(M)' = [int]$TotalMemVisible
            'MemUsed(M)'     = [int]$TotalMemused
            Location         = $null
            'NICSent(K)'     = [int]$TotalNICsent
            'NICReceived(K)' = [int]$TotalNICreceived
            'DiskRead(K)'    = [int]$TotalVolumeRead
            'DiskRead(IOPS)' = [int]$TotalVolumeReadIops
            'DiskWrite(K)'   = [int]$TotalVolumeWrite
            'DiskWrite(IOPS)'= [int]$TotalVolumeWriteIops
            'DiskQueueLength'= [int]$TotalVolumeQueue
        }

        $script:title = "Hyper-V PerfMon Statistics ($datestart -- $dateend)"
        $script:filename = "vm_perfmon_stats_$datestart--$dateend.csv" -replace ':', '_'
        $script:filename = $script:filename -replace '/', '-'
        $VMarr
    } # end function collectsamples 


    function Get-DurationMessage
    {
        param ([int]$count,[int]$Interval)
    
        Try
        {
            $WaitTime = $Interval * $count # total seconds for the whole operation

            if ($WaitTime -gt 60) 
            {
                $WaitTimeM = [Math]::Round(($WaitTime / 60), 2)
                $DurationText = "Duration:  $WaitTimeM minutes"
            }
            else 
            {
                $DurationText = "Duration:  $WaitTime seconds"
            }
        }
        catch
        {
            $DurationText = 'Oops, something went wrong ...'
        }

        return $DurationText
    }

    function Show-Form 
    {
        param ($Interval = 1,$MaxSamples = 1)
        #----------------------------------------------
        #region Import the Assemblies
        #----------------------------------------------
        [void][reflection.assembly]::Load('mscorlib, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089')
        [void][reflection.assembly]::Load('System, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089')
        [void][reflection.assembly]::Load('System.Windows.Forms, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089')
        [void][reflection.assembly]::Load('System.Data, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089')
        [void][reflection.assembly]::Load('System.Drawing, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a')
        [void][reflection.assembly]::Load('System.Xml, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089')
        [void][reflection.assembly]::Load('System.DirectoryServices, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a')
        [void][reflection.assembly]::Load('System.Core, Version=3.5.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089')
        [void][reflection.assembly]::Load('System.ServiceProcess, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a')
        #endregion Import Assemblies


        #----------------------------------------------
        #region Generated Form Objects
        #----------------------------------------------
        [System.Windows.Forms.Application]::EnableVisualStyles()
        $formCollectVMGuestStatis = New-Object -TypeName System.Windows.Forms.Form
        $Status = New-Object -TypeName System.Windows.Forms.GroupBox
        $RetrievalTextBox = New-Object -TypeName System.Windows.Forms.Label
        $CreatorTextBox = New-Object -TypeName System.Windows.Forms.Label
        $groupbox1 = New-Object -TypeName System.Windows.Forms.GroupBox
        $HostsTextBox = New-Object -TypeName System.Windows.Forms.Listview
        $grpBoxSampleinformation = New-Object -TypeName System.Windows.Forms.GroupBox
        $Duration = New-Object -TypeName System.Windows.Forms.Label
        $Intervalbox = New-Object -TypeName System.Windows.Forms.TextBox
        $labelInterval = New-Object -TypeName System.Windows.Forms.Label
        $count = New-Object -TypeName System.Windows.Forms.TextBox
        $labelCount = New-Object -TypeName System.Windows.Forms.Label
        $addhost = New-Object -TypeName System.Windows.Forms.TextBox
        $buttonaddhost = New-Object -TypeName System.Windows.Forms.Button
        $buttonQuit = New-Object -TypeName System.Windows.Forms.Button
        $buttonSelect = New-Object -TypeName System.Windows.Forms.Button
        $buttonCollect = New-Object -TypeName System.Windows.Forms.Button
        $InitialFormWindowState = New-Object -TypeName System.Windows.Forms.FormWindowState
        $LabelRuud = New-Object -TypeName System.Windows.Forms.Label
        $LabelQA = New-Object -TypeName System.Windows.Forms.Label
        $LinkLabelTwitter = New-Object -TypeName System.Windows.Forms.LinkLabel
        $LinkLabelQA = New-Object -TypeName System.Windows.Forms.LinkLabel
        $LinkLabelQA = New-Object -TypeName System.Windows.Forms.LinkLabel
        $ToolTipR = New-Object -TypeName System.Windows.Forms.ToolTip
        $ToolTipRuud = New-Object -TypeName System.Windows.Forms.ToolTip
        $ToolTipC = New-Object -TypeName System.Windows.Forms.ToolTip
        $ToolTipQA = New-Object -TypeName System.Windows.Forms.ToolTip
        $ToolTipAdd = New-Object -TypeName System.Windows.Forms.ToolTip 
        #endregion Generated Form Objects

        #----------------------------------------------
        # User Generated Script
        #----------------------------------------------
	
        $WatermarkTextC = 'Times'
        $WatermarkTextI = 'Seconds'
        $WatermarkTextAddHost = 'Hyper-V Host'

        $LinkLabelTwitter_OpenLink = {
            [System.Diagnostics.Process]::start('http://twitter.com/Ruud_Borst')
        }

        $LinkLabelQA_OpenLink = {
            [System.Diagnostics.Process]::start('https://gallery.technet.microsoft.com/Show-Hyper-V-Virtual-652fdd54/view/Discussions')
        }
	
        $formCollectVMGuestStatis_Load = {
            if ($MaxSamples)
            {
                $count.Text = $MaxSamples
            }
            else 
            {
                $count.ForeColor = 'LightGray'
                $count.Text = $WatermarkTextC
            }

            if ($Interval) 
            {
                $Intervalbox.Text = $Interval
            }
            else 
            {
                $Intervalbox.ForeColor = 'LightGray'
                $Intervalbox.Text = $WatermarkTextI
            }

            $addhost.ForeColor = 'LightGray'
            $addhost.Text = $WatermarkTextAddHost

            $Hosts = Find-Hosts

            if ($Hosts.count -lt 1)
            {
                $RetrievalTextBox.text = 'No Hyper-V Hosts found in AD, cluster or locally.'
            }
            else 
            {
                $RetrievalTextBox.text = 'Found Hyper-V Hosts.'
            } # end if hosts
		
            $Hosts |
            Sort-Object |
            ForEach-Object -Process {
                [string]$host = $_ -replace ' ', ''
                $HostsTextBox.Items.Add($host)
            }

            $HostsTextBox.AutoResizeColumns([Windows.Forms.ColumnHeaderAutoResizeStyle]::ColumnContent)
            $HostsTextBox.Items | ForEach-Object -Process {
                $_.checked = $true
            }
        }
	

        $buttonSelect_Click = {
            $items = $HostsTextBox.Items

            $chk = ($items | Where-Object -FilterScript {
                    $_.checked -eq $true
            }).count
    
            if ($chk -lt ($items.count / 2))
            {
                $HostsTextBox.Items | ForEach-Object -Process {
                    $_.checked = $true
                }
            } else 
            {
                $HostsTextBox.Items | ForEach-Object -Process {
                    $_.checked = $false
                }
            }
        }


        $buttonQuit_Click = {
            $formCollectVMGuestStatis.Close()
        }
	
	
        $buttonCollect_Click = {
            if ($count.Text -notmatch '\d{1,}?')
            {
                $RetrievalTextBox.text = 'Please supply the total number of samples to collect.'
            }
            elseif ($Intervalbox.Text -notmatch '\d{1,}')
            {
                $RetrievalTextBox.text = 'Please supply the interval in seconds between the samples.'
            }
            elseif (!($HostsTextBox.CheckedItems))
            {
                $RetrievalTextBox.text = 'Please select the Hyper-V Hosts to collect samples from.'
            }
            else
            {
                $hostsTxt = $HostsTextBox.CheckedItems.text -split ' ', ''
           

                $Data = Get-VMGuestSamples -Name $hostsTxt -MaxSamples $count.Text -Interval $Intervalbox.text

                $SelectArr = 'VM','HOST','CPU','MemConfigured(M)','MemUsed(M)','Location','NICSent(K)','NICReceived(K)','DiskRead(K)','DiskWrite(K)','DiskRead(IOPS)','DiskWrite(IOPS)','DiskQueueLength'
                
                if ($data.SubscriptionID -match '(\{|\()?[A-Za-z0-9]{4}([A-Za-z0-9]{4}\-?){4}[A-Za-z0-9]{12}(\}|\()?'){$SelectArr += 'ResourceGroup','Region','SubscriptionID','VMGuid'}

                if (!$ExportToCsv)
                {
                    $Data  |
                    Sort-Object -Property vm | select $SelectArr |
                    Out-GridView -Title $title
                } else 
                {
                    $Data | Export-Csv -NoTypeInformation -Path ($ExportToCSVPath + '\' + $filename) -Verbose
                }
            } # end if boxes check
        }
        $count_Enter = {
            if ($count.Text -eq $WatermarkTextC)
            {
                #Clear the text
                $count.Text = ''
                $count.ForeColor = 'WindowText'
            }
        }
	
        $HostsTextBox_MouseEnter = {
            #
        }
	
        $Intervalbox_Enter = {
            if ($Intervalbox.Text -eq $WatermarkTextI)
            {
                #Clear the text
                $Intervalbox.Text = ''
                $Intervalbox.ForeColor = 'WindowText'
            }
        }
	
	
        $Intervalbox_Leave = {
            if ($Intervalbox.Text -eq '')
            {
                $Intervalbox.Text = $WatermarkTextI
                $Intervalbox.ForeColor = 'LightGray'
            }
            elseif ($count.text -match '[1-9]' -and $Intervalbox.Text -match '[1-9]')
            {
                $Duration.text = Get-DurationMessage -interval $Intervalbox.Text -count $count.Text
            }
        }
	
        $Count_Leave = {
            if ($count.Text -eq '')
            {
                $count.Text = $WatermarkTextC
                $count.ForeColor = 'LightGray'
            }
            elseif ($count.text -match '[1-9]' -and $Intervalbox.Text -match '[1-9]')
            {
                $Duration.text = Get-DurationMessage -interval $Intervalbox.Text -count $count.Text
            }
        }

         $Addhost_Leave = {
            if ($AddHost.Text -eq '')
            {
                $AddHost.Text = $WatermarkTextAddHost
                $AddHost.ForeColor = 'LightGray'
            }
        }

        $AddHost_Enter = {
            if ($AddHost.Text -eq $WatermarkTextAddHost)
            {
                #Clear the text
                $AddHost.Text = ''
                $AddHost.ForeColor = 'WindowText'
            }
        }

        $buttonaddhost_Click = {
            if ($AddHost.Text -match '[A-Za-z0-9]' -and $AddHost.Text -ne $WatermarkTextAddHost)
            {
            $item = $HostsTextBox.Items.Add($AddHost.Text)
            $item.Checked = $true
            $HostsTextBox.AutoResizeColumns([Windows.Forms.ColumnHeaderAutoResizeStyle]::ColumnContent)
            }
        }

		
        # --End User Generated Script--
        #----------------------------------------------
        #region Generated Events
        #----------------------------------------------
	
        $Form_StateCorrection_Load = 
        {
            #Correct the initial state of the form to prevent the .Net maximized form issue
            $formCollectVMGuestStatis.WindowState = $InitialFormWindowState
        }
	
        $Form_Cleanup_FormClosed = 
        {
            #Remove all event handlers from the controls
            try
            {
                $Intervalbox.remove_Enter($Intervalbox_Enter)
                $Intervalbox.remove_Leave($Intervalbox_Leave)
                $count.remove_Enter($count_Enter)
                $count.remove_Leave($Count_Leave)
                $HostsTextBox.remove_MouseEnter($HostsTextBox_MouseEnter)
                $buttonQuit.remove_Click($buttonQuit_Click)
                $buttonCollect.remove_Click($buttonCollect_Click)
                $formCollectVMGuestStatis.remove_Load($formCollectVMGuestStatis_Load)
                $formCollectVMGuestStatis.remove_Load($Form_StateCorrection_Load)
                $formCollectVMGuestStatis.remove_FormClosed($Form_Cleanup_FormClosed)
            }
            catch [Exception]
            {

            }
        }
        #endregion Generated Events

        #----------------------------------------------
        #region Generated Form Code
        #----------------------------------------------
        $formCollectVMGuestStatis.SuspendLayout()
        $Status.SuspendLayout()
        $groupbox1.SuspendLayout()
        $grpBoxSampleinformation.SuspendLayout()
        #
        # formCollectVMGuestStatis
        #
        $formCollectVMGuestStatis.Controls.Add($Status)
        $formCollectVMGuestStatis.Controls.Add($groupbox1)
        $formCollectVMGuestStatis.Controls.Add($grpBoxSampleinformation)
        $formCollectVMGuestStatis.Controls.Add($buttonQuit)
        $formCollectVMGuestStatis.Controls.Add($buttonCollect)
        $formCollectVMGuestStatis.Controls.Add($LinkLabelTwitter)
        $formCollectVMGuestStatis.Controls.Add($LinkLabelQA)
        $formCollectVMGuestStatis.Controls.Add($LabelRuud)
        $formCollectVMGuestStatis.Controls.Add($LabelQA)
        $formCollectVMGuestStatis.AcceptButton = $buttonCollect
        $formCollectVMGuestStatis.CancelButton = $buttonQuit
        $formCollectVMGuestStatis.ClientSize = '345, 258'
        $formCollectVMGuestStatis.Name = 'formCollectVMGuestStatis'
        $formCollectVMGuestStatis.Text = 'Hyper-V PerfMon Tool'
        $base64icon = 'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAABmJLR0QA/wD/AP+gvaeTAAAACXBIWXMAAA7DAAAOwwHHb6hkAAAAB3RJTUUH3QkSCSI6+xv8KQAAAg9JREFUOMuNk71uE1EQhb+1r9dORZPKKRwlUmS7BUHLE+QZ0qWBMgWvACVCJC1IVEhUUCEKIhHRIAq7QYktI5xgh0Tx7nr/Zy6F7Y2REOG0c+75Gc11Hn/8bAHEQmYhTVOSJCZJEpIkZX9lzeEfMIvHzw4OAPA8D4BHe3uc/PjOTTAA96pw9+EuCnwdnlGv15mK5Vuaw8p/CIiF3IFUoF6vk6jFOrM6NyawwOvekCDwmXgeKkKpXMaUy7gVtyA+WcVa4On+AZ7nsbOzw9VkghEL99fXuFI4F/B9r1jgeDT6w+1OBZ4/2AXgVOHDzxFGgfe9ARfnv5h4Ho7jYEwZ163iLO0/tfDqeMYLo7CYG7WwvdlANhqkQGQhAFYdeHl4VAiohe2NBulmg0uFWw68ODzCqAiXWiafE0sWMhw+nY0Rq9cCIlyYMmJhah0687kRFd5+6RBMA6IwBqBSqVCtuliRQkBUeDfn5ZkUc5PnOe12G1VLHEdE8ewKrSqDwaAQCMOQZrNFlqf4fkASx/T6fYxapdvtEoRTommEWsV1XWrVKmrtdQWUbqeDHwSICiu12uwO8iyn1WqT5SlxFBFGMTqP3uv3C4HAn9JsNVGrRYLj4xPMsnIQ+JRKJaq1WuGwwPl4zOlwiKigIoRRTJ5lmMCfstXcIgpn/Rfuqkqvd53gzfrtv/5Ks6y8aGyXHG7Cb1dyYTa9ShmIAAAAAElFTkSuQmCC'
        $iconStream = [System.IO.MemoryStream][System.Convert]::FromBase64String($base64icon)
        $iconBmp = [System.Drawing.Bitmap][System.Drawing.Image]::FromStream($iconStream)
        $iconHandle = $iconBmp.GetHicon()
        $upIcon = [System.Drawing.Icon]::FromHandle($iconHandle)
        $formCollectVMGuestStatis.Icon = $upIcon
        $formCollectVMGuestStatis.StartPosition = "CenterScreen"
        $formCollectVMGuestStatis.Topmost = $true
        $formCollectVMGuestStatis.MinimizeBox = $True
        $formCollectVMGuestStatis.MaximizeBox = $False
        $formCollectVMGuestStatis.WindowState = "Normal"
        $formCollectVMGuestStatis.SizeGripStyle = "Hide"
        $formCollectVMGuestStatis.Opacity = 0.97
        $formCollectVMGuestStatis.AcceptButton = $buttonCollect
        $formCollectVMGuestStatis.CancelButton = $buttonQuit
        $formCollectVMGuestStatis.FormBorderStyle = 'FixedDialog'
        $formCollectVMGuestStatis.add_Load($formCollectVMGuestStatis_Load)

        #Create LabelRuudBorst
        $LabelRuud.Font = New-Object -TypeName System.Drawing.Font -ArgumentList ('Tahoma', 7.9, 0, 3, 0)
        $LabelRuud.Location = '1, 235'
        $LabelRuud.Size = New-Object -TypeName System.Drawing.Size -ArgumentList (60, 15)
        $LabelRuud.Text = '®'

        # Create ToolTip R
        $ToolTipR.SetToolTip($LabelRuud, "Special thanks go out to 'Darryl van der Peijl' for`nreviewing an contributing to this Tool!")
        $ToolTipR.AutomaticDelay = 0

        # Create ToolTip RuudBorst
        $ToolTipRuud.SetToolTip($LinkLabelTwitter, "Follow me on Twitter and keep yourself updated`nof recent 'PowerShell' or 'Microsoft Cloud' developments!")

        # Create ToolTip Collect
        $ToolTipC.SetToolTip($ButtonCollect, "Click here to start collecting/monitoring VM performance samples from selected Hyper-V Hosts.`nCommon non-invasive read-only WMI calls are used, no performance impact whatsoever.")
        $ToolTipC.ToolTipIcon = 'Info'
        $ToolTipC.AutoPopDelay = 9000
        $ToolTipC.AutomaticDelay = 2000

        # Create ToolTip Collect
        $ToolTipQA.SetToolTip($LinkLabelQA, "Download the latest version here and let me know if you have any questions or suggestions.`nI'm really commited to continue developing this free community tool.")
        $ToolTipQA.AutoPopDelay = 8000
        $ToolTipQA.AutomaticDelay = 0

        # Create ToolTip Collect
        $ToolTipAdd.SetToolTip($buttonaddhost, 'Add a Hyper-V host manually when it can not be discovered automatically.')
        $ToolTipAdd.AutoPopDelay = 7000
        $ToolTipAdd.AutomaticDelay = 1000

        #Create LabelQA
        $LabelQA.Font = New-Object -TypeName System.Drawing.Font -ArgumentList ('Tahoma', 7.9, 0, 3, 0)
        $LabelQA.Location = '73, 235'
        $LabelQA.Text = '| QA at'

        #Create LinkLabelTwitter
        $LinkLabelTwitter.Font = New-Object -TypeName System.Drawing.Font -ArgumentList ('Tahoma', 7.9, 0, 3, 0)
        $LinkLabelTwitter.Location = '13, 235'
        $LinkLabelTwitter.Size = New-Object -TypeName System.Drawing.Size -ArgumentList (60, 15)
        $LinkLabelTwitter.Text = 'Ruud Borst'
        $LinkLabelTwitter.tabstop = $false
        $LinkLabelTwitter.add_Click($LinkLabelTwitter_OpenLink)

        #Create LinkLabelQA
        $LinkLabelQA.Font = New-Object -TypeName System.Drawing.Font -ArgumentList ('Tahoma', 7.9, 0, 3, 0)
        $LinkLabelQA.Location = '111, 235'
        $LinkLabelQA.Text = 'TechNet'
        $LinkLabelQA.tabstop = $false
        $LinkLabelQA.add_Click($LinkLabelQA_OpenLink)

        #
        # Status
        #
        $Status.Controls.Add($RetrievalTextBox)
        $Status.Location = '12, 146'
        $Status.Name = 'Status'
        $Status.Size = '145, 80'
        $Status.TabStop = $false
        $Status.Text = 'Status'
        #
        # RetrievalTextBox
        #
        $RetrievalTextBox.Location = '6, 19'
        $RetrievalTextBox.Name = 'RetrievalTextBox'
        $RetrievalTextBox.Size = '137, 40'
        #
        # CreatorTextBox
        #
        $CreatorTextBox.Location = '12, 220'
        $CreatorTextBox.Name = 'CreatorTextBox'
        $CreatorTextBox.Size = '137, 54'
        #
        # groupbox1
        #
        $groupbox1.Controls.Add($HostsTextBox)
        $groupbox1.Controls.Add($buttonSelect)
        $groupbox1.Controls.Add($AddHost)
        $groupbox1.Controls.Add($buttonaddhost)
        $groupbox1.Location = '168, 12'
        $groupbox1.Name = 'groupbox1'
        $groupbox1.Text = 'Hyper-V Hosts'
        $groupbox1.Size = '163, 214'
        $groupbox1.TabStop = $false
        #
        # AddHost
        #
        $AddHost.Location = '55, 163'
        $AddHost.MaxLength = 100
        $AddHost.Name = 'addhost'
        $AddHost.Size = '98, 18'
        $AddHost.add_Enter($AddHost_Enter)
        $AddHost.add_Leave($AddHost_Leave)
        #
        # buttonaddhost
        #
        $buttonaddhost.Location = '9, 162'
        $buttonaddhost.Name = 'buttonaddhost'
        $buttonaddhost.Size = '40, 22'
        $buttonaddhost.Text = 'Add'
        $buttonaddhost.add_Click($buttonaddhost_Click)
        #
        # HostsTextBox
        #
        $HostsTextBox.Location = '9, 22'
        $HostsTextBox.CheckBoxes = $true
        $HostsTextBox.Name = 'HostsTextBox'
        $HostsTextBox.HeaderStyle = 'None'
        $HostsTextBox.Size = '144, 137'
        $HostsTextBox.Columns.Add('Select Hosts')
        $HostsTextBox.View = 'Details'
        $HostsTextBox.add_MouseEnter($HostsTextBox_MouseEnter)
        # 
        # grpBoxSampleinformation
        #
        $grpBoxSampleinformation.Controls.Add($Duration)
        $grpBoxSampleinformation.Controls.Add($Intervalbox)
        $grpBoxSampleinformation.Controls.Add($labelInterval)
        $grpBoxSampleinformation.Controls.Add($count)
        $grpBoxSampleinformation.Controls.Add($labelCount)
        $grpBoxSampleinformation.Location = '12, 12'
        $grpBoxSampleinformation.Name = 'grpBoxSampleinformation'
        $grpBoxSampleinformation.Size = '145, 123'
        $grpBoxSampleinformation.TabStop = $false
        $grpBoxSampleinformation.Text = 'Samples'
        #
        # Duration
        #
        $Duration.Location = '5, 96'
        $Duration.Name = 'Duration'
        $Duration.Size = '138, 38'
        #
        # Interval
        #
        $Intervalbox.Location = '54, 62'
        $Intervalbox.MaxLength = 1000
        $Intervalbox.Name = 'Interval'
        $Intervalbox.Size = '52, 20'
        $Intervalbox.add_Enter($Intervalbox_Enter)
        $Intervalbox.add_Leave($Intervalbox_Leave)
        $Intervalbox.TabIndex = 1
        $Intervalbox.TabStop = $true
        #
        # labelInterval
        #
        $labelInterval.Location = '6, 65'
        $labelInterval.Name = 'labelInterval'
        $labelInterval.Size = '52, 23'
        $labelInterval.Text = 'Interval:'
        #
        # Count
        #
        $count.Location = '54, 29'
        $count.MaxLength = 1000
        $count.Name = 'Count'
        $count.Size = '52, 20'
        $count.add_Enter($count_Enter)
        $count.add_Leave($Count_Leave)
        $count.TabIndex = 0
        $count.TabStop = $true
        #
        # labelCount
        #
        $labelCount.Location = '6, 32'
        $labelCount.Name = 'labelCount'
        $labelCount.Size = '52, 20'
        $labelCount.Text = 'Samples:'
        #
        # buttonQuit
        #
        $buttonQuit.DialogResult = 'Cancel'
        $buttonQuit.Location = '261, 230'
        $buttonQuit.Name = 'buttonQuit'
        $buttonQuit.Size = '67, 23'
        $buttonQuit.Text = 'Quit'
        $buttonQuit.UseVisualStyleBackColor = $true
        $buttonQuit.TabIndex = 3
        $buttonQuit.add_Click($buttonQuit_Click)
        #
        # buttonSelect
        #
        $buttonSelect.Location = '42, 190'
        $buttonSelect.Name = 'buttonSelect'
        $buttonSelect.Size = '80, 18'
        $buttonSelect.Text = '(de)select all'
        $buttonSelect.UseVisualStyleBackColor = $true
        $buttonSelect.add_Click($buttonSelect_Click)
        #
        # buttonCollect
        #
        $buttonCollect.Location = '174, 230'
        $buttonCollect.Name = 'buttonCollect'
        $buttonCollect.Size = '75, 23'
        $buttonCollect.Text = 'Monitor'
        $buttonCollect.UseVisualStyleBackColor = $true
        $buttonCollect.add_Click($buttonCollect_Click)
        $buttonCollect.TabIndex = 2
        $grpBoxSampleinformation.ResumeLayout()
        $groupbox1.ResumeLayout()
        $Status.ResumeLayout()
        $formCollectVMGuestStatis.ResumeLayout()
        #endregion Generated Form Code

        #----------------------------------------------

        #Save the initial state of the form
        $InitialFormWindowState = $formCollectVMGuestStatis.WindowState
        #Init the OnLoad event to correct the initial state of the form
        $formCollectVMGuestStatis.add_Load($Form_StateCorrection_Load)
        #Clean up the control events
        $formCollectVMGuestStatis.add_FormClosed($Form_Cleanup_FormClosed)
        #Show the Form
        return $formCollectVMGuestStatis.ShowDialog()
    } #End Function

    $Hosts = @()

} # end begin


PROCESS {


    # Add Hyper-V Hosts from the name parameter to the hosts array variable defined in the begin block
    # when pipeline input is detected. Else assign the '-Name' parameter variable to the hosts variable.

    if ($pscmdlet.ShouldProcess($Name) -and $Name)
    {
        $Name | ForEach-Object -Process {
            $Hosts += $_
        }
    } else 
    {
        $Hosts = $Name
    } # end shouldprocess name

} # end process


END {

    # Return PS objects by executing the 'Get-VMGuestSamples' directly when the '-PSobjects' and '-Name' switch are specified. Elseif execute
    # find-hosts function for automatic discovery. Else launch the GUI (Winforms) by executing the 'Show-Form' function in which 'Find-Hosts' function is used to populate the hosts in the checkbox.
    # 'Get-VMGuestSamples' with 'Out-Gridview output is executed when the user hits the 'Collect' button in the same form.

    if ($PSobjects -and $Name)
    {
        Get-VMGuestSamples -Interval $Interval -MaxSamples $MaxSamples -Name $Hosts
    } elseif ($PSobjects){
        Write-warning '''Name'' parameter not specified, using automatic discovery of Hyper-V Hosts ...'
        Get-VMGuestSamples -Interval $Interval -MaxSamples $MaxSamples -Name (Find-Hosts)
    } else 
    {
        $null = Show-Form -Interval $Interval -MaxSamples $MaxSamples -Name $Hosts
    }

}
