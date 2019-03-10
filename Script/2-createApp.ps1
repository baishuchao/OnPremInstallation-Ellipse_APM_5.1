$APP_GROUP_ID = "APM"
$REDIRECT_URLS = "https://web.andysongxt.top/signin-oidc"
$ENGINEERS_GROUP_ID = "S-1-5-21-3736716889-3166038402-411466330-1106"
$ADMIN_GROUP_ID = "S-1-5-21-3736716889-3166038402-411466330-1105"

cd C:\apm\apminstall\InstallationPackage\EnvironmentConfiguration\ADSetup
.\PrincipalsCreator-ADFS.ps1 -AppGroupID $APP_GROUP_ID -WebserviceRedirectUri $REDIRECT_URLS -AdminGroup $ADMIN_GROUP_ID -EngineersGroup $ENGINEERS_GROUP_ID
cd C:\Users\Administrator\Desktop