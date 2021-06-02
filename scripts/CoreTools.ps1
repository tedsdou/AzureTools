Function Get-MonthNames {
    (Get-Culture).DateTimeFormat.MonthGenitiveNames
}

Function ConvertFrom-HexTime{
    Param($hexTime)
        [datetime]::FromFileTime( [convert]::ToInt64( $hexTime ,16  ))
    }
    
    Function ConvertFrom-LastLogonTimeStamp{
    Param($timeStamp)
        [datetime]::FromFileTime($timeStamp)
    }
    
    Function ConvertFrom-Epoch
    {
    Param($epochTime)
    $origin = New-Object -Type DateTime -ArgumentList 1970, 1, 1, 0, 0, 0, 0
    $origin.AddSeconds($epochTime)
    
    }
Function ConvertTo-KiloGram {
    <#
    .SYNOPSIS
    Short description
    
    .DESCRIPTION
    Long description
    
    .EXAMPLE
    An example
    
    .NOTES
    General notes
    #>
    [CmdletBinding()]
    Param($Pound)
    Write-Output -InputObject "$Pound pounds | $('{0:N1}' -f ($Pound / 2.2)) kilograms"

}
Function ConvertTo-Celsius {
    Param($f)

    <#
°F to °C
Deduct 32, then multiply by 5, then divide by 9
#>

    '{0:N0}' -f (($f - 32) * 5 / 9)
}

Function ConvertFrom-Celsius {
    Param($degree)
    <#
Multiply by 9, then divide by 5, then add 32
#>
    '{0:N0}' -f (($degree * 9) / 5 + 32)

}

Function Get-PublicIP {
    [CmdletBinding()]
    Param()
    $pattern = '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}'
    $null = (Invoke-WebRequest -Uri 'https://www.bing.com/search?q=IP+Address' | Select-Object -Property content) -match $pattern 
    If ($Matches) { Write-Output $Matches.values  }
}

Function ConvertTo-ProperCase {
    [CmdletBinding()]
    Param($string)

    (Get-Culture).TextInfo.ToTitleCase($string)
}

Function Search-History {
    [CmdletBinding()]
    Param($SearchString)
    Get-History | Where-Object CommandLine -match $SearchString | Out-GridView -PassThru | Invoke-History
}

Function Rename-Profile {
    [CmdletBinding()]
    Param()

    Rename-Item $profile -NewName "$profile.old"
    pause
    Rename-Item "$profile.old" -NewName $profile
}
