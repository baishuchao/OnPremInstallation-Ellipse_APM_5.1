$SERVER="https://web.andysongxt.top/"
$AUTHORITY="https://adfs.andysongxt.top/adfs"
$CUSTOMER="CUSTOMER"
$Dataset="QA"
$AADApplicationID="APM-webservice-app"
$FeederApiEndpoint="https://rest.andysongxt.top/api/messages"
$AdminClientId="APM-webservice-admin"
$AdminClientSecret="5i5lybjN3p1m0z0fX_JiUOa41wM2qEfHliiDXqjI"
$ImportClientId="APM-webservice-import"
$ImportClientSecret="wanKo8nl01MVuNUnsFyrZv-g_v4fRxNjT-qHKK7A"
$SuperAdminID="APM-webservice-superadmin"
$SuperAdminSecret="ePF1Qc7cVNijU8YIo1JN7GMJuoN50JJRRcHv9_XY"

cd c:\apm\apminstall\InstallationPackage\InstallScripts

        & ".\PopulateData.ps1" `
            -WebAppServerUrl $Server `
            -Customer $Customer `
            -Dataset $Dataset `
            -Authority $Authority `
            -AadApplicationId $AADApplicationID `
            -FeederApiEndpoint $FeederApiEndpoint `
            -AdminClientId $AdminClientId `
            -AdminClientSecret $AdminClientSecret `
            -ImportClientId $ImportClientId `
            -ImportClientSecret $ImportClientSecret `
            -SuperAdminClientId $SuperAdminClientId `
            -SuperAdminClientSecret $SuperAdminClientSecret `
            -PopulateModelConfigurations

cd C:\Users\Administrator\Desktop