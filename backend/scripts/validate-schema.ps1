param(
    [string]$SqlServer = 'localhost\MSSQLSERVER01'
)

$ErrorActionPreference = 'Stop'
$workspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$databaseName = 'SosyoBelSchemaValidation_' + [Guid]::NewGuid().ToString('N')
$connection = $null
$created = $false

$scripts = @(
    'database\migrations\000_create_aspnet_identity_schema.sql',
    'database\migrations\001_create_sosyobel_v2_schema.sql',
    'database\migrations\002_create_municipality_integrations.sql',
    'database\migrations\003_create_access_control_and_audit.sql',
    'database\migrations\004_harden_identity_tasks_and_idempotency.sql',
    'database\seed\001_confirmed_reference_data.sql',
    'database\checks\000_verify_aspnet_identity.sql',
    'database\checks\001_verify_sosyobel_v2.sql',
    'database\checks\002_verify_municipality_integrations.sql',
    'database\checks\003_verify_access_control_and_audit.sql',
    'database\checks\004_verify_identity_tasks_and_idempotency.sql'
)

function Invoke-CommandText([string]$commandText) {
    $command = $connection.CreateCommand()
    try {
        $command.CommandTimeout = 60
        $command.CommandText = $commandText
        $null = $command.ExecuteNonQuery()
    }
    finally {
        $command.Dispose()
    }
}

try {
    # Tek açık bağlantı kullanılır. Kararsız yerel instance'ta her SQL dosyası
    # için yeniden login açılmasının oluşturduğu zaman aşımı böylece önlenir.
    $connectionString = "Server=$SqlServer;Database=master;Integrated Security=True;Encrypt=True;TrustServerCertificate=True;Connect Timeout=15"
    $connection = New-Object System.Data.SqlClient.SqlConnection $connectionString
    $connection.Open()

    $existsCommand = $connection.CreateCommand()
    try {
        $existsCommand.CommandText = 'SELECT CASE WHEN DB_ID(@name) IS NULL THEN 0 ELSE 1 END;'
        $null = $existsCommand.Parameters.Add('@name', [Data.SqlDbType]::NVarChar, 128)
        $existsCommand.Parameters['@name'].Value = $databaseName
        if ([int]$existsCommand.ExecuteScalar() -ne 0) {
            throw "Geçici doğrulama veritabanı zaten var: $databaseName"
        }
    }
    finally {
        $existsCommand.Dispose()
    }

    Invoke-CommandText "CREATE DATABASE [$databaseName];"
    $created = $true
    $connection.ChangeDatabase($databaseName)

    foreach ($relativePath in $scripts) {
        Write-Output "RUN $relativePath"
        $absolutePath = Join-Path $workspaceRoot $relativePath
        $sql = [IO.File]::ReadAllText($absolutePath)
        Invoke-CommandText $sql
    }

    Write-Output "SCHEMA_VALIDATION_OK $databaseName"
}
finally {
    if ($null -ne $connection) {
        try {
            if ($created -and $connection.State -eq [Data.ConnectionState]::Open) {
                $connection.ChangeDatabase('master')
                Invoke-CommandText "ALTER DATABASE [$databaseName] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$databaseName];"
                Write-Output "REMOVED $databaseName"
            }
        }
        finally {
            $connection.Dispose()
        }
    }
}
