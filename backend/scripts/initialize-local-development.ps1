param(
    [string]$SqlServer = 'localhost',
    [string]$DatabaseName = 'SosyoBelCompanyLocal'
)

$ErrorActionPreference = 'Stop'
$workspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$connection = $null
$createdDatabase = $false

$companySchemaFile = 'database\company\000_sosyalhizmet_schema_snapshot.sql'
$inspectionFile = 'database\compatibility\000_inspect_company_schema.sql'

$migrationFiles = @(
    'database\compatibility\migrations\001_create_foundation_extensions.sql',
    'database\compatibility\migrations\002_create_auth_support.sql',
    'database\compatibility\migrations\003_create_application_core_support.sql',
    'database\compatibility\migrations\004_create_application_family_support.sql',
    'database\compatibility\migrations\005_create_application_household_support.sql',
    'database\compatibility\migrations\006_create_application_photo_support.sql',
    'database\compatibility\migrations\007_add_kps_lookup_permission.sql'
)

$checkFiles = @(
    'database\compatibility\checks\001_verify_foundation_extensions.sql',
    'database\compatibility\checks\002_verify_auth_support.sql',
    'database\compatibility\checks\003_verify_application_core_support.sql',
    'database\compatibility\checks\004_verify_application_family_support.sql',
    'database\compatibility\checks\005_verify_application_household_support.sql',
    'database\compatibility\checks\006_verify_application_photo_support.sql',
    'database\compatibility\checks\007_verify_kps_lookup_permission.sql'
)

$developmentSeedFile =
    'database\compatibility\seed\001_local_development_reference_data.sql'

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
    # SQL Server istemcisi GO ifadesini tanımaz. Şirket snapshot'ındaki batch'ler
    # dosyadaki sırayı koruyacak biçimde burada ayrıştırılır.
    $batches = [regex]::Split($commandText, '(?im)^\s*GO\s*(?:--.*)?$')
    foreach ($batch in $batches) {
        if ([string]::IsNullOrWhiteSpace($batch)) {
            continue
        }

        $command = $connection.CreateCommand()
        try {
            $command.CommandTimeout = 180
            $command.CommandText = $batch
            $null = $command.ExecuteNonQuery()
        }
        finally {
            $command.Dispose()
        }
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

        # Yerel temel, şirketin verdiği dbo snapshot'ıdır. Eski bağımsız
        # database/migrations zinciri bu kurulumda bilinçli olarak kullanılmaz.
        Invoke-SqlFile $companySchemaFile
    }
    else {
        Write-Output ('VERIFY_EXISTING_DATABASE ' + $DatabaseName)
        $connection.ChangeDatabase($DatabaseName)
    }

    # Inspection başarısızsa hiçbir uyumluluk migration'ı çalıştırılmaz. Böylece
    # yanlış şemaya teknik tablolar eklenmesi engellenir.
    Invoke-SqlFile $inspectionFile

    foreach ($file in $migrationFiles) {
        Invoke-SqlFile $file
    }

    # Bu seed yalnız yerel demo akışını çalıştırır; şirket/canlı verisine uygulanmaz.
    Invoke-SqlFile $developmentSeedFile

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
