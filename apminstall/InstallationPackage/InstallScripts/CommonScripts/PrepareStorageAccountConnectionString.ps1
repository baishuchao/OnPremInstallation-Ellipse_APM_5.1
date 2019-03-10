#Requires -Version 4.0
[CmdletBinding(
    PositionalBinding = $false,
    DefaultParameterSetName = 'FromEntry'
)]
Param(
    [Parameter(
        Mandatory = $true,
        HelpMessage = 'Resource group name'
    )]
    [ValidateNotNullOrEmpty()]
    [string] $ResourceGroupName,
    
    [parameter(
        Mandatory = $true,
        HelpMessage = 'Web site name'
    )]
    [ValidateNotNullOrEmpty()]
    [String]$WebSiteName
)
[string] $storagename = 'storage' + $WebsiteName.Replace('-', '')
[Microsoft.Azure.Management.Storage.Models.StorageAccountKey[]] $output = (Get-AzureRmStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $storagename)
[string] $key = $output[0].Value
Write-Output "DefaultEndpointsProtocol=https;AccountName=$storagename;AccountKey=$key;EndpointSuffix=core.windows.net"