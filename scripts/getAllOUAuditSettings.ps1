<##############################################################################

Zach Butler

Microsoft Premier Field Engineer

July 2014



This script takes a report of all OU Audit settings.

Taken and modified from Ashley McGlone - https://urldefense.proofpoint.com/v1/url?u=http://aka.ms/GoateePFE&k=4%2BViHuL0UtSJBpVrYi3EdQ%3D%3D%0A&r=Jek3QSvahmIrNAN1nuPfQA%3D%3D%0A&m=1Hv9hh7I%2Bg5SBcgjZTK9K7XyCszBaTVyzGagkcNgWbQ%3D%0A&s=bf6cd14fe8d9bcfb227cc61a6deb6e9b2b1a26f571d113ad1bb1026f52869f24

https://urldefense.proofpoint.com/v1/url?u=http://gallery.technet.microsoft.com/Active-Directory-OU-1d09f989&k=4%2BViHuL0UtSJBpVrYi3EdQ%3D%3D%0A&r=Jek3QSvahmIrNAN1nuPfQA%3D%3D%0A&m=1Hv9hh7I%2Bg5SBcgjZTK9K7XyCszBaTVyzGagkcNgWbQ%3D%0A&s=d5bf6c069ff5339ff35a35184f90b244065c2c4a02d64578fa145d99653859b0





LEGAL DISCLAIMER

This Sample Code is provided for the purpose of illustration only and is not

intended to be used in a production environment.  THIS SAMPLE CODE AND ANY

RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER

EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF

MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.  We grant You a

nonexclusive, royalty-free right to use and modify the Sample Code and to

reproduce and distribute the object code form of the Sample Code, provided

that You agree: (i) to not use Our name, logo, or trademarks to market Your

software product in which the Sample Code is embedded; (ii) to include a valid

copyright notice on Your software product in which the Sample Code is embedded;

and (iii) to indemnify, hold harmless, and defend Us and Our suppliers from and

against any claims or lawsuits, including attorneys? fees, that arise or result

from the use or distribution of the Sample Code.

 

This posting is provided "AS IS" with no warranties, and confers no rights. Use

of included script samples are subject to the terms specified

at https://urldefense.proofpoint.com/v1/url?u=http://www.microsoft.com/info/cpyright.htm&k=4%2BViHuL0UtSJBpVrYi3EdQ%3D%3D%0A&r=Jek3QSvahmIrNAN1nuPfQA%3D%3D%0A&m=1Hv9hh7I%2Bg5SBcgjZTK9K7XyCszBaTVyzGagkcNgWbQ%3D%0A&s=2691df239da9a6323b1a2742374fcdc5998895cf741d36ee93ed10c0dedf81a1.



Requirements:

PowerShell v2

Active Directory Module

##############################################################################>



Import-Module ActiveDirectory



# This array will hold the report output.

$report = @()



$schemaIDGUID = @{}

$ErrorActionPreference = 'SilentlyContinue'

Get-ADObject -SearchBase (Get-ADRootDSE).schemaNamingContext -LDAPFilter '(schemaIDGUID=*)' -Properties name, schemaIDGUID |

 ForEach-Object {$schemaIDGUID.add([System.GUID]$_.schemaIDGUID,$_.name)}

Get-ADObject -SearchBase "CN=Extended-Rights,$((Get-ADRootDSE).configurationNamingContext)" -LDAPFilter '(objectClass=controlAccessRight)' -Properties name, rightsGUID |

 ForEach-Object {$schemaIDGUID.add([System.GUID]$_.rightsGUID,$_.name)}

$ErrorActionPreference = 'Continue'



# Get a list of all OUs.  Add in the root containers for good measure (users, computers, etc.).

$OUs  = @(Get-ADOrganizationalUnit -Filter * | Select-Object -ExpandProperty DistinguishedName)

$OUs += Get-ADObject -SearchBase (Get-ADDomain).DistinguishedName -SearchScope OneLevel -LDAPFilter '(objectClass=container)' | Select-Object -ExpandProperty DistinguishedName



# Loop through each of the OUs and retrieve their permissions.

# Add report columns to contain the OU path and string names of the ObjectTypes.

ForEach ($OU in $OUs) {

    $report += Get-Acl -audit -Path "AD:\$OU" |

     Select-Object -ExpandProperty audit | 

     Select-Object @{name='organizationalUnit';expression={$OU}}, `

                   @{name='objectTypeName';expression={if ($_.objectType.ToString() -eq '00000000-0000-0000-0000-000000000000') {'All'} Else {$schemaIDGUID.Item($_.objectType)}}}, `

                   @{name='inheritedObjectTypeName';expression={$schemaIDGUID.Item($_.inheritedObjectType)}}, `

                   *

}



# Dump the raw report out to a CSV file for analysis in Excel.

$report | Export-Csv ".\All_OU_Audit_Settings.csv" -NoTypeInformation

Start-Process ".\All_OU_Audit_Settings.csv"



###############################################################################

# Various reports of interest

###############################################################################

break



# Show only explicitly assigned permissions by Group and OU

$report |

 Where-Object {-not $_.IsInherited} |

 Select-Object IdentityReference, OrganizationalUnit -Unique |

 Sort-Object IdentityReference



# Show explicitly assigned permissions for a user or group

$filter = Read-Host "Enter the user or group name to search in OU permissions"

$report |

 Where-Object {$_.IdentityReference -like "*$filter*"} |

 Select-Object IdentityReference, OrganizationalUnit, IsInherited -Unique |

 Sort-Object IdentityReference

