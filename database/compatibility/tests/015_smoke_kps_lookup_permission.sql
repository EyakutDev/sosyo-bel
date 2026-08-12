/* KPS yetki kodunun eklenebildiğini veri bırakmadan doğrular. */

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRANSACTION;

BEGIN TRY
    DECLARE @AdminUserId nvarchar(450) = N'compat-kps-admin';
    DECLARE @PersonnelUserId nvarchar(450) = N'compat-kps-personnel';
    DECLARE @MunicipalityId int;

    INSERT INTO dbo.AspNetUsers (Id)
    VALUES (@AdminUserId), (@PersonnelUserId);

    INSERT INTO sosyobel.KullaniciUygulamaBilgileri (UserId)
    VALUES (@AdminUserId), (@PersonnelUserId);

    INSERT INTO sosyobel.Belediyeler (Kod, Ad)
    VALUES (N'KPS_TEST', N'KPS Yetki Test Belediyesi');
    SET @MunicipalityId = CONVERT(int, SCOPE_IDENTITY());

    INSERT INTO sosyobel.KullaniciBelediyeleri
        (UserId, BelediyeId, RolKodu)
    VALUES
        (@AdminUserId, @MunicipalityId, N'BELEDIYE_YONETICISI'),
        (@PersonnelUserId, @MunicipalityId, N'PERSONEL');

    INSERT INTO sosyobel.KullaniciYetkileri
        (UserId, BelediyeId, YetkiKodu, VerenUserId)
    VALUES
        (@PersonnelUserId, @MunicipalityId, N'KPS_SORGULA', @AdminUserId);

    IF NOT EXISTS
    (
        SELECT 1
        FROM sosyobel.KullaniciYetkileri
        WHERE UserId = @PersonnelUserId
          AND BelediyeId = @MunicipalityId
          AND YetkiKodu = N'KPS_SORGULA'
          AND AktifMi = 1
    )
    BEGIN
        THROW 51363, N'KPS sorgulama yetkisi kaydı doğrulanamadı.', 1;
    END;

    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
