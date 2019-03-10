#Requires -Version 4.0
[CmdletBinding(PositionalBinding = $true)]
Param (
    [Parameter(Mandatory = $true)]
    [string]$PlaceholderKey,
    [Parameter(Mandatory = $true)]
    [string]$PlaceholderValue,
    [Parameter(Mandatory = $true)]
    [AllowNull()]
    [hashtable]$ParametersTable
)

Write-Verbose "Looking in parameters for a $PlaceholderKey"
if ($ParametersTable.ContainsKey($PlaceholderKey)) {
    $tenantPlaceholder = $ParametersTable.GetEnumerator() | Where-Object {$_.Key -in ($PlaceholderKey)}
    Write-Verbose "Placeholder $PlaceholderKey exists in table. Overriding.."
    $ParametersTable.Set_Item($PlaceholderKey, $PlaceholderValue)
    return $ParametersTable
}
else {
    Write-Verbose "Placeholder $PlaceholderKey not found. Adding..."
    $ParametersTable.Add($PlaceholderKey, $PlaceholderValue)
    return $ParametersTable
}