[CmdletBinding(PositionalBinding = $false)]
param (
    # -server <URL>
    [parameter(Mandatory = $true, HelpMessage = 'URL to the AHC server.')]
    [ValidateNotNullOrEmpty()]
    [ValidateScript( {
            if (!$_.IsAbsoluteUri) {
                throw "$_ is not an absolute URL."
            }
            if ($_.Scheme -inotin ('http', 'https')) {
                throw "$_ is not an HTTP/HTTPS URL."
            }
            $true
        })]
    [Uri]$Server,

    [parameter(
        Mandatory = $true,
        HelpMessage = 'ActiveDirectory authority URI'
    )]
    [Uri]$Authority,

    [parameter(Mandatory = $true, HelpMessage = 'Resource application Id')]
    [ValidateNotNullOrEmpty()]
    [String]$AadApplicationId,

    [parameter(Mandatory = $true, HelpMessage = 'Client application principal Id')]
    [ValidateNotNullOrEmpty()]
    [String]$SuperAdminClientId,

    [parameter(Mandatory = $true, HelpMessage = 'Client application principal secret key')]
    [ValidateNotNullOrEmpty()]
    [String]$SuperAdminClientSecret,

    [parameter(Mandatory = $true, HelpMessage = 'Action to invoke (Database, Data)')]
    [ValidateNotNullOrEmpty()]
    [String]$Action,

    [parameter(Mandatory = $false, HelpMessage = 'Request timeout in seconds (default value: 1800)')]
    [int]$TimeoutSec = 1800
)

$Identities = @{
    "SuperAdmin" = @{
        "ID"     = $SuperAdminClientId;
        "SECRET" = $SuperAdminClientSecret
    };
}

[Microsoft.PowerShell.Commands.WebRequestSession] $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
Push-Location ((Get-Item -LiteralPath ($script:MyInvocation.MyCommand.Path)).Directory.FullName)
Try {
    If ($Action -eq 'Database') {
        (& ".\CommonScripts\Invoke-RestMethodEasily" `
                -Server $Server `
                -Session $session `
                -Identities $Identities `
                -AuthorizationLevel 'SuperAdmin' `
                -Authority $Authority `
                -AadApplicationId $AadApplicationId `
                -Uri '/api/Migration/Database/' `
                -Method PUT `
                -NoContent `
                -TimeoutSec $TimeoutSec)
    }
    ElseIf ($Action -eq 'Data') {
        (& ".\CommonScripts\Invoke-RestMethodEasily" `
                -Server $Server `
                -Session $session `
                -Identities $Identities `
                -AuthorizationLevel 'SuperAdmin' `
                -Authority $Authority `
                -AadApplicationId $AadApplicationId `
                -Uri '/api/Migration/Data/' `
                -Method POST `
                -NoContent `
                -TimeoutSec $TimeoutSec)
    }
    Else {
        throw "'$Action' action is not supported. Available options: Data, Database"
    }
}
Finally {
    Pop-Location
}

if ($script:wasError) {
    Write-Error "$([DateTime]::Now.ToString("HH\:mm\:ss")): There were errors. Last one: $script:lastError"
}