param(
    [string]$PrincipalType,
    [Object]$Client
)

Write-Host "---------------------------------------------------------------"
Write-Host $PrincipalType
Write-Host "ClientId:     $($Client.Identifier)"
Write-Host "ClientSecret: $($Client.ClientSecret)"
Write-Host "---------------------------------------------------------------"
