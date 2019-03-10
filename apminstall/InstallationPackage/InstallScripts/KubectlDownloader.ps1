[CmdletBinding(PositionalBinding=$false)]
Param(
    [Parameter(
        Mandatory = $true,
        HelpMessage = 'Localization for downloaded kubectl.exe'
    )]
        [string] $downloadLocation,
    [Parameter(
        Mandatory = $false,
        HelpMessage = 'Version of kubectl'
    )]
        [string] $kubectlReleaseVersion = 'latest'
)

function GetLatestVersion {
    [OutputType([string])]
    $getLatestReleaseVersion = Invoke-WebRequest "https://storage.googleapis.com/kubernetes-release/release/stable.txt" -UseBasicParsing
    return $getLatestReleaseVersion.Content.replace("`n", "")
}

Push-Location -LiteralPath $PSScriptRoot 

Try {

    $releaseVersion = $kubectlReleaseVersion
    if($kubectlReleaseVersion -eq 'latest')
    {
        $releaseVersion = GetLatestVersion
        Write-Output "Latest version of kubectl is $releaseVersion"
    }

    $downloadfile = Join-Path $downloadLocation "kubectl.exe"
    $uri = "http://storage.googleapis.com/kubernetes-release/release/$releaseVersion/bin/windows/amd64/kubectl.exe"
    Write-Output 'Invoke web request...'
    $req = Invoke-WebRequest -UseBasicParsing -Uri $uri -Outfile $downloadfile
    Write-Output "You can now start kubectl from $downloadfile ($releaseVersion)"
}
Finally {
    Pop-Location
}