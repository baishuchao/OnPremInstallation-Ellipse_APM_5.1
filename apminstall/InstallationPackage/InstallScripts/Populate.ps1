#Requires -Version 4.0
[CmdletBinding(PositionalBinding = $false)]
#region Script parameters
param (
    # -WebAppServerUrl <URL>
    [parameter(
        Mandatory = $false,
        HelpMessage = 'URL to the AHC WebApp server.'
    )]
    [Uri]$WebAppServerUrl,

    [parameter(
        Mandatory = $true,
        HelpMessage = 'ActiveDirectory authority URI'
    )]
    [Uri]$Authority,

    # -FeederApiEndpoint <URL>
    [parameter(
        Mandatory = $false,
        HelpMessage = 'Full URL to the feeder messages endpoint'
    )]
    [Uri]$FeederApiEndpoint,

    # -dataset <data_set_names>
    [parameter(
        Mandatory = $false,
        HelpMessage = 'Name of the data set to be loaded. May be many data sets separated by comma.'
    )]
    [AllowEmptyString()]
    [ValidateNotNull()]
    [string]$Dataset = 'Default',

    # -maxLimit <number>
    [parameter(
        Mandatory = $false,
        HelpMessage = 'Maximum number of row to upload (default: 0 - all rows from json files).'
    )]
    [ValidateNotNull()]
    [ValidateScript( {
            if ($_ -ge 0) {
                $true
            }
            else {
                throw "$_ is a negative value - maxLimit can't be."
            }
        })]
    [int]$MaxLimit = 0,

    # -excels
    [parameter(
        Mandatory = $false,
        HelpMessage = 'If Excel sample data should be populated.'
    )]
    [ValidateNotNull()]
    [switch]$Excels,

    # -nameplates
    [parameter(
        Mandatory = $false,
        HelpMessage = 'If nameplates should be populated.'
    )]
    [ValidateNotNull()]
    [switch]$Nameplates,

    # -nameplateAttributes
    [parameter(
        Mandatory = $false,
        HelpMessage = 'If asset attributes should be populated.'
    )]
    [ValidateNotNull()]
    [switch]$NameplateAttributes,

    # -modelConfigurations
    [parameter(
        Mandatory = $false,
        HelpMessage = 'If model configurations should be populated.'
    )]
    [ValidateNotNull()]
    [switch]$ModelConfigurations,

    # -issues
    [parameter(
        Mandatory = $false,
        HelpMessage = 'If issues should be populated.'
    )]
    [ValidateNotNull()]
    [switch]$Issues,

    # -manualInspections
    [parameter(
        Mandatory = $false,
        HelpMessage = 'If manual inspections should be populated.'
    )]
    [ValidateNotNull()]
    [switch]$ManualInspections,
        
    # -externalReports
    [parameter(
        Mandatory = $false,
        HelpMessage = 'If external reports should be populated.'
    )]
    [ValidateNotNull()]
    [switch]$ExternalReports,

    # -translations
    [parameter(
        Mandatory = $false,
        HelpMessage = 'If custom translations should be populated.'
    )]
    [ValidateNotNull()]
    [switch]$Translations,

    # -feederMessages
    [parameter(
        Mandatory = $false,
        HelpMessage = 'If feeder messages should be populated.'
    )]
    [ValidateNotNull()]
    [switch]$FeederMessages,

    # -processInputs
    [parameter(
        Mandatory = $false,
        HelpMessage = 'If model input data processing should be launched. Use only if run locally.'
    )]
    [ValidateNotNull()]
    [switch]$ProcessInputs,

    [parameter(
        Mandatory = $true,
        HelpMessage = 'Resource application Id'
    )]
    [String]$AadApplicationId,
    
    # Import
    [parameter(
        Mandatory = $false,
        HelpMessage = 'Client application principal Id'
    )]
    [String]$ImportClientId,
    [parameter(
        Mandatory = $false,
        HelpMessage = 'Client application principal secret key'
    )]
    [String]$ImportClientSecret,
    
    # Admin
    [parameter(
        Mandatory = $false,
        HelpMessage = 'Client application principal Id'
    )]
    [String]$AdminClientId,
    [parameter(
        Mandatory = $false,
        HelpMessage = 'Client application principal secret key'
    )]
    [String]$AdminClientSecret
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
Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")):   WebApp server: $($WebAppServerUrl.ToString())"
Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")):   Feeder API endpoint server: $($FeederApiEndpoint.ToString())"
Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")):   dataset: $Dataset"
Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")):   maxLimit: $MaxLimit"
Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")):   populateExcels: $Excels"
Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")):   populateNameplates: $Nameplates"
Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")):   populateNameplateAttributes: $NameplateAttributes"
Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")):   populateModelConfigurations: $ModelConfigurations"
Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")):   populateIssues: $Issues"
Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")):   populateManualInspections: $ManualInspections"
Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")):   populateExternalReports: $ExternalReports"
Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")):   populateFeederMessages: $FeederMessages"
Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")):   authority: $Authority"
Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")):   applicationId: $AadApplicationId"
Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")):   importClientId: $ImportClientId"
Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")):   importClientSecret: ***********"
Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")):   adminClientId: $AdminClientId"
Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")):   adminClientSecret: ***********"

if ($Nameplates -or $NameplateAttributes -or $ModelConfigurations -or $Issues -or
    $ManualInspections -or $ExternalReports -or $Translations) {
    if ([string]::IsNullOrWhiteSpace($WebAppServerUrl)) {
        throw "'WebAppServerUrl' is missing or empty string."
    }
    if (!$WebAppServerUrl.IsAbsoluteUri) {
        throw "'WebAppServerUrl' is not an absolute URL."
    }
    
    if ($WebAppServerUrl.Scheme -inotin ('http', 'https')) {
        throw "'WebAppServerUrl' is not an HTTP/HTTPS URL."
    }
}

if ($FeederMessages) {
    if ([string]::IsNullOrWhiteSpace($FeederApiEndpoint)) {
        throw "'FeederApiEndpoint' is missing or empty string."
    }
    if (!$FeederApiEndpoint.IsAbsoluteUri) {
        throw "'FeederApiEndpoint' is not an absolute URL."
    }
    
    if ($FeederApiEndpoint.Scheme -inotin ('http', 'https')) {
        throw "'FeederApiEndpoint' is not an HTTP/HTTPS URL."
    }
}

if ($ProcessInputs -and !($WebAppServerUrl.Host.StartsWith('localhost'))) {
    throw 'The "processInputs" flag should be used only on localhost (local development instance)'
}

if ($Excels) {
    if ([string]::IsNullOrWhiteSpace($Authority) -or
        [string]::IsNullOrWhiteSpace($AadApplicationId) -or
        [string]::IsNullOrWhiteSpace($AdminClientId) -or
        [string]::IsNullOrWhiteSpace($AdminClientSecret)
    ) {
        throw 'Admin credentials missing. Those operations require admin access (id & secret): populate excels'
    }
}

if ($Nameplates -or $NameplateAttributes -or $ModelConfigurations -or $Issues -or
    $ManualInspections -or $ExternalReports -or $Translations -or $FeederMessages) {
    if ([string]::IsNullOrWhiteSpace($Authority) -or
        [string]::IsNullOrWhiteSpace($AadApplicationId) -or
        [string]::IsNullOrWhiteSpace($ImportClientId) -or
        [string]::IsNullOrWhiteSpace($ImportClientSecret)
    ) {
        throw 'Import credentials missing. Require import access (id & secret) to populate: Nameplates, NameplatesAttributes, ModelConfigurations, Issues, ManualInspections, ExternalReports, Translations, FeederMessages'
    }
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
[string] $customerId = $null
[PSObject] $customerData = $null
[bool] $customerExists = $false
[string] $csrfToken = $null

$Identities = @{
    "Import" = @{
        "ID"     = $ImportClientId;
        "SECRET" = $ImportClientSecret
    };
    "Admin"  = @{
        "ID"     = $AdminClientId;
        "SECRET" = $AdminClientSecret
    }
}

[Microsoft.PowerShell.Commands.WebRequestSession] $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession

[string[]] $Datasets = @($Dataset.Split(',', [System.StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object {if ($_ -eq 'Default') {''} else {$_}})

[PSObject] $oldCertPolicy = [System.Net.ServicePointManager]::CertificatePolicy
if ($WebAppServerUrl.AbsoluteUri.StartsWith('https://localhost')) {
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

function MyInitStep {
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([array])]
    param (
        [parameter(
            position = 0,
            Mandatory = $true,
            HelpMessage = 'Give step name.'
        )]
        [ValidateNotNullOrEmpty()]
        [string]$step_name,

        [parameter(
            position = 1,
            Mandatory = $true,
            HelpMessage = 'Path.'
        )]
        [string]$path,

        [parameter(
            position = 2,
            Mandatory = $true,
            HelpMessage = 'Output arr.'
        )]
        [ref]$output_arr
    )

    $script:stepName = $step_name
    $script:stepNumber++

    Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): ------------------"
    Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): $($script:stepNumber). $step_name ..."
    Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): --> Start: ${step_name}:"
    Write-Progress -Activity $step_name -Status 'Loading file' -Id $script:stepNumber -CurrentOperation 'Locating file' -PercentComplete 0 -ParentId $script:stepParentId

    [PSObject] $data = $null
    (& "CommonScripts\LoadDataFile" -path $path -output_obj ([ref]$data))

    if ($data -eq $null) {
        Write-Progress -Activity $step_name -Status 'Loading file' -Id $script:stepNumber -CurrentOperation 'NO FILE FOUND' -ParentId $script:stepParentId -Completed
        $output_arr.Value = @()
    }
    else {
        [array] $dataArray = $data
        Write-Progress -Activity $step_name -Status 'Loading file' -Id $script:stepNumber -CurrentOperation 'File loaded' -PercentComplete 0 -ParentId $script:stepParentId
        Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): Populating data ..."
        $script:i = 0
        
        $script:stepStartTime = [DateTime]::UtcNow

        if ($script:MaxLimit -ne 0) {
            if ($dataArray.Length -gt $script:MaxLimit) {
                $dataArray = $dataArray[0..($script:MaxLimit - 1)]
            }
        }

        $script:cnt = $dataArray.Length
        $output_arr.Value = $dataArray
    }
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

#endregion Helper functions



#region Upload functions

function PopulateExcels {
    [CmdletBinding(PositionalBinding = $false)]
    param()

    $script:stepName = 'Populate Xlsx Model Sample Data'
    $script:stepNumber++
    Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): ------------------"
    Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): $($script:stepNumber). $($script:stepName) ..."
    Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): --> Start: $($script:stepName):"

    [string] $filesPath = "XlsxModelSampleData\SamplesToImport"
    [array] $entries = @(Get-ChildItem -Path $filesPath -Recurse -Include *.xlsx)

    if (($script:MaxLimit -ne 0) -and ($entries.Length -gt $script:MaxLimit)) {
        $entries = $entries[0..($script:MaxLimit - 1)]
    }

    $script:cnt = $entries.Length

    $script:i = 0

    Write-Progress -Activity $script:stepName -Status 'Sending data' -Id $script:stepNumber -CurrentOperation 'Listing files' -PercentComplete 0 -ParentId $script:stepParentId

    if ($entries.Length -le 0) {
        Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): WARNING: NO FILES FOUND IN: $filesPath"
    }
    else {
        $entries | Foreach-Object {
            MyUpdateProgress -entry_name $_.Name
            [byte[]] $fileContentBytes = [io.file]::ReadAllBytes($_.FullName)
            [string] $fileContentBase64 = [System.Convert]::ToBase64String($fileContentBytes)
            $fileContentBytes.Clear()
            $fileContentBytes = $null

            [hashtable]$data = @{
                'FileName'     = $_.Name
                'FileByteData' = $fileContentBase64
            }

            $result = (& "CommonScripts\Invoke-RestMethodEasily" `
                    -Server $script:WebAppServerUrl `
                    -Session $script:session `
                    -Identities $Identities `
                    -AuthorizationLevel 'Admin' `
                    -Authority $Authority `
                    -AadApplicationId $AadApplicationId `
                    -Uri '/api/XlsxImport/XlsxData/' `
                    -Entry $data `
                    -TimeoutSec 900 `
                    -sendCsrfToken)
        }
    }
    MyFinalizeStep
}

function PopulateNameplates {
    [CmdletBinding(PositionalBinding = $false)]
    param()

    foreach ($set in $script:datasets) {
        [array] $entries = @()
        MyInitStep -step_name "Populating Nameplates $set" -path "Assets\Nameplates${set}.json" -output_arr ([ref]$entries)

        ForEach ($entry in $entries) {
            Try {
                MyUpdateProgress -entry_name $entry.Id

                [Uri] $uri = "/api/Import/Asset/$(ConvertTo-UrlEncoded $entry.Id)/Nameplate"
                $result = (& "CommonScripts\Invoke-RestMethodEasily" `
                        -Server $script:WebAppServerUrl `
                        -Session $script:session `
                        -Identities $Identities `
                        -AuthorizationLevel 'Import' `
                        -Authority $Authority `
                        -AadApplicationId $AadApplicationId `
                        -Uri $uri `
                        -Entry $entry.Nameplate `
                )
            }
            Catch {
                $script:wasError = $true
                $script:lastError = $_.Exception.Message + " (in step $($script:stepName))"
                Write-Warning "$([DateTime]::Now.ToString("HH\:mm\:ss")): $($_.Exception.Message)"
            }
        }

        MyFinalizeStep
    }
}

function PopulateModelConfigurations {
    [CmdletBinding(PositionalBinding = $false)]
    param()

    foreach ($set in $script:datasets) {
        [array] $entries = @()
        MyInitStep -step_name "Populating ModelConfigurations $set" -path "ModelConfigurations\ModelConfigurations${set}.json" -output_arr ([ref]$entries)

        ForEach ($entry in $entries) {
            Try {
                MyUpdateProgress -entry_name $entry.ModelId

                [Uri] $uri = "/api/Import/ModelConfiguration/$(ConvertTo-UrlEncoded ($entry.ModelId))/"
                $result = (& "CommonScripts\Invoke-RestMethodEasily" `
                        -Server $script:WebAppServerUrl `
                        -Session $script:session `
                        -Identities $Identities `
                        -AuthorizationLevel 'Import' `
                        -Authority $Authority `
                        -AadApplicationId $AadApplicationId `
                        -Uri $uri `
                        -Entry $entry.ModelConfiguration
                )
            }
            Catch {
                $script:wasError = $true
                $script:lastError = $_.Exception.Message + " (in step $($script:stepName))"
                Write-Warning "$([DateTime]::Now.ToString("HH\:mm\:ss")): $($_.Exception.Message)"
            }
        }

        MyFinalizeStep
    }
}

function PopulateIssues {
    [CmdletBinding(PositionalBinding = $false)]
    param()

    foreach ($set in $script:datasets) {
        [array] $entries = @()
        MyInitStep -step_name "Populating Issues $set" -path "Issues\Issues${set}.json" -output_arr ([ref]$entries)

        ForEach ($entry in $entries) {
            Try {
                MyUpdateProgress -entry_name $entry.AssetId

                [Uri] $uri = '/api/Import/Issue'
                $result = (& "CommonScripts\Invoke-RestMethodEasily" `
                        -Server $script:WebAppServerUrl `
                        -Session $script:session `
                        -Identities $Identities `
                        -AuthorizationLevel 'Import' `
                        -Authority $Authority `
                        -AadApplicationId $AadApplicationId `
                        -Uri $uri `
                        -Entry $entry)
            }
            Catch {
                $script:wasError = $true
                $script:lastError = $_.Exception.Message + " (in step $($script:stepName))"
                Write-Warning "$([DateTime]::Now.ToString("HH\:mm\:ss")): $($_.Exception.Message)"
            }
        }

        MyFinalizeStep
    }
}

function PopulateManualInspections {
    [CmdletBinding(PositionalBinding = $false)]
    param()
    foreach ($set in $script:datasets) {
        [array] $entries = @()
        MyInitStep -step_name "Populating Inspections $set" -path "ManualInspections\ManualInspections${set}.json" -output_arr ([ref]$entries)

        ForEach ($entry in $entries) {
            MyUpdateProgress -entry_name "$($entry.AssetId) ($($entry.Inspections.Length))"

            ForEach ($inspection in $entry.Inspections) {
                Try {
                    [Uri] $uri = "/api/Inspections/$(ConvertTo-UrlEncoded $entry.AssetId)/"
                    $result = (& "CommonScripts\Invoke-RestMethodEasily" `
                            -Server $script:WebAppServerUrl `
                            -Session $script:session `
                            -Identities $Identities `
                            -AuthorizationLevel 'Import' `
                            -Authority $Authority `
                            -AadApplicationId $AadApplicationId `
                            -Uri $uri `
                            -Method Post `
                            -Entry $inspection
                    )
                }
                Catch {
                    $script:wasError = $true
                    $script:lastError = $_.Exception.Message + " (in step $($script:stepName))"
                    Write-Warning "$([DateTime]::Now.ToString("HH\:mm\:ss")): $($_.Exception.Message)"
                }
            }
        }

        MyFinalizeStep
    }
}

function PopulateNameplateAttributes {
    [CmdletBinding(PositionalBinding = $false)]
    param()
    foreach ($set in $script:datasets) {
        [array] $entries = @()
        MyInitStep -step_name "Populating AssetAttributes $set" -path "AssetAttributes\NameplateAttributes${set}.json" -output_arr ([ref]$entries)

        ForEach ($entry in $entries) {
            Try {
                MyUpdateProgress -entry_name "$($entry.Id) ($($entry.Values.Length))"

                [int] $j = 0
                ForEach ($subEntry in $entry.Values) {
                    $j++
                    Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")):    $j : [ $($subEntry.Key) ] : $($subEntry.Value)"

                    [Uri] $uri = "/api/Import/Asset/$(ConvertTo-UrlEncoded $entry.Id)/NameplateAttributes/$(ConvertTo-UrlEncoded $subEntry.Key)/"
                    $result = (& "CommonScripts\Invoke-RestMethodEasily" `
                            -Server $script:WebAppServerUrl `
                            -Session $script:session `
                            -Identities $Identities `
                            -AuthorizationLevel 'Import' `
                            -Authority $Authority `
                            -AadApplicationId $AadApplicationId `
                            -Uri $uri `
                            -Entry $subEntry.Value
                    )
                }
            }
            Catch {
                $script:wasError = $true
                $script:lastError = $_.Exception.Message + "(in step $($script:stepName))"
                Write-Warning "$([DateTime]::Now.ToString("HH\:mm\:ss")): $($_.Exception.Message)"
            }
        }

        MyFinalizeStep
    }
}

function PopulateExternalReports {
    [CmdletBinding(PositionalBinding = $false)]
    param()
    foreach ($set in $script:datasets) {
        [array] $entries = @()
        MyInitStep -step_name "Populating ExternalReports $set" -path "ExternalReports\ExternalReports${set}.json" -output_arr ([ref]$entries)

        ForEach ($entry in $entries) {
            Try {
                MyUpdateProgress -entry_name $entry.DisplayName

                [Uri] $uri = '/api/Import/ExternalReportLink'
                $result = (& "CommonScripts\Invoke-RestMethodEasily" `
                        -Server $script:WebAppServerUrl `
                        -Session $script:session `
                        -Identities $Identities `
                        -AuthorizationLevel 'Import' `
                        -Authority $Authority `
                        -AadApplicationId $AadApplicationId `
                        -Uri $uri `
                        -Entry $entry `
                        -TimeoutSec 900 `
                )
            }
            Catch {
                $script:wasError = $true
                $script:lastError = $_.Exception.Message + "(in step $($script:stepName))"
                Write-Warning "$([DateTime]::Now.ToString("HH\:mm\:ss")): $($_.Exception.Message)"
            }
        }

        MyFinalizeStep
    }
}

function PopulateTranslations {
    [CmdletBinding(PositionalBinding = $false)]
    param()

    $script:stepName = 'Load custom tranlations'
    $script:stepNumber++
    Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): ------------------"
    Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): ${script:stepNumber}. ${script:stepName} ..."
    Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): --> Start: ${script:stepName}:"
    Write-Progress -Activity $script:stepName -Status 'Loading file' -Id $script:stepNumber -CurrentOperation 'Locating file' -PercentComplete 0 -ParentId $script:stepParentId

    foreach ($set in $script:datasets) {
        [string] $translationsFileRoot = "Translations$set"
        [string] $translationsFileRegex = "$translationsFileRoot\.([a-z]{2})\.json$"
        [string] $translationsDirectory = "Translations\"
        $translationFiles = Get-ChildItem -Path $translationsDirectory -Recurse -ErrorAction SilentlyContinue -Force | where { $_.Name -match $translationsFileRegex }
        $locales = $translationFiles | Group-Object {[regex]::Match($_.Name, $translationsFileRegex).captures.groups[1].value}

        foreach ($foundLocale in $locales) {
            [string] $locale = $foundLocale.Name
            [PSObject] $entry = $null
            (& "CommonScripts\LoadDataFile" -path "Translations\$translationsFileRoot.$locale.json" -output_obj ([ref]$entry))

            if ($entry) {
                Try {
                    [Uri] $uri = "/api/Translations/$locale"
                    $result = (& "CommonScripts\Invoke-RestMethodEasily" `
                            -Server $script:WebAppServerUrl `
                            -Session $script:session `
                            -Identities $Identities `
                            -AuthorizationLevel 'Import' `
                            -Authority $Authority `
                            -AadApplicationId $AadApplicationId `
                            -Uri $uri `
                            -Method Post `
                            -sendCsrfToken `
                            -Entry $entry
                    )
                }
                Catch {
                    $script:wasError = $true
                    $script:lastError = $_.Exception.Message + "(in step $($script:stepName))"
                    Write-Warning "$([DateTime]::Now.ToString("HH\:mm\:ss")): $($_.Exception.Message)"
                }
            }
            else {
                Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): Warning: The file is empty."
            }
        }

        MyFinalizeStep
    }
}

function PopulateFeederMessages {
    [CmdletBinding(PositionalBinding = $false)]
    param()

    foreach ($set in $script:datasets) {
        [array] $entries = @()
        MyInitStep -step_name "Populating Feeder Messages $set" -path "FeederMessages\FeederMessages${set}.json" -output_arr ([ref]$entries)

        [array] $combinedEntries = @()
        ForEach ($entry in $entries) {
            if ($entry -is [string]) {
                [string] $filePath = $entry
                [PSObject] $fileEntries = $null
                (& "CommonScripts\LoadDataFile" -path "FeederMessages\${filePath}" -output_obj ([ref]$fileEntries))

                if ($fileEntries -ne $null) {
                    $combinedEntries = $combinedEntries + $fileEntries
                }
                else {
                    Write-Warning "$([DateTime]::Now.ToString("HH\:mm\:ss")): $($_.Exception.Message)"
                }
            }
            else {
                $combinedEntries = $combinedEntries + $entry
            }
        }

        $entries = $combinedEntries
        $script:cnt = $entries.Length

        ForEach ($entry in $entries) {
            Try {
                MyUpdateProgress -entry_name "$($entry.messages.length) messages"

                $result = (& "CommonScripts\Invoke-RestMethodEasily" `
                        -Server $script:FeederApiEndpoint `
                        -Session $script:session `
                        -Identities $Identities `
                        -AuthorizationLevel 'Import' `
                        -Authority $Authority `
                        -AadApplicationId $AadApplicationId `
                        -Uri $script:FeederApiEndpoint `
                        -Entry $entry `
                        -TimeoutSec 300 `
                        -Method Post 
                )
            }
            Catch {
                $script:wasError = $true
                $script:lastError = $_.Exception.Message + " (in step $($script:stepName))"
                Write-Warning "$([DateTime]::Now.ToString("HH\:mm\:ss")): $($_.Exception.Message)"
            }
        }

        MyFinalizeStep
    }
}

function ProcessInputs {
    [CmdletBinding(PositionalBinding = $false)]
    param()

    $script:stepName = "Processing model inputs"
    $script:stepNumber++

    Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): $($script:stepNumber). $($script:stepName) ..."
    
    $script:stepStartTime = [DateTime]::UtcNow

    Push-Location "..\ABB.AHC.ModelExecutor\bin\Debug"
    Try {
        Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): Execute model executor"
        .\ABB.AHC.ModelExecutor.exe process all
    }
    Catch {
        $script:wasError = $true
        $script:lastError = $_.Exception.Message + "(in step $($script:stepName))"
        Write-Warning "$([DateTime]::Now.ToString("HH\:mm\:ss")): $($_.Exception.Message)"
    }
    Finally {
        Pop-Location
    }
    
    Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")):  --> Finished: $($script:stepName)."
}

#endregion Upload functions

#region Main code
Push-Location ((Get-Item -LiteralPath ($script:MyInvocation.MyCommand.Path)).Directory.FullName)
Try {
    if ($Nameplates) {
        PopulateNameplates
    }

    if ($ModelConfigurations) {
        PopulateModelConfigurations
    }

    if ($Issues) {
        PopulateIssues
    }

    if ($ManualInspections) {
        PopulateManualInspections
    }

    if ($NameplateAttributes) {
        PopulateNameplateAttributes
    }

    if ($ExternalReports) {
        PopulateExternalReports
    }

    if ($Excels) {
        PopulateExcels
    }

    if ($Translations) {
        PopulateTranslations
    }
    
    if ($FeederMessages) {
        PopulateFeederMessages
    }

    if ($ProcessInputs) {
        ProcessInputs
    }

    if ($wasError) {
        Write-Error "$([DateTime]::Now.ToString("HH\:mm\:ss")): There were errors. Last one: $lastError"
    }
    elseif ($stepNumber -eq 0) {
        Write-Warning "$([DateTime]::Now.ToString("HH\:mm\:ss")): No Populate steps were actually executed"
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
        -Authority $Authority
)


[System.Net.ServicePointManager]::CertificatePolicy = $oldCertPolicy
Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): Finished."
#endregion Clean-up