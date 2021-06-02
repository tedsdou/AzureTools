<#
.Synopsis
   Measure AD Convergence for forest
.DESCRIPTION
   Measure AD Convergence for all domains in forest
.NOTES
   Version: 1.0 
   Date: 29SEP2016
   Author: Ted Sdoukos
   To-Do: Error handling, logging
#>
#requires -Version 3 -Modules ActiveDirectory
Param([int]$timeout = 90)
Try{ $null = Get-ADForest } Catch {Throw 'Unable to query forest'}
Write-Output -InputObject '***Forest Information***'
Get-ADForest | Select-Object -Property `
    @{Name = 'Forest Name' ; Expression = {$_.Name}},
    @{Name = 'Functional Level' ; Expression = {$_.ForestMode}} | Format-Table -AutoSize
Write-Output -InputObject '***Domain Information***'
(Get-ADForest).Domains | Select-Object -Property `
    @{Name = 'Domain Name'; Expression = {$_}}, 
    @{Name = 'Functional Level'; Expression = {(Get-ADDomain -Identity $_).DomainMode}} | Format-Table -AutoSize

$domains = (Get-ADForest).Domains
$sb = (Get-ADRootDSE).configurationNamingContext
$pdc = (Get-ADRootDSE).dnsHostName
$DCs= (Get-ADForest).Domains | ForEach-Object { Get-ADDomainController -Filter * -Server $_ } |
    Select-Object -ExpandProperty HostName

$ausers = Get-ADObject -Filter {Name -eq 'Authenticated Users'} -SearchBase $sb | 
    Select-Object -ExpandProperty DistinguishedName

# Grab original description for 'Authenticated Users' group
$oldDesc = (Get-ADObject -Identity $ausers -Properties Description -Server $pdc).Description
Set-ADObject -Identity $ausers -Description "$oldDesc-TestConverge-$(Get-Date -Format ddMMMyy)" -Server $pdc

# Grab change time from source
$oriChg = Get-ADObject -Identity $ausers -Properties whenChanged | Select-Object -ExpandProperty whenChanged

foreach($DC in $DCs){
Write-Verbose -Message "Working on $DC"  
    # Loop until change time on dc is higher than originating change
    $startTime = Get-Date
    Do{
        #Write-Warning -Message "Waiting on replication for $DC" 
        $lstChange = Get-ADObject -Identity $ausers -Properties whenChanged -Server $DC | Select-Object -ExpandProperty whenChanged 
        Write-Verbose "Original: $oriChg Updated: $lstChange"
        If( (Get-Date) -ge ($startTime).AddMinutes($timeout) ){ 
            Write-Warning "Timeout threshold of $timeout minutes has been reached for $DC...skipping"
            $lstChange = $oriChg 
            $threshold = $true
            }
    }
    Until($lstChange -ge $oriChg)
    If($threshold){$lstChange = 'Timeout exceeded'}
    [PSCustomObject] @{
        'Domain Controller' = $DC
        'Original Change' = $oriChg
        'Last Change' = $lstChange
        'Convergence Time'  = If($threshold){'Timeout Exceeded'} Else {$lstChange - $oriChg}
    }
    $threshold = $false
}

# After test is complete, set description back to what it was
Set-ADObject -Identity $ausers -Description $oldDesc -Server $pdc
