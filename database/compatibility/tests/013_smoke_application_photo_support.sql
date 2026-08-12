/*
    Yalniz gecici uyumluluk veritabaninda 006 fotograf metadata baglantilarini
    dogrular. Transaction geri alindigi icin kalici test verisi birakmaz.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRANSACTION;

INSERT INTO dbo.AspNetUsers (Id)
VALUES (N'application-photo-test-user');

INSERT INTO dbo.Basvurular DEFAULT VALUES;
DECLARE @ApplicationId int = CONVERT(int, SCOPE_IDENTITY());

INSERT INTO sosyobel.Belediyeler (Kod, Ad)
VALUES (N'PHOTO_TEST', N'Fotoğraf Test Belediyesi');
DECLARE @MunicipalityId int = CONVERT(int, SCOPE_IDENTITY());

INSERT INTO sosyobel.BasvuruFotograflari
(
    BelediyeId,
    BasvuruId,
    StorageKey,
    OrijinalDosyaAdi,
    MimeType,
    BoyutByte,
    Sha256,
    SiraNo,
    OlusturanUserId
)
VALUES
(
    @MunicipalityId,
    @ApplicationId,
    N'photo-test/application/01-test.png',
    N'ev.png',
    'image/png',
    8,
    HASHBYTES('SHA2_256', 0x89504E470D0A1A0A),
    1,
    N'application-photo-test-user'
);

IF NOT EXISTS
(
    SELECT 1
    FROM sosyobel.BasvuruFotograflari AS photo
    INNER JOIN dbo.Basvurular AS application
        ON application.Id = photo.BasvuruId
    INNER JOIN sosyobel.Belediyeler AS municipality
        ON municipality.Id = photo.BelediyeId
    WHERE photo.BasvuruId = @ApplicationId
      AND photo.BelediyeId = @MunicipalityId
      AND photo.SiraNo = 1
      AND photo.MimeType = 'image/png'
      AND photo.BoyutByte = 8
      AND photo.SilindiMi = 0
)
BEGIN
    THROW 51348, N'Uyumluluk 006 smoke fotograf metadata kaydi yazilamadi.', 1;
END;

ROLLBACK TRANSACTION;

SELECT N'COMPATIBILITY_APPLICATION_PHOTO_SMOKE_OK' AS ResultCode;
