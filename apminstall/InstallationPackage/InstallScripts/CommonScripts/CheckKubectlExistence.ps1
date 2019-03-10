#Requires -Version 4.0
[CmdletBinding(
    PositionalBinding=$false,
    DefaultParameterSetName='FromEntry'
)]
Param(
    [Parameter(
        Mandatory = $false,
        HelpMessage = 'Path to kubectl directory'
    )]
    [string] $KubectlDirPath = $null
)
Write-Verbose 'Checking kubectl presence'

[string] $currentDirPath
if(![string]::IsNullOrEmpty($KubectlDirPath))
{
    $currentDirPath = $kubectlDirPath;
}
else
{
    $currentDirPath = $PSScriptRoot;
}

if(-not(Test-Path "$currentDirPath\kubectl.exe"))
{
    Write-Error "Kubectl.exe not found in $PSScriptRoot."
    Exit
}



