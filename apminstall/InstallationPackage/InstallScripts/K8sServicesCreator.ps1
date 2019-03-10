[CmdletBinding(PositionalBinding = $false)]
Param(
    [Parameter(
        Mandatory = $false,
        HelpMessage = 'K8s config path'
    )]
    [ValidateScript( {Test-Path $_})]
    [string] $K8sConfigPath,
    [Parameter(
        Mandatory = $false,
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
        HelpMessage = 'Namespace prefix'
    )]
    [string] $NamespacePrefix,

    [Parameter(
        Mandatory = $true,
        HelpMessage = 'Namespace name'
    )]
    [string] $NamespaceName,

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
        HelpMessage = 'Hashtable containing paths to services conf and version'
    )]
    [string] $InstallPackageRootDirectory
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

[string]$ExistingRepositoryText = "Secrets $DockerRepositoryName already exists"

Push-Location -LiteralPath $PSScriptRoot 

Try {

    Write-Output 'Creating temporary files...'
    $namespaceTempFile = New-TemporaryFile
    $configTempFile = New-TemporaryFile
    $secretsTempFile = New-TemporaryFile
    Write-Verbose 'Temporary files created'

    $TenantConfigurationRelativePaths = Resolve-Path ".\ServicesPaths\TenantConfigurationPaths.txt"
    $TenantConfigurationAbsolutePaths = (& ".\CommonScripts\Get-AbsolutePaths" -RootDirectory $InstallPackageRootDirectory -ConfigFilePath $TenantConfigurationRelativePaths )
    Write-Output 'Reading configuration files...'
    $namespacePath = Get-Item -Path ($TenantConfigurationAbsolutePaths -match 'namespace')
    Write-Verbose 'Got namespace'
    $configPath = Get-Item -Path ($TenantConfigurationAbsolutePaths -match 'config')
    Write-Verbose 'Got configuration'
    $secretsPath = Get-Item -Path ($TenantConfigurationAbsolutePaths -match 'secrets')
    Write-Verbose 'Got secrets'

    Write-Verbose 'Checking if files are not empty..'
    if (((Get-Content $namespacePath) -eq $null) -or ((Get-Content $configPath) -eq $null) -or ((Get-Content $secretsPath) -eq $null)) {
        Write-Error "One or more of tenant configuration files are empty..."
        exit
    }

    [string] $namespaceFullName = (& ".\CommonScripts\PrepareNamespaceFullName.ps1" -NamespacePrefix $NamespacePrefix -NamespaceName $NamespaceName)

    [hashtable]$convertedTenantSecretsPlaceholders = @{}

    Write-Verbose 'Converting placeholders to desired format..'
    foreach ($tenantSecret in $TenantSecretsPlaceholders.GetEnumerator()) {
        Write-Verbose "Converting $($tenantSecret.Key)"
        $convertedToBytes = [System.Text.Encoding]::UTF8.GetBytes($tenantSecret.Value);
        $convertedToStringBase64 = [System.Convert]::ToBase64String($convertedToBytes);
        $convertedTenantSecretsPlaceholders.Add($tenantSecret.Key, $convertedToStringBase64);
    }

    Write-Output 'Tokenize files...'
    & ".\CommonScripts\ReplacePlaceholdersInDeploymentFile" -sourceFilePath $namespacePath -parametersTable $TenantNamespacePlaceholders -outputFilePath $namespaceTempFile
    & ".\CommonScripts\ReplacePlaceholdersInDeploymentFile" -sourceFilePath $configPath -parametersTable $TenantConfigurationPlaceholders -outputFilePath $configTempFile
    & ".\CommonScripts\ReplacePlaceholdersInDeploymentFile" -sourceFilePath $secretsPath -parametersTable $convertedTenantSecretsPlaceholders -outputFilePath $secretsTempFile


    Write-Output 'Creating and configuring kubernetes namespace...'
    Write-Output 'Applying namespace, config and secrets files...'
    & ".\CommonScripts\ApplyKubectlConfig" -ConfigFile $namespaceTempFile -K8sConfigPath $K8sConfigPath -KubectlDirPath $PSScriptRoot
    & ".\CommonScripts\ApplyKubectlConfig" -ConfigFile $configTempFile -K8sConfigPath $K8sConfigPath -NamespaceFullName $namespaceFullName -KubectlDirPath $PSScriptRoot
    & ".\CommonScripts\ApplyKubectlConfig" -ConfigFile $secretsTempFile -K8sConfigPath $K8sConfigPath -NamespaceFullName $namespaceFullName -KubectlDirPath $PSScriptRoot

    #Get List of microservices to deploy
    $ServicesRelativePaths = Resolve-Path ".\ServicesPaths\TenantServicesPaths.txt"
    $ServicesDeploymentPaths = (& ".\CommonScripts\Get-AbsolutePaths" -RootDirectory $InstallPackageRootDirectory -ConfigFilePath $ServicesRelativePaths)

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
        -K8sConfigPath $K8sConfigPath `
        -NamespaceFullName $namespaceFullName `
        -KubectlDirPath $PSScriptRoot
}
Catch {
    Throw
}
Finally {
    DeleteCreatedTempFiles
    Pop-Location
}