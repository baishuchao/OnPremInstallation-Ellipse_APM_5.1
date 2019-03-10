
$ENVIRONMENT_NAME = "apm"
$KUBECONFIG_LOCATION = ".\config"
$CUSTOMER = "customer"

Write-Warning "Cleaning customer: $ENVIRONMENT_NAME-$CUSTOMER namespace ....."
cd C:\apm\apminstall\InstallationPackage\InstallScripts
.\K8sDeleteTenantNamespace.ps1 -NamespacePrefix $ENVIRONMENT_NAME -K8sConfigPath $KUBECONFIG_LOCATION -Customers $CUSTOMER

Write-Warning "Cleaning common: $ENVIRONMENT_NAME namespace ....."
cd C:\apm\apminstall\InstallationPackage\InstallScripts
.\K8sDeleteCommonNamespace.ps1 -NamespacePrefix $ENVIRONMENT_NAME -K8sConfigPath $KUBECONFIG_LOCATION

cd C:\Users\Administrator\Desktop