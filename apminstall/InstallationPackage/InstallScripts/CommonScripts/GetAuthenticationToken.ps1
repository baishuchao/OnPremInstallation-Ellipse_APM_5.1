#Requires -Version 4.0
[CmdletBinding(PositionalBinding = $false)]
param (
    [parameter(
        Mandatory = $true,
        HelpMessage = 'Client application principal Id'
    )]
    [String]$clientId,
    [parameter(
        Mandatory = $true,
        HelpMessage = 'Client application principal secret key'
    )]
    [String]$clientKey,
    [parameter(
        Mandatory = $true,
        HelpMessage = 'Resource application Id'
    )]
    [String]$resourceAppId,
    [parameter(
        Mandatory = $true,
        HelpMessage = 'ActiveDirectory authority URI'
    )]
    [Uri]$authority
)

$ssl3 = [System.Net.SecurityProtocolType]48
$tls11 = [System.Net.SecurityProtocolType]768
$tls12 = [System.Net.SecurityProtocolType]3072

try {
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor $tls11
}
catch {
    Write-Debug "Could not add TLS 1.1 to .net security protocol settings: $($_.Exception.Message)"
}
try {
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor $tls12
}
catch {
    Write-Debug "Could not add TLS 1.2 to .net security protocol settings: $($_.Exception.Message)"
}
try {
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -band (-bnot $ssl3)
}
catch {
    Write-Debug "Could not remove SSL from .net security protocol settings: $($_.Exception.Message)"
}

$module = Get-Module -List Microsoft.ADAL.PowerShell
if (!$module) { 
    Install-PackageProvider -Name NuGet -Force -Scope CurrentUser
    Install-Module -Name Microsoft.ADAL.PowerShell -Force -Scope CurrentUser
}
Import-Module Microsoft.ADAL.PowerShell

Write-Verbose "Acquiring token for client id $clientId..."

$authContext = New-Object Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext($authority, $false)
$clientCred = New-Object Microsoft.IdentityModel.Clients.ActiveDirectory.ClientCredential($clientId, $clientKey)
$authResult = $authContext.AcquireToken($resourceAppId, $clientCred)

Write-Verbose "Token aquired for client id $clientId. Token expires on $($authResult.ExpiresOn). Id Token: $($authResult.IdToken)"

return $authResult