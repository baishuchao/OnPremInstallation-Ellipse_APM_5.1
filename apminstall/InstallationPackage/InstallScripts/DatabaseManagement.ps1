[CmdletBinding(PositionalBinding = $false)]
Param(
    [Parameter(
        Mandatory = $true,
        HelpMessage = "Path to Database Management tool dll"
    )]
    [ValidateScript( {Test-Path $_})]
    [string] $DatabaseToolPath,

    [Parameter(
        Mandatory = $true,
        HelpMessage = "Sql connection string - with initial catalog specified"
    )]
    [ValidateNotNullOrEmpty()]
    [string] $SqlConnectionString,

    [parameter(
        Mandatory = $true,
        HelpMessage = 'Customer file name for which the data will be imported.'
    )]
    [ValidateNotNullOrEmpty()]
    [string]$Customer,

    [Parameter(
        Mandatory = $false,
        HelpMessage = "Choose action that should be done on database, available options update (which also creates database if it doesn't exist, or delete"
    )]
    [ValidateSet('update', 'delete')]
    [string] $databaseAction = "update"
)

function DeleteCreatedTempFiles {
    if (Test-Path $databaseConfigPath) {
        Remove-Item -Path $databaseConfigPath    -ErrorAction SilentlyContinue -WarningAction SilentlyContinue -Force
    }
}

Push-Location ((Get-Item -LiteralPath ($script:MyInvocation.MyCommand.Path)).Directory.FullName)
Try {
    Write-Verbose "Creating temporary database schema file"
    $databaseConfigPath = New-TemporaryFile
    Write-Verbose "Output file is: $databaseConfigPath"
    Write-Verbose "Temporary file created"

	[string] $internalName = (&".\CommonScripts\Get-InternalName" -Customer $Customer)
	[string] $ahcDatabaseName = "AHC-$internalName"
	[string] $SqlConnectionStringWithCatalog = (&".\CommonScripts\AddInitialCatalog-SqlConnectionString" -SqlConnectionString $SqlConnectionString -DatabaseName $ahcDatabaseName)
	[string] $reportSchemaUserPassword = (&".\CommonScripts\Get-ReportSchemaUserPassword" -Customer $Customer)

	Write-Verbose "ahcDatabaseName: $ahcDatabaseName"

    $customerConfigJson = @{
        SqlConnectionString      = $SqlConnectionStringWithCatalog
        ReportSchemeUserName     = $internalName
        ReportSchemeUserPassword = $reportSchemaUserPassword
    }

    $customerConfigJson | ConvertTo-Json -depth 100 | Out-File $databaseConfigPath
    Push-Location $DatabaseToolPath
    [Environment]::CurrentDirectory = get-Location
    if ($databaseAction -eq "update") {
        & "dotnet" @("ABB.APM.DatabaseManagementTool.App.dll", "-up-db-f", $databaseConfigPath)
    }
    elseif ($databaseAction -eq 'delete') {
        & "dotnet" @("ABB.APM.DatabaseManagementTool.App.dll", "-d-db-f", $databaseConfigPath)
    }
    Pop-Location
}
Finally {
    DeleteCreatedTempFiles
    Pop-Location
}