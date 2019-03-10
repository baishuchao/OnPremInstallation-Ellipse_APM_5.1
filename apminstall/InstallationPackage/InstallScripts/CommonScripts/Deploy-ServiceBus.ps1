#Requires -Version 4.0
[CmdletBinding(PositionalBinding = $false)]
Param(
    [Parameter(
        Mandatory = $true,
        HelpMessage = 'Resource group name'
    )]
    [ValidateNotNullOrEmpty()]
    [string] $ResourceGroupName,
    [Parameter(
        Mandatory = $true,
        HelpMessage = 'Resource group location'
    )]
    [ValidateNotNullOrEmpty()]
    [string] $ResourceGroupLocation,
    [Parameter(
        Mandatory = $true,
        HelpMessage = 'Template file path'
    )]
    [ValidateNotNullOrEmpty()]
    [string] $TemplateFilePath,
    [Parameter(
        Mandatory = $true,
        HelpMessage = 'Service bus namespace name prefix'
    )]
    [ValidateNotNullOrEmpty()]
    [string] $ServiceBusNamespaceNamePrefix
)

$templateParameters = @{
    "serviceBusNamespaceNamePrefix" = $ServiceBusNamespaceNamePrefix;
    "tenantName"                    = $TenantName;
    "location"                      = $ResourceGroupLocation
}

$outputs = $(Deploy-Template `
        -ResourceGroupName $ResourceGroupName `
        -TemplateFilePath $TemplateFilePath `
        -TemplateParameters $TemplateParameters
)

$namespaceConnectionString = $outputs["namespaceConnectionString"].Value

Write-Output [System.String] $namespaceConnectionString