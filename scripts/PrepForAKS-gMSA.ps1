# Replace 'WebApp01' and 'contoso.local' with your own gMSA and domain names, respectively.

# To install the AD module on Windows Server, run Install-WindowsFeature RSAT-AD-PowerShell
# To install the AD module on Windows 10 version 1809 or later, run Add-WindowsCapability -Online -Name 'Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0'
# To install the AD module on older versions of Windows 10, see https://aka.ms/rsat

# Prepare AD
Get-KdsRootKey
# For production environments
Add-KdsRootKey -EffectiveImmediately
# For single-DC test environments ONLY
Add-KdsRootKey -EffectiveTime (Get-Date).AddHours(-10)

# Create the security group
New-ADGroup -Name 'WebApp01 Authorized Hosts' -SamAccountName 'WebApp01Hosts' -GroupScope DomainLocal

# Create the gMSA
New-ADServiceAccount -Name 'WebApp01' -DNSHostName 'WebApp01.contoso.local' -ServicePrincipalNames 'host/WebApp01', 'host/WebApp01.contoso.local' -PrincipalsAllowedToRetrieveManagedPassword 'WebApp01Hosts'

# Add your container hosts to the security group
Add-ADGroupMember -Identity 'WebApp01Hosts' -Members 'DC$', 'MS$', 'WIN10$'