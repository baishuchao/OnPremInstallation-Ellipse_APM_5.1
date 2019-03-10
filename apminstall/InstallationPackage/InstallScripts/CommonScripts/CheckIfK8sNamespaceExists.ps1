
[OutputType([bool])]
[CmdletBinding(PositionalBinding = $false)]
Param(

    [Parameter(
        Mandatory = $true,
        HelpMessage = 'Namespace full name'
    )]
    [string] $NamespaceFullName,

    [Parameter(
        Mandatory = $true,
        HelpMessage = 'Actual kubectl dir path'
    )]
    [string] $ActualKubectlDirPath,

    [Parameter(
        Mandatory = $false,
        HelpMessage = 'K8s config path'
    )]
    [ValidateScript( {Test-Path $_})]
    [string] $K8sConfigPath

)

Write-Verbose "Full -> $NamespaceFullName"
[string[]] $secrets = @()
if ([string]::IsNullOrEmpty($K8sConfigPath)) {
    $secrets = (& "$ActualKubectlDirPath\kubectl.exe" --insecure-skip-tls-verify get namespaces -o=name)
}
else {
    $secrets = (& "$ActualKubectlDirPath\kubectl.exe" --kubeconfig=$K8sConfigPath --insecure-skip-tls-verify get namespaces -o=name)
}

Write-Output (($secrets -icontains "namespace/$NamespaceFullName") -or ($secrets -icontains "namespaces/$NamespaceFullName"))