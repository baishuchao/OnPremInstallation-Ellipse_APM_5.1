#Requires -Version 4.0
[CmdletBinding(
    PositionalBinding = $false,
    DefaultParameterSetName = 'FromEntry'
)]
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
    [Uri]$Server,

    [parameter(
        position = 1,
        Mandatory = $true
    )]
    [Microsoft.PowerShell.Commands.WebRequestSession]$session,

    #Identities for token auth 
    [parameter(
        Position = 2,
        Mandatory = $true,
        HelpMessage = 'Identities'
    )]
    [hashtable]$Identities,

    #Authorization level for token and user auth
    [parameter(
        position = 3,
        Mandatory = $false
    )]
    [String]$AuthorizationLevel = "SuperAdmin",
        
    # AAD Authentication parameters
    [parameter(
        position = 4,
        Mandatory = $true,
        HelpMessage = 'ActiveDirectory authority URI'
    )]
    [Uri]$Authority,

    [parameter(
        position = 5,
        Mandatory = $true,
        HelpMessage = 'Resource application Id'
    )]
    [String]$AadApplicationId,

    [parameter(
        position = 6,
        Mandatory = $true,
        HelpMessage = 'Give a String, containing WebAPI URI (URL).'
    )]
    [ValidateNotNull()]
    [Uri]$Uri,

    [parameter(
        position = 7,
        Mandatory = $false,
        HelpMessage = 'Indicate HTTP method for the request (PUT is default).'
    )]
    [Microsoft.PowerShell.Commands.WebRequestMethod]$Method = [Microsoft.PowerShell.Commands.WebRequestMethod]::Put,

    [parameter(
        position = 8,
        Mandatory = $false,
        ParameterSetName = 'FromBytes'
    )]
    [string]$ContentType,

    [parameter(
        position = 9,
        Mandatory = $false,
        ParameterSetName = 'FromBytes'
    )]
    [byte[]]$Bytes,

    [parameter(
        position = 10,
        Mandatory = $true,
        ParameterSetName = 'FromEntry'
    )]
    [object]$Entry,

    [parameter(
        position = 11,
        Mandatory = $true,
        ParameterSetName = 'FromJson'
    )]
    [object]$Json,

    [parameter(
        position = 12,
        Mandatory = $false,
        ParameterSetName = 'NoContent'
    )]
    [switch]$NoContent,

    [parameter(
        position = 13,
        Mandatory = $false
    )]
    [int]$TimeoutSec = 30,
    [parameter(
        position = 14,
        Mandatory = $false
    )]
    [switch]$SendCsrfToken,

    [parameter(
        position = 15,
        Mandatory = $false
    )]
    [PSObject]$Proxy
)

[PSObject] $encoding = [System.Text.Encoding]::UTF8

$ssl3 = [System.Net.SecurityProtocolType]48
$tls11 = [System.Net.SecurityProtocolType]768
$tls12 = [System.Net.SecurityProtocolType]3072

try {
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor $tls11
}
catch {
    Write-Debug "Could not add TLS 1.1 to .net security protocol settings: $($_.Exception.Message)"
}
try {
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor $tls12
}
catch {
    Write-Debug "Could not add TLS 1.2 to .net security protocol settings: $($_.Exception.Message)"
}
try {
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -band (-bnot $ssl3)
}
catch {
    Write-Debug "Could not remove SSL from .net security protocol settings: $($_.Exception.Message)"
}

[hashtable] $headers = @{
    'Accept' = 'application/json,text/x-json;q=0.9,text/x-javascript;q=0.9,text/javascript;q=0.9,application/x-javascript;q=0.9,text/html;q=0.3,text/*;q=0.2,*/*;q=0.1'
}

if (    [string]::IsNullOrWhiteSpace($Authority) -or
    [string]::IsNullOrWhiteSpace($AadApplicationId)) {
    throw "Invalid credentials data for authentication with token: DirectoryId or ApplicationId is missing"
}
# Add AAD authorization Token
$clientId = $Identities[$AuthorizationLevel]["ID"]
$clientKey = $Identities[$AuthorizationLevel]["SECRET"]

if (    [string]::IsNullOrWhiteSpace($clientId) -or
    [string]::IsNullOrWhiteSpace($clientKey)) {
    throw "Invalid credentials data for authentication with token: clientId or clientKey for $AuthorizationLevel authorization level is missing"
}

$token = (& "$PSScriptRoot\GetAuthenticationToken" `
        -clientId $clientId `
        -clientKey $clientKey `
        -resourceAppId $AadApplicationId `
        -authority $Authority)
$headers.Add('Authorization', 'Bearer ' + $token.AccessToken)

Write-Verbose "$([DateTime]::Now.ToString("HH\:mm\:ss")): Using auth token to authenticate"


[byte[]] $body = @()

[hashtable] $invokeParams = @{}

switch ($PSCmdlet.ParameterSetName) {
    'FromEntry' {
        Write-Verbose "$([DateTime]::Now.ToString("HH\:mm\:ss")): FromEntry of type:"
        if ($Entry -eq $null) {
            Write-Verbose "$([DateTime]::Now.ToString("HH\:mm\:ss")): null"
        }
        else {
            Write-Verbose "$([DateTime]::Now.ToString("HH\:mm\:ss")): $($Entry.GetType().FullName)"
        }
        $invokeParams.Add( 'ContentType', 'application/json; charset=utf-8' )
        [string] $entryJson = (ConvertTo-Json -Depth 100 -Compress -InputObject $Entry)
        Write-Debug "$([DateTime]::Now.ToString("HH\:mm\:ss")): Entry json:"
        Write-Debug $entryJson
        $body = ($encoding.GetBytes($entryJson))
        $invokeParams.Add( 'Body', $body )
    }
    'FromJson' {
        Write-Verbose "$([DateTime]::Now.ToString("HH\:mm\:ss")): FromJson"
        Write-Debug $Json
        $invokeParams.Add( 'ContentType', 'application/json; charset=utf-8' )
        $body = ($encoding.GetBytes($Json))
        $invokeParams.Add( 'Body', $body )
    }
    'FromBytes' {
        Write-Verbose "$([DateTime]::Now.ToString("HH\:mm\:ss")): FromBytes of ContentType: $ContentType"
        $invokeParams.Add( 'ContentType', $ContentType )
        $body = $Bytes
        $invokeParams.Add( 'Body', $body )
    }
    'NoContent' {
        if (!$NoContent) {
            throw 'The NoContent parameter can''t be set to $false'
        }
        Write-Verbose "$([DateTime]::Now.ToString("HH\:mm\:ss")): NoContent"
        #$invokeParams.Add( 'Body', $body )
    }
}

if ($TimeoutSec -le 0) {
    $TimeoutSec = 30
}

[Uri] $destinationUri = $Uri
if (!$destinationUri.IsAbsoluteUri) {
    $destinationUri = (New-Object `
            -TypeName System.Uri `
            -ArgumentList $Server, $Uri
    )
}

if ($Proxy) {
    [Uri] $proxyUri = $Proxy.GetProxy($destinationUri)
    Write-Verbose "$([DateTime]::Now.ToString("HH\:mm\:ss")): proxyUri: $($proxyUri.AbsoluteUri)"
    if (!$proxyUri.Equals($destinationUri.AbsoluteUri)) {
        Write-Verbose "$([DateTime]::Now.ToString("HH\:mm\:ss")): Using proxy"
        $invokeParams.Add( 'Proxy', $proxyUri.AbsoluteUri )
        $invokeParams.Add( 'ProxyUseDefaultCredentials', $true )
    }
}

if ($SendCsrfToken) {
    if ([string]::IsNullOrEmpty($script:csrfToken)) {
        $script:csrfToken = [Guid]::NewGuid().ToString()
    }

    # cookie
    [System.Net.Cookie] $cookie = New-Object System.Net.Cookie
    $cookie.Name = 'X-Csrf-Token'
    $cookie.Path = $destinationUri.AbsolutePath
    $cookie.Value = $csrfToken
    $cookie.Domain = $destinationUri.Host
    $session.Cookies.Add($cookie)

    # header
    $headers.Add( 'X-Csrf-Token', $csrfToken )
}

[PSObject] $result = $null
try {
    $result = (Invoke-RestMethod `
            -Uri $destinationUri `
            -Method $Method `
            -TimeoutSec $TimeoutSec `
            -Headers $headers `
            -WebSession $session `
            -WarningAction Stop `
            -ErrorAction Stop `
            @invokeParams)
    if ($result -ne $null) {
        if ($result -is [string]) {
            if ($result.Trim() -ne '') {
                Write-Verbose "$([DateTime]::Now.ToString("HH\:mm\:ss")): Result (string): $($result.Trim())"
            }
            else {
                Write-Verbose "$([DateTime]::Now.ToString("HH\:mm\:ss")): Result (string) is empty"
            }
        }
        elseif ($result -is [Microsoft.PowerShell.Commands.WebResponseObject]) {
            Write-Verbose "$([DateTime]::Now.ToString("HH\:mm\:ss")): Result (WebResponseObject) StatusCode: $($result.StatusCode.value__)"
            Write-Verbose "$([DateTime]::Now.ToString("HH\:mm\:ss")): Result (WebResponseObject) StatusDescription: $($result.StatusDescription)"
            Write-Verbose "$([DateTime]::Now.ToString("HH\:mm\:ss")): Result (WebResponseObject) Content:"
            Write-Verbose $result.Content
        }
        else {
            Write-Verbose "$([DateTime]::Now.ToString("HH\:mm\:ss")): Result (other: $($result.GetType().FullName)):"
            Write-Verbose (ConvertTo-Json -Depth 100 -Compress -InputObject $result)
        }
    }
    else {
        Write-Verbose "$([DateTime]::Now.ToString("HH\:mm\:ss")): Result is null"
    }
}
catch {
    Write-Verbose "$([DateTime]::Now.ToString("HH\:mm\:ss")): Caught exception"
    $script:wasError = $true
    [string] $errMsg
    if (($_ -ne $null) -and ($_.Exception -ne $null) -and ($_.Exception.Message -ne $null)) {
        $errMsg = $_.Exception.Message
    }
    elseif ($_ -ne $null) {
        $errMsg = $_.ToString()
    }
    else {
        $errMsg = '<Unknown error>'
    }
    $script:lastError = "$errMsg (in step $($script:stepName))"
    Write-Warning "$([DateTime]::Now.ToString("HH\:mm\:ss")): $errMsg"
    if (($_ -ne $null) -and ($_.Exception -ne $null) -and ($_.Exception.Response -ne $null)) {
        $result = $_.Exception.Response.GetResponseStream()
        [PSObject] $reader = New-Object System.IO.StreamReader($result)
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        [PSObject] $responseBody = $reader.ReadToEnd()
        if ($responseBody -ne $null) {
            if ($responseBody -is [string]) {
                if ($responseBody.Trim() -ne '') {
                    Write-Warning "$([DateTime]::Now.ToString("HH\:mm\:ss")): Result: $($responseBody.Trim())"
                }
            }
            else {
                Write-Verbose "$([DateTime]::Now.ToString("HH\:mm\:ss")): Result (other):"
                Write-Verbose (ConvertTo-Json -Depth 100 -Compress -InputObject $responseBody)
            }
        }
        $result = $null
    }
    else {
        $result = $null
    }
}
return $result