param(
    [string]$SqlServer = 'np:\\.\pipe\sql\query',
    [int]$ApiPort = 5091,
    [string]$DotnetPath = 'C:\Program Files\dotnet\dotnet.exe'
)

$ErrorActionPreference = 'Stop'
$workspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$apiProject = Join-Path $workspaceRoot 'backend/src/SosyoBel.Api/SosyoBel.Api.csproj'
$runId = [Guid]::NewGuid().ToString('N')
$databaseName = 'SosyoBelIdentityValidation_' + $runId
$tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$runRoot = [IO.Path]::GetFullPath(
    (Join-Path $tempRoot ('sosyobel-identity-validation-' + $runId))
)
$buildOutput = Join-Path $runRoot 'bin'
$stdoutPath = Join-Path $runRoot 'api.stdout.log'
$stderrPath = Join-Path $runRoot 'api.stderr.log'
$apiProcess = $null
$connection = $null
$databaseCreated = $false

$oldConnection = $env:ConnectionStrings__SosyoBel
$oldSigningKey = $env:Authentication__Jwt__SigningKeyBase64
$oldEnvironment = $env:ASPNETCORE_ENVIRONMENT

# Bu hesap yalnız her çalıştırmada silinen geçici doğrulama veritabanında bulunur.
$testUsername = 'personel.demo'
$testEmail = 'personel@demo.bel.tr'
$testPassword = 'TestPersonel2026'
$testPasswordHash =
    'AQAAAAIAAYagAAAAEBsIJrTuKzYLrPj0MRENhvMhs3UHg5RTYQRZ1nLrbU6NEj0mPJyz4YkeSHqzKCpmPQ=='

if (-not $databaseName.StartsWith(
    'SosyoBelIdentityValidation_',
    [StringComparison]::Ordinal)) {
    throw 'Geçici veritabanı güvenlik öneki doğrulanamadı.'
}

if (-not $runRoot.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Geçici çalışma klasörü sistem temp dizininde değil.'
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

if (Get-NetTCPConnection -LocalPort $ApiPort -State Listen -ErrorAction SilentlyContinue) {
    throw "API doğrulama portu kullanımda: $ApiPort"
}

try {
    $null = New-Item -ItemType Directory -Path $runRoot

    # Test derlemesi açık geliştirme sürecinin bin klasörünü kilitlemez.
    & $DotnetPath build $apiProject --no-restore "-p:BaseOutputPath=$buildOutput/"
    if ($LASTEXITCODE -ne 0) {
        throw 'Geçici Identity API derlemesi başarısız oldu.'
    }

    $apiDll = Join-Path $buildOutput 'Debug/net10.0/SosyoBel.Api.dll'
    if (-not (Test-Path -LiteralPath $apiDll)) {
        throw 'Geçici API DLL dosyası bulunamadı.'
    }

    $masterConnectionString = (
        'Server=' + $SqlServer +
        ';Database=master;Integrated Security=True;' +
        'Encrypt=True;TrustServerCertificate=True;Connect Timeout=15'
    )
    $connection = New-Object System.Data.SqlClient.SqlConnection $masterConnectionString
    $connection.Open()
    $databaseCreated = $true
    Invoke-CommandText ('CREATE DATABASE [' + $databaseName + '];')
    $connection.ChangeDatabase($databaseName)

    # Yalnız şirket şemasında zaten bulunan standart dbo Identity tabloları kurulur.
    # sosyobel şeması ve uygulama uyumluluk migration'ları bilerek çalıştırılmaz.
    Invoke-SqlFile 'database/compatibility/tests/000_create_minimal_company_fixture.sql'
    Invoke-SqlFile 'database/compatibility/tests/007_expand_company_identity_fixture.sql'

    $seedSql = @"
INSERT INTO dbo.AspNetUsers
(
    Id, Ad, Soyad, UserName, NormalizedUserName, Email, NormalizedEmail,
    EmailConfirmed, PasswordHash, SecurityStamp, ConcurrencyStamp,
    PhoneNumberConfirmed, TwoFactorEnabled, LockoutEnabled, AccessFailedCount
)
VALUES
(
    N'identity-test-user-1', N'Test', N'Personel', N'$testUsername',
    N'PERSONEL.DEMO', N'$testEmail', N'PERSONEL@DEMO.BEL.TR', 1,
    N'$testPasswordHash', N'test-security-stamp', N'test-concurrency-stamp',
    0, 0, 1, 0
);

INSERT INTO dbo.AspNetRoles (Id, Name, NormalizedName, ConcurrencyStamp)
VALUES (N'identity-test-role-personel', N'Personel', N'PERSONEL', N'test-role-stamp');

INSERT INTO dbo.AspNetUserRoles (UserId, RoleId)
VALUES (N'identity-test-user-1', N'identity-test-role-personel');
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

    $apiWorkingDirectory = Split-Path -Parent $apiDll
    $startParameters = @{
        FilePath = $DotnetPath
        ArgumentList = @($apiDll, '--urls', "http://127.0.0.1:$ApiPort")
        WorkingDirectory = $apiWorkingDirectory
        RedirectStandardOutput = $stdoutPath
        RedirectStandardError = $stderrPath
        WindowStyle = 'Hidden'
        PassThru = $true
    }
    $apiProcess = Start-Process @startParameters

    $health = $null
    for ($attempt = 0; $attempt -lt 40; $attempt++) {
        Start-Sleep -Milliseconds 500
        try {
            $health = Invoke-RestMethod -Uri "http://127.0.0.1:$ApiPort/health/live" -TimeoutSec 2
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
        username = $testUsername
        password = 'WrongPassword2026'
    } | ConvertTo-Json -Compress
    try {
        $null = Invoke-WebRequest -UseBasicParsing -Method Post -Uri "http://127.0.0.1:$ApiPort/api/v1/auth/login" -ContentType 'application/json' -Body $invalidBody
        $invalidLoginStatus = 200
    }
    catch {
        $invalidLoginStatus = Get-HttpErrorStatus $_.Exception
    }

    $loginBody = @{
        username = $testUsername
        password = $testPassword
    } | ConvertTo-Json -Compress
    $login = Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:$ApiPort/api/v1/auth/login" -Headers @{ 'X-Device-Id' = 'identity-validation-device' } -ContentType 'application/json' -Body $loginBody
    $me = Invoke-RestMethod -Uri "http://127.0.0.1:$ApiPort/api/v1/auth/me" -Headers @{ Authorization = "Bearer $($login.accessToken)" }

    $refreshBody = @{
        refreshToken = $login.refreshToken
    } | ConvertTo-Json -Compress
    $refreshed = Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:$ApiPort/api/v1/auth/refresh" -Headers @{ 'X-Device-Id' = 'identity-validation-device' } -ContentType 'application/json' -Body $refreshBody

    $logoutBody = @{
        refreshToken = $refreshed.refreshToken
    } | ConvertTo-Json -Compress
    $logout = Invoke-WebRequest -UseBasicParsing -Method Post -Uri "http://127.0.0.1:$ApiPort/api/v1/auth/logout" -ContentType 'application/json' -Body $logoutBody

    try {
        $null = Invoke-WebRequest -UseBasicParsing -Method Post -Uri "http://127.0.0.1:$ApiPort/api/v1/auth/refresh" -Headers @{ 'X-Device-Id' = 'identity-validation-device' } -ContentType 'application/json' -Body $logoutBody
        $loggedOutRefreshStatus = 200
    }
    catch {
        $loggedOutRefreshStatus = Get-HttpErrorStatus $_.Exception
    }

    Assert-Equal $health.status 'Healthy' 'Liveness sonucu hatalı.'
    Assert-Equal $invalidLoginStatus 401 'Hatalı parola reddedilmedi.'
    Assert-Equal $login.user.username $testUsername 'Kullanıcı adı hatalı.'
    Assert-Equal ($login.user.roles -contains 'Personel') $true 'Mevcut Personel rolü tokena eklenmedi.'
    Assert-Equal ($login.user.PSObject.Properties.Name -contains 'municipalityCode') $false 'Login cevabında eski municipalityCode alanı kaldı.'
    Assert-Equal $me.username $testUsername '/me kullanıcı adı hatalı.'
    Assert-Equal ($refreshed.refreshToken -ne $login.refreshToken) $true 'Refresh token döndürülmedi.'
    Assert-Equal ([int]$logout.StatusCode) 204 'Logout sonucu hatalı.'
    Assert-Equal $loggedOutRefreshStatus 401 'Çıkış yapılan refresh token yeniden kullanılabildi.'

    [pscustomobject]@{
        LoginUsername = $login.user.username
        Roles = ($login.user.roles -join ',')
        MunicipalityCodeReturned = (
            $login.user.PSObject.Properties.Name -contains 'municipalityCode'
        )
        RefreshRotated = ($refreshed.refreshToken -ne $login.refreshToken)
        LogoutStatus = [int]$logout.StatusCode
        LoggedOutTokenStatus = $loggedOutRefreshStatus
        ResultCode = 'EXISTING_DBO_IDENTITY_HTTP_FLOW_OK'
    }
}
catch {
    Write-Output 'API_STDOUT_TAIL_BEGIN'
    Get-Content -LiteralPath $stdoutPath -Tail 100 -ErrorAction SilentlyContinue |
        Write-Output
    Write-Output 'API_STDOUT_TAIL_END'
    Write-Output 'API_STDERR_TAIL_BEGIN'
    Get-Content -LiteralPath $stderrPath -Tail 100 -ErrorAction SilentlyContinue |
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

    if ($null -ne $connection) {
        $connection.Dispose()
        $connection = $null
    }

    if ($databaseCreated) {
        $cleanupConnection = New-Object System.Data.SqlClient.SqlConnection $masterConnectionString
        try {
            $cleanupConnection.Open()
            $cleanupCommand = $cleanupConnection.CreateCommand()
            try {
                $cleanupCommand.CommandTimeout = 180
                $cleanupCommand.CommandText =
                    'IF DB_ID(N''' + $databaseName + ''') IS NOT NULL BEGIN ' +
                    'ALTER DATABASE [' + $databaseName + '] SET SINGLE_USER ' +
                    'WITH ROLLBACK IMMEDIATE; DROP DATABASE [' + $databaseName + ']; END;'
                $null = $cleanupCommand.ExecuteNonQuery()
                Write-Output ('DATABASE_CLEANUP_OK ' + $databaseName)
            }
            finally {
                $cleanupCommand.Dispose()
            }
        }
        finally {
            $cleanupConnection.Dispose()
        }
    }

    # Yalnız bu koşu için üretilmiş, doğrulanmış sistem temp klasörü temizlenir.
    if ((Test-Path -LiteralPath $runRoot) -and
        $runRoot.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase)) {
        Remove-Item -LiteralPath $runRoot -Recurse -Force
    }
}
