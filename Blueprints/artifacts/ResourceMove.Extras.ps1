param($SCPath, $Sub, $Intag, $Resources, $Task , $File, $SmaResources, $TableStyle)

If ($Task -eq 'Processing') {

    <######### Insert the resource extraction here ########>
    $CSVSupport = "$Env:TEMP\moveSupport.csv"
    $null = Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/tfitzmac/resource-capabilities/main/move-support-resources-with-regions.csv' -OutFile $CSVSupport
    $info = Import-Csv -Path $CSVSupport
    if ($Resources) {
        $tmp = @()
        foreach ($1 in $Resources) {
            $ResUCount = 1
            $sub1 = $SUB | Where-Object { $_.id -eq $1.subscriptionId }
            if ([string]::IsNullOrEmpty($sub1.Name)) {
                $sub1 = Get-AzSubscription | Where-Object {$_.Id -eq $1.subscriptionId}
            }
            $Tags = if (![string]::IsNullOrEmpty($1.tags.psobject.properties)) { $1.tags.psobject.properties }else { '0' }
            foreach ($Tag in $Tags) {
                $lineItem = $info | Where-Object { $_.Resource -eq $1.Type }
                $obj = @{
                    'ID'                = $1.id;
                    'Subscription'      = $sub1.Name;
                    'SubID'             = $1.subscriptionId
                    'Resource Group'    = $1.RESOURCEGROUP;
                    'Location'          = $1.LOCATION;                
                    'Name'              = $1.Name
                    'ResourceType'      = $1.Type                        
                    'MoveResourceGroup' = if ($lineItem.'Move Resource Group' -eq 0) { 'FALSE' }elseif ($lineItem.'Move Resource Group' -eq 1) { 'TRUE' }else { 'N/A' }
                    'MoveSubscription'  = if ($lineItem.'Move Subscription' -eq 0) { 'FALSE' }elseif ($lineItem.'Move Subscription' -eq 1) { 'TRUE' }else { 'N/A' }
                    'MoveRegion'        = if ($lineItem.'Move Region' -eq 0) { 'FALSE' }elseif ($lineItem.'Move Region' -eq 1) { 'TRUE' }else { 'N/A' }
                }
                $tmp += $obj
                if ($ResUCount -eq 1) { $ResUCount = 0 } 
            }                
        }
        $tmp
    }
}
<######## Resource Excel Reporting Begins Here ########>
else {
    $Style = New-ExcelStyle -HorizontalAlignment Center -AutoSize -NumberFormat '0'
    
    $Sub | 
        ForEach-Object { [PSCustomObject]$_ } | 
        Select-Object 'Subscription', 'SubID','Name','Resource Group','Location','ResourceType','MoveResourceGroup','MoveSubscription','MoveRegion' | 
        Export-Excel -Path $File -WorksheetName 'ResMover' -AutoSize -MaxAutoSizeRows 100 -TableName 'ResMover' -TableStyle $tableStyle -Style $Style -Numberformat '0' -MoveToStart 

}

<# 
Else {
    ######## $SmaResources.ResourceMove ##########

    if ($SmaResources.ResourceMove) {

        $TableName = ('ResourceMoveTable_' + ($SmaResources.ResourceMove.id | Select-Object -Unique).count)
        $Style = New-ExcelStyle -HorizontalAlignment Center -AutoSize -NumberFormat 0
       
        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Name')
        $Exc.Add('SubID')
        $Exc.Add('Subscription')
        $Exc.Add('Resource Group')
        $Exc.Add('Location')
        $Exc.Add('ResourceType')
        $Exc.Add('MoveResourceGroup')
        $Exc.Add('MoveSubscription')
        $Exc.Add('MoveRegion')
        if ($InTag) {
            $Exc.Add('Tag Name')
            $Exc.Add('Tag Value') 
        }
        
        $ExcelVar = $SmaResources.ResourceMove 

        $ExcelVar | 
            ForEach-Object { [PSCustomObject]$_ } | Select-Object -Unique $Exc | 
                Export-Excel -Path $File -WorksheetName 'ResourceMove' -AutoSize -MaxAutoSizeRows 100 -TableName $TableName -TableStyle $tableStyle -Style $Style -MoveToStart
    }
} #>