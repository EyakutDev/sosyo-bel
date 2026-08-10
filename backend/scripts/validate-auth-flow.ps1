param(
    [string]$SqlServer = 'localhost',
    [int]$ApiPort = 5088,
    [string]$DotnetPath = 'C:\Program Files\dotnet\dotnet.exe'
)

$ErrorActionPreference = 'Stop'
$databaseName = "SosyoBelAuthValidation_$PID"
$workspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$apiProject = 'backend\src\SosyoBel.Api\SosyoBel.Api.csproj'
$stdoutPath = Join-Path ([IO.Path]::GetTempPath()) "sosyobel-auth-$PID.stdout.log"
$stderrPath = Join-Path ([IO.Path]::GetTempPath()) "sosyobel-auth-$PID.stderr.log"
$apiProcess = $null
$oldConnection = $env:ConnectionStrings__SosyoBel
$oldSigningKey = $env:Authentication__Jwt__SigningKeyBase64

# Bu kullanıcı ve parola yalnız her çalıştırmada silinen doğrulama veritabanındadır.
$testEmail = 'personel@demo.bel.tr'
$testPassword = 'TestPersonel2026'
$testPasswordHash = 'AQAAAAIAAYagAAAAEBsIJrTuKzYLrPj0MRENhvMhs3UHg5RTYQRZ1nLrbU6NEj0mPJyz4YkeSHqzKCpmPQ=='

function Invoke-SqlFile([string]$relativePath) {
    & sqlcmd -S $SqlServer -E -C -b -d $databaseName -i (Join-Path $workspaceRoot $relativePath)
    if ($LASTEXITCODE -ne 0) {
        throw "SQL dosyası başarısız: $relativePath"
    }
}

function Get-HttpErrorStatus($exception) {
    return [int]$exception.Response.StatusCode
}

$exists = & sqlcmd -S $SqlServer -E -C -h -1 -W -Q "SET NOCOUNT ON; SELECT CASE WHEN DB_ID(N'$databaseName') IS NULL THEN 0 ELSE 1 END;"
if (($exists -join '').Trim() -ne '0') {
    throw "Geçici doğrulama veritabanı zaten var: $databaseName"
}

if (Get-NetTCPConnection -LocalPort $ApiPort -State Listen -ErrorAction SilentlyContinue) {
    throw "API doğrulama portu kullanımda: $ApiPort"
}

try {
    & sqlcmd -S $SqlServer -E -C -b -Q "CREATE DATABASE [$databaseName];"
    if ($LASTEXITCODE -ne 0) {
        throw 'Auth doğrulama veritabanı oluşturulamadı.'
    }

    Invoke-SqlFile 'database\migrations\000_create_aspnet_identity_schema.sql'
    Invoke-SqlFile 'database\migrations\001_create_sosyobel_v2_schema.sql'
    Invoke-SqlFile 'database\migrations\002_create_municipality_integrations.sql'
    Invoke-SqlFile 'database\migrations\003_create_access_control_and_audit.sql'
    Invoke-SqlFile 'database\migrations\004_harden_identity_tasks_and_idempotency.sql'
    Invoke-SqlFile 'database\seed\001_confirmed_reference_data.sql'

    $seedSql = @"
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
DECLARE @MunicipalityId int;
INSERT INTO sosyobel.Belediyeler (Kod, Ad) VALUES (N'DEMO', N'Demo Belediyesi');
SET @MunicipalityId = SCOPE_IDENTITY();
INSERT INTO dbo.AspNetUsers
    (Id, UserName, NormalizedUserName, Email, NormalizedEmail, EmailConfirmed,
     PasswordHash, SecurityStamp, ConcurrencyStamp, PhoneNumberConfirmed,
     TwoFactorEnabled, LockoutEnabled, AccessFailedCount, Ad, Soyad, AktifMi)
VALUES
    (N'auth-test-user-1', N'$testEmail', N'PERSONEL@DEMO.BEL.TR', N'$testEmail',
     N'PERSONEL@DEMO.BEL.TR', 1, N'$testPasswordHash', N'test-security-stamp',
     N'test-concurrency-stamp', 0, 0, 1, 0, N'Test', N'Personel', 1);
INSERT INTO sosyobel.KullaniciBelediyeleri (UserId, BelediyeId, RolKodu)
VALUES (N'auth-test-user-1', @MunicipalityId, N'PERSONEL');
"@

    & sqlcmd -S $SqlServer -E -C -b -d $databaseName -Q $seedSql
    if ($LASTEXITCODE -ne 0) {
        throw 'Auth doğrulama kullanıcısı oluşturulamadı.'
    }

    $env:ConnectionStrings__SosyoBel = "Server=$SqlServer;Database=$databaseName;Integrated Security=True;Encrypt=True;TrustServerCertificate=True"
    $keyBytes = New-Object byte[] 32
    $random = [Security.Cryptography.RandomNumberGenerator]::Create()
    $random.GetBytes($keyBytes)
    $random.Dispose()
    $env:Authentication__Jwt__SigningKeyBase64 = [Convert]::ToBase64String($keyBytes)

    $apiProcess = Start-Process -FilePath $DotnetPath `
        -ArgumentList @('run', '--no-build', '--project', $apiProject, '--urls', "http://127.0.0.1:$ApiPort") `
        -WorkingDirectory $workspaceRoot `
        -RedirectStandardOutput $stdoutPath `
        -RedirectStandardError $stderrPath `
        -WindowStyle Hidden `
        -PassThru

    $health = $null
    for ($attempt = 0; $attempt -lt 40; $attempt++) {
        Start-Sleep -Milliseconds 500
        try {
            $health = Invoke-RestMethod -Uri "http://127.0.0.1:$ApiPort/health/ready" -TimeoutSec 2
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

    $invalidBody = @{ email = $testEmail; password = 'WrongPassword2026' } | ConvertTo-Json
    try {
        $null = Invoke-WebRequest -UseBasicParsing -Method Post `
            -Uri "http://127.0.0.1:$ApiPort/api/v1/auth/login" `
            -ContentType 'application/json' -Body $invalidBody -TimeoutSec 10
        $invalidLoginStatus = 200
    }
    catch {
        $invalidLoginStatus = Get-HttpErrorStatus $_.Exception
    }

    $loginBody = @{ email = $testEmail; password = $testPassword } | ConvertTo-Json
    $login = Invoke-RestMethod -Method Post `
        -Uri "http://127.0.0.1:$ApiPort/api/v1/auth/login" `
        -Headers @{ 'X-Device-Id' = 'integration-test-device' } `
        -ContentType 'application/json' -Body $loginBody -TimeoutSec 10

    $me = Invoke-RestMethod -Uri "http://127.0.0.1:$ApiPort/api/v1/auth/me" `
        -Headers @{ Authorization = "Bearer $($login.accessToken)" } -TimeoutSec 10

    $refreshBody = @{ refreshToken = $login.refreshToken } | ConvertTo-Json
    $refreshed = Invoke-RestMethod -Method Post `
        -Uri "http://127.0.0.1:$ApiPort/api/v1/auth/refresh" `
        -Headers @{ 'X-Device-Id' = 'integration-test-device' } `
        -ContentType 'application/json' -Body $refreshBody -TimeoutSec 10

    try {
        $null = Invoke-WebRequest -UseBasicParsing -Method Post `
            -Uri "http://127.0.0.1:$ApiPort/api/v1/auth/refresh" `
            -ContentType 'application/json' -Body $refreshBody -TimeoutSec 10
        $reuseStatus = 200
    }
    catch {
        $reuseStatus = Get-HttpErrorStatus $_.Exception
    }

    $logoutBody = @{ refreshToken = $refreshed.refreshToken } | ConvertTo-Json
    $logoutResponse = Invoke-WebRequest -UseBasicParsing -Method Post `
        -Uri "http://127.0.0.1:$ApiPort/api/v1/auth/logout" `
        -ContentType 'application/json' -Body $logoutBody -TimeoutSec 10

    try {
        $null = Invoke-WebRequest -UseBasicParsing -Method Post `
            -Uri "http://127.0.0.1:$ApiPort/api/v1/auth/refresh" `
            -ContentType 'application/json' -Body $logoutBody -TimeoutSec 10
        $loggedOutRefreshStatus = 200
    }
    catch {
        $loggedOutRefreshStatus = Get-HttpErrorStatus $_.Exception
    }

    [pscustomobject]@{
        ReadyStatus = $health.status
        InvalidPasswordStatus = $invalidLoginStatus
        LoginUser = $login.user.email
        Municipality = $login.user.municipalityCode
        CurrentUser = $me.email
        Roles = ($me.roles -join ',')
        RefreshRotated = ($refreshed.refreshToken -ne $login.refreshToken)
        ReusedTokenStatus = $reuseStatus
        LogoutStatus = [int]$logoutResponse.StatusCode
        LoggedOutTokenStatus = $loggedOutRefreshStatus
    }
}
finally {
    if ($null -ne $apiProcess -and -not $apiProcess.HasExited) {
        Stop-Process -Id $apiProcess.Id -Force
        Wait-Process -Id $apiProcess.Id -ErrorAction SilentlyContinue
    }

    $env:ConnectionStrings__SosyoBel = $oldConnection
    $env:Authentication__Jwt__SigningKeyBase64 = $oldSigningKey

    & sqlcmd -S $SqlServer -E -C -b -Q "IF DB_ID(N'$databaseName') IS NOT NULL BEGIN ALTER DATABASE [$databaseName] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$databaseName]; END"
    if ($LASTEXITCODE -ne 0) {
        throw 'Auth doğrulama veritabanı kaldırılamadı.'
    }

    Remove-Item -LiteralPath $stdoutPath -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $stderrPath -Force -ErrorAction SilentlyContinue
}
