#Requires -Version 4.0
[CmdletBinding(
    PositionalBinding = $false,
    DefaultParameterSetName = 'FromEntry'
)]
Param(
    [Parameter(
        Mandatory = $true,
        HelpMessage = 'Hashtable containing paths to services conf and version'
    )]
    [string[]] $ServicesDeploymentPaths,

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
        HelpMessage = 'Path to kubectl directory'
    )]
    [string] $KubectlDirPath = $null,

    [Parameter(
        Mandatory = $false,
        HelpMessage = 'Feeder Api Port Number'
    )]
    [string] $FeederApiPort = $null,

    [Parameter(
        Mandatory = $false,
        HelpMessage = 'Web Service Port Number'
    )]
    [string] $WebServicePort = $null
)
Write-Verbose 'Checking kubectl presence'

[string] $actualKubectlDirPath = (& "$PSScriptRoot\PrepareKubectlDirPath" -KubectlDirPath $KubectlDirPath)

$deploymentTempFiles = @{}
try {    
    foreach ($deployFileConfig in $ServicesDeploymentPaths) {
        $parameterTable = @{}
        Write-Verbose 'Creating temporary file'
        $deploymentTempFile = New-TemporaryFile
        Write-Verbose "Tokenizing service deployment file with ${deployFileConfig.Value}"
        
        #Verify if feeder api port is not null 
        if (-Not [string]::IsNullOrEmpty($FeederApiPort)) {
            $parameterTable += @{'<FEEDER_API_PORT>' = $FeederApiPort}
        }

        if (-Not [string]::IsNullOrEmpty($WebServicePort)) {
            $parameterTable += @{'<WEB_SERVICE_PORT>' = $WebServicePort}
        }

        & ".\CommonScripts\ReplacePlaceholdersInDeploymentFile" -sourceFilePath $deployFileConfig -parametersTable $parameterTable -outputFilePath $deploymentTempFile.FullName

        ## prefixName - artifact name in deployment
        $prefixName = Split-Path (Split-Path $deployFileConfig) -Leaf
        $fileName = (Split-Path $deployFileConfig -Leaf)
        $identifier = "$prefixName.$fileName"

        $deploymentTempFiles.Add($identifier, $deploymentTempFile.FullName)
        Write-Verbose "Deploying service.. $identifier"
        if ([string]::IsNullOrEmpty($K8sConfigPath)) {
            (& "$actualKubectlDirPath\kubectl.exe" --insecure-skip-tls-verify apply -f $deploymentTempFile.FullName -n $NamespaceFullName)
        }
        else {
            (& "$actualKubectlDirPath\kubectl.exe" --kubeconfig=$K8sConfigPath --insecure-skip-tls-verify apply -f $deploymentTempFile.FullName -n $NamespaceFullName)
        }
        
    }
}
finally {
    foreach ($tempFile in $deploymentTempFiles.GetEnumerator()) {
        if (Test-Path $tempFile.Value) {
            Remove-Item -Path $tempFile.Value -ErrorAction SilentlyContinue -WarningAction SilentlyContinue -Force
        }
    }
}