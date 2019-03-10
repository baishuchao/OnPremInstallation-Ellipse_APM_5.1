#Requires -Version 4.0
[CmdletBinding(PositionalBinding = $false)]
Param(
    [Parameter(
        Mandatory = $true,
        HelpMessage = 'Resource group name'
    )]
    [ValidateNotNullOrEmpty()]
    [string] $ResourceGroupName,

    [Parameter(
        Mandatory = $true,
        HelpMessage = 'Template file path'
    )]
    [ValidateNotNullOrEmpty()]
    [string] $TemplateFilePath,

    [Parameter(
        Mandatory = $true,
        HelpMessage = 'Sql server name'
    )]
    [ValidateNotNullOrEmpty()]
    [string] $SqlServerName,

    [Parameter(
        Mandatory = $false,
        HelpMessage = 'Sql server location'
    )]
    [string] $SqlServerLocation = $null,
  
    [Parameter(
        Mandatory = $true,
        HelpMessage = 'Database name'
    )]
    [ValidateNotNullOrEmpty()]
    [string] $SqlDatabaseName,

    [Parameter(
        Mandatory = $false,
        HelpMessage = 'Create tenant database'
    )]
    [bool] $CreateTenantDatabase = $false,

    [Parameter(
        Mandatory = $false,
        HelpMessage = 'Sql database collation'
    )]
    [string] $SqlDatabaseCollation = $null,

    [Parameter(
        Mandatory = $false,
        HelpMessage = 'Sql database edition and tier'
    )]
    [string] $SqlDatabaseEditionAndTier = $null,

    [Parameter(
        Mandatory = $false,
        HelpMessage = 'Sql database max size'
    )]
    [string] $SqlDatabaseMaxSize = $null
)
. .\AzureSqlDatabaseUtils.ps1

if ([string]::IsNullOrEmpty($sqlServerLocation)) {
    $SqlServerLocation = $(Get-SqlServerLocation -ResourceGroupName $ResourceGroupName -ServerName $SqlServerName)
}

if ([string]::IsNullOrEmpty($ResourceGroupLocation)) {
    $ResourceGroupLocation = (Get-ResourceGroupLocation -ResourceGroupName $ResourceGroupName)
}

$templateParameters = @{
    "SqlServerName"     = $sqlServerName;
    "SqlDatabaseName"   = $SqlDatabaseName;
    "SqlServerLocation" = $sqlServerLocation
}

if (![string]::IsNullOrEmpty($SqlDatabaseCollation)) {
    $templateParameters.Add("SqlDatabaseCollation", $SqlDatabaseCollation)
}
if (![string]::IsNullOrEmpty($SqlDatabaseEditionAndTier)) {
    $templateParameters.Add("SqlDatabaseEditionAndTier", $SqlDatabaseEditionAndTier)
}
if (![string]::IsNullOrEmpty($SqlDatabaseMaxSize)) {
    $templateParameters.Add("SqlDatabaseMaxSize", $SqlDatabaseMaxSize)
}
    
& ".\Deploy-Template" -ResourceGroupName $ResourceGroupName -TemplateFilePath $TemplateFilePath -TemplateParameters $TemplateParameters