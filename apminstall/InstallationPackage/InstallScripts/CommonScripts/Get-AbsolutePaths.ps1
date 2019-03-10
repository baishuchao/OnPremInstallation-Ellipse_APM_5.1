[CmdletBinding(PositionalBinding = $false)]
Param(
    [Parameter(
        Mandatory = $true,
        HelpMessage = 'Root directory'
    )]
    [ValidateScript( {Test-Path $_})]
    [string] $RootDirectory,

    [Parameter(
        Mandatory = $true,
        HelpMessage = 'Path to file containing relative paths'
    )]
    [string] $ConfigFilePath
)

$absolutePaths = @()
$relativePathsArray = Get-Content $ConfigFilePath
foreach ($relativePath in $relativePathsArray) {
    $absolutePaths += (& Join-Path $RootDirectory $relativePath)
}

Write-Output $absolutePaths