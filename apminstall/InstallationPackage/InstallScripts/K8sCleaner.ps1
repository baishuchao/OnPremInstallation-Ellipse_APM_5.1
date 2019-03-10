#Requires -Version 4.0
[CmdletBinding(PositionalBinding = $false)]
Param(
    [parameter(
        Mandatory = $false,
        HelpMessage = 'Kubernetes config path'
    )]
    [string] $K8sConfigPath,

    [parameter(
        Mandatory = $false,
        HelpMessage = 'Tenants'
    )]
    [string[]] $Tenants,

    [parameter(
        Mandatory = $true,
        HelpMessage = 'Path to environment configuration file'
    )]
    [string] $EnvironmentConfigDataPath,

    [parameter(
        Mandatory = $false,
        HelpMessage = 'Path to kubectl exe'
    )]
    [ValidateScript( {Test-Path $_})]
    [string] $KubectlDirPath
)

if (-not(Test-Path -Path $EnvironmentConfigDataPath -PathType leaf)) {
    Write-Error 'Wrong path to json configuration file given. Path should point to json file.'
    Exit
}

Push-Location ((Get-Item -LiteralPath ($script:MyInvocation.MyCommand.Path)).Directory.FullName)
Try {
    [hashtable] $environmentConfigData = & ".\CommonScripts\ConvertFrom-ExtendedJSon" -LiteralPath $EnvironmentConfigDataPath
    
    $namespacePrefix = $environmentConfigData['NamespacePrefix']

    if([string]::IsNullOrEmpty($namespacePrefix)) {
        Throw "$([DateTime]::Now.ToString("HH\:mm\:ss")): Namespace prefix was not given"
    }

    if ([string]::IsNullOrEmpty($K8sConfigPath)) {
        Write-Verbose "$([DateTime]::Now.ToString("HH\:mm\:ss")): Getting K8sConfigPath"
        $K8sConfigPath = $environmentConfigData['K8sConfigPath']
    }

    & ".\K8sDeleteCommonNamespace" `
        -NamespacePrefix $namespacePrefix `
        -K8sConfigPath $K8sConfigPath `
        -KubectlDirPath $KubectlDirPath

    if($Tenants.Count -eq 0)
    {
        Write-Warning "$([DateTime]::Now.ToString("HH\:mm\:ss")): NO TENANTS PASSED!"
        Write-Verbose "$([DateTime]::Now.ToString("HH\:mm\:ss")): Script deleting tenant namespaces will not be called."
    } else 
    {
        & ".\K8sDeleteTenantNamespace" `
        -Customers $Tenants `
        -NamespacePrefix $namespacePrefix `
        -K8sConfigPath $K8sConfigPath `
        -KubectlDirPath $KubectlDirPath
    }
}
Finally {
    Pop-Location
}