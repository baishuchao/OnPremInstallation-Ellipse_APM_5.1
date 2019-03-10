$superadmin_clientkey="ePF1Qc7cVNijU8YIo1JN7GMJuoN50JJRRcHv9_XY"

cd C:\apm\apminstall\InstallationPackage\InstallScripts\CommonScripts
.\GetAuthenticationToken.ps1 -authority https://adfs.andysongxt.top/adfs -clientId APM-webservice-superadmin -clientKey $superadmin_clientkey -resourceAppId APM-webservice-app
