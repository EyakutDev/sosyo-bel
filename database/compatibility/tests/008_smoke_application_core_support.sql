/*
    Yalnız geçici uyumluluk veritabanında 003 foreign key ve insert davranışını
    doğrular. Transaction geri alındığı için fixture'da kalıcı test verisi bırakmaz.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRANSACTION;

INSERT INTO dbo.AspNetUsers (Id) VALUES (N'application-core-test-user');
INSERT INTO dbo.BasvuruDurumlari DEFAULT VALUES;
DECLARE @DraftStatusId int = CONVERT(int, SCOPE_IDENTITY());
INSERT INTO dbo.BasvuruDurumlari DEFAULT VALUES;
DECLARE @PendingStatusId int = CONVERT(int, SCOPE_IDENTITY());
INSERT INTO dbo.Basvurular DEFAULT VALUES;
DECLARE @ApplicationId int = CONVERT(int, SCOPE_IDENTITY());

INSERT INTO sosyobel.BasvuruDurumGecmisi
    (BasvuruId, OncekiDurumId, YeniDurumId, OlusturanUserId)
VALUES
    (@ApplicationId, NULL, @DraftStatusId, N'application-core-test-user'),
    (@ApplicationId, @DraftStatusId, @PendingStatusId, N'application-core-test-user');

IF
(
    SELECT COUNT(*)
    FROM sosyobel.BasvuruDurumGecmisi
    WHERE BasvuruId = @ApplicationId
) <> 2
BEGIN
    THROW 51277, N'Uyumluluk 003 smoke kayıtları oluşturulamadı.', 1;
END;

ROLLBACK TRANSACTION;

SELECT N'COMPATIBILITY_APPLICATION_CORE_SMOKE_OK' AS ResultCode;
