#Requires -Version 4.0
[CmdletBinding(PositionalBinding = $false)]
Param(
    [parameter(
        Mandatory = $true,
        HelpMessage = 'Sql Connection String'
    )]
    [ValidateNotNullOrEmpty()]
    [string]$SqlConnectionString,

    [parameter(
        Mandatory = $true,
        HelpMessage = 'Database name'
    )]
    [ValidateNotNullOrEmpty()]
    [string]$DatabaseName
)

[string] $result
Try {
    [System.Data.SqlClient.SqlConnectionStringBuilder] $connBuilder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder($SqlConnectionString)
    $connBuilder["Initial Catalog"] = $DatabaseName
    $result = $connBuilder.ConnectionString
}
Catch {
    Write-Error "Invalid connection string"
    throw
}
Write-Output $result



