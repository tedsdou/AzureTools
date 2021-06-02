# Create a file called ComputerList.txt and put one hostname per line
$machines = Get-Content -Path 'ComputerList.txt'

Foreach($machine in $machines){
    try{
        $NetTest = (Test-Connection -ComputerName $machine -ErrorAction Stop -Count 1).IPV4Address
        $Pingable = 'True'
    }
    catch{
        $NetTest = "ERROR: $($_.Exception.Message)"
        $Pingable = 'False'
    }
    finally{
        [PSCustomObject]@{
            'ComputerName' = $machine
            'IPInfo'       = $NetTest
            'Pingable'     = $Pingable
        }
    }
}