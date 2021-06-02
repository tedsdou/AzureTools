
$names = (Get-GPO -All).DisplayName
foreach($n in $names){ 
    $display = $n -replace 'd'
    Get-GPOReport -ReportType Xml -Name $n -Path "$PSScriptRoot\$display.xml"  
    }
