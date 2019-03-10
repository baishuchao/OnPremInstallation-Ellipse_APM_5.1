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
        Mandatory = $false,
        HelpMessage = 'Web site name'
    )]
    [String]$WebSiteName,

    [parameter(
        Mandatory = $true,
        HelpMessage = 'ActiveDirectory authority URI'
    )]
    [Uri]$Authority,

    [parameter(
        Mandatory = $true,
        HelpMessage = 'Aad application Id'
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

    [parameter(
        Mandatory = $true,
        HelpMessage = 'Customer file name for which the data will be imported'
    )]
    [ValidateNotNullOrEmpty()]
    [string[]]$Customers,

    [Parameter(
        Mandatory = $false,
        HelpMessage = 'Resource group name'
    )]
    [string] $ResourceGroupName,

    [Parameter(
        Mandatory = $false,
        HelpMessage = 'Resource group location'
    )]
    [string] $ResourceGroupLocation,

    [Parameter(
        Mandatory = $false,
        HelpMessage = 'Service bus template file path'
    )]
    [string] $ServiceBusTemplateFilePath,

    [Parameter(
        Mandatory = $false,
        HelpMessage = 'Service bus namespace name prefix'
    )]
    [string] $ServiceBusNamespaceNamePrefix,

    [Parameter(
        Mandatory = $false,
        HelpMessage = 'Sql server name'
    )]
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
        HelpMessage = 'Path to root directory of installation package'
    )]
    [string] $InstallPackageRootDirectory,

    [Parameter(
        Mandatory = $false,
        HelpMessage = 'Application insights name'
    )]
    [string] $ApplicationInsightsName,

    [Parameter(
        Mandatory = $true,
        HelpMessage = 'Namespace prefix'
    )]
    [string] $NamespacePrefix
)

Push-Location ((Get-Item -LiteralPath ($script:MyInvocation.MyCommand.Path)).Directory.FullName)
Try {
    foreach ($customer in $Customers) {
        [string] $internalName = & ".\CommonScripts\Get-InternalName" -Customer $customer
        [string] $namespaceFullName = (& ".\CommonScripts\PrepareNamespaceFullName.ps1" -NamespacePrefix $NamespacePrefix -NamespaceName $internalName)

        if (($BusType -eq "serviceBus") -And [string]::IsNullOrWhiteSpace($BusConfigurationString)) {
            $BusConfigurationString = (& ".\CommonScripts\Deploy-ServiceBus" `
                    -ResourceGroupName $ResourceGroupName `
                    -ResourceGroupLocation $ResourceGroupLocation `
                    -TemplateFilePath $ServiceBusTemplateFilePath `
                    -ServiceBusNamespaceNamePrefix $ServiceBusNamespaceNamePrefix)
            Write-Verbose "Service bus created"
        }
        if ([string]::IsNullOrWhiteSpace($BusConfigurationString)) {
            Throw "BusConfigurationString is null or empty"
        }

        $ahcDatabaseName = "AHC-$internalName"

        $SqlConnectionStringWithDatabase = (&".\CommonScripts\AddInitialCatalog-SqlConnectionString" -SqlConnectionString $SQLConnectionString -DatabaseName $ahcDatabaseName)

        if (($StoreType -eq "azureblob") -and [string]::IsNullOrWhiteSpace($StoreConfigurationString)) {
            $StoreConfigurationString = (&".\CommonScripts\PrepareStorageAccountConnectionString" -ResourceGroupName $ResourceGroupName -WebSiteName $WebSiteName)
        }
        if ([string]::IsNullOrWhiteSpace($StoreConfigurationString)) {
            Throw "StorageConfigurationString is null or empty"
        }

        $TenantNamespacePlaceholders = & ".\CommonScripts\OverrideOrAddKeyIfNotExist" -placeholderKey "<NAMESPACE_NAME>" -placeholderValue $namespaceFullName -parametersTable $TenantNamespacePlaceholders

        $TenantConfigurationPlaceholders = & ".\CommonScripts\OverrideOrAddKeyIfNotExist" -placeholderKey "<TENANT_NAME>" -placeholderValue $internalName -parametersTable $TenantConfigurationPlaceholders
        $TenantConfigurationPlaceholders = & ".\CommonScripts\OverrideOrAddKeyIfNotExist" -placeholderKey "<BUS_TYPE>" -placeholderValue $BusType -parametersTable $TenantConfigurationPlaceholders
        $TenantConfigurationPlaceholders = & ".\CommonScripts\OverrideOrAddKeyIfNotExist" -placeholderKey "<STORE_TYPE>" -placeholderValue $StoreType -parametersTable $TenantConfigurationPlaceholders
        $TenantConfigurationPlaceholders = & ".\CommonScripts\OverrideOrAddKeyIfNotExist" -placeholderKey "<ENVIRONMENT_NAME>" -placeholderValue $NamespacePrefix -parametersTable $TenantConfigurationPlaceholders

        if ([string]::IsNullOrWhiteSpace($ResourceGroupName) -or [string]::IsNullOrWhiteSpace($ApplicationInsightsName)) {
            $currentAppInsightsInstrumentationKey = "Nothing"
        }
        else {
            $currentAppInsightsInstrumentationKey = (& ".\CommonScripts\GetAppInsightsInstrumentationKey" -ApplicationInsightsName $ApplicationInsightsName -ResourceGroupName $ResourceGroupName)
        }

        $TenantConfigurationPlaceholders = (& ".\CommonScripts\OverrideOrAddKeyIfNotExist" -placeholderKey "<APP_INSIGHTS_INSTRUMENTATION_KEY>" -placeholderValue $currentAppInsightsInstrumentationKey -parametersTable $TenantConfigurationPlaceholders)

        $TenantSecretsPlaceholders = & ".\CommonScripts\OverrideOrAddKeyIfNotExist" -placeholderKey "<BUS_CONFIGURATION_BASE64>" -placeholderValue $BusConfigurationString -parametersTable $TenantSecretsPlaceholders
        $TenantSecretsPlaceholders = & ".\CommonScripts\OverrideOrAddKeyIfNotExist" -placeholderKey "<STORE_CONFIGURATION_BASE64>" -placeholderValue $StoreConfigurationString -parametersTable $TenantSecretsPlaceholders
        $TenantSecretsPlaceholders = & ".\CommonScripts\OverrideOrAddKeyIfNotExist" -placeholderKey "<SQL_CONNECTIONSTRING_BASE64>" -placeholderValue "$SqlConnectionStringWithDatabase" -parametersTable $TenantSecretsPlaceholders

        & ".\K8sServicesCreator" `
            -K8sConfigPath $K8sConfigPath `
            -TenantNamespacePlaceholders $TenantNamespacePlaceholders `
            -TenantConfigurationPlaceholders $TenantConfigurationPlaceholders `
            -TenantSecretsPlaceholders $TenantSecretsPlaceholders `
            -NamespacePrefix $NamespacePrefix `
            -NamespaceName $internalName `
            -DockerUserName $DockerUserName `
            -DockerPassword $DockerPassword `
            -DockerServer $DockerServer `
            -DockerRepositoryName $DockerRepositoryName `
            -InstallPackageRootDirectory $InstallPackageRootDirectory

        & ".\Customer" `
            -Server $Server `
            -Customer $Customer `
            -CreateNoUpdate `
            -PowerBIs `
            -Authority $Authority `
            -AadApplicationId $AadApplicationId `
            -SuperAdminClientId $SuperAdminClientId `
            -SuperAdminClientSecret $SuperAdminClientSecret
    }
}
Finally {
    Pop-Location
}