function Edit-AzTag {
    <#
    .SYNOPSIS
        This will remove errant whitespace from start or end of Azure tag in selected subscription.
    .DESCRIPTION
        This will remove errant whitespace from start or end of Azure tag in selected subscription.
        There is an option to target all subscriptions using the AllSubscriptions switch.
    .EXAMPLE
        PS C:\> Edit-AzTag -Subscription 'MyAzureSub' -ResourceGroupName 'ContosoResourceGroup'
        This will point to the subscription 'MyAzureSub' and target only the resoure group named 'ContosoResourceGroup'
    .EXAMPLE
        PS C:\> Edit-AzTag -AllSubscriptions
        This will target all subscriptions in your Azure environment
    .EXAMPLE
        PS C:\> Edit-AzTag -Subscription 'MyAzureSub'
        This will target all resources in the subscription named 'MyAzureSub'
    .NOTES
        Author:  Ted Sdoukos (Ted.Sdoukos@Microsoft.com)
        Date:    4NOV2020
        Version: 1.0
       
        Copyright (c) Microsoft Corporation.

        MIT License

        Permission is hereby granted, free of charge, to any person obtaining a copy
        of this software and associated documentation files (the "Software"), to deal
        in the Software without restriction, including without limitation the rights
        to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
        copies of the Software, and to permit persons to whom the Software is
        furnished to do so, subject to the following conditions:

        The above copyright notice and this permission notice shall be included in all
        copies or substantial portions of the Software.

        THE SOFTWARE IS PROVIDED *AS IS*, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
        IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
        FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
        AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
        LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
        OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
        SOFTWARE.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Targeted')]
    param (
        [Parameter(ParameterSetName = 'All')]
        [switch]$AllSubscriptions,

        [Parameter(ParameterSetName = 'Targeted', Mandatory)]
        [string]$Subscription,

        [Parameter(ParameterSetName = 'Targeted')]
        [string]$ResourceGroup
    )
    
    begin {
        If (-not(Get-AzContext)) {
            Write-Warning -Message "No Azure Context Found!`n`rLogging you in"
            Login-AzAccount
        }
    }
    process {
        If ($PSCmdlet.ParameterSetName -eq 'All') {
            $AzSubscription = Get-AzSubscription
        }
        Else {
            $AzSubscription = Get-AzSubscription -SubscriptionName $Subscription
        }
        foreach ($s in $AzSubscription) {
            $null = Set-AzContext -SubscriptionName $s.Name
            $bTags = Get-AzTag | Where-Object { $_.Name -match '^\s+|\s+$' }
            If (-not($bTags)) {
                Write-Output -InputObject "There is nothing to clean in subscription: $($s.name)"
                exit
            }
            foreach ($b in $bTags) {
                If ($ResourceGroup) {
                    try {
                        [array]$Resource = Get-AzResourceGroup -Name $ResourceGroup -ErrorAction Stop | Where-Object { $_.Tags.Keys -contains $b.Name } | 
                            Select-Object -Property Tags, ResourceId
                        $Resource += Get-AzResource -ResourceGroupName $ResourceGroup -TagName $b.Name | Select-Object -Property Tags, ResourceId
                    }
                    catch {
                        Write-Warning -Message "Unable to find $ResourceGroup in $($s.name)"
                        exit
                    }
                }
                else {
                    [array]$Resource = Get-AzResource -TagName $b.Name | Select-Object -Property Tags, ResourceId
                    $Resource += Get-AzResourceGroup | Where-Object { $_.Tags.Keys -contains $b.Name } | Select-Object -Property Tags, ResourceId   
                }
                foreach ($r in $Resource) {
                    #Find the one with the space
                    $space = $r.Tags.GetEnumerator() | Where-Object { $_.Key -eq $b.Name }
                    # If there is another one that matches the name, then delete this one
                    If ($r.Tags.ContainsKey($space.Key.Trim())) {
                        $DelTag = @{$space.Key = $space.Value }
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
Function Get-AzTagReport {
    <#
    .SYNOPSIS
        Gathers information about Azure tags in the environment
    .DESCRIPTION
        Gathers information about Azure tags in the environment
    .EXAMPLE
        PS C:\> Get-AzTagReport -Subscription 'MyAzureSub' -NoOutputFile
        This will point to the subscription 'MyAzureSub' supress the creation of the output file.
    .EXAMPLE
        PS C:\> Get-AzTagReport -AllSubscriptions
        This will target all subscriptions in your Azure environment.
    .EXAMPLE
        PS C:\> Get-AzTagReport -Subscription 'MyAzureSub' -OutputFile 'C:\Temp\AzTagReport.csv'
        This will target the subscription named 'MyAzureSub' and output to 'C:\Temp\AzTagReport.csv'
    .NOTES
        Author:  Ted Sdoukos (Ted.Sdoukos@Microsoft.com)
        Date:    4NOV2020
        Version: 1.0
    #>
    [CmdletBinding()]
    Param(
        [Parameter(ParameterSetName = 'Single')]
        $Subscription,

        [Parameter(ParameterSetName = 'All')]
        [Switch]
        $AllSubscriptions,

        $OutputFile = "$env:Temp\GetAzTagReport.csv",

        [switch]$NoOutputFile
    )
    Begin {
        If (-not(Get-AzContext)) {
            Write-Warning -Message "No Azure Context Found!`n`rLogging you in"
            Login-AzAccount
        }
    }
    Process {
        If ($PSCmdlet.ParameterSetName -eq 'All') {
            [System.Collections.ArrayList]$AzSubscription = (Get-AzSubscription).Name
        }
        else {
            try {
                $AzSubscription = New-Object -TypeName System.Collections.ArrayList
                $null = $AzSubscription.Add((Get-AzSubscription -SubscriptionName $Subscription -ErrorAction Stop).Name)
            }
            catch {
                Write-Warning -Message "Unable to find subscription: $Subscription"
                Exit
            }
        }
        #region Grab ALL tags from selected Subscriptions
        $AzTags = 'ResourceGroupName', 'Subscription'
        foreach ($s in $AzSubscription) {
            $null = Set-AzContext -Subscription $s
            $AzTags += (Get-AzTag).Name
        }
        #Check for duplicate tags
        $unique = ($AzTags.ToUpper().Trim() | Select-Object -Unique).count
        $actual = $AzTags.count
        if ($unique -ne $actual) {
            Write-Warning -Message "You have duplicated tag names in subscription name: $s`n`rActual: $actual`n`rUnique: $unique"
            Write-Warning -Message "Run 'Edit-AzTag -Subscription $s' to correct or edit manually at https://portal.azure.com`n`rSKIPPING subscription name $s"
            $null = $AzSubscription.Remove($s)
            Continue
        }
        $AzTags -join ',' | Out-File -FilePath $OutputFile
        #EndRegion

        #Region Grab all information for Resource Groups
        foreach ($s in $AzSubscription) {
            $null = Set-AzContext -Subscription $s
            $ResourceGroup = Get-AzResourceGroup 
            foreach ($Resource in $ResourceGroup) {
                $r = Get-AzResourceGroup -Name $Resource.ResourceGroupName
                [System.Collections.Hashtable]$Tags = $r.Tags
                $out = [ordered]@{
                    'ResourceGroupName' = $r.ResourceGroupName
                    'Subscription'      = $s
                }
                if ($tags) {
                    $Tags.GetEnumerator() | ForEach-Object {
                        $out.($_.Name) = $_.Value
                    }
                }
                $out | ForEach-Object { [PSCustomObject]$_ } | Export-Csv -Path $OutputFile -Append -Force 
                $null = $out
            }    
        }
        #EndRegion
    }
    End {
        If ($NoOutputFile) {
            Import-Csv -Path $OutputFile
            Remove-Item -Path $OutputFile -Force
        }
        else {
            Write-Output -InputObject "Your export file has been created here: $OutputFile"
        }
    }
}

##adding some comment