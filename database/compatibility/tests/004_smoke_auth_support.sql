/*
    Uyumluluk 002 auth tabloları için transaction içi smoke testi.
    Bütün test verileri sonda rollback edilir.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRANSACTION;

BEGIN TRY
    DECLARE @AdminUserId nvarchar(450) = N'compat-auth-admin';
    DECLARE @PersonnelUserId nvarchar(450) = N'compat-auth-personnel';
    DECLARE @NowUtc datetime2(3) = SYSUTCDATETIME();
    DECLARE @MunicipalityId int;

    INSERT INTO dbo.AspNetUsers (Id)
    VALUES (@AdminUserId), (@PersonnelUserId);

    INSERT INTO sosyobel.KullaniciUygulamaBilgileri (UserId)
    VALUES (@AdminUserId), (@PersonnelUserId);

    INSERT INTO sosyobel.Belediyeler (Kod, Ad)
    VALUES (N'TEST', N'Uyumluluk Test Belediyesi');

    SET @MunicipalityId = CONVERT(int, SCOPE_IDENTITY());

    INSERT INTO sosyobel.KullaniciBelediyeleri
        (UserId, BelediyeId, RolKodu)
    VALUES
        (@AdminUserId, @MunicipalityId, N'BELEDIYE_YONETICISI'),
        (@PersonnelUserId, @MunicipalityId, N'PERSONEL');

    INSERT INTO sosyobel.KullaniciYetkileri
        (UserId, BelediyeId, YetkiKodu, VerenUserId)
    VALUES
        (
            @PersonnelUserId,
            @MunicipalityId,
            N'KILITLI_BASVURU_DUZENLE',
            @AdminUserId
        );

    INSERT INTO sosyobel.IslemGecmisleri
        (
            BelediyeId,
            VarlikTuru,
            IslemKodu,
            OlusturanUserId,
            CorrelationId,
            HedefUserId
        )
    VALUES
        (
            @MunicipalityId,
            N'KULLANICI',
            N'UYUMLULUK_TESTI',
            @AdminUserId,
            NEWID(),
            @PersonnelUserId
        );

    INSERT INTO sosyobel.IdempotencyKayitlari
        (
            ActorUserId,
            ActorUserIdHash,
            EndpointKodu,
            IdempotencyKey,
            IstekHash,
            OlusturulmaTarihiUtc,
            SonKullanmaTarihiUtc
        )
    VALUES
        (
            @AdminUserId,
            HASHBYTES('SHA2_256', CONVERT(varbinary(max), @AdminUserId)),
            N'COMPATIBILITY_TEST',
            N'compat-key-0001',
            HASHBYTES('SHA2_256', CONVERT(varbinary(max), N'compat-request')),
            @NowUtc,
            DATEADD(hour, 1, @NowUtc)
        );

    INSERT INTO sosyobel.YenilemeTokenlari
        (UserId, TokenHash, OlusturulmaTarihiUtc, SonKullanmaTarihiUtc)
    VALUES
        (
            @PersonnelUserId,
            HASHBYTES('SHA2_256', CONVERT(varbinary(max), N'compat-refresh')),
            @NowUtc,
            DATEADD(day, 1, @NowUtc)
        );

    IF
    (
        SELECT COUNT(*)
        FROM sosyobel.KullaniciBelediyeleri
        WHERE BelediyeId = @MunicipalityId
    ) <> 2
    BEGIN
        THROW 51270, N'Auth smoke testi kullanıcı üyeliklerini doğrulayamadı.', 1;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sosyobel.KullaniciYetkileri AS permissionInfo
        INNER JOIN sosyobel.KullaniciUygulamaBilgileri AS userInfo
            ON userInfo.UserId = permissionInfo.UserId
        WHERE permissionInfo.UserId = @PersonnelUserId
          AND permissionInfo.BelediyeId = @MunicipalityId
          AND permissionInfo.AktifMi = 1
          AND userInfo.AktifMi = 1
    )
    BEGIN
        THROW 51271, N'Auth smoke testi aktif kullanıcı yetkisini doğrulayamadı.', 1;
    END;

    IF (SELECT COUNT(*) FROM sosyobel.IslemGecmisleri) <> 1 OR
       (SELECT COUNT(*) FROM sosyobel.IdempotencyKayitlari) <> 1 OR
       (SELECT COUNT(*) FROM sosyobel.YenilemeTokenlari) <> 1
    BEGIN
        THROW 51272, N'Auth smoke testi teknik kayıtları doğrulayamadı.', 1;
    END;

    ROLLBACK TRANSACTION;
    PRINT N'COMPATIBILITY_AUTH_SMOKE_OK';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
