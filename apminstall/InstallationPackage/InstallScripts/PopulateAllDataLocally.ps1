#Requires -Version 4.0
[CmdletBinding(PositionalBinding = $false)]
#region Script parameters
param (
    # -WebAppServerUrl <URL>
    [parameter(
        Mandatory = $false,
        HelpMessage = 'URL to the AHC WebApp server.'
    )]
    [Uri]$WebAppServerUrl = 'http://localhost:55031',

    # -FeederApiEndpoint <URL>
    [parameter(
        Mandatory = $false,
        HelpMessage = 'Full URL to the feeder messages endpoint'
    )]
    [Uri]$FeederApiEndpoint = 'http://localhost:5000/api/messages',

    # -dataset <data_set_names>
    [parameter(
        Mandatory = $false,
        HelpMessage = 'Name of the data set to be loaded. May be many data sets separated by comma.'
    )]
    [AllowEmptyString()]
    [ValidateNotNull()]
    [string]$Dataset = 'Default',

    # -customer <customer_file_name>
    [parameter(
        Mandatory = $false,
        HelpMessage = 'Customer file name for which the data will be imported.'
    )]
    [ValidateNotNullOrEmpty()]
    [string]$Customer = 'ABB',

    # -MaxLimit <number>
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
    # AAD Authentication parameters
    [parameter(
        Mandatory = $false,
        HelpMessage = 'ActiveDirectory authority URI'
    )]
    [Uri]$Authority = 'https://login.microsoftonline.com/0f3e7d0f-1b21-4b98-8a55-f2e2f3689d5e',
    [parameter(
        Mandatory = $false,
        HelpMessage = 'Resource application Id'
    )]
    [String]$AadApplicationId = '6b1cf328-847c-48f3-a4ad-05afcf8fc3d5', #AHC-LOCAL
    
    # Super Admin
    [parameter(
        Mandatory = $false,
        HelpMessage = 'Client application principal Id'
    )]
    [String]$SuperAdminClientId = '3ea8a3f6-401c-4269-bf99-cd3b6f7fdf09', #ahc-local-superadmin service principal
    [parameter(
        Mandatory = $false,
        HelpMessage = 'Client application principal secret key'
    )]
    [String]$SuperAdminClientSecret = 'rGt+AC/Qx3Hhl3+N03MUMRjDQAClFWJFbXhPyOeEkQg=',
    
    # Import
    [parameter(
        Mandatory = $false,
        HelpMessage = 'Client application principal Id'
    )]
    [String]$ImportClientId = '1606b3e0-5baf-4be8-8ba4-b6a3d83c15aa', #ahc-local-ABB-import service principal
    [parameter(
        Mandatory = $false,
        HelpMessage = 'Client application principal secret key'
    )]
    [String]$ImportClientSecret = 'sSA/+cSU9LdzP0ZbnxmEE4s/v3FUPSGKRYDUyKynnKU=',
    
    # Admin
    [parameter(
        Mandatory = $false,
        HelpMessage = 'Client application principal Id'
    )]
    [String]$AdminClientId = '949fc5c0-90e6-4282-a9be-78f7c5539aad', #ahc-local-ABB-administrator service principal

    [parameter(
        Mandatory = $false,
        HelpMessage = 'Client application principal secret key'
    )]
    [String]$AdminClientSecret = 'mbiO8BTcKIK4qleuXRSIGg3EyZSD8S5InVjuPFE/CKQ=' 
)
#endregion Script parameters

if ($processInputs -and !($WebAppServerUrl.Host.StartsWith('localhost'))) {
    $processInputs = $false
}

.\PopulateData.ps1 `
    -WebAppServerUrl $WebAppServerUrl `
    -FeederApiEndpoint $FeederApiEndpoint `
    -Dataset $Dataset `
    -Customer $Customer `
    -Authority $Authority `
    -AadApplicationId $AadApplicationId `
    -SuperAdminClientId $SuperAdminClientId `
    -SuperAdminClientSecret $SuperAdminClientSecret `
    -ImportClientId $ImportClientId `
    -ImportClientSecret $ImportClientSecret `
    -AdminClientId $AdminClientId `
    -AdminClientSecret $AdminClientSecret `
	-CreateCustomer `
    -UpdateCustomer `
    -PopulateExcels `
    -PopulatePowerBIs `
    -PopulateNameplates `
    -PopulateNameplateAttributes `
    -PopulateModelConfigurations `
    -PopulateIssues `
    -PopulateExternalReports `
    -PopulateTranslations `
    -PopulateFeederMessages `
    -ScheduleAssetRiskChangesUpdate `
    -ScheduleAssetRiskSummaryDashboardUpdate `
    -ScheduleMaintenancePriorityScoreUpdate `
    -ScheduleStationRiskMaterialization `
    -MaxLimit $MaxLimit `
    -ProcessInputs