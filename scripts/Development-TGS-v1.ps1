<#
.Synopsis
   Extract data from email

.DESCRIPTION
   Uses Regular Expressions to extract patterns from HTML email

.INPUTS
   Input file from email

.OUTPUTS
   Extracted data

.NOTES

Author:  Ted Sdoukos - Ted.Sdoukos@Microsoft.com
Creation Date:  12SEP17
Version: 1.0

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

Param([ValidateScript({Test-Path -Path $_})]
      $source = 'C:\Temp\Email.txt' )

$info = Get-Content -Path $source

# Scrub HTMl
$info = $info -replace '&gt;','>' -replace '</.*>|<.*>|&nbsp;','' 

# Start Search

$Intr = $info -match '^interface\s*:.*' -split 'interface\s*:'

$AlertTxt = $info -match '^Alert Text\s*:.*' -split 'Alert Text\s*:'

$TimeRaised = $info -match '^Time Raised\s*:.*' -split 'Time Raised\s*:'

$SupportHrs = $info -match '^Support Hrs\.\s*:.*' -split 'Support Hrs\.\s*:'

$Escalation = $info -match '^file:\\'  #********** Will this always be file:\\ ? *******

$AlertGrp =$info -match '^Alert Groups\s*:.*' -split 'Alert Groups\s*:'

$Status = $info -match '^Adapter Status\s*:.*' -split 'Adapter Status\s*:'

$IP = $info -match '^TCP/IP\s*:.*' -split 'TCP/IP\s*:'

$QSize = $info -match '^Queue Size\s*:.*' -split 'Queue Size\s*:'

$LMsg = $info -match '^Last Message\s*:.*' -split 'Last Message\s*:'

$LAct = $info -match '^Last Activity\s*:.*' -split 'Last Activity\s*:'

$TLvl = $info -match '^Tier Level\s*:.*' -split 'Tier Level\s*:'

$AlertNum  = $info -match '^Alert#\s*.*' -split 'Alert#\s*'
