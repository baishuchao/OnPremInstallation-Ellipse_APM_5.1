#Requires -Version 4.0
[CmdletBinding(PositionalBinding = $false)]
Param(

    [parameter(
        Mandatory = $true,
        HelpMessage = 'URL to the AHC server'
    )]
    [ValidateNotNull()]
    [ValidateScript( {
            if (!$_.IsAbsoluteUri) {
                throw "$_ is not an absolute URL."
            }
            if ($_.Scheme -inotin ('http', 'https')) {
                throw "$_ is not an HTTP/HTTPS URL."
            }
            $true
        })]
    [Uri]$Server,

    [parameter(
        Mandatory = $true,
        HelpMessage = 'Web site name'
    )]
    [ValidateNotNullOrEmpty()]
    [String]$WebSiteName,

    [parameter(
        Mandatory = $true,
        HelpMessage = 'ActiveDirectory authority URI'
    )]
    [Uri]$Authority,
    [parameter(
        Mandatory = $true,
        HelpMessage = 'Resource application Id'
    )]
    [String]$AadApplicationId,

    [parameter(
        Mandatory = $true,
        HelpMessage = 'Client application principal Id'
    )]
    [String]$SuperAdminClientId,

    [parameter(
        Mandatory = $true,
        HelpMessage = 'Client application principal secret key'
    )]
    [String]$SuperAdminClientSecret,

    [Parameter(
        Mandatory = $true,
        HelpMessage = 'Resource group name'
    )]
    [ValidateNotNullOrEmpty()]
    [string] $ResourceGroupName,

    [Parameter(
        Mandatory = $false,
        HelpMessage = 'Resource group location'
    )]
    [ValidateNotNullOrEmpty()]
    [string] $ResourceGroupLocation,

    [Parameter(
        Mandatory = $false,
        HelpMessage = 'Service bus template file path'
    )]
    [ValidateNotNullOrEmpty()]
    [string] $ServiceBusTemplateFilePath,

    [Parameter(
        Mandatory = $false,
        HelpMessage = 'Service bus namespace name prefix'
    )]
    [ValidateNotNullOrEmpty()]
    [string] $ServiceBusNamespaceNamePrefix,

    [Parameter(
        Mandatory = $false,
        HelpMessage = 'Database template file path'
    )]
    [ValidateNotNullOrEmpty()]
    [string] $DatabaseTemplateFilePath,
    
    [Parameter(
        Mandatory = $false,
        HelpMessage = 'Create tenant database'
    )]
    [bool] $CreateTenantDatabase = $false,

    [Parameter(
        Mandatory = $false,
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
    [string] $SqlDatabaseMaxSize = $null,

    [Parameter(
        Mandatory = $false,
        HelpMessage = 'K8s config path'
    )]
    [ValidateScript( {Test-Path $_})]
    [string] $K8sConfigPath,
    [Parameter(
        Mandatory = $true,
        HelpMessage = 'Tenant namespace values to tokenize'
    )]
    [hashtable] $TenantNamespacePlaceholders,
    [Parameter(
        Mandatory = $true,
        HelpMessage = 'Tenant configuration values to tokenize'
    )]
    [hashtable] $TenantConfigurationPlaceholders,
    [Parameter(
        Mandatory = $true,
        HelpMessage = 'Tenant secrets values to tokenize'
    )]
    [hashtable] $TenantSecretsPlaceholders,
    [Parameter(
        Mandatory = $true,
        HelpMessage = 'Docker username'
    )]
    [ValidateNotNullOrEmpty()]
    [string] $DockerUserName,
    [Parameter(
        Mandatory = $true,
        HelpMessage = 'Docker password'
    )]
    [ValidateNotNullOrEmpty()]
    [string] $DockerPassword,
    [Parameter(
        Mandatory = $true,
        HelpMessage = 'Docker server'
    )]
    [ValidateNotNullOrEmpty()]
    [string] $DockerServer,
    [Parameter(
        Mandatory = $true,
        HelpMessage = 'Docker repository name'
    )]
    [ValidateNotNullOrEmpty()]
    [string] $DockerRepositoryName,

    [Parameter(
        Mandatory = $true,
        HelpMessage = 'Bus type'
    )]
    [ValidateSet('serviceBus', 'kafka')]
    [ValidateNotNullOrEmpty()]
    [string] $BusType,

    [Parameter(
        Mandatory = $true,
        HelpMessage = 'Store type'
    )]
    [ValidateSet('azureblob', 'ceph', 'SqlDatabase')]
    [ValidateNotNullOrEmpty()]
    [string] $StoreType,

    [Parameter(
        Mandatory = $false,
        HelpMessage = 'Bus configuration string'
    )]
    [string] $BusConfigurationString,

    [Parameter(
        Mandatory = $false,
        HelpMessage = 'Store configuration string'
    )]
    [string] $StoreConfigurationString = $null,

    [Parameter(
        Mandatory = $true,
        HelpMessage = 'SQL connection string'
    )]
    [ValidateNotNullOrEmpty()]
    [string] $SQLConnectionString,

    [Parameter(
        Mandatory = $true,
        HelpMessage = 'Hashtable containing paths to services conf and version'
    )]
    [hashtable] $ServicesConfigurationAndVersions,
    [Parameter(
        Mandatory = $true,
        HelpMessage = 'Paths to tenant configuration'
    )]
    [string[]] $TenantConfigurationPaths,

    [Parameter(
        Mandatory = $true,
        HelpMessage = 'Application insights name'
    )]
    [ValidateNotNullOrEmpty()]
    [string] $ApplicationInsightsName,

    [Parameter(
        Mandatory = $true,
        HelpMessage = 'Namespace prefix'
    )]
    [string] $NamespacePrefix
)

Push-Location ((Get-Item -LiteralPath ($script:MyInvocation.MyCommand.Path)).Directory.FullName) 
Try {
    [PSObject] $customersData = $null

    $Identities = @{
        "SuperAdmin" = @{
            "ID"     = $SuperAdminClientId;
            "SECRET" = $SuperAdminClientSecret
        }
    }

    (& ".\CommonScripts\GetTenantsList" `
            -Server $Server `
            -Authority $Authority `
            -AadApplicationId $AadApplicationId `
            -Identities $Identities `
            -output_obj ([ref]$customersData))

    (& ".\K8sTenantEnvCreator" `
            -Server $Server `
            -WebSiteName $WebSiteName `
            -Authority $Authority `
            -AadApplicationId $AadApplicationId `
            -SuperAdminClientId $SuperAdminClientId `
            -SuperAdminClientSecret $SuperAdminClientSecret `
            -Customers $customersData `
            -ResourceGroupName $ResourceGroupName `
            -ResourceGroupLocation $ResourceGroupLocation `
            -ServiceBusTemplateFilePath $ServiceBusTemplateFilePath `
            -ServiceBusNamespaceNamePrefix $ServiceBusNamespaceNamePrefix `
            -DatabaseTemplateFilePath $DatabaseTemplateFilePath `
            -SqlServerName $SqlServerName `
            -SqlServerLocation $SqlServerLocation `
            -SqlDatabaseCollation $SqlDatabaseCollation `
            -SqlDatabaseEditionAndTier $SqlDatabaseEditionAndTier `
            -SqlDatabaseMaxSize $SqlDatabaseMaxSize `
            -K8sConfigPath $K8sConfigPath `
            -TenantNamespacePlaceholders $TenantNamespacePlaceholders `
            -TenantConfigurationPlaceholders $TenantConfigurationPlaceholders `
            -TenantSecretsPlaceholders $TenantSecretsPlaceholders `
            -DockerUserName $DockerUserName `
            -DockerPassword $DockerPassword `
            -DockerServer $DockerServer `
            -DockerRepositoryName $DockerRepositoryName `
            -BusType $BusType `
            -StoreType $StoreType `
            -BusConfigurationString $BusConfigurationString `
            -StoreConfigurationString $StoreConfigurationString `
            -SQLConnectionString $SQLConnectionString `
            -ApplicationInsightsName $ApplicationInsightsName `
            -NamespacePrefix $NamespacePrefix `
            -CreateTenantDatabase $CreateTenantDatabase
    )
}
Finally {
    Pop-Location
}