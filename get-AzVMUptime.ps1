function Get-AzVMUptime {
<#
.NOTES
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
    [CmdletBinding()]
    param (
        $ComputerName
    )
    Begin {
        If(-not(Get-AzContext)){
            Write-Warning -Message "You are not logged into Azure.  Use 'Login-AzAccount' to login and 'Set-AzContext' to choose your subscription."
            exit
        }
        $LocalTZ = (Get-TimeZone).Id
        if ($ComputerName) {
            $AllVMs = Get-AzVM -Status -Name $ComputerName | Where-Object { $_.PowerState -eq 'VM running' }
        }
        else {
            $AllVMs = Get-AzVM -Status | Where-Object { $_.PowerState -eq 'VM running' }
        }
        Write-Verbose -Message "`$AllVms = $($AllVMs.Name)"
    }
    Process{
        foreach ($VM in $AllVMs) {
            $VMAzLog = Get-AzLog -ResourceId $VM.Id -WarningAction Ignore | Where-Object { $_.OperationName.LocalizedValue -Like 'Start Virtual Machine' } | 
                Sort-Object EventTimestamp -Descending | Select-Object -First 1
            $BootTime = $VMAzLog.EventTimestamp
            if ($BootTime) {
                $LocalTime = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId( $BootTime, $LocalTZ)
                $Time = New-TimeSpan -Start $LocalTime -End (Get-Date)
                Switch ($time)
                {
                    { $_.Days -gt 0}{$upTime = "$($time.Days) Days, $($time.Hours) Hours, $($time.Minutes) Minutes" ; break}
                    { $_.Hours -gt 0}{$upTime = "$($time.Hours) Hours, $($time.Minutes) Minutes" ; break}
                    Default {$upTime = "$($time.Minutes) Minutes"}
                }
            }
            else {
                $Uptime = 'n/a' 
                $LocalTime = 'n/a'
            }
            [PSCustomObject]@{
                'HostName' = $VM.Name
                'BootupTime' = $LocalTime
                'Uptime' = $Uptime
            }   
        }
    }
}
