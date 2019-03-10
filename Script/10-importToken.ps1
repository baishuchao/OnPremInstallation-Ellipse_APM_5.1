$superadmin_clientkey="wanKo8nl01MVuNUnsFyrZv-g_v4fRxNjT-qHKK7A"

cd C:\apm\apminstall\InstallationPackage\InstallScripts\CommonScripts
.\GetAuthenticationToken.ps1 -authority https://adfs.andysongxt.top/adfs -clientId APM-webservice-import -clientKey $superadmin_clientkey -resourceAppId APM-webservice-app
