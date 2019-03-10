$ENVIRONMENTFILE="C:\apm\apminstall\InstallationPackage\InstallScripts\EnvironmentsConfigs\env.json"


cd c:\apm\apminstall\InstallationPackage\InstallScripts
.\K8sCreator.ps1 -EnvironmentConfigDataPath $ENVIRONMENTFILE -Tenants @("customer")
cd C:\Users\Administrator\Desktop
