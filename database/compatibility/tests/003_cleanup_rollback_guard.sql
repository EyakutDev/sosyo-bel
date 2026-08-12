/*
    Yalnız geçici validation DB için rollback koruma kaydı temizliği.

    Sadece sabit test numarası ve kullanıcı kimliği hedeflenir; şirket ortamında
    çalıştırılmaz.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @BasvuruId int =
(
    SELECT BasvuruId
    FROM sosyobel.BasvuruUygulamaBilgileri
    WHERE BasvuruNo = N'COMPAT-ROLLBACK-GUARD'
);

DELETE FROM sosyobel.BasvuruUygulamaBilgileri
WHERE BasvuruId = @BasvuruId;

DELETE FROM dbo.Basvurular
WHERE Id = @BasvuruId;

DELETE FROM dbo.AspNetUsers
WHERE Id = N'compatibility-rollback-guard-user';
