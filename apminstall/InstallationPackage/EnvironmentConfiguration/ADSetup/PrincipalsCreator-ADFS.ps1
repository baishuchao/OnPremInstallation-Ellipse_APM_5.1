param(
    [string]$AppGroupID,
    [string[]]$WebserviceRedirectUri,
    [string]$EngineersGroup,
    [string]$AdminGroup
)

# Create Application Group
if ( Get-AdfsApplicationGroup -ApplicationGroupIdentifier $AppGroupID ) {
    Remove-AdfsApplicationGroup -TargetApplicationGroupIdentifier $AppGroupID
}
New-AdfsApplicationGroup -Name $AppGroupID -ApplicationGroupIdentifier $AppGroupID

$WebServiceApp = "$AppGroupID-webservice-app"

## Create WebService Principals
.\Create-WebServiceApi.ps1 `
    -AppGroupId $AppGroupID `
    -WebServiceId  $WebServiceApp `
    -WebServiceApiRoleName "$AppGroupID-webservice-api" `
    -RedirectUrl $WebserviceRedirectUri `
    -EngineersGroupId $EngineersGroup `
    -AdministratorsGroupId $AdminGroup

.\Create-ClientWithRoleForApp.ps1 -AppGroupId $AppGroupID `
    -ClientAppId "$AppGroupID-webservice-superadmin" `
    -ResourceApId $WebServiceApp `
    -RedirectUrl $webserviceRedirectUri `
    -Role "SuperAdmin"

.\Create-ClientWithRoleForApp.ps1 -AppGroupId $AppGroupID `
    -ClientAppId "$AppGroupID-webservice-scheduler" `
    -ResourceApId $WebServiceApp `
    -RedirectUrl $webserviceRedirectUri `
    -Role "Scheduler"

.\Create-ClientWithRoleForApp.ps1 -AppGroupId $AppGroupID `
    -ClientAppId "$AppGroupID-webservice-import" `
    -ResourceApId $WebServiceApp `
    -RedirectUrl $webserviceRedirectUri `
    -Role "Import"

.\Create-ClientWithRoleForApp.ps1 -AppGroupId $AppGroupID `
    -ClientAppId "$AppGroupID-webservice-admin" `
    -ResourceApId $WebServiceApp `
    -RedirectUrl $webserviceRedirectUri `
    -Role "Administrator"