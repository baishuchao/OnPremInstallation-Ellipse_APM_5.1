#Requires -Version 4.0
[CmdletBinding(
    PositionalBinding = $false,
    DefaultParameterSetName = 'FromEntry'
)]
Param(
    [Parameter(
        Mandatory = $true,
        HelpMessage = 'K8s config path'
    )]
    [ValidateScript( {Test-Path $_})]
    [string] $ConfigFile,

    [Parameter(
        Mandatory = $false,
        HelpMessage = 'K8s config path'
    )]
    [ValidateScript( {Test-Path $_})]
    [string] $K8sConfigPath,

    [Parameter(
        Mandatory = $false,
        HelpMessage = 'Path to kubectl directory'
    )]
    [string] $KubectlDirPath = $null,

    [Parameter(
        Mandatory = $false,
        HelpMessage = 'Namespace full name'
    )] 
    [string] $NamespaceFullName = $null

)

[string] $actualKubectlDirPath = & "$PSScriptRoot\PrepareKubectlDirPath" -KubectlDirPath $KubectlDirPath

Write-Verbose 'Applying config file'

if ([string]::IsNullOrEmpty($K8sConfigPath)) {
    if ([string]::IsNullOrEmpty($NamespaceFullName)) {
        ( & "$actualKubectlDirPath\kubectl.exe" -f $ConfigFile --insecure-skip-tls-verify apply)
    }
    else {
        ( & "$actualKubectlDirPath\kubectl.exe" -f $ConfigFile -n $NamespaceFullName --insecure-skip-tls-verify apply)
    }
}
else {
    if ([string]::IsNullOrEmpty($NamespaceFullName)) {
        ( & "$actualKubectlDirPath\kubectl.exe" --kubeconfig=$K8sConfigPath -f $ConfigFile --insecure-skip-tls-verify apply )
    }
    else {
        ( & "$actualKubectlDirPath\kubectl.exe" --kubeconfig=$K8sConfigPath -f $ConfigFile -n $NamespaceFullName --insecure-skip-tls-verify apply )
    }
}