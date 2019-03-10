#Requires -Version 4.0
[OutputType([string])]
[CmdletBinding(PositionalBinding = $false)]
Param(
    [parameter(
        Mandatory = $true,
        HelpMessage = 'Customer file name for which the data will be imported.'
    )]
    [ValidateNotNullOrEmpty()]
    [string]$Customer
)
[PSObject] $entry = $null
(& ".\CommonScripts\LoadDataFile" -path ([System.IO.Path]::Combine('Customers', "${Customer}.json")) -output_obj ([ref]$entry))

if ([string]::IsNullOrEmpty($entry)) {
    Write-Warning "${Customer}.json file not found. Using ${Customer} as Internal name"
    return $Customer
}

if ($entry.ContainsKey('InternalName')) {
    return $entry['PowerBiDatabasePassword']
}
elseif($entry.ContainsKey('internalName')) {
    return $entry['PowerBiDatabasePassword']
}
else{
    Throw 'Invalid customer json data, PowerBiDatabasePassword is missing'
}