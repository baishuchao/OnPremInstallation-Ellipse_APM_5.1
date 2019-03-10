#Requires -Version 4.0
[CmdletBinding(
    PositionalBinding = $false,
    DefaultParameterSetName = 'FromEntry'
)]
Param(

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
        HelpMessage = 'Namespace full name'
    )]
    [string] $NamespaceFullName,

    [Parameter(
        Mandatory = $false,
        HelpMessage = 'K8s config path'
    )]
    [ValidateScript( {Test-Path $_})]
    [string] $K8sConfigPath,

    [Parameter(
        Mandatory = $false,
        HelpMessage = 'Paths to kubectl directory'
    )]
    [string] $KubectlDirPath = $null
)

function CheckRepositorySecretExistence {
    #Requires -Version 4.0
    [CmdletBinding(
        PositionalBinding = $false,
        DefaultParameterSetName = 'FromEntry'
    )]
    [OutputType([bool])]
    Param(
        [Parameter(
            Mandatory = $false,
            HelpMessage = 'K8s config path'
        )]
        [ValidateScript( {Test-Path $_})]
        [string] $K8sConfigPath,

        [Parameter(
            Mandatory = $true,
            HelpMessage = 'Docker repository name'
        )]
        [string] $NamespaceFullName,

        [Parameter(
            Mandatory = $true,
            HelpMessage = 'Docker repository name'
        )]
        [ValidateNotNullOrEmpty()]
        [string] $DockerRepositoryName,

        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Path to kubectl directory'
        )]
        [string] $KubectlDirPath = $null
    )
    [string] $actualKubectlDirPath = (& "$PSScriptRoot\PrepareKubectlDirPath" -KubectlDirPath $KubectlDirPath)

    Write-Verbose 'Checking existence of secret repository'

    [string[]] $secrets = @()
    if ([string]::IsNullOrEmpty($K8sConfigPath)) {
        $secrets = (& "$actualKubectlDirPath\kubectl.exe" --insecure-skip-tls-verify get secrets --namespace=$NamespaceFullName -o=name)
    }
    else {
        $secrets = (& "$actualKubectlDirPath\kubectl.exe" --kubeconfig=$K8sConfigPath --insecure-skip-tls-verify get secrets --namespace=$NamespaceFullName -o=name)
    }
    
    Write-Output ($secrets -icontains "secret/$DockerRepositoryName")
}


[string]$ExistingRepositoryText = "Secrets $DockerRepositoryName already exists"

$secretExistence = (CheckRepositorySecretExistence -K8sConfigPath $K8sConfigPath -NamespaceFullName $NamespaceFullName -DockerRepositoryName $DockerRepositoryName -KubectlDirPath $KubectlDirPath)

[string] $actualKubectlDirPath = & "$PSScriptRoot\PrepareKubectlDirPath" -KubectlDirPath $KubectlDirPath

if ($secretExistence -eq $false) {
    Write-Verbose 'Creating secrets repository'
    if ([string]::IsNullOrEmpty($K8sConfigPath)) {
        & "$actualKubectlDirPath\kubectl.exe" create secret docker-registry $DockerRepositoryName --docker-username=$DockerUsername --docker-password=$DockerPassword --docker-server=$DockerServer --docker-email=epiphany@azure.com -n $NamespaceFullName --insecure-skip-tls-verify
    }
    else {
        & "$actualKubectlDirPath\kubectl.exe" --kubeconfig=$K8sConfigPath create secret docker-registry $DockerRepositoryName --docker-username=$DockerUsername --docker-password=$DockerPassword --docker-server=$DockerServer --docker-email=epiphany@azure.com -n $NamespaceFullName --insecure-skip-tls-verify
    }
}
else {
    Write-Verbose $ExistingRepositoryText
}