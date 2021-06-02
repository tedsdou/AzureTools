#requires -version 3 -modules ActiveDirectory
$groups = 'Domain Admins','Enterprise Admins','Schema Admins','Backup Operators','Server Operators','Account Operators'
Foreach ($group in $groups)
{
    Get-ADGroupMember -Identity $group | 
        ForEach-Object {
            [PSCustomObject]@{
                'GroupName' = $group
                'Name' = $_.name
                'Type' = $_.objectClass
                'PasswordLastSet' = (Get-ADUser -Identity $_.name -Properties PasswordLastSet -ErrorAction Ignore).PasswordLastSet
                'Enabled' = (Get-ADUser -Identity $_.name -Properties Enabled -ErrorAction Ignore).Enabled
               } | 
         Export-Csv -Path "C:\temp\PrivUsrReport-$(Get-Date -Format ddMMMyyy).csv" -Append
        }
}
# SIG # Begin signature block
# MIIIawYJKoZIhvcNAQcCoIIIXDCCCFgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUMDH5vROyFlzQaPW2LJhIy8eu
# XBOgggXQMIIFzDCCBLSgAwIBAgITGwAAAC3keeiKKsz/TQAAAAAALTANBgkqhkiG
# 9w0BAQUFADBNMRMwEQYKCZImiZPyLGQBGRYDY29tMRcwFQYKCZImiZPyLGQBGRYH
# Y29udG9zbzEdMBsGA1UEAxMUY29udG9zby0yMDEyUjItREMtQ0EwHhcNMTgwMTEy
# MTc0ODU3WhcNMjMxMjEyMTIyOTI3WjBWMRMwEQYKCZImiZPyLGQBGRYDY29tMRcw
# FQYKCZImiZPyLGQBGRYHY29udG9zbzEOMAwGA1UEAxMFVXNlcnMxFjAUBgNVBAMT
# DUFkbWluaXN0cmF0b3IwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDR
# pu1DxwKAymITI9NeVgSUbqnzCYp8NiEKIc9UPMo/GbB9z7hbFhr4my4qeED4C1mk
# R+YsGZMF5CpSTw59AIOKPVvNNcxKQFU62SJRvyou4HKThbIEdBNY+BiEkNDhbnMs
# nqhH9BKkjS6uFtepaEHh89+LVZfzHCoXKc8niByorg/iimQxp5TwSLQpM7EsGXBG
# X2B87cpF+2fQmCty6gDvk9+OohuQuytQggjF1dy8YDcLywj8jUFI4M9jODu6OnvA
# GxC1VNVDDSnNRUYNImSAlgv/ZFWDucTZ7ZCMTwEpU23LysfY9Hm/OAS1jV/I1s3Z
# uN01sc9wbbG8527PWljBAgMBAAGjggKaMIICljA8BgkrBgEEAYI3FQcELzAtBiUr
# BgEEAYI3FQjTnFuHt4hjhIWVJ4Hs1TGF2ollgWu6qVGH060EAgFkAgECMBMGA1Ud
# JQQMMAoGCCsGAQUFBwMDMA4GA1UdDwEB/wQEAwIHgDAbBgkrBgEEAYI3FQoEDjAM
# MAoGCCsGAQUFBwMDMB0GA1UdDgQWBBRDYMY420fxGOX2hKT1TOA6dlodejAfBgNV
# HSMEGDAWgBQDk6S7smbhtQxQkdXglwIVNwi0FzCB1AYDVR0fBIHMMIHJMIHGoIHD
# oIHAhoG9bGRhcDovLy9DTj1jb250b3NvLTIwMTJSMi1EQy1DQSxDTj0yMDEyUjIt
# REMsQ049Q0RQLENOPVB1YmxpYyUyMEtleSUyMFNlcnZpY2VzLENOPVNlcnZpY2Vz
# LENOPUNvbmZpZ3VyYXRpb24sREM9Y29udG9zbyxEQz1jb20/Y2VydGlmaWNhdGVS
# ZXZvY2F0aW9uTGlzdD9iYXNlP29iamVjdENsYXNzPWNSTERpc3RyaWJ1dGlvblBv
# aW50MIHGBggrBgEFBQcBAQSBuTCBtjCBswYIKwYBBQUHMAKGgaZsZGFwOi8vL0NO
# PWNvbnRvc28tMjAxMlIyLURDLUNBLENOPUFJQSxDTj1QdWJsaWMlMjBLZXklMjBT
# ZXJ2aWNlcyxDTj1TZXJ2aWNlcyxDTj1Db25maWd1cmF0aW9uLERDPWNvbnRvc28s
# REM9Y29tP2NBQ2VydGlmaWNhdGU/YmFzZT9vYmplY3RDbGFzcz1jZXJ0aWZpY2F0
# aW9uQXV0aG9yaXR5MDQGA1UdEQQtMCugKQYKKwYBBAGCNxQCA6AbDBlBZG1pbmlz
# dHJhdG9yQGNvbnRvc28uY29tMA0GCSqGSIb3DQEBBQUAA4IBAQCFpPAXqoi5PK7U
# iWdPsyuGt2psPZvdZk7wh99ummKnOoSbG1W5q+/97UkCx4fa/edYoWmQXJO/WJe8
# Ao5XCcOD4aosjkuo6x1nnX6yhL94DA0YkQ02a7AbYIYaFtfHtEUiGRzGRyXYBy5Q
# 8djdeDsKd5t3BYYQZWC52fAXzNQ8mnIJ5l5TJWQ0T8ZMn1ofd09vSwF6JwzeW+Be
# rzs9rqB2ZiMSdWEmPd+GjH0e8b0O+BJaoCAfaWzT7o2foO+sc1FfTf5qBB2dKVMP
# GmKnwKn8F7hy8IT2/4E5uvjbKhkuPB6RdFFkKJMP6nmJxBJvWP6rlR99K3NpTuqx
# GyUY2jREMYICBTCCAgECAQEwZDBNMRMwEQYKCZImiZPyLGQBGRYDY29tMRcwFQYK
# CZImiZPyLGQBGRYHY29udG9zbzEdMBsGA1UEAxMUY29udG9zby0yMDEyUjItREMt
# Q0ECExsAAAAt5HnoiirM/00AAAAAAC0wCQYFKw4DAhoFAKB4MBgGCisGAQQBgjcC
# AQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYB
# BAGCNwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFHOBWEUZMzpN
# pHoQpX/wbdeOPrLGMA0GCSqGSIb3DQEBAQUABIIBAI2iEfYFrTQpdPRG0/yP+DPz
# nJhvmd90vrBz03r1mrCPqvjxYfYELKf38ctfIX3ckwE+tJBLaTe81Z9JxyJe+pVI
# NCIO6TNLn54p4jlL7qtmlzCCGa5PCu80vR3yqH8PJIPjIfCYMZijRgJ8l9rk6YTj
# fPvejJ0+HnH/3y0OTHUH5DbclJSGi+S2t+fbpSEs295Cd/6cDbV2N27czh94UJWq
# Ozu8Tf2YjPuBJzPHI9ANJkb8twM9khgsr/c8Ia9TI6NYJibqGDPj7CtWxaaq27FK
# mSWfkSJYjWxV/cu4sMpeUX05dJjHiR3mOMy86AcysABNZCg51mbiFMxOmI1pL+Y=
# SIG # End signature block
