For($i = 0; $i -lt 4; $i++){
    1..3 | ForEach-Object {
        $CloudDBConfirm = Get-ADComputer -Filter {Name -like '*$_*'}
        $SQLServer = $CloudDBConfirm.PSComputerName
        If ($CloudDBConfirm) { Break }
    } 
}

