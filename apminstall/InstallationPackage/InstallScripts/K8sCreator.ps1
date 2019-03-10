#Requires -Version 4.0
[CmdletBinding(PositionalBinding = $false)]
Param(
    [parameter(
        Mandatory = $true,
        HelpMessage = 'Path to environment configuration file'
    )]
    [ValidateScript( {Test-Path $_ -PathType leaf})]
    [string] $EnvironmentConfigDataPath,

    [parameter(
        Mandatory = $false,
        HelpMessage = 'Tenants to create'
    )]
    [ValidateNotNull()]
    [string[]] $Tenants,

    [parameter(
        Mandatory = $false,
        HelpMessage = 'Application secret key'
    )]
    [string] $ApplicationSecretKey,

    [parameter(
        Mandatory = $false,
        HelpMessage = 'Bus configuration string'
    )]
    [string] $BusConfigurationString,

    [parameter(
        Mandatory = $false,
        HelpMessage = 'Docker password'
    )]
    [string] $DockerPassword,

    [parameter(
        Mandatory = $false,
        HelpMessage = 'Docker username'
    )]
    [string] $DockerUserName,

    [parameter(
        Mandatory = $false,
        HelpMessage = 'Feeder client secret'
    )]
    [string] $FeederClientSecret,

    [parameter(
        Mandatory = $false,
        HelpMessage = 'KeyVault application key'
    )]
    [string] $KeyVaultApplicationKey,

    [parameter(
        Mandatory = $false,
        HelpMessage = 'Root directory of installation Package'
    )]
    [string] $InstallPackageRootDirectory,

    [parameter(
        Mandatory = $false,
        HelpMessage = 'KeyVault key address'
    )]
    [string] $KeyVaultKeyAddress,

    [parameter(
        Mandatory = $false,
        HelpMessage = 'Notification email server password'
    )]
    [string] $NotificationEmailServerPassword,

    [parameter(
        Mandatory = $false,
        HelpMessage = 'PowerBI access key'
    )]
    [string] $PowerBiAccessKey,

    [parameter(
        Mandatory = $false,
        HelpMessage = 'SQL connection string'
    )]
    [string] $SQLConnectionString,

    [parameter(
        Mandatory = $false,
        HelpMessage = 'Super admin client ID'
    )]
    [string] $SuperAdminClientId,

    [parameter(
        Mandatory = $false,
        HelpMessage = 'Super admin client secret'
    )]
    [string] $SuperAdminClientSecret,

    [Parameter(
        Mandatory = $false,
        HelpMessage = 'K8s config path'
    )]
    [ValidateScript( {Test-Path $_})]
    [string] $K8sConfigPath,

    [Parameter(
        Mandatory = $false,
        HelpMessage = 'Store configuration string'
    )]
    [string] $StoreConfigurationString,

    [Parameter(
        Mandatory = $false,
        HelpMessage = 'Default map configuration key'
    )]
    [string] $DefaultMapConfigurationKey
)

function ReplaceParametersInTenantConfigFile($configData, $passedParameters) {
    if ($passedParameters.ContainsKey('<APPLICATION_SECRET_KEY_BASE64>')) {
        $configData['TenantSecretsPlaceholders']['<APPLICATION_SECRET_KEY_BASE64>'] = $passedParameters['<APPLICATION_SECRET_KEY_BASE64>']
    }

    if ($passedParameters.ContainsKey('BusConfigurationString')) {
        $configData['BusConfigurationString'] = $passedParameters['BusConfigurationString']
    }

    if ($passedParameters.ContainsKey('<FEEDER_CLIENT_SECRET_BASE64>')) {
        $configData['TenantSecretsPlaceholders']['<FEEDER_CLIENT_SECRET_BASE64>'] = $passedParameters['<FEEDER_CLIENT_SECRET_BASE64>']
    }

    if ($passedParameters.ContainsKey('<NOTIFICATION_EMAIL_SERVER_PASSWORD>')) {
        $configData['TenantSecretsPlaceholders']['<NOTIFICATION_EMAIL_SERVER_PASSWORD>'] = $passedParameters['<NOTIFICATION_EMAIL_SERVER_PASSWORD>']
    }

    if ($passedParameters.ContainsKey('SuperAdminClientId')) {
        $configData['SuperAdminClientId'] = $passedParameters['SuperAdminClientId']
    }

    if ($passedParameters.ContainsKey('SuperAdminClientSecret')) {
        $configData['SuperAdminClientSecret'] = $passedParameters['SuperAdminClientSecret']
    }

    if ($passedParameters.ContainsKey('K8sConfigPath')) {
        $configData['K8sConfigPath'] = $passedParameters['K8sConfigPath']
    }

    if ($passedParameters.ContainsKey('StoreConfigurationString')) {
        $configData['StoreConfigurationString'] = $passedParameters['StoreConfigurationString']
    }

    if ($passedParameters.ContainsKey('StoreConfigurationString')) {
        $configData['StoreConfigurationString'] = $passedParameters['StoreConfigurationString']
    }

    $configData['AadApplicationId'] = $passedParameters['AadApplicationId']
    $configData['TenantConfigurationPlaceholders']['<AAD_APPLICATION_ID>'] = $passedParameters['AadApplicationId']
    $configData['TenantConfigurationPlaceholders']['<FEEDER_CLIENT_ID>'] = $passedParameters['AadApplicationId']
    $configData['Authority'] = $passedParameters['Authority']
    $configData['TenantConfigurationPlaceholders']['<FEEDER_AUTHORITY>'] = $passedParameters['Authority']
    $configData['StoreType'] = $passedParameters['StoreType']
    $configData['SqlServerLogin'] = $passedParameters['SqlServerLogin']
    $configData['BusType'] = $passedParameters['BusType']

}

function GetTenantsConfigurationFilesPaths($tenantsCollection) {
    $tenantsConfigFilePaths = New-Object System.Collections.Generic.List[System.Object]
    foreach ($tenant in $tenantsCollection) {
        $tenantConfigurationFilePath = Join-Path $PSScriptRoot -Childpath "\TenantsConfigurations\$tenant.json"
        if (-not (Test-Path -Path $tenantConfigurationFilePath -PathType leaf)) {
            Throw 'Tenant configuration file does not exists. Check if tenant name is valid or if configuration file exists.'
        }
        $tenantsConfigFilePaths.Add($tenantConfigurationFilePath)
    }
    return $tenantsConfigFilePaths
}

function GetFileNameFromPath ($filePath) {
    return [System.IO.Path]::GetFileNameWithoutExtension($filePath)
}

function ChangeDatabaseNameInConnectionString ($tenantConfigurationFilePath, $connectionString) {
    $tenantName = GetFileNameFromPath -filePath $tenantConfigurationFilePath
    $tenantInternalName = & ".\CommonScripts\Get-InternalName" -Customer $tenantName
    [string]$sqlConnectionString = & ".\CommonScripts\AddInitialCatalog-SqlConnectionString" -SqlConnectionString $connectionString -DatabaseName $tenantInternalName
    return $sqlConnectionString
}

Push-Location ((Get-Item -LiteralPath ($script:MyInvocation.MyCommand.Path)).Directory.FullName)
Try {
    [hashtable] $environmentConfigData = & ".\CommonScripts\ConvertFrom-ExtendedJSon" -LiteralPath $EnvironmentConfigDataPath
    [hashtable] $tenantsPassedParamaters = @{}

    if (-not [string]::IsNullOrEmpty($ApplicationSecretKey)) {
        Write-Verbose "$([DateTime]::Now.ToString("HH\:mm\:ss")): Replacing ApplicationSecretKey"
        $environmentConfigData['CommonSecretsPlaceholders']['<APPLICATION_SECRET_KEY_BASE64>'] = $ApplicationSecretKey
        $tenantsPassedParamaters.Add('<APPLICATION_SECRET_KEY_BASE64>', $ApplicationSecretKey)
    }

    if (-not [string]::IsNullOrEmpty($DefaultMapConfigurationKey)) {
        Write-Verbose "$([DateTime]::Now.ToString("HH\:mm\:ss")): Replacing DefaultMapConfigurationKey"
        $environmentConfigData['CommonSecretsPlaceholders']['<DEFAULT_MAP_CONFIGURATION_KEY_BASE64>'] = $DefaultMapConfigurationKey
    }

    if (-not [string]::IsNullOrEmpty($BusConfigurationString)) {
        Write-Verbose "$([DateTime]::Now.ToString("HH\:mm\:ss")): Replacing BusConfigurationString"
        $environmentConfigData['CommonSecretsPlaceholders']['<BUS_CONFIGURATION_BASE64>'] = $BusConfigurationString
        $tenantsPassedParamaters.Add('BusConfigurationString', $BusConfigurationString)
    }

    if (-not [string]::IsNullOrEmpty($DockerPassword)) {
        Write-Verbose "$([DateTime]::Now.ToString("HH\:mm\:ss")): Replacing DockerPassword"
        $environmentConfigData['DockerPassword'] = $DockerPassword
    }

    if (-not [string]::IsNullOrEmpty($DockerUserName)) {
        Write-Verbose "$([DateTime]::Now.ToString("HH\:mm\:ss")): Replacing DockerUserName"
        $environmentConfigData['DockerUserName'] = $DockerUserName
    }

    if (-not [string]::IsNullOrEmpty($FeederClientSecret)) {
        Write-Verbose "$([DateTime]::Now.ToString("HH\:mm\:ss")): Replacing FeederClientSecret"
        $tenantsPassedParamaters.Add('<FEEDER_CLIENT_SECRET_BASE64>', $FeederClientSecret)
    }

    if (-not [string]::IsNullOrEmpty($KeyVaultApplicationKey)) {
        Write-Verbose "$([DateTime]::Now.ToString("HH\:mm\:ss")): Replacing KeyVaultApplicationKey"
        $environmentConfigData['CommonSecretsPlaceholders']['<KEY_VAULT_APPLICATION_KEY_BASE64>'] = $KeyVaultApplicationKey
    }

    if (-not [string]::IsNullOrEmpty($KeyVaultKeyAddress)) {
        Write-Verbose "$([DateTime]::Now.ToString("HH\:mm\:ss")): Replacing KeyVaultKeyAddress"
        $environmentConfigData['CommonConfigPlaceholders']['<KEY_VAULT_KEY_ADDRESS>'] = $keyVaultKeyAddress
    }

    if (-not [string]::IsNullOrEmpty($NotificationEmailServerPassword)) {
        Write-Verbose "$([DateTime]::Now.ToString("HH\:mm\:ss")): Replacing NotificationEmailServerPassword"
        $tenantsPassedParamaters.Add('<NOTIFICATION_EMAIL_SERVER_PASSWORD>', $NotificationEmailServerPassword)
    }

    if (-not [string]::IsNullOrEmpty($PowerBiAccessKey)) {
        Write-Verbose "$([DateTime]::Now.ToString("HH\:mm\:ss")): Replacing PowerBiAccessKey"
        $environmentConfigData['CommonSecretsPlaceholders']['<POWER_BI_ACCESS_KEY_BASE64>'] = $PowerBiAccessKey
    }

    if (-not [string]::IsNullOrEmpty($SQLConnectionString)) {
        Write-Verbose "$([DateTime]::Now.ToString("HH\:mm\:ss")): Replacing SQLConnectionString"
        $environmentConfigData['CommonSecretsPlaceholders']['<SQL_CONNECTIONSTRING_BASE64>'] = $SQLConnectionString
        $tenantsPassedParamaters.Add('SQLConnectionString', $SQLConnectionString)
    }

    if (-not [string]::IsNullOrEmpty($SuperAdminClientId)) {
        Write-Verbose "$([DateTime]::Now.ToString("HH\:mm\:ss")): Replacing SuperAdminClientId"
        $tenantsPassedParamaters.Add('SuperAdminClientId', $SuperAdminClientId)
    }

    if (-not [string]::IsNullOrEmpty($SuperAdminClientSecret)) {
        Write-Verbose "$([DateTime]::Now.ToString("HH\:mm\:ss")): Replacing SuperAdminClientSecret"
        $tenantsPassedParamaters.Add('SuperAdminClientSecret', $SuperAdminClientSecret)
    }

    if (-not [string]::IsNullOrEmpty($InstallPackageRootDirectory)) {
        Write-Verbose "$([DateTime]::Now.ToString("HH\:mm\:ss")): Replacing InstallPackageRootDirectory"
        $environmentConfigData['InstallPackageRootDirectory'] = $InstallPackageRootDirectory
    }

    if (-not [string]::IsNullOrEmpty($K8sConfigPath)) {
        Write-Verbose "$([DateTime]::Now.ToString("HH\:mm\:ss")): Replacing K8sConfigPath"
        $environmentConfigData['K8sConfigPath'] = $K8sConfigPath
        $tenantsPassedParamaters.Add('K8sConfigPath', $K8sConfigPath)
    }

    if (-not [string]::IsNullOrEmpty($StoreConfigurationString)) {
        Write-Verbose "$([DateTime]::Now.ToString("HH\:mm\:ss")): Replacing StoreConfigurationString"
        $environmentConfigData['StoreConfigurationString'] = $StoreConfigurationString
        $tenantsPassedParamaters.Add('StoreConfigurationString', $StoreConfigurationString)
    }

    & ".\K8sCommonEnvCreator" `
        -ApplicationInsightsName $environmentConfigData['ApplicationInsightsName'] `
        -CommonConfigPlaceholders $environmentConfigData['CommonConfigPlaceholders'] `
        -CommonNamespacePlaceholders $environmentConfigData['CommonNamespacePlaceholders'] `
        -CommonSecretsPlaceholders $environmentConfigData['CommonSecretsPlaceholders'] `
        -FeederApiPort $environmentConfigData['FeederApiPort'] `
        -InstallPackageRootDirectory $environmentConfigData['InstallPackageRootDirectory'] `
        -NamespacePrefix $environmentConfigData['NamespacePrefix'] `
        -ResourceGroupName $environmentConfigData['ResourceGroupName'] `
        -StoreConfigurationString $environmentConfigData['StoreConfigurationString'] `
        -StoreType $environmentConfigData['StoreType'] `
        -WebServicePort $environmentConfigData['WebServicePort'] `
        -K8sConfigPath $environmentConfigData['K8sConfigPath'] `
        -DockerUserName $environmentConfigData['DockerUserName'] `
        -DockerPassword $environmentConfigData['DockerPassword'] `
        -DockerServer $environmentConfigData['DockerServer'] `
        -DockerRepositoryName $environmentConfigData['DockerRepositoryName'] `
        -WebSiteName $environmentConfigData['WebSiteName'] `
        -Verbose

    $tenantsPassedParamaters.Add('AadApplicationId', $environmentConfigData['CommonConfigPlaceholders']['<AAD_APPLICATION_ID>'])
    $tenantsPassedParamaters.Add('Authority', $environmentConfigData['CommonConfigPlaceholders']['<AAD_DIRECTORY_AUTHORITY>'])
    $tenantsPassedParamaters.Add('StoreType', $environmentConfigData['StoreType'])
    $tenantsPassedParamaters.Add('SqlServerLogin', $environmentConfigData['SqlServerLogin'])
    $tenantsPassedParamaters.Add('BusType', $environmentConfigData['CommonConfigPlaceholders']['<BUS_TYPE>'])

    Write-Verbose "--------------------------------"
    Write-Verbose "K8sCommonEnvCreator script ended"
    Write-Verbose "--------------------------------"

    Start-Sleep -s 60

    if ($Tenants.Count -eq 0) {
        Write-Warning "$([DateTime]::Now.ToString("HH\:mm\:ss")): No tenants passed!"
        Write-Verbose "$([DateTime]::Now.ToString("HH\:mm\:ss")): Skipping tenant(s) creation."
    }
    else {
        $tenantsConfigurationFilePaths = GetTenantsConfigurationFilesPaths -tenantsCollection $Tenants

        foreach ($tenantConfigurationFilePath in $tenantsConfigurationFilePaths) {

            [hashtable] $tenantConfigurationData = & ".\CommonScripts\ConvertFrom-ExtendedJSon" -LiteralPath $tenantConfigurationFilePath
            $tenantName = GetFileNameFromPath -filePath $tenantConfigurationFilePath
            Write-Verbose "Tenant name: $tenantName"

            if ([string]::IsNullOrEmpty($environmentConfigData['Server'])) { 
                Throw "Environment configuration file does not contain application server address."
            }

            $tenantConfigurationData['TenantConfigurationPlaceholders'].Add('<APPLICATION_WEBSITE_URL>', $environmentConfigData['Server'])

            if ([string]::IsNullOrEmpty($tenantConfigurationData['SQLConnectionString']) -and (-not [string]::IsNullOrEmpty($tenantsPassedParamaters['SQLConnectionString']))) {
                $tenantConfigurationData['SQLConnectionString'] = ChangeDatabaseNameInConnectionString -tenantConfigurationFilePath $tenantConfigurationFilePath -connectionString $tenantsPassedParamaters['SQLConnectionString']
            }
            else {
                Throw "SQL connection string was not given in tenant configuration file, was not given as parameter either."
            }

            ReplaceParametersInTenantConfigFile -configData $tenantConfigurationData -passedParameters $tenantsPassedParamaters

            & ".\K8sTenantEnvCreator" `
                -AadApplicationId $tenantConfigurationData['AadApplicationId'] `
                -ApplicationInsightsName $environmentConfigData['ApplicationInsightsName'] `
                -Authority $tenantConfigurationData['Authority'] `
                -BusConfigurationString $tenantConfigurationData['BusConfigurationString'] `
                -BusType $tenantConfigurationData['BusType'] `
                -Customers $tenantName `
                -DockerUserName $environmentConfigData['DockerUserName'] `
                -DockerPassword $environmentConfigData['DockerPassword'] `
                -DockerServer $environmentConfigData['DockerServer'] `
                -DockerRepositoryName $environmentConfigData['DockerRepositoryName'] `
                -K8sConfigPath $tenantConfigurationData['K8sConfigPath'] `
                -NamespacePrefix $environmentConfigData['NamespacePrefix'] `
                -ResourceGroupLocation $environmentConfigData['ResourceGroupLocation'] `
                -ResourceGroupName $environmentConfigData['ResourceGroupName'] `
                -SQLConnectionString $tenantConfigurationData['SQLConnectionString'] `
                -SqlServerName $environmentConfigData['SqlServerName'] `
                -StoreConfigurationString $tenantConfigurationData['StoreConfigurationString'] `
                -StoreType $tenantConfigurationData['StoreType'] `
                -SuperAdminClientId $tenantConfigurationData['SuperAdminClientId'] `
                -SuperAdminClientSecret $tenantConfigurationData['SuperAdminClientSecret'] `
                -TenantConfigurationPlaceholders $tenantConfigurationData['TenantConfigurationPlaceholders'] `
                -TenantNamespacePlaceholders $tenantConfigurationData['TenantNamespacePlaceholders'] `
                -TenantSecretsPlaceholders $tenantConfigurationData['TenantSecretsPlaceholders'] `
                -WebSiteName $environmentConfigData['WebSiteName'] `
                -InstallPackageRootDirectory $environmentConfigData['InstallPackageRootDirectory'] `
                -Server $environmentConfigData['Server'] `
                -Verbose

            Write-Verbose "--------------------------------"
            Write-Verbose "K8sTenantEnvCreator script ended"
            Write-Verbose "--------------------------------"
        }
    }
}
Finally {
    Pop-Location
}