#Requires -Version 4.0
[CmdletBinding(PositionalBinding=$false)]

#region Script parameters

param (
    # -server <URL>
    [parameter(
        Mandatory=$true,
        HelpMessage='URL to the AHC server.'
    )]
    [ValidateNotNull()]
    [ValidateScript({
        if (!$_.IsAbsoluteUri) {
            throw "$_ is not an absolute URL."
        }
        if ($_.Scheme -inotin ('http','https')) {
            throw "$_ is not an HTTP/HTTPS URL."
        }
        $true
    })]
    [Uri]$Server,

    # AAD Authentication parameters
    [parameter(
        Mandatory=$true,
        HelpMessage='ActiveDirectory authority URI'
    )]
    [Uri]$Authority,

    [parameter(
        Mandatory=$true,
        HelpMessage='Resource application Id'
    )]
    [ValidateNotNullOrEmpty()]
    [string]$AadApplicationId,

    # Super Admin
    [parameter(
        Mandatory=$true,
        HelpMessage='Client application principal Id'
    )]
    [ValidateNotNullOrEmpty()]
    [string]$SuperAdminClientId,
    [parameter(
        Mandatory=$true,
        HelpMessage='Client application principal secret key'
    )]
    [ValidateNotNullOrEmpty()]
    [string]$SuperAdminClientSecret,

    # -ResetReportDbSettings
    [parameter(
        Mandatory=$false,
        HelpMessage='If report db settings should be reset.'
    )]
    [ValidateNotNull()]
    [switch]$ResetReportDbSettings,

    # -ResetPowerBiWorkspaces
    [parameter(
        Mandatory=$false,
        HelpMessage='If power bi workspaces should be reset.'
    )]
    [ValidateNotNull()]
    [switch]$ResetPowerBiWorkspaces
)
#endregion Script parameters


#region Preparation steps
Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): Passed parameters:"
$PSBoundParameters.GetEnumerator() | ForEach-Object {
    if ($_.Key -iin 'superAdminClientSecret')
    {
        Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")):   $($_.Key): ***********"
    }
    else
    {
        Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")):   $($_.Key): $($_.Value)"
    }
}

If ($PSBoundParameters['Debug'] -and ($DebugPreference -ieq 'Inquire'))
{
    $DebugPreference = 'Continue'
}

Write-Verbose "$([DateTime]::Now.ToString("HH\:mm\:ss")): Verbose mode is ON"
Write-Debug   "$([DateTime]::Now.ToString("HH\:mm\:ss")): Debug mode is ON"
Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")): Effective parameters:"
Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")):   Server: $($Server.ToString())"
Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")):   Authority: $Authority"
Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")):   AadApplicationId: $AadApplicationId"
Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")):   SuperAdminClientId: $SuperAdminClientId"
Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")):   SuperAdminClientSecret: ***********"
Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")):   ResetReportDbSettings: $ResetReportDbSettings"
Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")):   ResetPowerBiWorkspaces: $ResetPowerBiWorkspaces"

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

$Identities = @{
    "SuperAdmin" = @{
        "ID" = $SuperAdminClientId;
        "SECRET" = $SuperAdminClientSecret
    };
}

[Microsoft.PowerShell.Commands.WebRequestSession] $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession

function ResetReportDbSettings {
    [CmdletBinding(PositionalBinding = $false)]
    param()

    $script:stepNumber++
    Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): ------------------"
    Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): ${script:stepNumber}. ${script:stepName} ..."
    Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): --> Start: ${script:stepName}:"

	$script:stepName = "Reset report Db settings"
	$script:stepNumber++
	Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): ------------------"
	Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): ${script:stepNumber}. ${script:stepName} ..."
	Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): --> Start: ${script:stepName}:"

	[void] (& "CommonScripts\Invoke-RestMethodEasily" `
				-Server $script:Server `
				-Session $script:session `
				-Identities $Identities `
				-AuthorizationLevel 'SuperAdmin' `
				-Authority $Authority `
				-AadApplicationId $AadApplicationId `
				-Uri '/api/Customer/ResetReportDbSettings' `
				-Method POST `
				-NoContent `
				-WarningAction Stop `
				-TimeoutSec 90 `
				-ErrorAction Stop
			)

    Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")):  --> Finished: $($script:stepName)."
}


function ResetPowerBiWorkspaces {
    [CmdletBinding(PositionalBinding = $false)]
    param()

    $script:stepNumber++
    Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): ------------------"
    Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): ${script:stepNumber}. ${script:stepName} ..."
    Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): --> Start: ${script:stepName}:"

	$script:stepName = "Reset PowerBi workspaces"
	$script:stepNumber++
	Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): ------------------"
	Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): ${script:stepNumber}. ${script:stepName} ..."
	Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): --> Start: ${script:stepName}:"

	[void] (& "CommonScripts\Invoke-RestMethodEasily" `
				-Server $script:Server `
				-Session $script:session `
				-Identities $Identities `
				-AuthorizationLevel 'SuperAdmin' `
				-Authority $Authority `
				-AadApplicationId $AadApplicationId `
				-Uri '/api/Customer/ResetPowerBiWorkspaces' `
				-Method POST `
				-NoContent `
				-WarningAction Stop `
				-TimeoutSec 90 `
				-ErrorAction Stop
			)

    Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")):  --> Finished: $($script:stepName)."
}

Push-Location ((Get-Item -LiteralPath ($script:MyInvocation.MyCommand.Path)).Directory.FullName)
Try
{
    $script:stepName = "Restore PowerBI Reports"
	if ($ResetReportDbSettings)
	{
		ResetReportDbSettings
	}
	
	if ($ResetPowerBiWorkspaces)
	{
		ResetPowerBiWorkspaces
	}
}
Catch
{
    Write-Error "$([DateTime]::Now.ToString("HH\:mm\:ss")): $($_.Exception.Message)"
}
Finally
{
    Pop-Location
}