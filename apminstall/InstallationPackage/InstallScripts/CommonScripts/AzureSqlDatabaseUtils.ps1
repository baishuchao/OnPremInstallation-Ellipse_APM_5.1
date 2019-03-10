function Get-SqlServerLocation {
    [OutputType([string])]
    [CmdletBinding(PositionalBinding = $false)]

    Param(
        [Parameter(
            Mandatory = $true,
            HelpMessage = 'Resource group name'
        )]
        [ValidateNotNullOrEmpty()]
        [string] $ResourceGroupName,

        [Parameter(
            Mandatory = $true,
            HelpMessage = 'Server name'
        )]
        [ValidateNotNullOrEmpty()]
        [string] $ServerName
    )

    [Microsoft.Azure.Commands.Sql.Server.Model.AzureSqlServerModel] $outputs = (Get-AzureRmSqlServer -ResourceGroupName $ResourceGroupName -ServerName $ServerName)

    if ([string]::IsNullOrEmpty($outputs.Location)) {
        Write-Error "Database server location not found"
    }
    
    return $outputs.Location
}

function Get-ResourceGroupLocation {
    [OutputType([string])]
    [CmdletBinding(PositionalBinding = $false)]

    Param(
        [Parameter(
            Mandatory = $true,
            HelpMessage = 'Resource group name'
        )]
        [ValidateNotNullOrEmpty()]
        [string] $ResourceGroupName
    )
     
    $outputs = (Get-AzureRmResourceGroup -ResourceGroupName $ResourceGroupName)

    if ([string]::IsNullOrEmpty($outputs)) {
        Write-Error "Resource group location not found"
    }
    
    return $outputs.Location
}