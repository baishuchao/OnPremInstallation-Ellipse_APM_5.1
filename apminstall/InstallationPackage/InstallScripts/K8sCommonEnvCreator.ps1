[CmdletBinding(PositionalBinding = $false)]
Param(
    [Parameter(
        Mandatory = $false,
        HelpMessage = 'K8s config path'
    )]
    [ValidateScript( {Test-Path $_})]
    [string] $K8sConfigPath,

    [Parameter(
        Mandatory = $true,
        HelpMessage = 'Common configuration values to tokenize'
    )]
    [hashtable] $CommonConfigPlaceholders,

    [Parameter(
        Mandatory = $true,
        HelpMessage = 'Root directory of installation Package'
    )]
    [string] $InstallPackageRootDirectory,    

    [Parameter(
        Mandatory = $true,
        HelpMessage = 'Common secrets values to tokenize'
    )]
    [hashtable] $CommonSecretsPlaceholders,

    [Parameter(
        Mandatory = $true,
        HelpMessage = 'Common namespace values to tokenize'
    )]
    [hashtable] $CommonNamespacePlaceholders,

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

    [parameter(
        Mandatory = $false,
        HelpMessage = 'Web site name'
    )]
    [String]$WebSiteName,

    [Parameter(
        Mandatory = $false,
        HelpMessage = 'Resource group name'
    )]
    [string] $ResourceGroupName,

    [Parameter(
        Mandatory = $true,
        HelpMessage = 'Store type'
    )]
    [ValidateSet('azureblob', 'ceph', 'SqlDatabase')]
    [ValidateNotNullOrEmpty()]
    [string] $StoreType,

    [Parameter(
        Mandatory = $false,
        HelpMessage = 'Store configuration string'
    )]
    [string] $StoreConfigurationString = $null,

    [Parameter(
        Mandatory = $false,
        HelpMessage = 'Application insights name'
    )]
    [string] $ApplicationInsightsName,

    [Parameter(
        Mandatory = $true,
        HelpMessage = 'Namespace prefix'
    )]
    [string] $NamespacePrefix,

    [Parameter(
        Mandatory = $true,
        HelpMessage = 'Number of Node Port for Feeder Api'
    )]
    [string] $FeederApiPort,

    [Parameter(
        Mandatory = $true,
        HelpMessage = 'Number of Node Port for Seb Service'
    )]
    [string] $WebServicePort,

    [Parameter(
        Mandatory = $false,
        HelpMessage = 'Role - ID binding for Windows Active Directory'
    )]
    [hashtable] $windowsActiveDirectoryRoles
)

function DeleteCreatedTempFiles {
    if (Test-Path $namespaceTempFile) {
        Remove-Item -Path $namespaceTempFile -ErrorAction SilentlyContinue -WarningAction SilentlyContinue -Force
    }
    if (Test-Path $configTempFile) {
        Remove-Item -Path $configTempFile -ErrorAction SilentlyContinue -WarningAction SilentlyContinue -Force
    }
    if (Test-Path $secretsTempFile) {
        Remove-Item -Path $secretsTempFile -ErrorAction SilentlyContinue -WarningAction SilentlyContinue -Force
    }
}

Push-Location ((Get-Item -LiteralPath ($script:MyInvocation.MyCommand.Path)).Directory.FullName)
Try {
    Write-Verbose  'Creating temporary files...'
    $namespaceTempFile = New-TemporaryFile
    $configTempFile = New-TemporaryFile
    $secretsTempFile = New-TemporaryFile
    Write-Verbose 'Temporary files created'    

    ##Create proper paths
    $CommonConfigurationRelativePaths = Resolve-Path ".\ServicesPaths\CommonConfigurationPaths.txt"
    $CommonConfigurationAbsolutePaths = (& ".\CommonScripts\Get-AbsolutePaths" -RootDirectory $InstallPackageRootDirectory -ConfigFilePath $CommonConfigurationRelativePaths)

    $namespacePath = Get-Item -Path ($CommonConfigurationAbsolutePaths -match 'namespace')
    Write-Verbose 'Got namespace'
    $configPath = Get-Item -Path ($CommonConfigurationAbsolutePaths -match 'config')
    Write-Verbose 'Got configuration'
    $secretsPath = Get-Item -Path ($CommonConfigurationAbsolutePaths -match 'secrets')
    Write-Verbose 'Got secrets'


    Write-Verbose 'Checking if files are not empty..'
    if (((Get-Content $namespacePath) -eq $null) -or ((Get-Content $configPath) -eq $null) -or ((Get-Content $secretsPath) -eq $null)) {
        Write-Error "One or more of common configuration files are empty..."
        exit
    }

    [string] $namespaceFullName = (& ".\CommonScripts\PrepareNamespaceFullName.ps1" -NamespacePrefix $NamespacePrefix)

    ##CommonNamespacePlaceholders
    $CommonNamespacePlaceholders = (& ".\CommonScripts\OverrideOrAddKeyIfNotExist" -placeholderKey "<NAMESPACE_NAME>" -placeholderValue $namespaceFullName -parametersTable $CommonNamespacePlaceholders)


    ##CommonSecretsPlaceholders
    if (($StoreType -eq "azureblob") -and [string]::IsNullOrWhiteSpace($StoreConfigurationString) -and -not [string]::IsNullOrEmpty($ResourceGroupName)) {
        $StoreConfigurationString = (&".\CommonScripts\PrepareStorageAccountConnectionString" -ResourceGroupName $ResourceGroupName -WebSiteName $WebSiteName)
    }
    if ([string]::IsNullOrWhiteSpace($storeConfigurationString)) {
        Throw "storeConfigurationString is null or empty"
    }
    $CommonSecretsPlaceholders = (& ".\CommonScripts\OverrideOrAddKeyIfNotExist" -placeholderKey "<STORE_CONFIGURATION_BASE64>" -placeholderValue $storeConfigurationString -parametersTable $CommonSecretsPlaceholders)

    ##CommonConfigPlaceholders
    $CommonConfigPlaceholders = (& ".\CommonScripts\OverrideOrAddKeyIfNotExist" -placeholderKey "<STORE_TYPE>" -placeholderValue $StoreType -parametersTable $CommonConfigPlaceholders)
    if ([string]::IsNullOrWhiteSpace($ResourceGroupName) -or [string]::IsNullOrWhiteSpace($ApplicationInsightsName)) {
        $CommonConfigPlaceholders = (& ".\CommonScripts\OverrideOrAddKeyIfNotExist" -placeholderKey "<APP_INSIGHTS_INSTRUMENTATION_KEY>" -placeholderValue '""' -parametersTable $CommonConfigPlaceholders)
    }
    else {
        $currentAppInsightsInstrumentationKey = (& ".\CommonScripts\GetAppInsightsInstrumentationKey" -ApplicationInsightsName $ApplicationInsightsName -ResourceGroupName $ResourceGroupName)
        $CommonConfigPlaceholders = (& ".\CommonScripts\OverrideOrAddKeyIfNotExist" -placeholderKey "<APP_INSIGHTS_INSTRUMENTATION_KEY>" -placeholderValue $currentAppInsightsInstrumentationKey -parametersTable $CommonConfigPlaceholders)
    }
    $CommonConfigPlaceholders = (& ".\CommonScripts\OverrideOrAddKeyIfNotExist" -placeholderKey "<ENVIRONMENT_NAME>" -placeholderValue $NamespacePrefix -parametersTable $CommonConfigPlaceholders)

    # Windows AD role bindings
    if ($windowsActiveDirectoryRoles.Count -eq 0) {
        $CommonConfigPlaceholders = (& ".\CommonScripts\OverrideOrAddKeyIfNotExist" -placeholderKey "<ACTIVE_DIRECTORY_ROLES_JSON>" -placeholderValue '""' -parametersTable $CommonConfigPlaceholders)
    }
    else {
        $WindowsActiveDirectoryJson = $windowsActiveDirectoryRoles | ConvertTo-Json -Depth 10
        CommonConfigPlaceholders = (& ".\CommonScripts\OverrideOrAddKeyIfNotExist" -placeholderKey "<ACTIVE_DIRECTORY_ROLES_JSON>" -placeholderValue $WindowsActiveDirectoryJson -parametersTable $CommonConfigPlaceholders)
    }

    [hashtable]$convertedCommonSecretsPlaceholders = @{}
    Write-Verbose 'Converting placeholders to desired format..'
    foreach ($secret in $CommonSecretsPlaceholders.GetEnumerator()) {
        $convertedToBytes = [System.Text.Encoding]::UTF8.GetBytes($secret.Value);
        $convertedToStringBase64 = [System.Convert]::ToBase64String($convertedToBytes);
        $convertedCommonSecretsPlaceholders.Add($secret.Key, $convertedToStringBase64);
    }

    #Get List of microservices to deploy
    $ServicesRelativePaths = Resolve-Path ".\ServicesPaths\CommonServicesPaths.txt"
    $ServicesDeploymentPaths = (& ".\CommonScripts\Get-AbsolutePaths" -RootDirectory $InstallPackageRootDirectory -ConfigFilePath $ServicesRelativePaths)
    
    Write-Output 'Tokenize files...'
    & ".\CommonScripts\ReplacePlaceholdersInDeploymentFile" -sourceFilePath $namespacePath -parametersTable $CommonNamespacePlaceholders -outputFilePath $namespaceTempFile
    & ".\CommonScripts\ReplacePlaceholdersInDeploymentFile" -sourceFilePath $configPath -parametersTable $CommonConfigPlaceholders -outputFilePath $configTempFile
    & ".\CommonScripts\ReplacePlaceholdersInDeploymentFile" -sourceFilePath $secretsPath -parametersTable $convertedCommonSecretsPlaceholders -outputFilePath $secretsTempFile


    Write-Output 'Applying config and secrets files...'
    & ".\CommonScripts\ApplyKubectlConfig" -ConfigFile $namespaceTempFile -K8sConfigPath $K8sConfigPath -KubectlDirPath $PSScriptRoot
    & ".\CommonScripts\ApplyKubectlConfig" -ConfigFile $configTempFile -K8sConfigPath $K8sConfigPath -NamespaceFullName $namespaceFullName -KubectlDirPath $PSScriptRoot
    & ".\CommonScripts\ApplyKubectlConfig" -ConfigFile $secretsTempFile -K8sConfigPath $K8sConfigPath -NamespaceFullName $namespaceFullName -KubectlDirPath $PSScriptRoot


    & ".\CommonScripts\CreateKubectlSecretsRepository" `
        -DockerUserName $DockerUserName `
        -DockerPassword $DockerPassword `
        -DockerServer $DockerServer `
        -DockerRepositoryName $DockerRepositoryName `
        -NamespaceFullName $namespaceFullName `
        -K8sConfigPath $K8sConfigPath `
        -KubectlDirPath $PSScriptRoot

    & ".\CommonScripts\DeployKubectlServices" `
        -ServicesDeploymentPaths $ServicesDeploymentPaths `
        -NamespaceFullName $namespaceFullName `
        -K8sConfigPath $K8sConfigPath `
        -KubectlDirPath $PSScriptRoot `
        -FeederApiPort $FeederApiPort `
        -WebServicePort $WebServicePort

}
Finally {
    DeleteCreatedTempFiles
    Pop-Location
}