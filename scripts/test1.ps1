<#
.SYNOPSIS
Some synopsis

.DESCRIPTION
Some description

.NOTES
Microsoft PowerShell Source File -- Created with Windows PowerShell ISE

FILENAME: 2-CreatingConstrainedEndpoints-Demo.ps1
VERSION:  .09
AUTHOR: Ted Sdoukos - Ted.Sdoukos@microsoft.com
DATE:   Wednesday, October 19, 2016

WORKSHOP:  Windows PowerShell v4.0 for the IT Professional, Part 2
MODULE: Module 2 - Remoting

Please provide credit to original author when used :-)


DISCLAIMER:
===========
This Sample Code is provided for the purpose of illustration only and is 
not intended to be used in a production environment.  
THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT
WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT 
LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS
FOR A PARTICULAR PURPOSE.  

We grant You a nonexclusive, royalty-free
right to use and modify the Sample Code and to reproduce and distribute
the object code form of the Sample Code, provided that You agree:
(i) to not use Our name, logo, or trademarks to market Your software
product in which the Sample Code is embedded; (ii) to include a valid
copyright notice on Your software product in which the Sample Code is
embedded; and (iii) to indemnify, hold harmless, and defend Us and
Our suppliers from and against any claims or lawsuits, including
attorneys' fees, that arise or result from the use or distribution
of the Sample Code.
#>

# Setup firewall rule
Set-NetFirewallProfile –All –Enabled True

# Create Session Configuration File
New-PSSessionConfigurationFile -Path .\restricted.pssc -SessionType RestrictedRemoteServer

# Manipulate/View Configuration File
notepad.exe .\restricted.pssc

# Associate Configuration File with Remote Endpoint
Register-PSSessionConfiguration -Path .\restricted.pssc -Name HelpDesk

# view the restricted session configurations
Get-PSSessionConfiguration

# Set Account Access Permissions
Set-PSSessionConfiguration -Name HelpDesk -ShowSecurityDescriptorUI

# Set an Endpoint RunAs Account
Set-PSSessionConfiguration -Name HelpDesk -RunAsCredential contoso\administrator

# List the session configurations
Get-PSSessionConfiguration -Name HelpDesk

# Unregister the session configuration
Unregister-PSSessionConfiguration HelpDesk
