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

    # -customer <customer_file_name>
    [parameter(
        Mandatory = $false,
        HelpMessage = 'Customer file name for which the data will be imported.'
    )]
    [string]$Customer,

    # -createCustomer
    [parameter(
        Mandatory = $false,
        HelpMessage = 'If customer should be created.'
    )]
    [ValidateNotNull()]
    [switch]$CreateCustomer,

    # -updateCustomer
    [parameter(
        Mandatory = $false,
        HelpMessage = 'If customer should be updated.'
    )]
    [ValidateNotNull()]
    [switch]$UpdateCustomer,

    # -createCustomerNoUpdate
    [parameter(
        Mandatory = $false,
        HelpMessage = 'If customer should created only if not exists without update.'
    )]
    [ValidateNotNull()]
    [switch]$CreateCustomerNoUpdate,

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

    # -populateExcels
    [parameter(
        Mandatory = $false,
        HelpMessage = 'If Excel sample data should be populated.'
    )]
    [ValidateNotNull()]
    [switch]$PopulateExcels,

    # -populatePowerBIs
    [parameter(
        Mandatory = $false,
        HelpMessage = 'If PowerBI standard reports should be populated.'
    )]
    [ValidateNotNull()]
    [switch]$PopulatePowerBIs,

    # -populateNameplates
    [parameter(
        Mandatory = $false,
        HelpMessage = 'If nameplates should be populated.'
    )]
    [ValidateNotNull()]
    [switch]$PopulateNameplates,

    # -populateNameplateAttributes
    [parameter(
        Mandatory = $false,
        HelpMessage = 'If asset attributes should be populated.'
    )]
    [ValidateNotNull()]
    [switch]$PopulateNameplateAttributes,

    # -populateModelConfigurations
    [parameter(
        Mandatory = $false,
        HelpMessage = 'If model configurations should be populated.'
    )]
    [ValidateNotNull()]
    [switch]$PopulateModelConfigurations,

    # -populateIssues
    [parameter(
        Mandatory = $false,
        HelpMessage = 'If issues should be populated.'
    )]
    [ValidateNotNull()]
    [switch]$PopulateIssues,

    # -populateManualInspections
    [parameter(
        Mandatory = $false,
        HelpMessage = 'If manual inspections should be populated.'
    )]
    [ValidateNotNull()]
    [switch]$PopulateManualInspections,
        
    # -populateExternalReports
    [parameter(
        Mandatory = $false,
        HelpMessage = 'If external reports should be populated.'
    )]
    [ValidateNotNull()]
    [switch]$PopulateExternalReports,

    # -populateTranslations
    [parameter(
        Mandatory = $false,
        HelpMessage = 'If custom translations should be populated.'
    )]
    [ValidateNotNull()]
    [switch]$PopulateTranslations,

    # -populateFeederMessages
    [parameter(
        Mandatory = $false,
        HelpMessage = 'If feeder messages should be populated.'
    )]
    [ValidateNotNull()]
    [switch]$PopulateFeederMessages,

    # -scheduleAssetRiskChangesUpdate
    [parameter(
        Mandatory = $false,
        HelpMessage = 'If asset risk changes need to be updated.'
    )]
    [ValidateNotNull()]
    [switch]$ScheduleAssetRiskChangesUpdate,

    # -scheduleAssetRiskSummaryDashboardUpdate
    [parameter(
        Mandatory = $false,
        HelpMessage = 'If asset risk summary dashboard need to be updated.'
    )]
    [ValidateNotNull()]
    [switch]$ScheduleAssetRiskSummaryDashboardUpdate,

    # -scheduleMaintenancePriorityScoreUpdate
    [parameter(
        Mandatory = $false,
        HelpMessage = 'If maintenance priority score need to be updated.'
    )]
    [ValidateNotNull()]
    [switch]$ScheduleMaintenancePriorityScoreUpdate,

    # -scheduleStationRiskMaterialization
    [parameter(
        Mandatory = $false,
        HelpMessage = 'If station risk need to be updated.'
    )]
    [ValidateNotNull()]
    [switch]$ScheduleStationRiskMaterialization,

    # -processInputs
    [parameter(
        Mandatory = $false,
        HelpMessage = 'If model input data processing should be launched. Use only if run locally.'
    )]
    [ValidateNotNull()]
    [switch]$ProcessInputs,
    # AAD Authentication parameters
    [parameter(
        Mandatory = $true,
        HelpMessage = 'ActiveDirectory authority URI'
    )]
    [Uri]$Authority,
    [parameter(
        Mandatory = $false,
        HelpMessage = 'Resource application Id'
    )]
    [String]$AadApplicationId,

    # Super Admin
    [parameter(
        Mandatory = $false,
        HelpMessage = 'Client application principal Id'
    )]
    [String]$SuperAdminClientId,
    [parameter(
        Mandatory = $false,
        HelpMessage = 'Client application principal secret key'
    )]
    [String]$SuperAdminClientSecret,
    
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

Push-Location ((Get-Item -LiteralPath ($script:MyInvocation.MyCommand.Path)).Directory.FullName)

Try {
	if ($CreateCustomer -or $UpdateCustomer -or $CreateCustomerNoUpdate -or $PopulatePowerBIs) {
		Write-Information 'Executing Customer.ps1 script'

		(& ".\Customer.ps1" `
				-Server $script:WebAppServerUrl `
				-Create:$script:CreateCustomer `
				-Update:$script:UpdateCustomer `
				-Customer $script:Customer `
				-PowerBIs:$script:PopulatePowerBIs `
				-MaxLimit $MaxLimit `
				-CreateNoUpdate:$script:CreateCustomerNoUpdate `
				-Authority $Authority `
				-AadApplicationId $AadApplicationId `
				-SuperAdminClientId $script:SuperAdminClientId `
				-SuperAdminClientSecret $script:SuperAdminClientSecret
		)

		Write-Output "`n"
	}

	if ($PopulateExcels -or $PopulateNameplates -or $PopulateNameplateAttributes -or $PopulateModelConfigurations -or 
		$PopulateIssues -or $PopulateExternalReports -or $PopulateTranslations -or $PopulateFeederMessages -or $ProcessInputs) {
		Write-Information 'Executing Populate.ps1 script'

		(& ".\Populate.ps1" `
				-WebAppServerUrl $script:WebAppServerUrl `
				-FeederApiEndpoint $script:FeederApiEndpoint `
				-Dataset $Dataset `
				-MaxLimit $MaxLimit `
				-Authority $script:Authority `
				-AadApplicationId $AadApplicationId `
				-ImportClientId $script:ImportClientId `
				-ImportClientSecret $script:ImportClientSecret `
				-AdminClientId $script:AdminClientId `
				-AdminClientSecret $script:AdminClientSecret `
				-Excels:$script:PopulateExcels `
				-Nameplates:$script:PopulateNameplates `
				-NameplateAttributes:$script:PopulateNameplateAttributes `
				-ModelConfigurations:$script:PopulateModelConfigurations `
				-Issues:$script:PopulateIssues `
				-ExternalReports:$script:PopulateExternalReports `
				-Translations:$script:PopulateTranslations `
				-FeederMessages:$script:PopulateFeederMessages `
				-ProcessInputs:$script:ProcessInputs 
		)

		Write-Output "`n"
	}

	if ($ScheduleAssetRiskChangesUpdate -or $ScheduleAssetRiskSummaryDashboardUpdate -or 
		$ScheduleMaintenancePriorityScoreUpdate -or $ScheduleStationRiskMaterialization) {
		Write-Information 'Executing Schedule.ps1 script'

		(& ".\Schedule.ps1" `
				-Server $script:WebAppServerUrl `
				-Authority $Authority `
				-AadApplicationId $AadApplicationId `
				-ImportClientId $script:ImportClientId `
				-ImportClientSecret $script:ImportClientSecret `
				-AssetRiskChangesUpdate:$script:ScheduleAssetRiskChangesUpdate `
				-AssetRiskSummaryDashboardUpdate:$script:ScheduleAssetRiskSummaryDashboardUpdate `
				-MaintenancePriorityScoreUpdate:$script:ScheduleMaintenancePriorityScoreUpdate `
				-StationRiskMaterialization:$script:ScheduleStationRiskMaterialization `
		)
	}


	if ($script:wasError) {
		Write-Error "$([DateTime]::Now.ToString("HH\:mm\:ss")): There were errors. Last one: $script:lastError"
	}
	elseif ($script:stepNumber -eq 0) {
		Write-Warning "$([DateTime]::Now.ToString("HH\:mm\:ss")): No steps were actually executed"
	}

}
Finally {
	Pop-Location
}