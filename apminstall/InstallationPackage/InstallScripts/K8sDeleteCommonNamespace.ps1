[CmdletBinding(PositionalBinding = $false)]
Param(

    [Parameter(
        Mandatory = $true,
        HelpMessage = 'Namespace prefix'
    )]
    [string] $NamespacePrefix,

    [Parameter(
        Mandatory = $false,
        HelpMessage = 'Path to kubectl directory'
    )]
    [string] $KubectlDirPath = $PSScriptRoot,

    [Parameter(
        Mandatory = $false,
        HelpMessage = 'K8s config path'
    )]
    [ValidateScript( {Test-Path $_})]
    [string] $K8sConfigPath
)

Push-Location -LiteralPath $PSScriptRoot
Try {
    [string] $namespaceFullName = (& ".\CommonScripts\PrepareNamespaceFullName.ps1" -NamespacePrefix $NamespacePrefix)
    [string] $actualKubectlDirPath = & ".\CommonScripts\PrepareKubectlDirPath" -KubectlDirPath $KubectlDirPath
    
    [bool] $namespaceExists = (& ".\CommonScripts\CheckIfK8sNamespaceExists.ps1" -NamespaceFullName $namespaceFullName -ActualKubectlDirPath $actualKubectlDirPath -K8sConfigPath $K8sConfigPath)

    if ($namespaceExists -eq $false) {
        Write-Warning "$NamespaceFullName namespace does not exist. Nothing to do"
    }
    else {
        Write-Verbose "Attempting to delete K8s $namespaceFullName namespace"
        if ([string]::IsNullOrEmpty($K8sConfigPath)) {
            ( & "$actualKubectlDirPath\kubectl.exe" delete namespace $namespaceFullName --insecure-skip-tls-verify)
        }
        else {
            ( & "$actualKubectlDirPath\kubectl.exe" delete namespace $namespaceFullName --insecure-skip-tls-verify --kubeconfig=$K8sConfigPath)
        }
    }
}

Finally {
    Pop-Location
}