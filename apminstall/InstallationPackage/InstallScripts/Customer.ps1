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

    # -customer <customer_file_name>
    [parameter(
        Mandatory=$false,
        HelpMessage='Customer file name for which the data will be imported.'
    )]
    [ValidateNotNullOrEmpty()]
    [string]$Customer,

    # -create
    [parameter(
        Mandatory=$false,
        HelpMessage='If customer should be created.'
    )]
    [ValidateNotNull()]
    [switch]$Create,

    # -update
    [parameter(
        Mandatory=$false,
        HelpMessage='If customer should be updated.'
    )]
    [ValidateNotNull()]
    [switch]$Update,

    # -createNoUpdate
    [parameter(
        Mandatory=$false,
        HelpMessage='If customer should created only if not exists without update.'
    )]
    [ValidateNotNull()]
    [switch]$CreateNoUpdate,

    # -delete
    [parameter(
        Mandatory=$false,
        HelpMessage='If customer should be deletaed.'
    )]
    [ValidateNotNull()]
    [switch]$Delete,

    # -PowerBIs
    [parameter(
        Mandatory=$false,
        HelpMessage='If PowerBI standard reports should be populated.'
    )]
    [ValidateNotNull()]
    [switch]$PowerBIs,

    # -PowerBIReportsToDeleteNames
    [parameter(
        Mandatory=$false,
        HelpMessage='If PowerBI report should be deleted provide report name'
    )]
    [ValidateNotNullOrEmpty()]
    [string[]]$PowerBIReportsToDeleteNames = $null,

    # -maxLimit <number>
    [parameter(
        Mandatory=$false,
        HelpMessage='Maximum number of row to upload (default: 0 - all rows from json files).'
    )]
    [ValidateNotNull()]
    [ValidateScript({
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
    [string]$SuperAdminClientSecret
)

#endregion Script parameters


#region Preparation steps
Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): Passed parameters:"
$PSBoundParameters.GetEnumerator() | ForEach-Object {
    if ($_.Key -iin 'superAdminClientSecret', 'importClientSecret', 'adminClientSecret')
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
Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")):   Customer: $Customer"
Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")):   Create: $Create"
Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")):   Update: $Update"
Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")):   CreateNoUpdate: $CreateNoUpdate"
Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")):   Delete: $Delete"
Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")):   PowerBIs: $PowerBIs"
Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")):   PowerBIReportsToDeleteNames: $PowerBIReportsToDeleteNames"
Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")):   Authority: $Authority"
Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")):   AadApplicationId: $AadApplicationId"
Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")):   SuperAdminClientId: $SuperAdminClientId"
Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")):   SuperAdminClientSecret: ***********"

# Those flags are actually used to determine if the customer should be created
# and/or updated. They are initially set based on the script parameters, but
# can be cleared later.
[bool] $shouldCreateCustomer = $false
[bool] $shouldUpdateCustomer = $false
[bool] $shouldDeleteCustomer = $false
if ($Create -or $CreateNoUpdate -or $Update -or $Delete)
{
    if ($Create -or $CreateNoUpdate) 
    {
        $shouldCreateCustomer = $true
    }
    if ($Update) 
    {
        $shouldUpdateCustomer = $true
    }
    if ($Delete)
    {
        $shouldDeleteCustomer = $true
    }
    if (($CreateNoUpdate -and $Create) -or (($CreateNoUpdate -and $Update))) 
    {
        throw "Invalid parameters was passed. createCustomerNoUpdate cannot be combinated with createCustomer or updateCustomer"
    }
    if ($CreateNoUpdate -and $Create -and $Update -and -$Delete) 
    {
        throw "Invalid parameters was passed. delete cannot be combinated with create or update or createNoUpdate"
    }
}

#This flag is to detemine if powerBI report should be deleted.
[bool] $shouldDeletePowerBIReport = $false
if($PowerBIReportsToDeleteNames -ne $null)
{
    $shouldDeletePowerBIReport = $true
}

[PSObject] $proxy = [System.Net.WebRequest]::GetSystemWebProxy()
if ($proxy)
{
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
[string] $csrfToken = $null

$Identities = @{
    "SuperAdmin" = @{
        "ID" = $SuperAdminClientId;
        "SECRET" = $SuperAdminClientSecret
    };
}

[Microsoft.PowerShell.Commands.WebRequestSession] $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession

[PSObject] $oldCertPolicy = [System.Net.ServicePointManager]::CertificatePolicy
if ($server.AbsoluteUri.StartsWith('https://localhost'))
{
    Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): Turning off security for localhost connection"
    
    if (-not ([System.Management.Automation.PSTypeName]'TrustAllCertsPolicy').Type)
    {
        Add-Type @"
                    using System.Net;
                    using System.Security.Cryptography.X509Certificates;
                    public class TrustAllCertsPolicy : ICertificatePolicy
                    {
                        public bool CheckValidationResult(ServicePoint srvPoint, X509Certificate certificate, WebRequest request, int certificateProblem)
                        {
                            return true;
                        }
                    }
"@
    }
    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
}

#endregion Preparation steps

#region Customer function
function ConvertTo-UrlEncoded {
    [CmdletBinding(PositionalBinding=$true)]
    [OutputType([string])]
    param (
        [parameter(position=0,Mandatory=$true)]
        [AllowEmptyString()]
        [ValidateNotNull()]
            [string]$Text
    )
    return [System.Uri]::EscapeDataString($Text)
}

function LoadCustomer
{
    [CmdletBinding(PositionalBinding=$false)]
    param()

    Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): ------------------"
    Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): --> Start: Load customer:"
    [PSObject] $entry = $null
    (& "CommonScripts\LoadDataFile" -path ([System.IO.Path]::Combine('Customers', "${script:Customer}.json")) -output_obj ([ref]$entry))

    if ($entry -eq $null) 
    {
        throw "Customer file ${script:Customer} does not exist or is empty."
    }
    Write-Verbose "$([DateTime]::Now.ToString("HH\:mm\:ss")): Read entry of type $($entry.GetType().FullName)"
    if ($entry -isnot [System.Collections.Generic.Dictionary[string,object]]) 
    {
        throw "Customer file ${script:Customer} does not contain a correct structure."
    }
    [System.Collections.Generic.Dictionary[string,object]] $dict = $entry

    $script:customerData = $entry

    Try
    {
        if ($dict.ContainsKey('InternalName')) 
        {
            $script:customerId = $entry['InternalName']
        }
        else 
        {
            $script:customerId = $null
        }
    }
    Catch
    {
        $script:wasError = $true
        $script:lastError = $_.Exception.Message
        Write-Warning "$([DateTime]::Now.ToString("HH\:mm\:ss")): $($_.Exception.Message)"
        $script:customerData = $null
        $script:customerId = $null
    }

    if ([string]::IsNullOrWhiteSpace($script:customerId))
    {
        throw "InternalName value is missing from customer data (it's required for all customer-based operations)."
    }
    else 
    {
        Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): Loaded customer: ${script:customerId}"
    }
    Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")):  --> Finished: $($script:stepName)."
}

function MyCustomerExists
{
    [CmdletBinding(PositionalBinding=$false)]
    param()

    $script:stepName = 'Verifying customer existence'
    $script:stepNumber++
    Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): ------------------"
    Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): ${script:stepNumber}. ${script:stepName} ..."
    Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): --> Start: ${script:stepName}:"

    if ($script:customerData -eq $null) {
        throw "Customer data was not loaded."
    }

    [PSObject] $entry = $null

    Try
    {
        $entry = (& "CommonScripts\Invoke-RestMethodEasily" `
            -Server $script:Server `
            -Session $script:session `
            -Identities $Identities `
            -AuthorizationLevel 'SuperAdmin' `
            -Authority $Authority `
            -AadApplicationId $AadApplicationId `
            -Uri '/api/Customer/Retrieve' `
            -Method Get `
            -NoContent `
            -WarningAction Stop `
            -TimeoutSec 90 `
            -ErrorAction Stop)
        if ($entry -eq $null)
        {
            Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): Received empty response."
            $entry = @()
        }
        if (($entry -isnot [string]) -and ($entry -isnot [array]))
        {
            throw "Invalid response structure ($($entry.GetType().FullName))."
        }
        [string[]] $arr = ($entry)
        if ($script:customerId -notin $arr)
        {
            Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): Customer ${script:customerId} not found."
            if ($script:Create -or $script:CreateNoUpdate) {
                $script:shouldUpdateCustomer = $false
            }
        }
        else
        {
            Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): Customer found."
            if ($script:Update) {
                $script:shouldCreateCustomer = $false
            }
            if ($script:CreateNoUpdate){
                $script:shouldCreateCustomer = $false
                $script:shouldUpdateCustomer = $false
            }
            $entry = (& "CommonScripts\Invoke-RestMethodEasily" `
                -Server $script:Server `
                -Session $script:session `
                -Identities $Identities `
                -AuthorizationLevel 'SuperAdmin' `
                -Authority $Authority `
                -AadApplicationId $AadApplicationId `
                -Uri "/api/Customer/Retrieve/$(ConvertTo-UrlEncoded $script:customerId)/" `
                -Method Get `
                -NoContent `
                -WarningAction Stop `
                -ErrorAction Stop)
            if ($entry -eq $null)
            {
                throw 'Could not retrieve customer''s configuration.'
            }
            Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): Customer data:"
            ConvertTo-Json -InputObject $entry -Depth 100
            Write-Output ''
        }
    }
    Catch
    {
        $script:wasError = $true
        $script:lastError = $_.Exception.Message + "(in step $($script:stepName))"
        Write-Error "$([DateTime]::Now.ToString("HH\:mm\:ss")): $($_.Exception.Message)"
    }
    Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")):  --> Finished: $($script:stepName)."
}

function CreateCustomer
{
    [CmdletBinding(PositionalBinding=$false)]
    param()

    $script:stepName = 'Create customer'
    $script:stepNumber++
    Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): ------------------"
    Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): ${script:stepNumber}. ${script:stepName} ..."
    Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): --> Start: ${script:stepName}:"

    if ($script:customerData -eq $null) {
        throw "Customer data was not loaded."
    }

    Try
    {
        [psobject] $result = (& "CommonScripts\Invoke-RestMethodEasily" `
            -Server $script:Server `
            -Session $script:session `
            -Identities $Identities `
            -AuthorizationLevel 'SuperAdmin' `
            -Authority $Authority `
            -AadApplicationId $AadApplicationId `
            -Uri '/api/Customer/Add' `
            -Method Post `
            -Entry $script:customerData `
            -TimeoutSec 900 `
            -WarningAction Stop `
            -ErrorAction Stop)
    }
    Catch
    {
        $script:wasError = $true
        $script:lastError = $_.Exception.Message + "(in step $($script:stepName))"
        Write-Error "$([DateTime]::Now.ToString("HH\:mm\:ss")): $($_.Exception.Message)"
    }
    Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")):  --> Finished: $($script:stepName)."
}

function UpdateCustomer
{
    [CmdletBinding(PositionalBinding=$false)]
    param()

    $script:stepName = 'Update customer'
    $script:stepNumber++
    Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): ------------------"
    Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): ${script:stepNumber}. ${script:stepName} ..."
    Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): --> Start: ${script:stepName}:"

    if ($script:customerData -eq $null) {
        throw "Customer data was not loaded."
    }

    Try
    {
        [psobject] $result = (& "CommonScripts\Invoke-RestMethodEasily" `
            -Server $script:Server `
            -Session $script:session `
            -Identities $Identities `
            -AuthorizationLevel 'SuperAdmin' `
            -Authority $Authority `
            -AadApplicationId $AadApplicationId `
            -Uri '/api/Customer/Update' `
            -Method Post `
            -Entry $script:customerData `
            -WarningAction Stop `
            -ErrorAction Stop)
        if ($result -ne $null)
        {
            Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): New customer data:"
            ConvertTo-Json -InputObject $result -Depth 100
            Write-Output ''
        }
    }
    Catch
    {
        $script:wasError = $true
        $script:lastError = $_.Exception.Message + "(in step $($script:stepName))"
        Write-Error "$([DateTime]::Now.ToString("HH\:mm\:ss")): $($_.Exception.Message)"
    }
    Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")):  --> Finished: $($script:stepName)."
}

function DeleteCustomer
{
    [CmdletBinding(PositionalBinding=$false)]
    param()

    $script:stepName = 'Delete customer'
    $script:stepNumber++
    Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): ------------------"
    Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): ${script:stepNumber}. ${script:stepName} ..."
    Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): --> Start: ${script:stepName}:"

    if ($script:customerData -eq $null) {
        throw "Customer data was not loaded."
    }

    Try
    {
        [psobject] $result = (& "CommonScripts\Invoke-RestMethodEasily" `
            -Server $script:Server `
            -Session $script:session `
            -Identities $Identities `
            -AuthorizationLevel 'SuperAdmin' `
            -Authority $Authority `
            -AadApplicationId $AadApplicationId `
            -Uri "/api/Customer/Delete/$($script:customerData.InternalName)/" `
            -Method Delete `
            -NoContent `
            -WarningAction Stop `
            -ErrorAction Stop)
        if ($result -ne $null)
        {
            Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): New customer data:"
            ConvertTo-Json -InputObject $result -Depth 100
            Write-Output ''
        }
    }
    Catch
    {
        $script:wasError = $true
        $script:lastError = $_.Exception.Message + "(in step $($script:stepName))"
        Write-Error "$([DateTime]::Now.ToString("HH\:mm\:ss")): $($_.Exception.Message)"
    }
    Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")):  --> Finished: $($script:stepName)."
}

#endregion Customer function

function DeletePowerBI
{
    [CmdletBinding(PositionalBinding=$false)]
    param()

    $script:stepName = 'Delete PowerBi reports'
    $script:stepNumber++
    Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): ------------------"
    Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): ${script:stepNumber}. ${script:stepName} ..."
    Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): --> Start: ${script:stepName}:"

    ForEach($reportName in $PowerBIReportsToDeleteNames)
    {
        Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): --> Deleting $($reportName)"

        Try
        {
            [PSObject] $result = (& "CommonScripts\Invoke-RestMethodEasily" `
                -Server $script:Server `
                -Session $script:session `
                -Identities $Identities `
                -AuthorizationLevel 'SuperAdmin' `
                -Authority $Authority `
                -AadApplicationId $AadApplicationId `
                -Method Delete `
                -Uri "/api/Reports/Standard/$reportName/Delete" `
                -TimeoutSec 900 `
                -NoContent)
            Write-Verbose "$([DateTime]::Now.ToString("HH\:mm\:ss")): Result:"
            Write-Verbose $result
        }
        Catch
        {
            $script:wasError = $true
            $script:lastError = $_.Exception.Message + "(in step $($script:stepName))"
            Write-Warning "$([DateTime]::Now.ToString("HH\:mm\:ss")): $($_.Exception.Message)"
        }
        Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")):  --> Finished deleting: $($reportName)."
    }
        Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")):  --> Finished: $($script:stepName)."
}

function PopulatePowerBIs
{
    [CmdletBinding(PositionalBinding=$false)]
    param()

    $script:stepName = 'Populate PowerBi reports'
    $script:stepNumber++
    Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): ------------------"
    Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): ${script:stepNumber}. ${script:stepName} ..."
    Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): --> Start: ${script:stepName}:"

    [string] $reportsPath = "..\PowerBIReports"
    [array] $allFiles = @()

    if (Test-Path $reportsPath -PathType Container) 
    {
        $allFiles += @(Get-ChildItem -Path $reportsPath -Recurse -Include "*.pbix","*.pbit")
    }
    
    if (($script:MaxLimit -ne 0) -and ($allFiles.Length -gt $script:MaxLimit)) 
    {
        $allFiles = $allFiles[0..($script:MaxLimit-1)]
    }

    if ($allFiles.Length -le 0) 
    {
        Write-Output "$([DateTime]::Now.ToString("HH\:mm\:ss")): WARNING: NO FILES FOUND"
    }
    else {
        $allFiles | Foreach-Object {
            Try
            {
                [byte[]] $fileContentBytes = [io.file]::ReadAllBytes($_.FullName)
                [string] $fileContentBase64 = [System.Convert]::ToBase64String($fileContentBytes)
                $fileContentBytes.Clear()
                $fileContentBytes = $null

                [hashtable]$data = @{
                    'ReportName' = $_.Name
                    'FileByteData' = $fileContentBase64
                }
                [void] (& "CommonScripts\Invoke-RestMethodEasily" `
                    -Server $script:Server `
                    -Session $script:session `
                    -Identities $Identities `
                    -AuthorizationLevel 'SuperAdmin' `
                    -Authority $Authority `
                    -AadApplicationId $AadApplicationId `
                    -Uri "/api/Import/PowerBIReport/$(ConvertTo-UrlEncoded $script:customerId)/" `
                    -TimeoutSec 900 `
                    -Entry $data)
            }
            Catch
            {
                $script:wasError = $true
                $script:lastError = $_.Exception.Message + "(in step $($script:stepName))"
                Write-Warning "$([DateTime]::Now.ToString("HH\:mm\:ss")): $($_.Exception.Message)"
            }
        }
    }

    Write-Output  "$([DateTime]::Now.ToString("HH\:mm\:ss")):  --> Finished: $($script:stepName)."
}


#region Main code
Push-Location ((Get-Item -LiteralPath ($script:MyInvocation.MyCommand.Path)).Directory.FullName)
Try
{
    LoadCustomer

    MyCustomerExists -WarningAction Stop -ErrorAction Stop

    if ($shouldCreateCustomer)
    {
        CreateCustomer -WarningAction Stop -ErrorAction Stop
    }

    if ($shouldUpdateCustomer)
    {
        UpdateCustomer -WarningAction Stop -ErrorAction Stop
    }

    if ($shouldDeleteCustomer)
    {
        DeleteCustomer -WarningAction Stop -ErrorAction Stop
    }

    if ($PowerBIs)
    {
        PopulatePowerBIs
    }

    if($shouldDeletePowerBIReport)
    {
        DeletePowerBI
    }

    if ($wasError) {
        Write-Error "$([DateTime]::Now.ToString("HH\:mm\:ss")): There were errors. Last one: $lastError"
    } 
    elseif ($stepNumber -eq 0) {
        Write-Warning "$([DateTime]::Now.ToString("HH\:mm\:ss")): No Customer steps were actually executed"
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

#endregion Main code