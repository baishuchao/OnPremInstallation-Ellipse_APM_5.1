#Requires -Version 4.0
[CmdletBinding(PositionalBinding = $false)]
param (
    
    [Parameter(
        Mandatory = $true,
        HelpMessage = 'Application insights name'
    )]
    [ValidateNotNullOrEmpty()]
    [string] $ApplicationInsightsName,

    [Parameter(
        Mandatory = $true,
        HelpMessage = 'Resource group name'
    )]
    [ValidateNotNullOrEmpty()]
    [string] $ResourceGroupName
)

$module = Get-Module -List AzureRM.ApplicationInsights
if (!$module) { 
    Install-PackageProvider -Name NuGet -Force -Scope CurrentUser
    Install-Module -Name AzureRM.ApplicationInsights -Force -Scope CurrentUser
}

Import-Module AzureRM.ApplicationInsights

[Microsoft.Azure.Commands.ApplicationInsights.Models.PSApplicationInsightsComponent ] $result = Get-AzureRmApplicationInsights -ResourceGroupName $ResourceGroupName -Name $ApplicationInsightsName

Write-Output $result.InstrumentationKey