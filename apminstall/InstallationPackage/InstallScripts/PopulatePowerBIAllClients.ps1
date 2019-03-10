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
    [Uri]$Server = "",
    
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
    [String]$AadApplicationId,
    
    # Super Admin
    [parameter(
        Mandatory = $true,
        HelpMessage = 'Client application principal Id'
    )]
    [String]$SuperAdminClientId,
    [parameter(
        Mandatory = $true,
        HelpMessage = 'Client application principal secret key'
    )]
    [String]$SuperAdminClientSecret
)
#endregion Script parameters

#region Preparation steps

Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): Passed parameters:"
$PSBoundParameters.GetEnumerator() | ForEach-Object {
    if ($_.Key -iin 'superAdminClientSecret') {
        Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")):   $($_.Key): ***********"
    }
    else {
        Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")):   $($_.Key): $($_.Value)"
    }
}

If ($PSBoundParameters['Debug'] -and ($DebugPreference -ieq 'Inquire')) {
    $DebugPreference = 'Continue'
}

$path = ((Get-Item -LiteralPath ($script:MyInvocation.MyCommand.Path)).Directory.Parent.FullName)
Write-Verbose "$([DateTime]::Now.ToString("HH\:mm\:ss")): Verbose mode is ON"
Write-Debug   "$([DateTime]::Now.ToString("HH\:mm\:ss")): Debug mode is ON"
Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")): Effective parameters:"
Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")):   server: $($Server.ToString())"
Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")):   path: $path"
Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")):   authority: $Authority"
Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")):   resourceAppId: $AadApplicationId"
Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")):   superAdminClientId: $SuperAdminClientId"
Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")):   superAdminClientSecret: ***********"

if ([string]::IsNullOrWhiteSpace($SuperAdminClientId) -or
    [string]::IsNullOrWhiteSpace($SuperAdminClientSecret)) {
    throw 'SuperAdmin credentials missing.'
}

[PSObject] $encoding = [System.Text.Encoding]::UTF8

[void][System.Reflection.Assembly]::LoadWithPartialName('System.Web.Extensions')
[PSObject] $json = New-Object -TypeName System.Web.Script.Serialization.JavaScriptSerializer
$json.MaxJsonLength = 2147483647
$json.RecursionLimit = 999

[PSObject] $proxy = [System.Net.WebRequest]::GetSystemWebProxy()
if ($proxy) {
    $proxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials
}

[bool] $wasError = $false
[string] $lastError = ''
[DateTime] $stepEndTime = [DateTime]::UtcNow
[DateTime] $allEndTime = [DateTime]::UtcNow
[DateTime] $allStartTime = [DateTime]::UtcNow
[DateTime] $stepStartTime = [DateTime]::UtcNow
[string[]] $customersData = $null
[string] $csrfToken = $null

[string] $stepName = ''
[int] $stepNumber = 0
[int] $stepParentId = -1
[int] $i = 0
[int] $cnt = 0

$Identities = @{
    "SuperAdmin" = @{
        "ID"     = $SuperAdminClientId;
        "SECRET" = $SuperAdminClientSecret
    };
}


[Microsoft.PowerShell.Commands.WebRequestSession] $session =
New-Object Microsoft.PowerShell.Commands.WebRequestSession

[PSObject] $oldCertPolicy = [System.Net.ServicePointManager]::CertificatePolicy
if ($Server.AbsoluteUri.StartsWith('https://localhost')) {
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

#region Helper functions

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

function MyUpdateProgress {
    [CmdletBinding(PositionalBinding = $false)]
    param (
        [parameter(
            position = 0,
            Mandatory = $true,
            HelpMessage = 'Give current entry name.'
        )]
        [string]$entry_name
    )

    $script:i++
    [int] $i = $script:i
    [hashtable] $additionalParams = @{}
    if ($i -gt 1) {
        [int] $sec = [DateTime]::UtcNow.Subtract($script:stepStartTime).TotalSeconds
        $sec = [int]($sec * ($script:cnt - $i + 1) / $i)
        $additionalParams['SecondsRemaining'] = $sec
    }

    Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): $i / $script:cnt : $entry_name"
    Write-Progress -Activity $script:stepName -Status 'Sending data' -Id $script:stepNumber -CurrentOperation "$i / $script:cnt : $entry_name" -PercentComplete (($i - 1) * 100 / $script:cnt) -ParentId $script:stepParentId @additionalParams
}

function MyFinalizeStep {
    [CmdletBinding(PositionalBinding = $false)]
    param()

    Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")):  --> Finished: $($script:stepName)."
    Write-Progress -Activity $script:stepName -Status 'Sending data' -Id $script:stepNumber -CurrentOperation 'Done' -ParentId $script:stepParentId -Completed
    $script:stepEndTime = [DateTime]::UtcNow
}

function GetCustomersList {
    [CmdletBinding(PositionalBinding = $false)]
    param()

    $script:customersData = @()

    (& ".\CommonScripts\GetTenantsList" `
            -Server $Server `
            -Authority $Authority `
            -AadApplicationId $AadApplicationId `
            -Identities $Identities `
            -output_obj ([ref]$script:customersData))
    
}

#endregion Helper functions

#region Upload functions
function PopulatePowerBIs {
    [CmdletBinding(PositionalBinding = $false)]
    param()

    $script:stepName = 'Populate PowerBi Reports'
    $script:stepNumber++
    Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): ------------------"
    Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): $($script:stepNumber). $($script:stepName) ..."
    Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): --> Start: $($script:stepName):"

    Write-Progress -Activity $script:stepName -Status 'Sending data' -Id $script:stepNumber -CurrentOperation 'Listing files' -PercentComplete 0 -ParentId $script:stepParentId

    [string] $reportsPath = "$($script:path)\PowerBIReports"
    Write-Verbose "$([DateTime]::Now.ToString("HH\:mm\:ss")): Searching for reports in: $reportsPath"
    [array] $allFiles = @()

    if (Test-Path $reportsPath -PathType Container) {
        $allFiles = @(Get-ChildItem -Path $reportsPath -Recurse -Include "*.pbix", "*.pbit" )
        Write-Verbose "$([DateTime]::Now.ToString("HH\:mm\:ss")): Found $($allFiles.Length) report files."
    }
    else {
        throw "No PowerBI report folder found."
    }
    
    $script:cnt = $allFiles.Length * $script:customersData.Length

    $script:i = 0
    $script:stepStartTime = [DateTime]::UtcNow
    
    Write-Progress -Activity $script:stepName -Status 'Sending data' -Id $script:stepNumber -CurrentOperation 'Uploading files' -PercentComplete 0 -ParentId $script:stepParentId

    if ($allFiles.Length -le 0) {
        Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): WARNING: NO FILES FOUND"
    }
    else {
        $allFiles | Foreach-Object {
            Write-Verbose "$([DateTime]::Now.ToString("HH\:mm\:ss")): Report: $($_.FullName)"
            [byte[]]$fileContentBytes = [io.file]::ReadAllBytes($_.FullName)
            [hashtable]$data = @{
                'ReportName'   = $_.Name
                'FileByteData' = $fileContentBytes
            }
            foreach ($customer in $script:customersData) {
                MyUpdateProgress -entry_name "$($_.Name) / $customer"
                Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): --> Importing report $($_.Name) for $customer"
                # Upload PowerBI report for customer
                $result = (& ".\CommonScripts\Invoke-RestMethodEasily" `
                        -Server $script:Server `
                        -Session $script:session `
                        -Identities $Identities `
                        -AuthorizationLevel 'SuperAdmin' `
                        -Authority $Authority `
                        -AadApplicationId $AadApplicationId `
                        -Uri "/api/Import/PowerBIReport/$(ConvertTo-UrlEncoded $customer)/" `
                        -TimeoutSec 900 `
                        -Entry $data)

                Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): --> Done"
            }
        }
    }

    MyFinalizeStep
}
#endregion Upload functions

Push-Location ((Get-Item -LiteralPath ($script:MyInvocation.MyCommand.Path)).Directory.FullName)
Try {
    #region Main code
    GetCustomersList
    PopulatePowerBIs

    if ($wasError) {
        Write-Error "$([DateTime]::Now.ToString("HH\:mm\:ss")): There were errors. Last one: $lastError"
    }
    #endregion Main code

    #region Clean-up
    $json = $null
    $proxy = $null
    $encoding = $null

    (& ".\CommonScripts\ClearAuthenticationTokenCache" `
            -authority $Authority
    )

    [System.Net.ServicePointManager]::CertificatePolicy = $oldCertPolicy
    Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): Finished."
    #endregion Clean-up
}
Catch {
    Write-Error "$([DateTime]::Now.ToString("HH\:mm\:ss")): $($_.Exception.Message)"
}
Finally {
    Pop-Location
}