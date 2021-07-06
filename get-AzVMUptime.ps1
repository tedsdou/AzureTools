function Get-AzVMUptime {
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
