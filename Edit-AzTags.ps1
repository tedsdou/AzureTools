function Edit-AzTags {
    <#
    .SYNOPSIS
        This will remove errant whitespace from start or end of Azure tag in selected subscription.
    .DESCRIPTION
        This will remove errant whitespace from start or end of Azure tag in selected subscription.
        There is an option to target all subscriptions using the AllSubscriptions switch.
    .EXAMPLE
        PS C:\> <example usage>
        Explanation of what the example does
    .NOTES
        Author:  Ted Sdoukos (Ted.Sdoukos@Microsoft.com)
        Date:    4NOV2020
        Version: 1.0
    #>
    [CmdletBinding(DefaultParameterSetName = 'Targeted')]
    param (
        [Parameter(ParameterSetName = 'All')]
        [switch]$AllSubscriptions,

        [Parameter(ParameterSetName = 'Targeted',Mandatory)]
        [string]$Subscription,

        [Parameter(ParameterSetName = 'Targeted')]
        [string]$ResourceGroup
    )
    
    begin {
        If(-not(Get-AzContext)){
            Write-Warning -Message "No Azure Context Found!`n`rLogging you in"
            Login-AzAccount
        }
    }
    process {
        If($PSCmdlet.ParameterSetName -eq 'All'){
            $AzSubscription = Get-AzSubscription
        }
        Else{
            $AzSubscription = Get-AzSubscription -SubscriptionName $Subscription
        }
        foreach($s in $AzSubscription){
            $null = Set-AzContext -SubscriptionName $s.Name
            $bTags = Get-AzTag | Where-Object {$_.Name -match '^\s+|\s+$'}
            If(-not($bTags)){
                Write-Output -InputObject "There is nothing to clean in subscription: $($s.name)"
                exit
            }
            foreach($b in $bTags){
                If($ResourceGroup){
                    try {
                        [array]$Resource = Get-AzResourceGroup -Name $ResourceGroup -ErrorAction Stop | Where-Object {$_.Tags.Keys -contains $b.Name} | 
                            Select-Object -Property Tags,ResourceId
                        $Resource += Get-AzResource -ResourceGroupName $ResourceGroup -TagName $b.Name | Select-Object -Property Tags,ResourceId
                    }
                    catch {
                        Write-Warning -Message "Unable to find $ResourceGroup in $($s.name)"
                        exit
                    }
                }
                else {
                    [array]$Resource = Get-AzResource -TagName $b.Name | Select-Object -Property Tags,ResourceId
                    $Resource += Get-AzResourceGroup | Where-Object {$_.Tags.Keys -contains $b.Name} | Select-Object -Property Tags,ResourceId   
                }
                foreach ($r in $Resource) {
                    #Find the one with the space
                    $space = $r.Tags.GetEnumerator() | Where-Object { $_.Key -eq $b.Name}
                    # If there is another one that matches the name, then delete this one
                    If($r.Tags.ContainsKey($space.Key.Trim())){
                        $DelTag = @{$space.Key = $space.Value}
                        try {
                            Update-AzTag -ResourceId $r.ResourceId -Tag $DelTag -Operation Delete -ErrorAction Stop
                        }
                        catch {
                            $_.Exception.Message
                        }
                    }
                    else {
                        #If there is not a match, fix the space
                        [HashTable]$updateHTable = $r.Tags
                        $updateHTable.Remove($space.Key)
                        $updateHTable[$space.Key.Trim()] = $space.Value
                        try {
                            Update-AzTag -Operation Replace -Tag $updateHTable -ResourceId $r.ResourceId   
                        }
                        catch {
                            $_.Exception.Message
                        }
                    }
                }
            }    
        }
    }
}