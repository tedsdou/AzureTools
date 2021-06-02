# Example 1 with a foreach loop

$dirs = Get-ChildItem 'C:\Program Files' -Recurse -Directory
$i = 0 # initialize our iterator

Foreach($dir in $dirs){
    $i++
    $percent = (($i / $dirs.Count)  * 100) # percent will be iterator / total count of array * 100
    # In Write-Progress, you'll just need to go through the status and round your percent for CurrentOperation
    Write-Progress -activity 'Working...' -Status "Scanned: $i of $($dirs.Count)" `
        -PercentComplete $percent -CurrentOperation "$(([math]::Round($percent)))% complete"
    "DirName: $($dirs[$i-1]) | CurrentNumber: $i" # $i-1 is to start at index 0 in the $dirs array
}

# Example 2 with a for loop

$dirs = Get-ChildItem 'C:\Program Files' -Recurse -Directory

for ($i=1; $i -lt ($dirs.Count+1); $i++) {
    $percent = (($i / $dirs.Count)  * 100)
    $fPercent = [math]::Round($percent)
    Write-Progress -Activity 'Working...' -PercentComplete $percent -CurrentOperation " $fPercent % complete" `
        -Status 'Please wait.'
    "DirName: $($dirs[$i-1]) | CurrentNumber: $i"
}
