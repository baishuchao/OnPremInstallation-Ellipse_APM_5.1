#Requires -Version 4.0
[CmdletBinding(PositionalBinding = $false)]
#region Script parameters
param (
    # -server <URL>
    [parameter(
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
    [Uri]$Server,

    # AAD Authentication parameters
    [parameter(
        Mandatory = $true,
        HelpMessage = 'ActiveDirectory authority URI'
    )]
    [Uri]$Authority,

    [parameter(
        Mandatory = $true,
        HelpMessage = 'Resource application Id'
    )]
    [ValidateNotNullOrEmpty()]
    [String]$AadApplicationId,
    
    # Import
    [parameter(
        Mandatory = $true,
        HelpMessage = 'Client application principal Id'
    )]
    [ValidateNotNullOrEmpty()]
    [String]$ImportClientId,

    [parameter(
        Mandatory = $true,
        HelpMessage = 'Client application principal secret key'
    )]
    [ValidateNotNullOrEmpty()]
    [String]$ImportClientSecret,

    # -assetRiskChangesUpdate
    [parameter(
        Mandatory = $false,
        HelpMessage = 'If asset risk changes need to be updated.'
    )]
    [ValidateNotNull()]
    [switch]$AssetRiskChangesUpdate,

    # -assetRiskSummaryDashboardUpdate
    [parameter(
        Mandatory = $false,
        HelpMessage = 'If asset risk summary dashboard need to be updated.'
    )]
    [ValidateNotNull()]
    [switch]$AssetRiskSummaryDashboardUpdate,

    # -maintenancePriorityScoreUpdate
    [parameter(
        Mandatory = $false,
        HelpMessage = 'If maintenance priority score need to be updated.'
    )]
    [ValidateNotNull()]
    [switch]$MaintenancePriorityScoreUpdate,

    # -stationRiskMaterialization
    [parameter(
        Mandatory = $false,
        HelpMessage = 'If station risk need to be updated.'
    )]
    [ValidateNotNull()]
    [switch]$StationRiskMaterialization
)
#endregion Script parameters

#region Preparation steps
Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): Passed parameters:"
$PSBoundParameters.GetEnumerator() | ForEach-Object {
    if ($_.Key -iin 'superAdminClientSecret', 'importClientSecret', 'adminClientSecret') {
        Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")):   $($_.Key): ***********"
    }
    else {
        Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")):   $($_.Key): $($_.Value)"
    }
}

If ($PSBoundParameters['Debug'] -and ($DebugPreference -ieq 'Inquire')) {
    $DebugPreference = 'Continue'
}

Write-Verbose "$([DateTime]::Now.ToString("HH\:mm\:ss")): Verbose mode is ON"
Write-Debug   "$([DateTime]::Now.ToString("HH\:mm\:ss")): Debug mode is ON"
Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")): Effective parameters:"
Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")):   server: $($Server.ToString())"
Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")):   authority: $Authority"
Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")):   applicationId: $AadApplicationId"
Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")):   importClientId: $ImportClientId"
Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")):   importClientSecret: ***********"


if (!$AssetRiskChangesUpdate -and
    !$AssetRiskSummaryDashboardUpdate -and
    !$MaintenancePriorityScoreUpdate -and
    !$StationRiskMaterialization) {
    throw "Schedule was not selected";
}

if ([string]::IsNullOrWhiteSpace($Authority) -or [string]::IsNullOrWhiteSpace($AadApplicationId)) {
    throw 'Resource application Id and AAD Id missing.'
}

[PSObject] $proxy = [System.Net.WebRequest]::GetSystemWebProxy()
if ($proxy) {
    $proxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials
}

[bool] $wasError = $false
[string] $lastError = ''
[DateTime] $allStartTime = [DateTime]::UtcNow
[DateTime] $stepStartTime = [DateTime]::UtcNow
[string] $stepName = ''
[int] $stepNumber = 0
[int] $stepParentId = -1
[DateTime] $stepEndTime = [DateTime]::UtcNow
[DateTime] $allEndTime = [DateTime]::UtcNow
[int] $i = 0
[int] $cnt = 0
[PSObject] $customerData = $null
[bool] $customerExists = $false
[string] $csrfToken = $null

$Identities = @{
    "Import" = @{
        "ID"     = $ImportClientId;
        "SECRET" = $ImportClientSecret
    };
}

[Microsoft.PowerShell.Commands.WebRequestSession] $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession

[PSObject] $oldCertPolicy = [System.Net.ServicePointManager]::CertificatePolicy
if ($server.AbsoluteUri.StartsWith('https://localhost')) {
    Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): Turning off security for localhost connection"
    
    if (-not ([System.Management.Automation.PSTypeName]'TrustAllCertsPolicy').Type) {
        Add-Type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy
{
    public bool CheckValidationResult(
        ServicePoint srvPoint,
        X509Certificate certificate,
        WebRequest request,
        int certificateProblem
    )
    {
        return true;
    }
}
"@
    }
    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
}

#endregion Preparation steps

#region Schedule functions
function ConvertTo-UrlEncoded {
    [CmdletBinding(PositionalBinding = $true)]
    [OutputType([string])]
    param (
        [parameter(position = 0, Mandatory = $true)]
        [AllowEmptyString()]
        [ValidateNotNull()]
        [string]$Text
    )
    return [System.Uri]::EscapeDataString($Text)
}

function ScheduleAssetAssetRiskChangesUpdate {
    [CmdletBinding(PositionalBinding = $false)]
    param()

    $script:stepName = 'Schedule Update Asset Risk Changes'
    $script:stepNumber++
    Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): ------------------"
    Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): ${script:stepNumber}. ${script:stepName} ..."
    Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): --> Start: ${script:stepName}:"
    [PSObject] $entry = $null

    Try {
        $entry = (& "CommonScripts\Invoke-RestMethodEasily" `
                -Server $script:Server `
                -Session $script:session `
                -Identities $Identities `
                -AuthorizationLevel 'Import' `
                -Authority $Authority `
                -AadApplicationId $AadApplicationId `
                -Uri '/api/Processors/ScheduleUpdateAssetRiskChanges' `
                -Method Post `
                -NoContent 
        )
        if ($entry -eq $null) {
            Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): Received empty response."
            $entry = @()
        }

    }
    Catch {
        $script:wasError = $true
        $script:lastError = $_.Exception.Message + "(in step $($script:stepName))"
        Write-Warning "$([DateTime]::Now.ToString("HH\:mm\:ss")): $($_.Exception.Message)"
    }
    Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")):  --> Finished: $($script:stepName)."
}

function ScheduleAssetRiskSummaryDashboardUpdate {
    [CmdletBinding(PositionalBinding = $false)]
    param()

    $script:stepName = 'Schedule Update Asset Risk Summary dashboard'
    $script:stepNumber++
    Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): ------------------"
    Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): ${script:stepNumber}. ${script:stepName} ..."
    Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): --> Start: ${script:stepName}:"
    [PSObject] $entry = $null

    Try {
        $entry = (& "CommonScripts\Invoke-RestMethodEasily" `
                -Server $script:Server `
                -Session $script:session `
                -Identities $Identities `
                -AuthorizationLevel 'Import' `
                -Authority $Authority `
                -AadApplicationId $AadApplicationId `
                -Uri '/api/Processors/ScheduleUpdateAssetRiskSummaryDashboard' `
                -Method Post `
                -NoContent
        )
        if ($entry -eq $null) {
            Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): Received empty response."
            $entry = @()
        }

    }
    Catch {
        $script:wasError = $true
        $script:lastError = $_.Exception.Message + "(in step $($script:stepName))"
        Write-Warning "$([DateTime]::Now.ToString("HH\:mm\:ss")): $($_.Exception.Message)"
    }
    Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")):  --> Finished: $($script:stepName)."
}

function ScheduleMaintenancePriorityScoreUpdate {
    [CmdletBinding(PositionalBinding = $false)]
    param()

    $script:stepName = 'Schedule Update Maintenance Priority Score'
    $script:stepNumber++
    Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): ------------------"
    Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): ${script:stepNumber}. ${script:stepName} ..."
    Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): --> Start: ${script:stepName}:"
    [PSObject] $entry = $null

    Try {
        $entry = (& "CommonScripts\Invoke-RestMethodEasily" `
                -Server $script:Server `
                -Session $script:session `
                -Identities $Identities `
                -AuthorizationLevel 'Import' `
                -Authority $Authority `
                -AadApplicationId $AadApplicationId `
                -Uri '/api/Processors/ScheduleUpdateMaintenancePriorityScore' `
                -Method Post `
                -NoContent
        )
        if ($entry -eq $null) {
            Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): Received empty response."
            $entry = @()
        }

    }
    Catch {
        $script:wasError = $true
        $script:lastError = $_.Exception.Message + "(in step $($script:stepName))"
        Write-Warning "$([DateTime]::Now.ToString("HH\:mm\:ss")): $($_.Exception.Message)"
    }
    Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")):  --> Finished: $($script:stepName)."
}

function ScheduleStationRiskMaterialization {
    [CmdletBinding(PositionalBinding = $false)]
    param()

    $script:stepName = 'Schedule Station Risk Materialization'
    $script:stepNumber++
    Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): ------------------"
    Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): ${script:stepNumber}. ${script:stepName} ..."
    Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): --> Start: ${script:stepName}:"
    [PSObject] $entry = $null

    Try {
        $entry = (& "CommonScripts\Invoke-RestMethodEasily" `
                -Server $script:Server `
                -Session $script:session `
                -Identities $Identities `
                -AuthorizationLevel 'Import' `
                -Authority $Authority `
                -AadApplicationId $AadApplicationId `
                -Uri '/api/Processors/ScheduleUpdateStationRiskAssets' `
                -Method Post `
                -NoContent
        )
        if ($entry -eq $null) {
            Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): Received empty response."
            $entry = @()
        }
    }
    Catch {
        $script:wasError = $true
        $script:lastError = $_.Exception.Message + "(in step $($script:stepName))"
        Write-Warning "$([DateTime]::Now.ToString("HH\:mm\:ss")): $($_.Exception.Message)"
    }
    Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")):  --> Finished: $($script:stepName)."
}

#endregion Schedule functions

#region Main code
Push-Location ((Get-Item -LiteralPath ($script:MyInvocation.MyCommand.Path)).Directory.FullName)
Try {
    if ($AssetRiskChangesUpdate) {
        ScheduleAssetAssetRiskChangesUpdate
    }

    if ($AssetRiskSummaryDashboardUpdate) {
        ScheduleAssetRiskSummaryDashboardUpdate
    }

    if ($MaintenancePriorityScoreUpdate) {
        ScheduleMaintenancePriorityScoreUpdate
    }

    if ($StationRiskMaterialization) {
        ScheduleStationRiskMaterialization
    }

    if ($wasError) {
        Write-Error "$([DateTime]::Now.ToString("HH\:mm\:ss")): There were errors. Last one: $lastError"
    }
    elseif ($stepNumber -eq 0) {
        Write-Warning "$([DateTime]::Now.ToString("HH\:mm\:ss")): No Schedule steps were actually executed"
    }
}
Catch {
    Write-Error "$([DateTime]::Now.ToString("HH\:mm\:ss")): $($_.Exception.Message)"
}
Finally {
    Pop-Location
}

#endregion Main code

#region Clean-up
$allEndTime = [DateTime]::UtcNow
$json = $null
$proxy = $null

(& "CommonScripts\ClearAuthenticationTokenCache" `
        -authority $Authority
)

[System.Net.ServicePointManager]::CertificatePolicy = $oldCertPolicy
Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): Finished."
#endregion Clean-up