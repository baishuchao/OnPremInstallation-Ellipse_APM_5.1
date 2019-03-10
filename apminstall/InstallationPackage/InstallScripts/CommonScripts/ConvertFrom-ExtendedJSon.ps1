[CmdletBinding(
    PositionalBinding = $true,
    DefaultParameterSetName = 'FromString'
)]
[OutputType([PSCustomObject])]
param (
    [Parameter(
        position = 0,
        Mandatory = $true,
        ValueFromPipeline = $true,
        ParameterSetName = 'FromString',
        HelpMessage = 'Give a String, containing valid JSON.'
    )]
    [ValidateNotNullOrEmpty()]
    [string]$JSonText,

    [Parameter(
        position = 0,
        Mandatory = $true,
        ParameterSetName = 'FromFile',
        HelpMessage = 'Give a literal path to a file, containing valid JSON.'
    )]
    [ValidateNotNullOrEmpty()]
    [string]$LiteralPath,

    [Parameter(
        position = 1,
        Mandatory = $false,
        HelpMessage = 'Indicates if JSON is allowed to contain comments.'
    )]
    [bool]$AllowComments = $true
)

[void][System.Reflection.Assembly]::LoadWithPartialName('System.Web.Extensions')
[PSObject] $json = New-Object -TypeName System.Web.Script.Serialization.JavaScriptSerializer
$json.MaxJsonLength = 2147483647
$json.RecursionLimit = 999

[string] $content = ''
$ErrorActionPreference = "Stop"
switch ($PSCmdlet.ParameterSetName) {
    'FromString' {
        if (($JSonText -eq $null) -or ($JSonText -eq '')) {
            return $null
        }
        $content = $JSonText
    }
    'FromFile' {
        $content = (Get-Content `
                -LiteralPath $LiteralPath `
                -Raw `
                -Encoding UTF8 `
                -ErrorAction Stop `
        )
    }
}
if ($AllowComments) {
    Write-Debug 'JSON content prior to comment removal:'
    Write-Debug $content
    $content = ($content -replace '("(?:[^"\n\\]+|\\.)*")|\/\/.*|/\*(?s:.*?)\*/', '$1')
}
Write-Debug 'JSON content:'
Write-Debug $content
#ConvertFrom-JSON -InputObject $content -ErrorAction Stop # 2MB limitation
$script:json.Deserialize($content, [System.Object])