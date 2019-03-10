param(
    [string]$AppGroupId,
    [string]$ClientAppId,
    [string]$ResourceApId,
    [string[]]$RedirectUrl,
    [string]$Role
)

$client = (Add-AdfsServerApplication -ApplicationGroupIdentifier $AppGroupId -Name $ClientAppId -Identifier $ClientAppId -RedirectUri $RedirectUrl -GenerateClientSecret)
Grant-AdfsApplicationPermission -ClientRoleIdentifier $ClientAppId -ServerRoleIdentifier $ResourceApId -ScopeNames @("openid", "allatclaims")

$newClaimRule = (New-AdfsClaimRuleSet -ClaimRule "
@RuleTemplate = `"MapClaims`"
@RuleName = `"$($ClientAppId): $($Role) Role`"
c:[Type == `"http://schemas.microsoft.com/2014/01/clientcontext/claims/appid`", Value =~ `"^(?i)$($ClientAppId)$`"] => issue(Type = `"http://schemas.microsoft.com/ws/2008/06/identity/claims/role`", Issuer = c.Issuer, OriginalIssuer = c.OriginalIssuer, Value = `"$($Role)`", ValueType = c.ValueType);").ClaimRulesString

$existingClaimRules = (Get-AdfsWebApiApplication -Identifier $ResourceApId).IssuanceTransformRules
$updatedClaimRules = $existingClaimRules + $newClaimRule
Set-AdfsWebApiApplication -TargetIdentifier $ResourceApId -IssuanceTransformRules (New-AdfsClaimRuleSet -ClaimRule $updatedClaimRules).ClaimRulesString

.\Write-ClientCredentials.ps1 -PrincipalType $ClientAppId -Client $client
