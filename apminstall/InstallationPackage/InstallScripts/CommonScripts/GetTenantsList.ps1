[CmdletBinding(PositionalBinding = $false)]
param (
    # -server <URL>
    [parameter(
        position = 0,
        Mandatory = $true,
        HelpMessage = 'URL to the AHC server.'
    )]
    [ValidateNotNull()]
    [ValidateScript( {
            if (!$_.IsAbsoluteUri) {
                throw "$_ is not an absolute URL."
            }
            if ($_.Scheme -inotin ('http', 'https')) {
                throw "$_ is not an HTTP/HTTPS URL."
            }
            $true
        })]
    [Uri]$server,

    [parameter(
        position = 1,
        Mandatory = $true,
        HelpMessage = 'ActiveDirectory authority URI'
    )]
    [Uri]$Authority,

    [parameter(
        position = 2,
        Mandatory = $false
    )]
    [Microsoft.PowerShell.Commands.WebRequestSession] $Session,

    #Identities for token and user auth 
    [parameter(
        Position = 3,
        Mandatory = $false,
        HelpMessage = 'Identities'
    )]
    [hashtable] $Identities,

    # AAD Authentication parameters
    [parameter(
        position = 4,
        Mandatory = $false,
        HelpMessage = 'AAD application Id'
    )]
    [String]$AadApplicationId,

    [parameter(
        position = 5,
        Mandatory = $false,
        HelpMessage = 'Indicate HTTP method for the request (PUT is default).'
    )]
    [Microsoft.PowerShell.Commands.WebRequestMethod]$Method = [Microsoft.PowerShell.Commands.WebRequestMethod]::Put,

    [parameter(
        position = 6,
        Mandatory = $true,
        HelpMessage = 'Output object.'
    )]
    [ref]$output_obj
)

$script:stepName = 'Get customers list from server'
$script:stepNumber++
Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): ------------------"
Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): ${script:stepNumber}. ${script:stepName} ..."
Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): --> Start: ${script:stepName}:"

$script:customersData = @()

if ($Session -eq $null) {
    [Microsoft.PowerShell.Commands.WebRequestSession] $session =
    New-Object Microsoft.PowerShell.Commands.WebRequestSession
}

[PSObject] $apiOut = (& "$PSScriptRoot\Invoke-RestMethodEasily" `
        -Server $Server `
        -Session $Session `
        -Identities $Identities `
        -AuthorizationLevel "SuperAdmin" `
        -Authority $Authority `
        -AadApplicationId $AadApplicationId `
        -Uri '/api/Customer/Retrieve' `
        -Method Get `
        -NoContent)
    
if ($apiOut -eq $null) {
    Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): Received empty response."
}
if (($apiOut -isnot [string]) -and ($apiOut -isnot [array])) {
    throw "Invalid response structure ($($apiOut.GetType().FullName))."
}

[int] $cnt = 0
foreach ($entry in $apiOut) {
    Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): Received customer #$($i): $entry"
    if ([string]::IsNullOrWhiteSpace($entry)) {
        throw "Customer entry is empty."
    }
    $i++
}

$output_obj.Value = [string[]]($apiOut)

Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")):  --> Finished: $($script:stepName)."