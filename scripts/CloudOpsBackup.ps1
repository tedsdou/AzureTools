function Publish-CloudOps {
    [CmdletBinding()]
    param (
        [string]$Path = 'c:\Users\power\LocalGitRepo\FedEx-CloudOps',
        [Parameter(Mandatory)]
        [ValidateSet('Dev','Test','Production')]
        [string[]]$Environment
    )
    
    begin {
        $Server = @()
        switch ($Environment) {
            'Dev'        {$Server += 'MS'}
            'Test'       {$Server += 'DC'}
            'Production' {$Server += 'MS','DC'}
        }
    }
    
    process {
        foreach ($S in $Server) {
            #Region Backup data
            $TimeStamp = Get-Date -Format 'MM-dd-yyyy_hhmmtt'
            $BackupDir = "\\$s\c$\CloudOps\SCCMGateway\scripts\BackupData\CloudOpsBackup-$TimeStamp"
                try {
                    $null = New-Item -ItemType Directory -Path $BackupDir
                }
                catch {
                    Write-Warning -Message "Unable to create $BackupDir`n`rERROR: $($_.Exception.Message)"
                }
                Try {
                    Copy-Item -Path "\\$s\c$\CloudOps\SCCMGateway\Scripts\CloudOpsMaster.ps1" -Destination $BackupDir -Force
                }
                catch {
                    Write-Warning -Message "Unable to Copy CloudOpsMaster.ps1`n`rERROR: $($_.Exception.Message)"
                }
                Try {
                    Copy-Item -Path "\\$s\c$\Program Files\WindowsPowerShell\Modules\CloudOpsOSD" -Destination "$BackupDir\CloudOpsOSD" -Force -Recurse
                }
                Catch{
                    Write-Warning -Message "Unable to Copy module`n`rERROR: $($_.Exception.Message)"
                }
            }
            #EndRegion

            #Region Copy in new data
            Try {
                Copy-Item -Path "$Path\CloudOpsMaster.ps1" -Destination "\\$s\c$\CloudOps\SCCMGateway\Scripts" -Force
            }
            Catch{
                Write-Warning -Message "Unable to copy`n`rERROR: $($_.Exception.Message)"
            }

            Try {
                Copy-Item -Path "$Path\CloudOpsOSD\*" -Destination "\\$s\c$\Program Files\WindowsPowerShell\Modules\CloudOpsOSD" -Force
            }
            Catch {
                Write-Warning -Message "Unable to copy`n`rERROR: $($_.Exception.Message)"
            }
            #EndRegion
        }    
}

function Restore-CloudOps {
    [CmdletBinding()]
    param (
        [string]$Path,
        [Parameter(Mandatory)]
        [ValidateSet('Dev', 'Test', 'Production')]
        [string[]]$Environment
    )
    
    begin {
        $Server = @()
        switch ($Environment) {
            'Dev' { $Server += 'MS' }
            'Test' { $Server += 'DC' }
            'Production' { $Server += 'MS', 'DC' }
        }
    }
    
    process {
        foreach ($S in $Server) {
            $Path = Get-ChildItem -Path "\\$s\c$\CloudOps\SCCMGateway\scripts\BackupData\" -Directory |
                Where-Object -FilterScript {$_.Name -match 'CloudOpsBackup-\d{2}-\d{2}-\d{4}'} | Sort-Object -Property LastWriteTime | 
                Select-Object -First 1
            #Region Copy in new data
            Try {
                Copy-Item -Path "\\$s\c$\CloudOps\SCCMGateway\scripts\BackupData\$path\CloudOpsMaster.ps1" -Destination "\\$s\c$\CloudOps\SCCMGateway\Scripts\CloudOpsMaster.ps1" -Force
            }
            Catch {
                Write-Warning -Message "Unable to copy`n`rERROR: $($_.Exception.Message)"
            }

            Try {
                Copy-Item -Path "\\$s\c$\CloudOps\SCCMGateway\scripts\BackupData\$path\CloudOpsOSD\*" -Destination "\\$s\c$\Program Files\WindowsPowerShell\Modules\CloudOpsOSD" -Force
            }
            Catch {
                Write-Warning -Message "Unable to copy`n`rERROR: $($_.Exception.Message)"
            }
            #EndRegion
        }
    }
    end {
        
    }
}

Publish-CloudOps -Environment Dev

#Restore-CloudOps -Environment Dev