Write-Host $env:COMPUTERNAME; Write-Host (whoami)
if(Test-Path C:\Windows){
    Write-Host "exists"
    }
$session = Invoke-Command -InDisconnectedSession -Credential $cred -ScriptBlock {
    Write-Host $env:COMPUTERNAME; Write-Host (whoami); Test-Path \\2012R2-DC\C$\Windows
    } -ComputerName 2012R2-MS
    Start-Sleep -Seconds 5
    $result = Receive-PSSession -Session $session ; $result
