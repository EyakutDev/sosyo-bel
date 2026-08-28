param(
    [string]$SqlServer = 'localhost\MSSQLSERVER01'
)

$ErrorActionPreference = 'Stop'
$workspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$databaseName = 'SosyoBelCompatibilityValidation_' + [Guid]::NewGuid().ToString('N')
$connection = $null
$created = $false

if (-not $databaseName.StartsWith(
    'SosyoBelCompatibilityValidation_',
    [StringComparison]::Ordinal)) {
    throw 'Geçici veritabanı güvenlik öneki doğrulanamadı.'
}

function Invoke-CommandText([string]$commandText) {
    $command = $connection.CreateCommand()
    try {
        # Yerel SQL Server CREATE/DROP islemleri disk veya antivirus taramasi
        # altinda uzayabildigi icin auth dogrulama betigiyle ayni sinir kullanilir.
        $command.CommandTimeout = 180
        $command.CommandText = $commandText
        $null = $command.ExecuteNonQuery()
    }
    finally {
        $command.Dispose()
    }
}

function Invoke-SqlFile([string]$relativePath) {
    Write-Output ('RUN ' + $relativePath)
    $absolutePath = Join-Path $workspaceRoot $relativePath
    $sql = [IO.File]::ReadAllText($absolutePath)
    Invoke-CommandText $sql
}

try {
    # Tek bağlantı, named instance üzerindeki tekrar login gecikmelerini önler ve
    # bütün test yaşam döngüsünü aynı açıkça adlandırılmış geçici DB ile sınırlar.
    $connectionString = (
        'Server=' + $SqlServer +
        ';Database=master;Integrated Security=True;' +
        'Encrypt=True;TrustServerCertificate=True;Connect Timeout=60'
    )
    $connection = New-Object System.Data.SqlClient.SqlConnection $connectionString
    $connection.Open()

    $existsCommand = $connection.CreateCommand()
    try {
        $existsCommand.CommandText =
            'SELECT CASE WHEN DB_ID(@name) IS NULL THEN 0 ELSE 1 END;'
        $null = $existsCommand.Parameters.Add(
            '@name',
            [Data.SqlDbType]::NVarChar,
            128
        )
        $existsCommand.Parameters['@name'].Value = $databaseName
        if ([int]$existsCommand.ExecuteScalar() -ne 0) {
            throw ('Geçici uyumluluk veritabanı zaten var: ' + $databaseName)
        }
    }
    finally {
        $existsCommand.Dispose()
    }

    # CREATE komutu istemci tarafında zaman aşımına uğrasa bile sunucuda geç
    # tamamlanabilir. Cleanup bayrağı bu nedenle komuttan önce açılır.
    $created = $true
    Invoke-CommandText ('CREATE DATABASE [' + $databaseName + '];')
    $connection.ChangeDatabase($databaseName)

    Invoke-SqlFile 'database\compatibility\tests\000_create_minimal_company_fixture.sql'
    Invoke-SqlFile 'database/compatibility/tests/014_expand_company_photo_fixture.sql'
    Invoke-SqlFile 'database/compatibility/tests/010_expand_company_family_fixture.sql'
    Invoke-SqlFile 'database\compatibility\migrations\001_create_foundation_extensions.sql'

    # Aynı migration'ın ikinci kez güvenle no-op olması ayrıca doğrulanır.
    Invoke-SqlFile 'database\compatibility\migrations\001_create_foundation_extensions.sql'
    Invoke-SqlFile 'database\compatibility\checks\001_verify_foundation_extensions.sql'
    Invoke-SqlFile 'database\compatibility\tests\001_smoke_foundation_extensions.sql'
    Invoke-SqlFile 'database\compatibility\checks\001_verify_foundation_extensions.sql'

    Invoke-SqlFile 'database/compatibility/migrations/002_create_auth_support.sql'
    # 002 de yeniden çalıştırıldığında güvenli no-op olmalıdır.
    Invoke-SqlFile 'database/compatibility/migrations/002_create_auth_support.sql'
    Invoke-SqlFile 'database/compatibility/checks/002_verify_auth_support.sql'
    Invoke-SqlFile 'database/compatibility/tests/004_smoke_auth_support.sql'
    Invoke-SqlFile 'database/compatibility/checks/002_verify_auth_support.sql'

    Invoke-SqlFile 'database/compatibility/migrations/003_create_application_core_support.sql'
    # 003 de ikinci çalıştırmada mevcut yapıyı bozmadan no-op olmalıdır.
    Invoke-SqlFile 'database/compatibility/migrations/003_create_application_core_support.sql'
    Invoke-SqlFile 'database/compatibility/checks/003_verify_application_core_support.sql'
    Invoke-SqlFile 'database/compatibility/tests/008_smoke_application_core_support.sql'
    Invoke-SqlFile 'database/compatibility/checks/003_verify_application_core_support.sql'

    Invoke-SqlFile 'database/compatibility/migrations/004_create_application_family_support.sql'
    # 004 de ikinci calistirmada mevcut yapiyi ve SAG/OLU kodlarini cogaltmamalidir.
    Invoke-SqlFile 'database/compatibility/migrations/004_create_application_family_support.sql'
    Invoke-SqlFile 'database/compatibility/checks/004_verify_application_family_support.sql'
    Invoke-SqlFile 'database/compatibility/tests/011_smoke_application_family_support.sql'
    Invoke-SqlFile 'database/compatibility/checks/004_verify_application_family_support.sql'

    Invoke-SqlFile 'database/compatibility/migrations/005_create_application_household_support.sql'
    # 005 yeniden calistirildiginda soru ve secenek kodlari cogaltilmamalidir.
    Invoke-SqlFile 'database/compatibility/migrations/005_create_application_household_support.sql'
    Invoke-SqlFile 'database/compatibility/checks/005_verify_application_household_support.sql'
    Invoke-SqlFile 'database/compatibility/tests/012_smoke_application_household_support.sql'
    Invoke-SqlFile 'database/compatibility/checks/005_verify_application_household_support.sql'

    Invoke-SqlFile 'database/compatibility/migrations/006_create_application_photo_support.sql'
    # 006 yeniden calistirildiginda mevcut fotograf metadata tablosunu degistirmemelidir.
    Invoke-SqlFile 'database/compatibility/migrations/006_create_application_photo_support.sql'
    Invoke-SqlFile 'database/compatibility/checks/006_verify_application_photo_support.sql'
    Invoke-SqlFile 'database/compatibility/tests/013_smoke_application_photo_support.sql'
    Invoke-SqlFile 'database/compatibility/checks/006_verify_application_photo_support.sql'

    Invoke-SqlFile 'database/compatibility/migrations/007_add_kps_lookup_permission.sql'
    # 007 yeniden çalıştırıldığında mevcut yetki kayıtlarını değiştirmemelidir.
    Invoke-SqlFile 'database/compatibility/migrations/007_add_kps_lookup_permission.sql'
    Invoke-SqlFile 'database/compatibility/checks/007_verify_kps_lookup_permission.sql'
    Invoke-SqlFile 'database/compatibility/tests/015_smoke_kps_lookup_permission.sql'
    Invoke-SqlFile 'database/compatibility/checks/007_verify_kps_lookup_permission.sql'

    Invoke-SqlFile 'database/compatibility/migrations/008_remove_application_municipality_scope.sql'
    # 008 tekrar calistirildiginda tek belediye semasi degismemelidir.
    Invoke-SqlFile 'database/compatibility/migrations/008_remove_application_municipality_scope.sql'
    Invoke-SqlFile 'database/compatibility/checks/008_verify_application_single_municipality.sql'

    Invoke-SqlFile 'database/compatibility/rollbacks/007_remove_kps_lookup_permission.sql'
    Invoke-SqlFile 'database/compatibility/rollbacks/007_remove_kps_lookup_permission.sql'

    Invoke-SqlFile 'database/compatibility/rollbacks/006_drop_application_photo_support.sql'
    Invoke-SqlFile 'database/compatibility/rollbacks/006_drop_application_photo_support.sql'

    $postApplicationPhotoRollbackCheck = @(
        'IF OBJECT_ID(N''sosyobel.BasvuruFotograflari'', N''U'') IS NOT NULL'
        'BEGIN'
        '    THROW 51351, N''Rollback 006 sonrasinda fotograf metadata tablosu kaldi.'', 1;'
        'END;'
        ''
        'IF OBJECT_ID(N''dbo.HaneFotograflari'', N''U'') IS NULL OR'
        '   OBJECT_ID(N''dbo.Basvurular'', N''U'') IS NULL OR'
        '   OBJECT_ID(N''sosyobel.BasvuruHaneCevaplari'', N''U'') IS NULL'
        'BEGIN'
        '    THROW 51352, N''Rollback 006 sirket veya 005 tablosunu etkiledi.'', 1;'
        'END;'
    ) -join [Environment]::NewLine
    Invoke-CommandText $postApplicationPhotoRollbackCheck

    Invoke-SqlFile 'database/compatibility/rollbacks/005_drop_application_household_support.sql'
    Invoke-SqlFile 'database/compatibility/rollbacks/005_drop_application_household_support.sql'

    $postApplicationHouseholdRollbackCheck = @(
        'IF OBJECT_ID(N''sosyobel.HaneSorulari'', N''U'') IS NOT NULL OR'
        '   OBJECT_ID(N''sosyobel.HaneSoruSecenekleri'', N''U'') IS NOT NULL OR'
        '   OBJECT_ID(N''sosyobel.BasvuruHaneCevaplari'', N''U'') IS NOT NULL'
        'BEGIN'
        '    THROW 51332, N''Rollback 005 sonrasinda hane teknik tablosu kaldi.'', 1;'
        'END;'
        ''
        'IF OBJECT_ID(N''dbo.Basvurular'', N''U'') IS NULL OR'
        '   OBJECT_ID(N''sosyobel.BasvuruAileFertiUygulamaBilgileri'', N''U'') IS NULL'
        'BEGIN'
        '    THROW 51333, N''Rollback 005 sirket veya 004 tablosunu etkiledi.'', 1;'
        'END;'
    ) -join [Environment]::NewLine
    Invoke-CommandText $postApplicationHouseholdRollbackCheck

    Invoke-SqlFile 'database/compatibility/rollbacks/004_drop_application_family_support.sql'
    Invoke-SqlFile 'database/compatibility/rollbacks/004_drop_application_family_support.sql'

    $postApplicationFamilyRollbackCheck = @(
        'IF OBJECT_ID(N''sosyobel.BasvuruAileFertiUygulamaBilgileri'', N''U'') IS NOT NULL OR'
        '   OBJECT_ID(N''sosyobel.YasamDurumlari'', N''U'') IS NOT NULL'
        'BEGIN'
        '    THROW 51311, N''Rollback 004 sonrasinda aile teknik tablosu kaldi.'', 1;'
        'END;'
        ''
        'IF OBJECT_ID(N''dbo.BasvuruAileFertleri'', N''U'') IS NULL OR'
        '   OBJECT_ID(N''sosyobel.BasvuruDurumGecmisi'', N''U'') IS NULL'
        'BEGIN'
        '    THROW 51312, N''Rollback 004 sirket veya 003 tablosunu etkiledi.'', 1;'
        'END;'
    ) -join [Environment]::NewLine
    Invoke-CommandText $postApplicationFamilyRollbackCheck

    Invoke-SqlFile 'database/compatibility/rollbacks/003_drop_application_core_support.sql'
    Invoke-SqlFile 'database/compatibility/rollbacks/003_drop_application_core_support.sql'

    $postApplicationCoreRollbackCheck = @(
        'IF OBJECT_ID(N''sosyobel.BasvuruDurumGecmisi'', N''U'') IS NOT NULL'
        'BEGIN'
        '    THROW 51279, N''Rollback 003 sonrasında durum geçmişi tablosu kaldı.'', 1;'
        'END;'
        ''
        'IF OBJECT_ID(N''dbo.Basvurular'', N''U'') IS NULL OR'
        '   OBJECT_ID(N''sosyobel.BasvuruUygulamaBilgileri'', N''U'') IS NULL'
        'BEGIN'
        '    THROW 51280, N''Rollback 003 temel başvuru tablolarından birini etkiledi.'', 1;'
        'END;'
    ) -join [Environment]::NewLine
    Invoke-CommandText $postApplicationCoreRollbackCheck

    # Auth tablolarında veri varken rollback 002'nin tablo silmesi engellenir.
    Invoke-SqlFile 'database/compatibility/tests/005_seed_auth_rollback_guard.sql'
    $authRollbackBlocked = $false
    try {
        Invoke-SqlFile 'database/compatibility/rollbacks/002_drop_auth_support.sql'
    }
    catch {
        $candidateException = $_.Exception
        while ($null -ne $candidateException -and
            $candidateException -isnot [System.Data.SqlClient.SqlException]) {
            $candidateException = $candidateException.InnerException
        }

        if ($null -eq $candidateException -or
            $candidateException.Number -ne 51260) {
            throw
        }

        $authRollbackBlocked = $true
        Write-Output 'EXPECTED_AUTH_ROLLBACK_BLOCKED'
    }

    if (-not $authRollbackBlocked) {
        throw 'Auth rollback veri bulunan tabloyu silmeyi reddetmedi.'
    }

    Invoke-SqlFile 'database/compatibility/tests/006_cleanup_auth_rollback_guard.sql'
    Invoke-SqlFile 'database/compatibility/rollbacks/002_drop_auth_support.sql'

    $postAuthRollbackCheck = @(
        'IF OBJECT_ID(N''sosyobel.Belediyeler'', N''U'') IS NOT NULL OR'
        '   OBJECT_ID(N''sosyobel.KullaniciBelediyeleri'', N''U'') IS NOT NULL OR'
        '   OBJECT_ID(N''sosyobel.KullaniciYetkileri'', N''U'') IS NOT NULL OR'
        '   OBJECT_ID(N''sosyobel.IslemGecmisleri'', N''U'') IS NOT NULL OR'
        '   OBJECT_ID(N''sosyobel.IdempotencyKayitlari'', N''U'') IS NOT NULL OR'
        '   OBJECT_ID(N''sosyobel.YenilemeTokenlari'', N''U'') IS NOT NULL'
        'BEGIN'
        '    THROW 51261, N''Rollback 002 sonrasında auth tablosu kaldı.'', 1;'
        'END;'
        ''
        'IF OBJECT_ID(N''sosyobel.BasvuruUygulamaBilgileri'', N''U'') IS NULL OR'
        '   OBJECT_ID(N''sosyobel.ReferansKodlari'', N''U'') IS NULL OR'
        '   OBJECT_ID(N''sosyobel.KullaniciUygulamaBilgileri'', N''U'') IS NULL'
        'BEGIN'
        '    THROW 51262, N''Rollback 002, migration 001 tablolarından birini sildi.'', 1;'
        'END;'
    ) -join [Environment]::NewLine
    Invoke-CommandText $postAuthRollbackCheck

    # Boş durumda ikinci rollback çağrısı güvenli no-op olmalıdır.
    Invoke-SqlFile 'database/compatibility/rollbacks/002_drop_auth_support.sql'

    # Veri varken rollback'in sessizce tablo silmediği de beklenen 51210 hata
    # numarasıyla doğrulanır; ardından yalnız sabit test kaydı temizlenir.
    Invoke-SqlFile 'database\compatibility\tests\002_seed_rollback_guard.sql'
    $rollbackBlocked = $false
    try {
        Invoke-SqlFile 'database\compatibility\rollbacks\001_drop_foundation_extensions.sql'
    }
    catch {
        $candidateException = $_.Exception
        while ($null -ne $candidateException -and
            $candidateException -isnot [System.Data.SqlClient.SqlException]) {
            $candidateException = $candidateException.InnerException
        }

        if ($null -eq $candidateException -or
            $candidateException.Number -ne 51210) {
            throw
        }

        $rollbackBlocked = $true
        Write-Output 'EXPECTED_ROLLBACK_BLOCKED'
    }

    if (-not $rollbackBlocked) {
        throw 'Rollback veri bulunan tabloyu silmeyi reddetmedi.'
    }

    Invoke-SqlFile 'database\compatibility\tests\003_cleanup_rollback_guard.sql'
    Invoke-SqlFile 'database\compatibility\rollbacks\001_drop_foundation_extensions.sql'

    $postRollbackCheck = @(
        'IF OBJECT_ID(N''sosyobel.BasvuruUygulamaBilgileri'', N''U'') IS NOT NULL OR'
        '   OBJECT_ID(N''sosyobel.ReferansKodlari'', N''U'') IS NOT NULL OR'
        '   OBJECT_ID(N''sosyobel.KullaniciUygulamaBilgileri'', N''U'') IS NOT NULL OR'
        '   OBJECT_ID(N''sosyobel.Belediyeler'', N''U'') IS NOT NULL OR'
        '   OBJECT_ID(N''sosyobel.KullaniciBelediyeleri'', N''U'') IS NOT NULL OR'
        '   OBJECT_ID(N''sosyobel.KullaniciYetkileri'', N''U'') IS NOT NULL OR'
        '   OBJECT_ID(N''sosyobel.IslemGecmisleri'', N''U'') IS NOT NULL OR'
        '   OBJECT_ID(N''sosyobel.IdempotencyKayitlari'', N''U'') IS NOT NULL OR'
        '   OBJECT_ID(N''sosyobel.YenilemeTokenlari'', N''U'') IS NOT NULL'
        'BEGIN'
        '    THROW 51231, N''Rollback sonrasında uyumluluk tablolarından biri kaldı.'', 1;'
        'END;'
        ''
        'IF OBJECT_ID(N''dbo.AspNetUsers'', N''U'') IS NULL OR'
        '   OBJECT_ID(N''dbo.Basvurular'', N''U'') IS NULL'
        'BEGIN'
        '    THROW 51232, N''Rollback mevcut dbo temel tablolarından birini değiştirdi.'', 1;'
        'END;'
    ) -join [Environment]::NewLine
    Invoke-CommandText $postRollbackCheck

    # Rollback da yeniden çalıştırıldığında güvenli no-op olmalıdır.
    Invoke-SqlFile 'database\compatibility\rollbacks\001_drop_foundation_extensions.sql'

    Write-Output ('DATABASE_COMPATIBILITY_VALIDATION_OK ' + $databaseName)
}
finally {
    if ($null -ne $connection) {
        try {
            if ($created -and
                $connection.State -eq [Data.ConnectionState]::Open) {
                $connection.ChangeDatabase('master')
                Invoke-CommandText (
                    'IF DB_ID(N''' + $databaseName + ''') IS NOT NULL BEGIN ' +
                    'ALTER DATABASE [' + $databaseName + '] SET SINGLE_USER ' +
                    'WITH ROLLBACK IMMEDIATE; DROP DATABASE [' + $databaseName + ']; END;'
                )
                Write-Output ('CLEANUP_CHECKED ' + $databaseName)
            }
        }
        finally {
            $connection.Dispose()
        }
    }
}
