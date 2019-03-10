$SERVER="https://web.andysongxt.top/"
$AUTHORITY="https://adfs.andysongxt.top/adfs"
$CUSTOMER="CUSTOMER"
$AADApplicationID="APM-webservice-app"
$SuperAdminID="APM-webservice-superadmin"
$SuperAdminSecret="ePF1Qc7cVNijU8YIo1JN7GMJuoN50JJRRcHv9_XY"

<# in k8screator.ps1 file
        & ".\Customer" `
            -Server $Server `
            -Customer $Customer `
            -CreateNoUpdate `
            -PowerBIs `
            -Authority $Authority `
            -AadApplicationId $AadApplicationId `
            -SuperAdminClientId $SuperAdminClientId `
            -SuperAdminClientSecret $SuperAdminClientSecret
#>

cd c:\apm\apminstall\InstallationPackage\InstallScripts
.\Customer.ps1 -Server $SERVER -Authority $AUTHORITY -Customer $CUSTOMER -AadApplicationId $AADApplicationID -SuperAdminClientId $SuperAdminID -SuperAdminClientSecret $SuperAdminSecret -Delete
cd C:\Users\Administrator\Desktop
