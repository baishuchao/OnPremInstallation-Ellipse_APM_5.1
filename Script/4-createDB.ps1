$DATABASE_TOOL_PATH="C:\apm\apm-buildingblocks-databasemanagementtool\database-management-tool"
$SQL_CONNECTION_STRING="Data Source=192.168.0.136,1433;User ID=sa;Password=1qaz!QAZ;"
$CUSTOMER="customer"
$DATABASE_ACTION="update"

cd c:\apm\apminstall\InstallationPackage\InstallScripts
.\DatabaseManagement.ps1 -DatabaseToolPath $DATABASE_TOOL_PATH -SqlConnectionString $SQL_CONNECTION_STRING -Customer $CUSTOMER -databaseAction $DATABASE_ACTION
cd C:\Users\Administrator\Desktop