param(
    [string]$SqlServer = 'np:\\.\pipe\sql\query',
    [int]$ApiPort = 5088,
    [string]$DotnetPath = 'C:\Program Files\dotnet\dotnet.exe'
)

$ErrorActionPreference = 'Stop'
$httpRequestTimeoutSeconds = 60
# Windows PowerShell 5.1 multipart istemci tiplerini otomatik yuklemez.
Add-Type -AssemblyName System.Net.Http
# Istemci zaman asimi, EF Core'un 30 saniyelik SQL komut sinirindan uzun tutulur.
# Boylece yavas yerel SQL ortaminda gercek sunucu hatasi test tarafindan kesilmez.
$workspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$apiProject = Join-Path $workspaceRoot 'backend/src/SosyoBel.Api/SosyoBel.Api.csproj'
$runId = [Guid]::NewGuid().ToString('N')
$databaseName = 'SosyoBelAuthValidation_' + $runId
$tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$runRoot = [IO.Path]::GetFullPath(
    (Join-Path $tempRoot ('sosyobel-auth-validation-' + $runId))
)
$buildOutput = Join-Path $runRoot 'bin'
$stdoutPath = Join-Path $runRoot 'api.stdout.log'
$stderrPath = Join-Path $runRoot 'api.stderr.log'
$apiProcess = $null
$connection = $null
$databaseCreated = $false
$validationSucceeded = $false

$oldConnection = $env:ConnectionStrings__SosyoBel
$oldSigningKey = $env:Authentication__Jwt__SigningKeyBase64
$oldEnvironment = $env:ASPNETCORE_ENVIRONMENT
$oldPhotoRoot = $env:ApplicationPhotos__RootPath

# Bu hesap yalnız her çalıştırmada silinen geçici doğrulama veritabanında bulunur.
$testEmail = 'personel@demo.bel.tr'
$testPassword = 'TestPersonel2026'
$testPasswordHash =
    'AQAAAAIAAYagAAAAEBsIJrTuKzYLrPj0MRENhvMhs3UHg5RTYQRZ1nLrbU6NEj0mPJyz4YkeSHqzKCpmPQ=='

if (-not $databaseName.StartsWith(
    'SosyoBelAuthValidation_',
    [StringComparison]::Ordinal)) {
    throw 'Geçici auth veritabanı güvenlik öneki doğrulanamadı.'
}

if (-not $runRoot.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Geçici auth çalışma klasörü sistem temp dizininde değil.'
}

function Invoke-CommandText([string]$commandText) {
    $command = $connection.CreateCommand()
    try {
        # Yerel SQL Server, özellikle OneDrive ve antivirüs taraması altında
        # CREATE/DROP DATABASE işlemlerinde 60 saniyeyi aşabiliyor.
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
    $sqlPath = Join-Path $workspaceRoot $relativePath
    Invoke-CommandText ([IO.File]::ReadAllText($sqlPath))
}

function Get-HttpErrorStatus($exception) {
    if ($null -eq $exception.Response) {
        throw $exception
    }

    return [int]$exception.Response.StatusCode
}

function Assert-Equal($actual, $expected, [string]$message) {
    if ($actual -ne $expected) {
        throw ($message + ' Beklenen: ' + $expected + ', gerçek: ' + $actual)
    }
}

function Invoke-PhotoUpload(
    [string]$uri,
    [string]$accessToken,
    [string]$rowVersion,
    [string]$idempotencyKey,
    [byte[]]$photoBytes
) {
    $client = [System.Net.Http.HttpClient]::new()
    $multipart = [System.Net.Http.MultipartFormDataContent]::new()
    try {
        $client.Timeout = [TimeSpan]::FromSeconds($httpRequestTimeoutSeconds)
        $client.DefaultRequestHeaders.Authorization =
            [System.Net.Http.Headers.AuthenticationHeaderValue]::new(
                'Bearer',
                $accessToken
            )
        $client.DefaultRequestHeaders.Add('Idempotency-Key', $idempotencyKey)

        $rowVersionContent =
            [System.Net.Http.StringContent]::new(
                $rowVersion,
                [Text.Encoding]::UTF8
            )
        $multipart.Add($rowVersionContent, 'expectedRowVersion')

        $photoContent = [System.Net.Http.ByteArrayContent]::new($photoBytes)
        $photoContent.Headers.ContentType =
            [System.Net.Http.Headers.MediaTypeHeaderValue]::new('image/png')
        $multipart.Add($photoContent, 'photos', 'household-test.png')

        $response = $client.PostAsync($uri, $multipart).GetAwaiter().GetResult()
        try {
            [pscustomobject]@{
                StatusCode = [int]$response.StatusCode
                Body = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
            }
        }
        finally {
            $response.Dispose()
        }
    }
    finally {
        # Multipart dispose islemi alt string ve byte content nesnelerini de kapatir.
        $multipart.Dispose()
        $client.Dispose()
    }
}

if (Get-NetTCPConnection -LocalPort $ApiPort -State Listen -ErrorAction SilentlyContinue) {
    throw "API doğrulama portu kullanımda: $ApiPort"
}

try {
    $null = New-Item -ItemType Directory -Path $runRoot

    # Açık duran geliştirme API'sinin bin klasörünü kullanmamak için bu test
    # sürümü tamamen ayrı bir temp çıktı klasörüne derlenir.
    & $DotnetPath build $apiProject --no-restore "-p:BaseOutputPath=$buildOutput/"
    if ($LASTEXITCODE -ne 0) {
        throw 'Geçici auth API derlemesi başarısız oldu.'
    }

    $apiDll = Join-Path $buildOutput 'Debug/net10.0/SosyoBel.Api.dll'
    if (-not (Test-Path -LiteralPath $apiDll)) {
        throw 'Geçici auth API DLL dosyası bulunamadı.'
    }

    $connectionString = (
        'Server=' + $SqlServer +
        ';Database=master;Integrated Security=True;' +
        'Encrypt=True;TrustServerCertificate=True;Connect Timeout=15'
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
            throw ('Geçici auth veritabanı zaten var: ' + $databaseName)
        }
    }
    finally {
        $existsCommand.Dispose()
    }

    # CREATE istemci tarafında zaman aşımına uğrasa bile sunucuda tamamlanabilir;
    # cleanup bu nedenle komuttan önce etkinleştirilir.
    $databaseCreated = $true
    Invoke-CommandText ('CREATE DATABASE [' + $databaseName + '];')
    $connection.ChangeDatabase($databaseName)

    Invoke-SqlFile 'database/compatibility/tests/000_create_minimal_company_fixture.sql'
    Invoke-SqlFile 'database/compatibility/tests/014_expand_company_photo_fixture.sql'
    Invoke-SqlFile 'database/compatibility/tests/007_expand_company_identity_fixture.sql'
    Invoke-SqlFile 'database/compatibility/tests/009_expand_company_application_fixture.sql'
    Invoke-SqlFile 'database/compatibility/tests/010_expand_company_family_fixture.sql'
    Invoke-SqlFile 'database/compatibility/migrations/001_create_foundation_extensions.sql'
    Invoke-SqlFile 'database/compatibility/checks/001_verify_foundation_extensions.sql'
    Invoke-SqlFile 'database/compatibility/migrations/002_create_auth_support.sql'
    Invoke-SqlFile 'database/compatibility/checks/002_verify_auth_support.sql'
    Invoke-SqlFile 'database/compatibility/migrations/003_create_application_core_support.sql'
    Invoke-SqlFile 'database/compatibility/checks/003_verify_application_core_support.sql'
    Invoke-SqlFile 'database/compatibility/migrations/004_create_application_family_support.sql'
    Invoke-SqlFile 'database/compatibility/checks/004_verify_application_family_support.sql'
    Invoke-SqlFile 'database/compatibility/migrations/005_create_application_household_support.sql'
    Invoke-SqlFile 'database/compatibility/checks/005_verify_application_household_support.sql'
    Invoke-SqlFile 'database/compatibility/migrations/006_create_application_photo_support.sql'
    Invoke-SqlFile 'database/compatibility/checks/006_verify_application_photo_support.sql'
    Invoke-SqlFile 'database/compatibility/migrations/007_add_kps_lookup_permission.sql'
    Invoke-SqlFile 'database/compatibility/checks/007_verify_kps_lookup_permission.sql'

    $seedSql = @"
DECLARE @MunicipalityId int;

INSERT INTO dbo.AspNetUsers
(
    Id,
    Ad,
    Soyad,
    UserName,
    NormalizedUserName,
    Email,
    NormalizedEmail,
    EmailConfirmed,
    PasswordHash,
    SecurityStamp,
    ConcurrencyStamp,
    PhoneNumberConfirmed,
    TwoFactorEnabled,
    LockoutEnabled,
    AccessFailedCount
)
VALUES
(
    N'auth-test-user-1',
    N'Test',
    N'Personel',
    N'$testEmail',
    N'PERSONEL@DEMO.BEL.TR',
    N'$testEmail',
    N'PERSONEL@DEMO.BEL.TR',
    1,
    N'$testPasswordHash',
    N'test-security-stamp',
    N'test-concurrency-stamp',
    0,
    0,
    1,
    0
);

INSERT INTO sosyobel.KullaniciUygulamaBilgileri (UserId)
VALUES (N'auth-test-user-1');

INSERT INTO sosyobel.Belediyeler (Kod, Ad)
VALUES (N'DEMO', N'Demo Belediyesi');

SET @MunicipalityId = CONVERT(int, SCOPE_IDENTITY());

INSERT INTO sosyobel.KullaniciBelediyeleri
    (UserId, BelediyeId, RolKodu)
VALUES
    (N'auth-test-user-1', @MunicipalityId, N'PERSONEL');

DECLARE @DraftStatusId int;
DECLARE @PendingStatusId int;
DECLARE @HelpTypeId int;
DECLARE @RequestChannelId int;
DECLARE @RelationshipId int;
DECLARE @EmploymentStatusId int;
DECLARE @EducationStatusId int;

INSERT INTO dbo.BasvuruDurumlari (Name, Sil)
VALUES (N'Taslak', 0);
SET @DraftStatusId = CONVERT(int, SCOPE_IDENTITY());

INSERT INTO dbo.BasvuruDurumlari (Name, Sil)
VALUES (N'Kurul Bekliyor', 0);
SET @PendingStatusId = CONVERT(int, SCOPE_IDENTITY());

INSERT INTO dbo.YardimTurleri (Name, Sil)
VALUES (N'Gıda Yardımı', 0);
SET @HelpTypeId = CONVERT(int, SCOPE_IDENTITY());

INSERT INTO dbo.TalepGelisKanallari (Name, Sil)
VALUES (N'Mobil Saha', 0);
SET @RequestChannelId = CONVERT(int, SCOPE_IDENTITY());

INSERT INTO dbo.Yakinliklar (Name, Sil)
VALUES (N'Es', 0);
SET @RelationshipId = CONVERT(int, SCOPE_IDENTITY());

INSERT INTO dbo.CalismaDurumlari (Name, Sil)
VALUES (N'Calismiyor', 0);
SET @EmploymentStatusId = CONVERT(int, SCOPE_IDENTITY());

INSERT INTO dbo.EgitimDurumlari (Name, Sil)
VALUES (N'Lise', 0);
SET @EducationStatusId = CONVERT(int, SCOPE_IDENTITY());

INSERT INTO sosyobel.ReferansKodlari
    (ReferansTuruKodu, KaynakId, Kod)
VALUES
    (N'BASVURU_DURUMU', @DraftStatusId, N'TASLAK'),
    (N'BASVURU_DURUMU', @PendingStatusId, N'KURUL_BEKLIYOR'),
    (N'YARDIM_TURU', @HelpTypeId, N'GIDA'),
    (N'TALEP_GELIS_KANALI', @RequestChannelId, N'MOBIL_SAHA'),
    (N'YAKINLIK', @RelationshipId, N'ES'),
    (N'CALISMA_DURUMU', @EmploymentStatusId, N'CALISMIYOR'),
    (N'EGITIM_DURUMU', @EducationStatusId, N'LISE');
"@
    Invoke-CommandText $seedSql

    $env:ConnectionStrings__SosyoBel = (
        'Server=' + $SqlServer +
        ';Database=' + $databaseName +
        ';Integrated Security=True;Encrypt=True;TrustServerCertificate=True'
    )
    $keyBytes = New-Object byte[] 32
    $random = [Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $random.GetBytes($keyBytes)
    }
    finally {
        $random.Dispose()
    }

    $env:Authentication__Jwt__SigningKeyBase64 =
        [Convert]::ToBase64String($keyBytes)
    $env:ASPNETCORE_ENVIRONMENT = 'Development'
    # Fiziksel test fotografi yalnız bu kosunun sistem temp klasorunde tutulur.
    $photoStorageRoot = Join-Path $runRoot 'application-photos'
    $env:ApplicationPhotos__RootPath = $photoStorageRoot

    # appsettings.json geçici build çıktısına kopyalanır; content root bu klasör
    # olmalıdır ki issuer, audience ve oturum ayarları normal biçimde yüklensin.
    $apiWorkingDirectory = Split-Path -Parent $apiDll
    $apiProcess = Start-Process -FilePath $DotnetPath `
        -ArgumentList @($apiDll, '--urls', "http://127.0.0.1:$ApiPort") `
        -WorkingDirectory $apiWorkingDirectory `
        -RedirectStandardOutput $stdoutPath `
        -RedirectStandardError $stderrPath `
        -WindowStyle Hidden `
        -PassThru

    $health = $null
    for ($attempt = 0; $attempt -lt 40; $attempt++) {
        Start-Sleep -Milliseconds 500
        try {
            $health = Invoke-RestMethod `
                -Uri "http://127.0.0.1:$ApiPort/health/ready" `
                -TimeoutSec 2
            break
        }
        catch {
            if ($apiProcess.HasExited) {
                break
            }
        }
    }

    if ($null -eq $health) {
        $stdout = Get-Content -LiteralPath $stdoutPath -ErrorAction SilentlyContinue
        $stderr = Get-Content -LiteralPath $stderrPath -ErrorAction SilentlyContinue
        throw "API başlatılamadı. STDOUT: $stdout STDERR: $stderr"
    }

    $invalidBody = @{
        email = $testEmail
        password = 'WrongPassword2026'
    } | ConvertTo-Json -Compress
    try {
        $null = Invoke-WebRequest -UseBasicParsing -Method Post `
            -Uri "http://127.0.0.1:$ApiPort/api/v1/auth/login" `
            -ContentType 'application/json' `
            -Body $invalidBody `
            -TimeoutSec $httpRequestTimeoutSeconds
        $invalidLoginStatus = 200
    }
    catch {
        $invalidLoginStatus = Get-HttpErrorStatus $_.Exception
    }

    $loginBody = @{
        email = $testEmail
        password = $testPassword
    } | ConvertTo-Json -Compress
    $login = Invoke-RestMethod -Method Post `
        -Uri "http://127.0.0.1:$ApiPort/api/v1/auth/login" `
        -Headers @{ 'X-Device-Id' = 'integration-test-device' } `
        -ContentType 'application/json' `
        -Body $loginBody `
        -TimeoutSec $httpRequestTimeoutSeconds

    $me = Invoke-RestMethod `
        -Uri "http://127.0.0.1:$ApiPort/api/v1/auth/me" `
        -Headers @{ Authorization = "Bearer $($login.accessToken)" } `
        -TimeoutSec $httpRequestTimeoutSeconds

    # Mobil form etiketlerini sabit yazmak yerine şirket ve sosyobel referans
    # tablolarından okuyan katalog endpoint'i gerçek SQL Server üzerinde sınanır.
    $applicationReferences = Invoke-RestMethod `
        -Uri "http://127.0.0.1:$ApiPort/api/v1/application-references" `
        -Headers @{ Authorization = "Bearer $($login.accessToken)" } `
        -TimeoutSec $httpRequestTimeoutSeconds

    $refreshBody = @{
        refreshToken = $login.refreshToken
    } | ConvertTo-Json -Compress
    $refreshed = Invoke-RestMethod -Method Post `
        -Uri "http://127.0.0.1:$ApiPort/api/v1/auth/refresh" `
        -Headers @{ 'X-Device-Id' = 'integration-test-device' } `
        -ContentType 'application/json' `
        -Body $refreshBody `
        -TimeoutSec $httpRequestTimeoutSeconds

    try {
        $null = Invoke-WebRequest -UseBasicParsing -Method Post `
            -Uri "http://127.0.0.1:$ApiPort/api/v1/auth/refresh" `
            -ContentType 'application/json' `
            -Body $refreshBody `
            -TimeoutSec $httpRequestTimeoutSeconds
        $reuseStatus = 200
    }
    catch {
        $reuseStatus = Get-HttpErrorStatus $_.Exception
    }

    # Token tekrar kullanım testi bütün aktif oturumları kapattığı için logout
    # davranışı yeni ve halen aktif ayrı bir oturumla doğrulanır.
    $logoutSession = Invoke-RestMethod -Method Post `
        -Uri "http://127.0.0.1:$ApiPort/api/v1/auth/login" `
        -Headers @{ 'X-Device-Id' = 'integration-test-device' } `
        -ContentType 'application/json' `
        -Body $loginBody `
        -TimeoutSec $httpRequestTimeoutSeconds

    $logoutBody = @{
        refreshToken = $logoutSession.refreshToken
    } | ConvertTo-Json -Compress
    $logoutResponse = Invoke-WebRequest -UseBasicParsing -Method Post `
        -Uri "http://127.0.0.1:$ApiPort/api/v1/auth/logout" `
        -ContentType 'application/json' `
        -Body $logoutBody `
        -TimeoutSec $httpRequestTimeoutSeconds

    try {
        $null = Invoke-WebRequest -UseBasicParsing -Method Post `
            -Uri "http://127.0.0.1:$ApiPort/api/v1/auth/refresh" `
            -ContentType 'application/json' `
            -Body $logoutBody `
            -TimeoutSec $httpRequestTimeoutSeconds
        $loggedOutRefreshStatus = 200
    }
    catch {
        $loggedOutRefreshStatus = Get-HttpErrorStatus $_.Exception
    }

    $applicationDraft = @{
        identityNumber = '12345678901'
        birthDate = '1990-01-15'
        phoneNumber = '5551234567'
        helpTypeCode = 'GIDA'
        hasDisability = $false
        description = 'Geçici HTTP doğrulama başvurusu'
        applicantFirstName = 'Test'
        applicantLastName = 'Vatandaş'
        address = 'Geçici doğrulama adresi'
    }
    $createApplicationJson = @{
        draft = $applicationDraft
    } | ConvertTo-Json -Depth 5 -Compress
    # Windows PowerShell 5 JSON metnini varsayilan sistem kodlamasiyla
    # gonderebildigi icin Turkce karakterli govde acikca UTF-8'e cevrilir.
    $createApplicationBody = [Text.Encoding]::UTF8.GetBytes($createApplicationJson)
    $application = Invoke-RestMethod -Method Post `
        -Uri "http://127.0.0.1:$ApiPort/api/v1/applications/drafts" `
        -Headers @{
            Authorization = "Bearer $($login.accessToken)"
            'Idempotency-Key' = 'application-draft-test-0001'
        } `
        -ContentType 'application/json; charset=utf-8' `
        -Body $createApplicationBody `
        -TimeoutSec $httpRequestTimeoutSeconds

    $applicationFromGet = Invoke-RestMethod `
        -Uri "http://127.0.0.1:$ApiPort/api/v1/applications/$($application.applicationPublicId)" `
        -Headers @{ Authorization = "Bearer $($login.accessToken)" } `
        -TimeoutSec $httpRequestTimeoutSeconds

    $applicationDraft.phoneNumber = '5557654321'
    $updateApplicationJson = @{
        expectedRowVersion = $application.rowVersion
        draft = $applicationDraft
    } | ConvertTo-Json -Depth 5 -Compress
    $updateApplicationBody = [Text.Encoding]::UTF8.GetBytes($updateApplicationJson)
    $updatedApplication = Invoke-RestMethod -Method Put `
        -Uri "http://127.0.0.1:$ApiPort/api/v1/applications/$($application.applicationPublicId)/draft" `
        -Headers @{ Authorization = "Bearer $($login.accessToken)" } `
        -ContentType 'application/json; charset=utf-8' `
        -Body $updateApplicationBody `
        -TimeoutSec $httpRequestTimeoutSeconds

    $fieldDataRequest = @{
        expectedRowVersion = $updatedApplication.rowVersion
        familyMembers = @(
            @{
                fullName = 'Ayse Yilmaz'
                age = 42
                relationshipCode = 'ES'
                hasDisability = $false
                employmentStatusCode = 'CALISMIYOR'
                educationStatusCode = 'LISE'
                vitalStatusCode = 'SAG'
            }
        )
        householdAnswers = @(
            @{
                questionCode = 'MULKIYET_DURUMU'
                optionCode = 'KIRACI'
            },
            @{
                questionCode = 'MULK_TIPI'
                optionCode = 'APARTMAN_DAIRESI'
            },
            @{
                questionCode = 'EV_TEMIZLIGI'
                optionCode = 'EVET'
            },
            @{
                questionCode = 'BARINMA_DURUMU'
                optionCode = 'IYI'
            },
            @{
                questionCode = 'EV_ESYALARI'
                optionCode = 'YETERLI'
            }
        )
        saveToBeneficiaryDirectory = $false
    }
    $fieldDataJson = $fieldDataRequest | ConvertTo-Json -Depth 6 -Compress
    $fieldDataBody = [Text.Encoding]::UTF8.GetBytes($fieldDataJson)

    # Mobil doğrulama atlatılsa bile eksik zorunlu hane cevabı API tarafından
    # reddedilmelidir. Başarısız istek RowVersion değerini ilerletmez.
    $incompleteFieldDataRequest = @{
        expectedRowVersion = $updatedApplication.rowVersion
        familyMembers = $fieldDataRequest.familyMembers
        householdAnswers = @($fieldDataRequest.householdAnswers | Select-Object -First 4)
        saveToBeneficiaryDirectory = $false
    }
    $incompleteFieldDataJson =
        $incompleteFieldDataRequest | ConvertTo-Json -Depth 6 -Compress
    $incompleteFieldDataBody = [Text.Encoding]::UTF8.GetBytes($incompleteFieldDataJson)
    try {
        $null = Invoke-WebRequest -UseBasicParsing -Method Put `
            -Uri "http://127.0.0.1:$ApiPort/api/v1/applications/$($application.applicationPublicId)/field-data" `
            -Headers @{ Authorization = "Bearer $($login.accessToken)" } `
            -ContentType 'application/json; charset=utf-8' `
            -Body $incompleteFieldDataBody `
            -TimeoutSec $httpRequestTimeoutSeconds
        $missingRequiredHouseholdStatus = 200
    }
    catch {
        $missingRequiredHouseholdStatus = Get-HttpErrorStatus $_.Exception
    }

    $fieldDataApplication = Invoke-RestMethod -Method Put `
        -Uri "http://127.0.0.1:$ApiPort/api/v1/applications/$($application.applicationPublicId)/field-data" `
        -Headers @{ Authorization = "Bearer $($login.accessToken)" } `
        -ContentType 'application/json; charset=utf-8' `
        -Body $fieldDataBody `
        -TimeoutSec $httpRequestTimeoutSeconds

    $photoBytes = [Convert]::FromBase64String(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII='
    )
    $photoUploadUri =
        "http://127.0.0.1:$ApiPort/api/v1/applications/$($application.applicationPublicId)/photos"
    $photoUpload = Invoke-PhotoUpload `
        -uri $photoUploadUri `
        -accessToken $login.accessToken `
        -rowVersion $fieldDataApplication.rowVersion `
        -idempotencyKey 'application-photo-upload-test-0001' `
        -photoBytes $photoBytes
    Assert-Equal $photoUpload.StatusCode 200 'Fotoğraf yükleme isteği başarısız.'
    $photoApplication = $photoUpload.Body | ConvertFrom-Json

    # Gonderim cevabi kaybolmus gibi once baska bir taslak yazimiyla RowVersion
    # ilerletilir; ayni anahtar ve fotograf yine de tekil replay edilmelidir.
    $fieldDataRequest.expectedRowVersion = $photoApplication.rowVersion
    $retryFieldDataJson = $fieldDataRequest | ConvertTo-Json -Depth 6 -Compress
    $retryFieldDataBody = [Text.Encoding]::UTF8.GetBytes($retryFieldDataJson)
    $retryFieldDataApplication = Invoke-RestMethod -Method Put `
        -Uri "http://127.0.0.1:$ApiPort/api/v1/applications/$($application.applicationPublicId)/field-data" `
        -Headers @{ Authorization = "Bearer $($login.accessToken)" } `
        -ContentType 'application/json; charset=utf-8' `
        -Body $retryFieldDataBody `
        -TimeoutSec $httpRequestTimeoutSeconds

    $photoReplay = Invoke-PhotoUpload `
        -uri $photoUploadUri `
        -accessToken $login.accessToken `
        -rowVersion $retryFieldDataApplication.rowVersion `
        -idempotencyKey 'application-photo-upload-test-0001' `
        -photoBytes $photoBytes
    Assert-Equal $photoReplay.StatusCode 200 'Fotoğraf idempotency replay başarısız.'
    $photoReplayApplication = $photoReplay.Body | ConvertFrom-Json
    Assert-Equal $photoReplayApplication.rowVersion $retryFieldDataApplication.rowVersion `
        'Fotoğraf replay sonucu güncel RowVersion değerini döndürmedi.'

    # Taslakta fotograf secimi degistiginde yeni anahtar aktif anlik kopyayi
    # degistirir; eski metadata audit icin silinmis olarak kalir.
    $replacementPhotoBytes = [Convert]::FromBase64String(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR42mP8z8BQDwAFgQIAK1z7WQAAAABJRU5ErkJggg=='
    )
    $photoReplacement = Invoke-PhotoUpload `
        -uri $photoUploadUri `
        -accessToken $login.accessToken `
        -rowVersion $photoReplayApplication.rowVersion `
        -idempotencyKey 'application-photo-replace-test-0002' `
        -photoBytes $replacementPhotoBytes
    Assert-Equal $photoReplacement.StatusCode 200 'Taslak fotoğraf değiştirme isteği başarısız.'
    $replacementApplication = $photoReplacement.Body | ConvertFrom-Json

    $draftSnapshot = Invoke-RestMethod `
        -Uri "http://127.0.0.1:$ApiPort/api/v1/applications/$($application.applicationPublicId)/draft-snapshot" `
        -Headers @{ Authorization = "Bearer $($login.accessToken)" } `
        -TimeoutSec $httpRequestTimeoutSeconds
    $downloadedPhoto = Invoke-WebRequest -UseBasicParsing `
        -Uri "http://127.0.0.1:$ApiPort/api/v1/applications/$($application.applicationPublicId)/photos/$($draftSnapshot.photos[0].photoId)" `
        -Headers @{ Authorization = "Bearer $($login.accessToken)" } `
        -TimeoutSec $httpRequestTimeoutSeconds
    $draftWorkItems = Invoke-RestMethod `
        -Uri "http://127.0.0.1:$ApiPort/api/v1/work-items/mine?limit=100" `
        -Headers @{ Authorization = "Bearer $($login.accessToken)" } `
        -TimeoutSec $httpRequestTimeoutSeconds

    $submitApplicationJson = @{
        expectedRowVersion = $replacementApplication.rowVersion
    } | ConvertTo-Json -Compress
    $submitApplicationBody = [Text.Encoding]::UTF8.GetBytes($submitApplicationJson)
    $submittedApplication = Invoke-RestMethod -Method Post `
        -Uri "http://127.0.0.1:$ApiPort/api/v1/applications/$($application.applicationPublicId)/submit" `
        -Headers @{
            Authorization = "Bearer $($login.accessToken)"
            'Idempotency-Key' = 'application-submit-test-0001'
        } `
        -ContentType 'application/json; charset=utf-8' `
        -Body $submitApplicationBody `
        -TimeoutSec $httpRequestTimeoutSeconds
    $submittedWorkItems = Invoke-RestMethod `
        -Uri "http://127.0.0.1:$ApiPort/api/v1/work-items/mine?limit=100" `
        -Headers @{ Authorization = "Bearer $($login.accessToken)" } `
        -TimeoutSec $httpRequestTimeoutSeconds

    $lockedUpdateJson = @{
        expectedRowVersion = $submittedApplication.rowVersion
        draft = $applicationDraft
    } | ConvertTo-Json -Depth 5 -Compress
    $lockedUpdateBody = [Text.Encoding]::UTF8.GetBytes($lockedUpdateJson)
    try {
        $null = Invoke-WebRequest -UseBasicParsing -Method Put `
            -Uri "http://127.0.0.1:$ApiPort/api/v1/applications/$($application.applicationPublicId)/draft" `
            -Headers @{ Authorization = "Bearer $($login.accessToken)" } `
            -ContentType 'application/json; charset=utf-8' `
            -Body $lockedUpdateBody `
            -TimeoutSec $httpRequestTimeoutSeconds
        $lockedUpdateStatus = 200
    }
    catch {
        $lockedUpdateStatus = Get-HttpErrorStatus $_.Exception
    }

    $fieldDataRequest.expectedRowVersion = $submittedApplication.rowVersion
    $lockedFieldDataJson = $fieldDataRequest | ConvertTo-Json -Depth 6 -Compress
    $lockedFieldDataBody = [Text.Encoding]::UTF8.GetBytes($lockedFieldDataJson)
    try {
        $null = Invoke-WebRequest -UseBasicParsing -Method Put `
            -Uri "http://127.0.0.1:$ApiPort/api/v1/applications/$($application.applicationPublicId)/field-data" `
            -Headers @{ Authorization = "Bearer $($login.accessToken)" } `
            -ContentType 'application/json; charset=utf-8' `
            -Body $lockedFieldDataBody `
            -TimeoutSec $httpRequestTimeoutSeconds
        $lockedFieldDataStatus = 200
    }
    catch {
        $lockedFieldDataStatus = Get-HttpErrorStatus $_.Exception
    }

    $lockedPhotoUpload = Invoke-PhotoUpload `
        -uri $photoUploadUri `
        -accessToken $login.accessToken `
        -rowVersion $submittedApplication.rowVersion `
        -idempotencyKey 'application-photo-locked-test-0003' `
        -photoBytes $replacementPhotoBytes
    $lockedPhotoUploadStatus = $lockedPhotoUpload.StatusCode

    $storageCheck = $connection.CreateCommand()
    try {
        $storageCheck.CommandText = @"
SELECT
    CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END
FROM dbo.Basvurular AS application
INNER JOIN sosyobel.BasvuruUygulamaBilgileri AS metadata
    ON metadata.BasvuruId = application.Id
INNER JOIN dbo.BasvuruAileFertleri AS familyMember
    ON familyMember.BasvuruId = application.Id
INNER JOIN sosyobel.BasvuruAileFertiUygulamaBilgileri AS familyMetadata
    ON familyMetadata.BasvuruAileFertiId = familyMember.Id
INNER JOIN sosyobel.YasamDurumlari AS vitalStatus
    ON vitalStatus.Id = familyMetadata.YasamDurumuId
WHERE metadata.PublicId = @publicId
  AND application.BasvuranTcKimlikNo = N'12345678901'
  AND application.BasvuranTelefon = N'5557654321'
  AND metadata.KurulaGonderilmeTarihiUtc IS NOT NULL
  AND familyMember.AdSoyad = N'Ayse Yilmaz'
  AND familyMember.Yas = 42
  AND vitalStatus.Kod = N'SAG';
"@
        $null = $storageCheck.Parameters.Add(
            '@publicId',
            [Data.SqlDbType]::UniqueIdentifier
        )
        $storageCheck.Parameters['@publicId'].Value =
            [Guid]$application.applicationPublicId
        $applicationStoredInSplitTables =
            [int]$storageCheck.ExecuteScalar() -eq 1
    }
    finally {
        $storageCheck.Dispose()
    }

    $householdStorageCheck = $connection.CreateCommand()
    try {
        $householdStorageCheck.CommandText = @"
SELECT COUNT(*)
FROM sosyobel.BasvuruHaneCevaplari AS answer
INNER JOIN sosyobel.BasvuruUygulamaBilgileri AS metadata
    ON metadata.BasvuruId = answer.BasvuruId
INNER JOIN sosyobel.HaneSorulari AS question
    ON question.Id = answer.SoruId
INNER JOIN sosyobel.HaneSoruSecenekleri AS optionValue
    ON optionValue.SoruId = answer.SoruId
   AND optionValue.Id = answer.SecenekId
WHERE metadata.PublicId = @publicId
  AND
  (
      (question.Kod = N'MULKIYET_DURUMU' AND optionValue.Kod = N'KIRACI') OR
      (question.Kod = N'MULK_TIPI' AND optionValue.Kod = N'APARTMAN_DAIRESI') OR
      (question.Kod = N'EV_TEMIZLIGI' AND optionValue.Kod = N'EVET') OR
      (question.Kod = N'BARINMA_DURUMU' AND optionValue.Kod = N'IYI') OR
      (question.Kod = N'EV_ESYALARI' AND optionValue.Kod = N'YETERLI')
  );
"@
        $null = $householdStorageCheck.Parameters.Add(
            '@publicId',
            [Data.SqlDbType]::UniqueIdentifier
        )
        $householdStorageCheck.Parameters['@publicId'].Value =
            [Guid]$application.applicationPublicId
        $householdAnswerCount = [int]$householdStorageCheck.ExecuteScalar()
    }
    finally {
        $householdStorageCheck.Dispose()
    }

    $photoStorageCheck = $connection.CreateCommand()
    try {
        $photoStorageCheck.CommandText = @"
SELECT
    SUM(CASE WHEN photo.SilindiMi = 0 THEN 1 ELSE 0 END) AS ActivePhotoCount,
    COUNT(*) AS PhotoHistoryCount,
    MAX(CASE WHEN photo.SilindiMi = 0 THEN photo.StorageKey END) AS ActiveStorageKey,
    MAX(CASE WHEN photo.SilindiMi = 1 THEN photo.StorageKey END) AS DeletedStorageKey
FROM sosyobel.BasvuruFotograflari AS photo
INNER JOIN sosyobel.BasvuruUygulamaBilgileri AS metadata
    ON metadata.BasvuruId = photo.BasvuruId
WHERE metadata.PublicId = @publicId
  AND photo.SiraNo = 1
  AND photo.MimeType = 'image/png';
"@
        $null = $photoStorageCheck.Parameters.Add(
            '@publicId',
            [Data.SqlDbType]::UniqueIdentifier
        )
        $photoStorageCheck.Parameters['@publicId'].Value =
            [Guid]$application.applicationPublicId
        $photoReader = $photoStorageCheck.ExecuteReader()
        try {
            if (-not $photoReader.Read()) {
                throw 'Fotoğraf metadata sorgusu sonuç döndürmedi.'
            }
            $activePhotoCount = [int]$photoReader['ActivePhotoCount']
            $photoHistoryCount = [int]$photoReader['PhotoHistoryCount']
            $photoStorageKey = [string]$photoReader['ActiveStorageKey']
            $deletedPhotoStorageKey = [string]$photoReader['DeletedStorageKey']
        }
        finally {
            $photoReader.Dispose()
        }
    }
    finally {
        $photoStorageCheck.Dispose()
    }

    $photoRelativePath = $photoStorageKey.Replace(
        '/',
        [IO.Path]::DirectorySeparatorChar
    )
    $photoFileExists = Test-Path -LiteralPath (
        Join-Path $photoStorageRoot $photoRelativePath
    )
    $deletedPhotoRelativePath = $deletedPhotoStorageKey.Replace(
        '/',
        [IO.Path]::DirectorySeparatorChar
    )
    $deletedPhotoFileRemoved = -not (Test-Path -LiteralPath (
        Join-Path $photoStorageRoot $deletedPhotoRelativePath
    ))

    $historyCheck = $connection.CreateCommand()
    try {
        $historyCheck.CommandText = @"
SELECT COUNT(*)
FROM sosyobel.BasvuruDurumGecmisi AS history
INNER JOIN sosyobel.BasvuruUygulamaBilgileri AS metadata
    ON metadata.BasvuruId = history.BasvuruId
WHERE metadata.PublicId = @publicId;
"@
        $null = $historyCheck.Parameters.Add(
            '@publicId',
            [Data.SqlDbType]::UniqueIdentifier
        )
        $historyCheck.Parameters['@publicId'].Value =
            [Guid]$application.applicationPublicId
        $applicationHistoryCount = [int]$historyCheck.ExecuteScalar()
    }
    finally {
        $historyCheck.Dispose()
    }

    Assert-Equal $health.status 'Healthy' 'Readiness sonucu hatalı.'
    Assert-Equal $invalidLoginStatus 401 'Hatalı parola reddedilmedi.'
    Assert-Equal $login.user.email $testEmail 'Login kullanıcı e-postası hatalı.'
    Assert-Equal $login.user.municipalityCode 'DEMO' 'Login belediye kapsamı hatalı.'
    Assert-Equal $me.email $testEmail 'Bearer /me kullanıcı bilgisi hatalı.'
    Assert-Equal ($me.roles -contains 'PERSONEL') $true 'PERSONEL rolü tokena eklenmedi.'
    Assert-Equal $applicationReferences.helpTypes.Count 1 `
        'Yardım türü referans kataloğuna gelmedi.'
    Assert-Equal $applicationReferences.helpTypes[0].code 'GIDA' `
        'Yardım türü kararlı kodu hatalı.'
    Assert-Equal $applicationReferences.disabilityStatuses[0].code 'YOK' `
        'Engel yok form seçeneği referans kataloğuna gelmedi.'
    Assert-Equal $applicationReferences.householdQuestions.Count 5 `
        'Hane soruları referans kataloğuna gelmedi.'
    Assert-Equal ($refreshed.refreshToken -ne $login.refreshToken) $true `
        'Refresh token döndürülmedi.'
    Assert-Equal $reuseStatus 401 'Eski refresh token tekrar kullanımı reddedilmedi.'
    Assert-Equal ([int]$logoutResponse.StatusCode) 204 'Logout sonucu hatalı.'
    Assert-Equal $loggedOutRefreshStatus 401 'Çıkış yapılan token tekrar kullanılabildi.'
    Assert-Equal $application.statusCode 'TASLAK' 'Taslak başvuru durumu hatalı.'
    Assert-Equal $applicationFromGet.identityNumber '12345678901' 'Başvuru tekrar okunamadı.'
    Assert-Equal $updatedApplication.phoneNumber '5557654321' 'Taslak güncellenemedi.'
    Assert-Equal $missingRequiredHouseholdStatus 400 `
        'Eksik zorunlu hane cevabı API tarafından reddedilmedi.'
    Assert-Equal $draftSnapshot.familyMembers.Count 1 'Taslak snapshot aile üyelerini döndürmedi.'
    Assert-Equal $draftSnapshot.householdAnswers.Count 5 'Taslak snapshot hane cevaplarını döndürmedi.'
    Assert-Equal $draftSnapshot.photos.Count 1 'Taslak snapshot aktif fotoğraf metadata bilgisini döndürmedi.'
    Assert-Equal ([int]$downloadedPhoto.StatusCode) 200 'Taslak fotoğrafı yetkilendirilmiş endpointten indirilemedi.'
    Assert-Equal $downloadedPhoto.Content.Length $replacementPhotoBytes.Length 'İndirilen taslak fotoğrafının boyutu hatalı.'
    Assert-Equal $draftWorkItems.Count 1 'Kaydedilen taslak bekleyen iş listesine gelmedi.'
    Assert-Equal $draftWorkItems[0].applicationPublicId $application.applicationPublicId 'İş listesi yanlış başvuruyu döndürdü.'
    Assert-Equal $draftWorkItems[0].isEditable $true 'Taslak iş listesinde düzenlenebilir görünmüyor.'
    Assert-Equal $submittedApplication.statusCode 'KURUL_BEKLIYOR' 'Başvuru kurula gönderilemedi.'
    Assert-Equal $submittedApplication.isEditable $false 'Kurula gönderilen başvuru kilitlenmedi.'
    Assert-Equal $submittedWorkItems[0].statusCode 'KURUL_BEKLIYOR' 'Kurula gönderilen başvuru bekleyen listede güncellenmedi.'
    Assert-Equal $submittedWorkItems[0].isEditable $false 'Kurula gönderilen iş listede düzenlenebilir kaldı.'
    Assert-Equal $lockedUpdateStatus 409 'Kilitli başvuru tekrar düzenlenebildi.'
    Assert-Equal $lockedFieldDataStatus 409 'Kilitli başvurunun aile bilgileri değiştirilebildi.'
    Assert-Equal $lockedPhotoUploadStatus 409 'Kilitli başvuruya fotoğraf yüklenebildi.'
    Assert-Equal $applicationStoredInSplitTables $true 'Başvuru ve aile bilgileri dbo ile metadata tablolarına birlikte yazılmadı.'
    Assert-Equal $householdAnswerCount 5 'Hane cevapları soru ve seçenek kodlarıyla kaydedilemedi.'
    Assert-Equal $activePhotoCount 1 'Aktif fotoğraf anlık kopyası tekil değil.'
    Assert-Equal $photoHistoryCount 2 'Fotoğraf değiştirme audit metadata kaydı eksik.'
    Assert-Equal $photoFileExists $true 'Fotoğraf özel dosya deposuna yazılmadı.'
    Assert-Equal $deletedPhotoFileRemoved $true 'Değiştirilen eski fotoğraf dosyası temizlenmedi.'
    Assert-Equal $applicationHistoryCount 2 'Başvuru durum geçmişi eksik.'

    $validationSucceeded = $true
    [pscustomobject]@{
        ReadyStatus = $health.status
        InvalidPasswordStatus = $invalidLoginStatus
        LoginUser = $login.user.email
        Municipality = $login.user.municipalityCode
        CurrentUser = $me.email
        Roles = ($me.roles -join ',')
        HelpTypeReferenceCount = $applicationReferences.helpTypes.Count
        HouseholdQuestionReferenceCount = `
            $applicationReferences.householdQuestions.Count
        RefreshRotated = ($refreshed.refreshToken -ne $login.refreshToken)
        ReusedTokenStatus = $reuseStatus
        LogoutStatus = [int]$logoutResponse.StatusCode
        LoggedOutTokenStatus = $loggedOutRefreshStatus
        ApplicationStatus = $submittedApplication.statusCode
        MissingRequiredHouseholdStatus = $missingRequiredHouseholdStatus
        LockedUpdateStatus = $lockedUpdateStatus
        LockedFieldDataStatus = $lockedFieldDataStatus
        LockedPhotoUploadStatus = $lockedPhotoUploadStatus
        SplitTableStorage = $applicationStoredInSplitTables
        HouseholdAnswerCount = $householdAnswerCount
        ActivePhotoCount = $activePhotoCount
        PhotoHistoryCount = $photoHistoryCount
        PhotoFileStored = $photoFileExists
        ReplacedPhotoFileRemoved = $deletedPhotoFileRemoved
        DraftSnapshotFamilyCount = $draftSnapshot.familyMembers.Count
        DraftSnapshotHouseholdCount = $draftSnapshot.householdAnswers.Count
        DraftSnapshotPhotoCount = $draftSnapshot.photos.Count
        DraftWorkItemEditable = $draftWorkItems[0].isEditable
        SubmittedWorkItemEditable = $submittedWorkItems[0].isEditable
        ApplicationHistoryCount = $applicationHistoryCount
        ResultCode = 'COMPANY_SCHEMA_HTTP_AUTH_APPLICATION_DRAFT_SNAPSHOT_OK'
    }
}
catch {
    # Test hata verirse API sureci durdurulmadan once son log satirlari gosterilir.
    # Gecici calisma klasoru yine finally blogunda tamamen temizlenir.
    Write-Output 'API_STDOUT_TAIL_BEGIN'
    Get-Content -LiteralPath $stdoutPath -Tail 200 -ErrorAction SilentlyContinue |
        Write-Output
    Write-Output 'API_STDOUT_TAIL_END'
    Write-Output 'API_STDERR_TAIL_BEGIN'
    Get-Content -LiteralPath $stderrPath -Tail 200 -ErrorAction SilentlyContinue |
        Write-Output
    Write-Output 'API_STDERR_TAIL_END'
    throw
}
finally {
    if ($null -ne $apiProcess -and -not $apiProcess.HasExited) {
        Stop-Process -Id $apiProcess.Id -Force
        Wait-Process -Id $apiProcess.Id -ErrorAction SilentlyContinue
    }

    $env:ConnectionStrings__SosyoBel = $oldConnection
    $env:Authentication__Jwt__SigningKeyBase64 = $oldSigningKey
    $env:ASPNETCORE_ENVIRONMENT = $oldEnvironment
    $env:ApplicationPhotos__RootPath = $oldPhotoRoot

    if ($null -ne $connection) {
        $connection.Dispose()
        $connection = $null
    }

    if ($databaseCreated) {
        # Başarısız CREATE/ChangeDatabase sonrasında aynı bağlantı kullanılamaz
        # durumda olabilir. Temizlik her zaman yeni bir master bağlantısıyla yapılır.
        $cleanupConnectionString = (
            'Server=' + $SqlServer +
            ';Database=master;Integrated Security=True;' +
            'Encrypt=True;TrustServerCertificate=True;Connect Timeout=60'
        )
        $cleanupConnection =
            New-Object System.Data.SqlClient.SqlConnection $cleanupConnectionString
        try {
            $cleanupConnection.Open()
            $cleanupCommand = $cleanupConnection.CreateCommand()
            try {
                $cleanupCommand.CommandTimeout = 180
                $cleanupCommand.CommandText =
                    'IF DB_ID(N''' + $databaseName + ''') IS NOT NULL BEGIN ' +
                    'ALTER DATABASE [' + $databaseName + '] SET SINGLE_USER ' +
                    'WITH ROLLBACK IMMEDIATE; DROP DATABASE [' + $databaseName + ']; END;'
                try {
                    $null = $cleanupCommand.ExecuteNonQuery()
                    Write-Output ('DATABASE_CLEANUP_OK ' + $databaseName)
                }
                catch {
                    $cleanupFailure = $_
                    $probeCommand = $cleanupConnection.CreateCommand()
                    try {
                        $probeCommand.CommandTimeout = 60
                        $probeCommand.CommandText =
                            'SELECT DB_ID(N''' + $databaseName + ''');'
                        $remainingDatabaseId = $probeCommand.ExecuteScalar()
                    }
                    catch {
                        $remainingDatabaseId = -1
                    }
                    finally {
                        $probeCommand.Dispose()
                    }

                    if ($null -eq $remainingDatabaseId -or
                        [DBNull]::Value.Equals($remainingDatabaseId)) {
                        Write-Output ('DATABASE_CLEANUP_ALREADY_ABSENT ' + $databaseName)
                    }
                    elseif ($validationSucceeded) {
                        throw $cleanupFailure
                    }
                    else {
                        # Asil test hatasi maskelenmez; kalan GUID adi logda acikca
                        # gorunur ve bir sonraki kontrollu temizlikte hedeflenebilir.
                        Write-Warning (
                            'DATABASE_CLEANUP_FAILED ' + $databaseName + ': ' +
                            $cleanupFailure.Exception.GetBaseException().Message
                        )
                    }
                }
            }
            finally {
                $cleanupCommand.Dispose()
            }
        }
        finally {
            $cleanupConnection.Dispose()
        }
    }

    if (Test-Path -LiteralPath $runRoot) {
        Remove-Item -LiteralPath $runRoot -Recurse -Force
    }
}
