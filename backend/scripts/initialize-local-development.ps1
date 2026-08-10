param(
    [string]$SqlServer = 'localhost',
    [string]$DatabaseName = 'SosyoBel'
)

$ErrorActionPreference = 'Stop'
$workspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$connection = $null
$createdDatabase = $false

$migrationFiles = @(
    'database\migrations\000_create_aspnet_identity_schema.sql',
    'database\migrations\001_create_sosyobel_v2_schema.sql',
    'database\migrations\002_create_municipality_integrations.sql',
    'database\migrations\003_create_access_control_and_audit.sql',
    'database\migrations\004_harden_identity_tasks_and_idempotency.sql',
    'database\migrations\005_create_application_number_sequence.sql',
    'database\seed\001_confirmed_reference_data.sql',
    'database\seed\002_development_form_options.sql',
    'database\seed\003_development_household_options.sql'
)

$checkFiles = @(
    'database\checks\000_verify_aspnet_identity.sql',
    'database\checks\001_verify_sosyobel_v2.sql',
    'database\checks\002_verify_municipality_integrations.sql',
    'database\checks\003_verify_access_control_and_audit.sql',
    'database\checks\004_verify_identity_tasks_and_idempotency.sql',
    'database\checks\005_verify_application_lifecycle.sql'
)

function Test-LocalSqlServer([string]$serverName) {
    $normalized = $serverName.Trim().ToLowerInvariant()
    $computerName = $env:COMPUTERNAME.ToLowerInvariant()

    return $normalized -eq 'localhost' -or
        $normalized.StartsWith('localhost\') -or
        $normalized -eq '.' -or
        $normalized.StartsWith('.\') -or
        $normalized -eq '(local)' -or
        $normalized.StartsWith('(local)\') -or
        $normalized -eq $computerName -or
        $normalized.StartsWith($computerName + '\')
}

function Invoke-CommandText([string]$commandText) {
    $command = $connection.CreateCommand()
    try {
        $command.CommandTimeout = 180
        $command.CommandText = $commandText
        $null = $command.ExecuteNonQuery()
    }
    finally {
        $command.Dispose()
    }
}

function Invoke-SqlFile([string]$relativePath) {
    $absolutePath = Join-Path $workspaceRoot $relativePath
    if (-not (Test-Path -LiteralPath $absolutePath -PathType Leaf)) {
        throw ('SQL dosyası bulunamadı: ' + $relativePath)
    }

    Write-Output ('RUN ' + $relativePath)
    Invoke-CommandText ([IO.File]::ReadAllText($absolutePath))
}

if (-not (Test-LocalSqlServer $SqlServer)) {
    throw 'Bu betik yalnızca yerel geliştirme SQL Server örneklerinde çalıştırılabilir.'
}

if ($DatabaseName -notmatch '^[A-Za-z][A-Za-z0-9_]{0,127}$') {
    throw 'Veritabanı adı harfle başlamalı ve yalnızca harf, rakam veya alt çizgi içermelidir.'
}

try {
    # Tek bakım bağlantısı kullanmak, yerel SQL örneklerindeki tekrar bağlantı
    # gecikmelerini azaltır ve migration sırasının bozulmasını engeller.
    $connectionString =
        ('Server=' + $SqlServer + ';Database=master;Integrated Security=True;') +
        'Encrypt=True;TrustServerCertificate=True;Connect Timeout=60'
    $connection = New-Object System.Data.SqlClient.SqlConnection $connectionString
    $connection.Open()

    $existsCommand = $connection.CreateCommand()
    try {
        $existsCommand.CommandText =
            'SELECT CASE WHEN DB_ID(@databaseName) IS NULL THEN 0 ELSE 1 END;'
        $null = $existsCommand.Parameters.Add(
            '@databaseName',
            [Data.SqlDbType]::NVarChar,
            128)
        $existsCommand.Parameters['@databaseName'].Value = $DatabaseName
        $databaseExists = [int]$existsCommand.ExecuteScalar() -eq 1
    }
    finally {
        $existsCommand.Dispose()
    }

    if (-not $databaseExists) {
        Write-Output ('CREATE_DATABASE ' + $DatabaseName)
        Invoke-CommandText ('CREATE DATABASE [' + $DatabaseName + '];')
        $createdDatabase = $true
        $connection.ChangeDatabase($DatabaseName)

        foreach ($file in $migrationFiles) {
            Invoke-SqlFile $file
        }
    }
    else {
        Write-Output ('VERIFY_EXISTING_DATABASE ' + $DatabaseName)
        $connection.ChangeDatabase($DatabaseName)
    }

    # Yeni veya daha önce kurulmuş veritabanı aynı doğrulama zincirinden geçer.
    foreach ($file in $checkFiles) {
        Invoke-SqlFile $file
    }

    Write-Output ('LOCAL_DATABASE_READY ' + $DatabaseName)
    Write-Output (
        ('CONNECTION_STRING Server=' + $SqlServer + ';Database=' + $DatabaseName + ';') +
        'Integrated Security=True;Encrypt=True;TrustServerCertificate=True')
}
catch {
    # Yalnız bu çalıştırmada oluşturulan yarım veritabanı temizlenir.
    if ($createdDatabase -and $null -ne $connection) {
        try {
            if ($connection.State -ne [Data.ConnectionState]::Open) {
                $connection.Open()
            }

            $connection.ChangeDatabase('master')
            Invoke-CommandText (
                ('ALTER DATABASE [' + $DatabaseName + '] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; ') +
                ('DROP DATABASE [' + $DatabaseName + '];'))
            Write-Output ('REMOVED_INCOMPLETE_DATABASE ' + $DatabaseName)
        }
        catch {
            Write-Warning ('Yarım veritabanı otomatik kaldırılamadı: ' + $DatabaseName)
        }
    }

    throw
}
finally {
    if ($null -ne $connection) {
        $connection.Dispose()
    }
}
