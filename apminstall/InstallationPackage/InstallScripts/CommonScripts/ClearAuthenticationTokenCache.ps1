#Requires -Version 4.0
[CmdletBinding(PositionalBinding = $false)]
param (
    [parameter(
        Mandatory = $true,
        HelpMessage = 'ActiveDirectory authority URI'
    )]
    [String]$authority
)

$module = Get-Module -List Microsoft.ADAL.PowerShell
if (!$module) { 
    Install-PackageProvider -Name NuGet -Force -Scope CurrentUser
    Install-Module -Name Microsoft.ADAL.PowerShell -Force -Scope CurrentUser
}
Import-Module Microsoft.ADAL.PowerShell

$authContext = New-Object Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext($authority, $false)
$authContext.TokenCache.Clear()

Write-Verbose "Token cache cleared."