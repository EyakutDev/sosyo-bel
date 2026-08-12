param(
    [string]$SqlServer = 'localhost\MSSQLSERVER01',
    [int]$ApiPort = 5091,
    [string]$DotnetPath = 'C:\Program Files\dotnet\dotnet.exe'
)

$ErrorActionPreference = 'Stop'
$databaseName = "SosyoBelAdministrationValidation_$PID"
$workspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$apiProject = 'backend\src\SosyoBel.Api\SosyoBel.Api.csproj'
$bootstrapProject = 'backend\src\SosyoBel.Bootstrap\SosyoBel.Bootstrap.csproj'
$stdoutPath = Join-Path ([IO.Path]::GetTempPath()) "sosyobel-admin-$PID.stdout.log"
$stderrPath = Join-Path ([IO.Path]::GetTempPath()) "sosyobel-admin-$PID.stderr.log"
$apiProcess = $null
$maintenanceConnection = $null
$created = $false

# Bu hesaplar ve parolalar yalnız test sonunda silinen doğrulama veritabanındadır.
$systemEmail = 'system.admin@validation.invalid'
$systemPassword = 'SystemAdmin2026!'
$municipalityAdminEmail = 'municipality.admin@validation.invalid'
$municipalityAdminPassword = 'MunicipalityAdmin2026!'
$personnelEmail = 'personnel@validation.invalid'
$personnelPassword = 'PersonnelInitial2026!'
$personnelNewPassword = 'PersonnelReset2026!'

$environmentNames = @(
    'ConnectionStrings__SosyoBel',
    'Authentication__Jwt__SigningKeyBase64',
    'SOSYOBEL_BOOTSTRAP_EMAIL',
    'SOSYOBEL_BOOTSTRAP_FIRST_NAME',
    'SOSYOBEL_BOOTSTRAP_LAST_NAME',
    'SOSYOBEL_BOOTSTRAP_PASSWORD'
)
$oldEnvironment = @{}
foreach ($name in $environmentNames) {
    $oldEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}

function Set-ProcessEnvironment([string]$name, [string]$value) {
    [Environment]::SetEnvironmentVariable($name, $value, 'Process')
}

function Invoke-CommandText([string]$commandText) {
    $command = $maintenanceConnection.CreateCommand()
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
    Invoke-CommandText ([IO.File]::ReadAllText($absolutePath))
}

function Invoke-Scalar([string]$commandText) {
    $command = $maintenanceConnection.CreateCommand()
    try {
        $command.CommandTimeout = 30
        $command.CommandText = $commandText
        return $command.ExecuteScalar()
    }
    finally {
        $command.Dispose()
    }
}

function Get-HttpErrorStatus([scriptblock]$action) {
    try {
        $null = & $action
        return 200
    }
    catch {
        return [int]$_.Exception.Response.StatusCode
    }
}

function Stop-ApiProcess {
    if ($null -ne $script:apiProcess -and -not $script:apiProcess.HasExited) {
        Stop-Process -Id $script:apiProcess.Id -Force
        Wait-Process -Id $script:apiProcess.Id -ErrorAction SilentlyContinue
    }

    $script:apiProcess = $null
}

if (Get-NetTCPConnection -LocalPort $ApiPort -State Listen -ErrorAction SilentlyContinue) {
    throw "API doğrulama portu kullanımda: $ApiPort"
}

try {
    # Migrationlar tek açık bakım bağlantısında çalışır; bağlantı ayrıca finally
    # bloğunda yalnız bu test veritabanını güvenle kaldırmak için açık tutulur.
    $maintenanceConnection = New-Object System.Data.SqlClient.SqlConnection (
        "Server=$SqlServer;Database=master;Integrated Security=True;Encrypt=True;TrustServerCertificate=True;Connect Timeout=60")
    $maintenanceConnection.Open()

    if ([int](Invoke-Scalar "SELECT CASE WHEN DB_ID(N'$databaseName') IS NULL THEN 0 ELSE 1 END;") -ne 0) {
        throw "Geçici doğrulama veritabanı zaten var: $databaseName"
    }

    Invoke-CommandText "CREATE DATABASE [$databaseName];"
    $created = $true
    $maintenanceConnection.ChangeDatabase($databaseName)

    foreach ($file in @(
        'database\migrations\000_create_aspnet_identity_schema.sql',
        'database\migrations\001_create_sosyobel_v2_schema.sql',
        'database\migrations\002_create_municipality_integrations.sql',
        'database\migrations\003_create_access_control_and_audit.sql',
        'database\migrations\004_harden_identity_tasks_and_idempotency.sql',
        'database\migrations\005_create_application_number_sequence.sql',
        'database\migrations\006_add_kps_lookup_permission.sql',
        'database\migrations\007_create_user_application_info.sql',
        'database\seed\001_confirmed_reference_data.sql')) {
        Write-Output "RUN $file"
        Invoke-SqlFile $file
    }

    $connectionString = "Server=$SqlServer;Database=$databaseName;Integrated Security=True;Encrypt=True;TrustServerCertificate=True"
    Set-ProcessEnvironment 'ConnectionStrings__SosyoBel' $connectionString
    $keyBytes = New-Object byte[] 32
    $random = [Security.Cryptography.RandomNumberGenerator]::Create()
    $random.GetBytes($keyBytes)
    $random.Dispose()
    Set-ProcessEnvironment 'Authentication__Jwt__SigningKeyBase64' ([Convert]::ToBase64String($keyBytes))

    Set-ProcessEnvironment 'SOSYOBEL_BOOTSTRAP_EMAIL' $systemEmail
    Set-ProcessEnvironment 'SOSYOBEL_BOOTSTRAP_FIRST_NAME' 'Cats'
    Set-ProcessEnvironment 'SOSYOBEL_BOOTSTRAP_LAST_NAME' 'System Administrator'
    Set-ProcessEnvironment 'SOSYOBEL_BOOTSTRAP_PASSWORD' $systemPassword

    # İkinci çalıştırma hiçbir profil/parola değişikliği yapmadan başarılı olmalıdır.
    for ($attempt = 0; $attempt -lt 2; $attempt++) {
        $bootstrapOutput = & $DotnetPath run --no-build --project $bootstrapProject 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Bootstrap başarısız: $bootstrapOutput"
        }
    }

    # API sürecinin bootstrap parolasını miras almaması için hemen temizlenir.
    Set-ProcessEnvironment 'SOSYOBEL_BOOTSTRAP_PASSWORD' $null

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

    $systemLogin = Invoke-RestMethod -Method Post `
        -Uri "http://127.0.0.1:$ApiPort/api/v1/auth/login" `
        -ContentType 'application/json' `
        -Body (@{ email = $systemEmail; password = $systemPassword } | ConvertTo-Json) `
        -TimeoutSec 10
    if ($null -ne $systemLogin.user.municipalityCode -or
        $systemLogin.user.roles -notcontains 'SISTEM_YONETICISI') {
        throw 'Sistem yöneticisi tenant dışı rol ile giriş yapamadı.'
    }

    $systemHeaders = @{
        Authorization = "Bearer $($systemLogin.accessToken)"
        'Idempotency-Key' = 'create-municipality-0001'
        'X-Device-Id' = 'validation-system-device'
    }
    $municipalityBody = @{
        code = 'DEMO'
        name = 'Demo Belediyesi'
        administrator = @{
            email = $municipalityAdminEmail
            firstName = 'Demo'
            lastName = 'Yönetici'
            initialPassword = $municipalityAdminPassword
        }
    } | ConvertTo-Json -Depth 4
    $municipality = Invoke-RestMethod -Method Post `
        -Uri "http://127.0.0.1:$ApiPort/api/v1/system/municipalities" `
        -Headers $systemHeaders -ContentType 'application/json' `
        -Body $municipalityBody -TimeoutSec 10
    $municipalityReplay = Invoke-RestMethod -Method Post `
        -Uri "http://127.0.0.1:$ApiPort/api/v1/system/municipalities" `
        -Headers $systemHeaders -ContentType 'application/json' `
        -Body $municipalityBody -TimeoutSec 10
    if ($municipality.municipalityPublicId -ne $municipalityReplay.municipalityPublicId) {
        throw 'Belediye oluşturma idempotent replay sonucu değişti.'
    }

    $municipalityAdminLogin = Invoke-RestMethod -Method Post `
        -Uri "http://127.0.0.1:$ApiPort/api/v1/auth/login" `
        -ContentType 'application/json' `
        -Body (@{ email = $municipalityAdminEmail; password = $municipalityAdminPassword } | ConvertTo-Json) `
        -TimeoutSec 10
    $municipalityHeaders = @{
        Authorization = "Bearer $($municipalityAdminLogin.accessToken)"
        'Idempotency-Key' = 'create-personnel-0001'
        'X-Device-Id' = 'validation-municipality-device'
    }
    $personnelBody = @{
        email = $personnelEmail
        firstName = 'Demo'
        lastName = 'Personel'
        initialPassword = $personnelPassword
    } | ConvertTo-Json
    $personnel = Invoke-RestMethod -Method Post `
        -Uri "http://127.0.0.1:$ApiPort/api/v1/municipality/personnel/" `
        -Headers $municipalityHeaders -ContentType 'application/json' `
        -Body $personnelBody -TimeoutSec 10
    $personnelReplay = Invoke-RestMethod -Method Post `
        -Uri "http://127.0.0.1:$ApiPort/api/v1/municipality/personnel/" `
        -Headers $municipalityHeaders -ContentType 'application/json' `
        -Body $personnelBody -TimeoutSec 10
    if ($personnel.userId -ne $personnelReplay.userId) {
        throw 'Personel oluşturma idempotent replay sonucu değişti.'
    }

    $personnelLogin = Invoke-RestMethod -Method Post `
        -Uri "http://127.0.0.1:$ApiPort/api/v1/auth/login" `
        -ContentType 'application/json' `
        -Body (@{ email = $personnelEmail; password = $personnelPassword } | ConvertTo-Json) `
        -TimeoutSec 10
    $personnelHeaders = @{ Authorization = "Bearer $($personnelLogin.accessToken)" }

    $personnelAdminStatus = Get-HttpErrorStatus {
        Invoke-WebRequest -UseBasicParsing -Method Post `
            -Uri "http://127.0.0.1:$ApiPort/api/v1/municipality/personnel/" `
            -Headers @{
                Authorization = "Bearer $($personnelLogin.accessToken)"
                'Idempotency-Key' = 'forbidden-personnel-create-0001'
            } `
            -ContentType 'application/json' -Body $personnelBody -TimeoutSec 10
    }

    $assignedTasksResponse = Invoke-RestMethod `
        -Uri "http://127.0.0.1:$ApiPort/api/v1/tasks/assigned" `
        -Headers $personnelHeaders -TimeoutSec 10
    # Windows PowerShell 5.1 boş JSON dizisini tek, iç içe dizi olarak döndürebilir.
    # Pipeline üzerinden geçirmek gerçek öğe sayısını kararlı biçimde verir.
    $assignedTasks = @($assignedTasksResponse | ForEach-Object { $_ })

    $municipalityHeaders['Idempotency-Key'] = 'reset-personnel-0001'
    $null = Invoke-RestMethod -Method Post `
        -Uri "http://127.0.0.1:$ApiPort/api/v1/municipality/personnel/$($personnel.userId)/reset-password" `
        -Headers $municipalityHeaders -ContentType 'application/json' `
        -Body (@{ newPassword = $personnelNewPassword } | ConvertTo-Json) -TimeoutSec 10
    $oldRefreshStatus = Get-HttpErrorStatus {
        Invoke-WebRequest -UseBasicParsing -Method Post `
            -Uri "http://127.0.0.1:$ApiPort/api/v1/auth/refresh" `
            -ContentType 'application/json' `
            -Body (@{ refreshToken = $personnelLogin.refreshToken } | ConvertTo-Json) `
            -TimeoutSec 10
    }

    $personnelLoginAfterReset = Invoke-RestMethod -Method Post `
        -Uri "http://127.0.0.1:$ApiPort/api/v1/auth/login" `
        -ContentType 'application/json' `
        -Body (@{ email = $personnelEmail; password = $personnelNewPassword } | ConvertTo-Json) `
        -TimeoutSec 10

    $systemHeaders['Idempotency-Key'] = 'grant-locked-edit-0001'
    $permission = Invoke-RestMethod -Method Put `
        -Uri "http://127.0.0.1:$ApiPort/api/v1/system/municipalities/DEMO/personnel/$($personnel.userId)/permissions/locked-application-edit" `
        -Headers $systemHeaders -ContentType 'application/json' `
        -Body (@{ enabled = $true; reason = 'Gecici dogrulama yetkisi verildi.' } | ConvertTo-Json) `
        -TimeoutSec 10

    $systemAudit = @(Invoke-RestMethod `
        -Uri "http://127.0.0.1:$ApiPort/api/v1/system/audit?municipalityCode=DEMO" `
        -Headers @{ Authorization = "Bearer $($systemLogin.accessToken)" } -TimeoutSec 10)
    $municipalityAudit = @(Invoke-RestMethod `
        -Uri "http://127.0.0.1:$ApiPort/api/v1/municipality/audit" `
        -Headers @{ Authorization = "Bearer $($municipalityAdminLogin.accessToken)" } -TimeoutSec 10)

    $municipalityHeaders['Idempotency-Key'] = 'deactivate-personnel-0001'
    $null = Invoke-RestMethod -Method Post `
        -Uri "http://127.0.0.1:$ApiPort/api/v1/municipality/personnel/$($personnel.userId)/deactivate" `
        -Headers $municipalityHeaders -ContentType 'application/json' `
        -Body (@{ reason = 'Gecici dogrulama hesabi kapatildi.' } | ConvertTo-Json) `
        -TimeoutSec 10

    $staleAccessStatus = Get-HttpErrorStatus {
        Invoke-WebRequest -UseBasicParsing `
            -Uri "http://127.0.0.1:$ApiPort/api/v1/tasks/assigned" `
            -Headers @{ Authorization = "Bearer $($personnelLoginAfterReset.accessToken)" } `
            -TimeoutSec 10
    }
    $inactiveLoginStatus = Get-HttpErrorStatus {
        Invoke-WebRequest -UseBasicParsing -Method Post `
            -Uri "http://127.0.0.1:$ApiPort/api/v1/auth/login" `
            -ContentType 'application/json' `
            -Body (@{ email = $personnelEmail; password = $personnelNewPassword } | ConvertTo-Json) `
            -TimeoutSec 10
    }

    Stop-ApiProcess

    $globalTenantRoleCount = [int](Invoke-Scalar @"
SELECT COUNT(*)
FROM dbo.AspNetRoles
WHERE NormalizedName IN (N'PERSONEL', N'BELEDIYE_YONETICISI');
"@)
    $idempotencyCount = [int](Invoke-Scalar 'SELECT COUNT(*) FROM sosyobel.IdempotencyKayitlari;')
    $secretLeakCount = [int](Invoke-Scalar @"
SELECT COUNT(*)
FROM sosyobel.IslemGecmisleri
WHERE CONCAT(Aciklama, N' ', Gerekce, N' ', DegisiklikOzetiJson) LIKE N'%$systemPassword%'
   OR CONCAT(Aciklama, N' ', Gerekce, N' ', DegisiklikOzetiJson) LIKE N'%$municipalityAdminPassword%'
   OR CONCAT(Aciklama, N' ', Gerekce, N' ', DegisiklikOzetiJson) LIKE N'%$personnelPassword%'
   OR CONCAT(Aciklama, N' ', Gerekce, N' ', DegisiklikOzetiJson) LIKE N'%$personnelNewPassword%';
"@)

    $appendOnlyProtected = $false
    try {
        Invoke-CommandText @"
UPDATE sosyobel.IslemGecmisleri
SET Aciklama = Aciklama
WHERE Id = (SELECT MIN(Id) FROM sosyobel.IslemGecmisleri);
"@
    }
    catch [System.Data.SqlClient.SqlException] {
        $appendOnlyProtected = $_.Exception.Errors.Number -contains 51073
    }

    $validationDetails = [pscustomobject]@{
        PersonnelAdminStatus = $personnelAdminStatus
        OldRefreshStatus = $oldRefreshStatus
        StaleAccessStatus = $staleAccessStatus
        InactiveLoginStatus = $inactiveLoginStatus
        AssignedTaskCount = $assignedTasks.Count
        PermissionEnabled = $permission.enabled
        SystemAuditCount = $systemAudit.Count
        MunicipalityAuditCount = $municipalityAudit.Count
        GlobalTenantRoleCount = $globalTenantRoleCount
        IdempotencyCount = $idempotencyCount
        SecretLeakCount = $secretLeakCount
        AppendOnlyProtected = $appendOnlyProtected
    }

    if ($personnelAdminStatus -ne 403 -or
        $oldRefreshStatus -ne 401 -or
        $staleAccessStatus -ne 403 -or
        $inactiveLoginStatus -ne 401 -or
        $assignedTasks.Count -ne 0 -or
        -not $permission.enabled -or
        $systemAudit.Count -lt 1 -or
        $municipalityAudit.Count -lt 1 -or
        $globalTenantRoleCount -ne 0 -or
        $idempotencyCount -lt 5 -or
        $secretLeakCount -ne 0 -or
        -not $appendOnlyProtected) {
        Write-Output ($validationDetails | Format-List | Out-String)
        throw 'Yönetim akışı doğrulama beklentilerinden en az biri sağlanmadı.'
    }

    [pscustomobject]@{
        ReadyStatus = $health.status
        BootstrapIdempotent = $true
        MunicipalityIdempotent = $true
        PersonnelIdempotent = $true
        PersonnelAdminStatus = $personnelAdminStatus
        ResetRevokedRefreshStatus = $oldRefreshStatus
        DeactivatedAccessStatus = $staleAccessStatus
        DeactivatedLoginStatus = $inactiveLoginStatus
        AuditEventsVisible = $true
        AuditAppendOnly = $appendOnlyProtected
        SecretLeakCount = $secretLeakCount
    }
}
finally {
    Stop-ApiProcess

    foreach ($name in $environmentNames) {
        [Environment]::SetEnvironmentVariable($name, $oldEnvironment[$name], 'Process')
    }

    if ($null -ne $maintenanceConnection) {
        try {
            if ($created -and $maintenanceConnection.State -eq [Data.ConnectionState]::Open) {
                $maintenanceConnection.ChangeDatabase('master')
                Invoke-CommandText "ALTER DATABASE [$databaseName] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$databaseName];"
            }
        }
        finally {
            $maintenanceConnection.Dispose()
        }
    }

    Remove-Item -LiteralPath $stdoutPath -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $stderrPath -Force -ErrorAction SilentlyContinue
}
