[CmdletBinding(PositionalBinding = $false)]
param (
    [parameter(
        position = 1,
        Mandatory = $true,
        HelpMessage = 'Path to file.'
    )]
    [string]$path,

    [parameter(
        position = 2,
        Mandatory = $true,
        HelpMessage = 'Output object.'
    )]
    [ref]$output_obj
)

if (!(Test-Path -LiteralPath $path -PathType Leaf)) {
    Write-Verbose "$([DateTime]::Now.ToString("HH\:mm\:ss")): WARNING: NO FILE FOUND: $path"
    $output_obj.Value = $null
}
else {
    [PSObject] $data = (& "$PSScriptRoot\ConvertFrom-ExtendedJSon" -LiteralPath $path)
    Write-Verbose "$([DateTime]::Now.ToString("HH\:mm\:ss")): File loaded: $path"
    $output_obj.Value = $data
}