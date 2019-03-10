#Requires -Version 4.0
[CmdletBinding(
    PositionalBinding = $false,
    DefaultParameterSetName = 'FromEntry'
)]
Param(
    [Parameter(
        Mandatory = $true,
        HelpMessage = 'Namespace prefix'
    )]
    [string] $NamespacePrefix,

    [Parameter(
        Mandatory = $false,
        HelpMessage = 'Namespace name'
    )]
    [string] $NamespaceName = $null
)

if ([string]::isNullOrEmpty($NamespaceName)) {
    Write-Output "$NamespacePrefix".ToLower()
}
Else {
    Write-Output "$NamespacePrefix-$NamespaceName".ToLower()
}