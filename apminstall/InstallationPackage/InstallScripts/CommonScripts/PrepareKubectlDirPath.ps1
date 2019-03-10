#Requires -Version 4.0
[CmdletBinding(
    PositionalBinding = $false,
    DefaultParameterSetName = 'FromEntry'
)]
Param(
    [Parameter(
        Mandatory = $false,
        HelpMessage = 'Path to kubectl directory'
    )]
    [string] $KubectlDirPath = $null
)

[string] $currentDirPath
if (![string]::IsNullOrEmpty($KubectlDirPath)) {
    $currentDirPath = $KubectlDirPath;
}
else {
    $currentDirPath = $PSScriptRoot;
}

if (-not(Test-Path ([System.IO.Path]::Combine("$currentDirPath", "kubectl.exe")))) {
    $errorMessage = "Kubectl.exe not found in $currentDirPath"
    throw $errorMessage
}

return [string] "$currentDirPath"