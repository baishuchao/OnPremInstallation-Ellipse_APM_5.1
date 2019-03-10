param(
    [string]$AppGroupId,
    [string]$WebServiceId,
    [string]$WebServiceApiRoleName,
    [string[]]$RedirectUrl,
    [string]$EngineersGroupId,
    [string]$AdministratorsGroupId
)

# Create Claim rules for api
$claimRules = (New-AdfsClaimRuleSet -ClaimRule "
@RuleTemplate = `"PassThroughClaims`"
@RuleName = `"AppId`"
c:[Type == `"http://schemas.microsoft.com/2014/01/clientcontext/claims/appid`"] => issue(claim = c);

@RuleTemplate = `"EmitGroupClaims`"
@RuleName = `"Engineer Role by group`"
c:[Type == `"http://schemas.microsoft.com/ws/2008/06/identity/claims/groupsid`", Value == `"$($EngineersGroupId)`", Issuer == `"AD AUTHORITY`"] => issue(Type = `"http://schemas.microsoft.com/ws/2008/06/identity/claims/role`", Value = `"Engineer`", Issuer = c.Issuer, OriginalIssuer = c.OriginalIssuer, ValueType = c.ValueType);

@RuleTemplate = `"EmitGroupClaims`"
@RuleName = `"Administrator Role by group`"
c:[Type == `"http://schemas.microsoft.com/ws/2008/06/identity/claims/groupsid`", Value == `"$($AdministratorsGroupId)`", Issuer == `"AD AUTHORITY`"] => issue(Type = `"http://schemas.microsoft.com/ws/2008/06/identity/claims/role`", Value = `"Administrator`", Issuer = c.Issuer, OriginalIssuer = c.OriginalIssuer, ValueType = c.ValueType);

@RuleTemplate = `"LdapClaims`"
@RuleName = `"User info`"
c:[Type == `"http://schemas.microsoft.com/ws/2008/06/identity/claims/windowsaccountname`", Issuer == `"AD AUTHORITY`"] => issue(store = `"Active Directory`", types = (`"http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress`", `"http://schemas.xmlsoap.org/ws/2005/05/identity/claims/givenname`", `"http://schemas.xmlsoap.org/ws/2005/05/identity/claims/surname`"), query = `";mail,givenName,sn;{0}`", param = c.Value);
").ClaimRulesString

# Create WebService Api Principal
$client = Add-AdfsServerApplication -ApplicationGroupIdentifier $AppGroupId -Name $WebServiceId -Identifier $WebServiceId -RedirectUri $RedirectUrl -GenerateClientSecret

# Add Api role for WebService app
Add-AdfsWebApiApplication -ApplicationGroupIdentifier $AppGroupId -Name $WebServiceApiRoleName -Identifier $WebServiceId -AccessControlPolicyName "Permit everyone" -IssuanceTransformRules $claimRules
Grant-AdfsApplicationPermission -ClientRoleIdentifier $WebServiceId -ServerRoleIdentifier $WebServiceId -ScopeNames @("openid", "allatclaims")

.\Write-ClientCredentials.ps1 -PrincipalType "Web Service API" -Client $client



