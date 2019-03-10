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
        HelpMessage = 'Template file path'
    )]
    [ValidateNotNullOrEmpty()]
    [string] $TemplateFilePath,
    
    [Parameter(
        Mandatory = $true,
        HelpMessage = 'Template parameters'
    )]
    [ValidateNotNullOrEmpty()]
    [hashtable] $TemplateParameters
)
New-AzureRmResourceGroupDeployment `
    -ResourceGroupName $ResourceGroupName `
    -TemplateFile $TemplateFilePath `
    -TemplateParameterObject $TemplateParameters

    
