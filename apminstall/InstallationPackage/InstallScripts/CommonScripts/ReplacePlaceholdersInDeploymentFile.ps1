#Requires -Version 4.0
[CmdletBinding(
    PositionalBinding = $false,
    DefaultParameterSetName = 'FromEntry'
)]
Param (
    [Parameter(Mandatory = $true)]
    [string]$sourceFilePath,

    [Parameter(Mandatory = $true)]
    [hashtable]$parametersTable,

    [Parameter(Mandatory = $true)]
    [string]$outputFilePath
)

[string] $sourceFilename = [System.IO.Path]::GetFileName($sourceFilePath)
Write-Verbose "ReplacePlaceholdersInDeploymentFile - Getting source file content $sourceFilename"
[string[]] $sourceFileContent = Get-Content -Path $sourceFilePath
foreach ($parameter in $parametersTable.GetEnumerator()) {
    [string] $keyName = $parameter.Key
    Write-Verbose "Replacing $keyName"
    if ([string]::IsNullOrEmpty($parameter.Value)) {
        $parameter.Value = '""'
    }
    $sourceFileContent = $sourceFileContent -replace $parameter.Key, $parameter.Value
}
if ($sourceFileContent -match "<\w+>" -or $sourceFileContent -match "<>") {
    [string] $filename = [System.IO.Path]::GetFileName($sourceFilePath)
    Write-Error "File $sourceFileContent contains unknown paremeter. Exiting..."
    exit
}
Set-Content $outputFilePath -Value $sourceFileContent
Write-Verbose 'File saved.'