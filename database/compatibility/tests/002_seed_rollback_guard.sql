/*
    Yalnız geçici validation DB için rollback koruma kaydı.

    Bu kayıt varken 001 rollback'in veri kaybını önlemek için 51210 hatasıyla
    durması beklenir.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @UserId nvarchar(450) = N'compatibility-rollback-guard-user';
INSERT INTO dbo.AspNetUsers (Id) VALUES (@UserId);

INSERT INTO dbo.Basvurular DEFAULT VALUES;
DECLARE @BasvuruId int = CONVERT(int, SCOPE_IDENTITY());

INSERT INTO sosyobel.BasvuruUygulamaBilgileri
    (BasvuruId, BasvuruNo)
VALUES
    (@BasvuruId, N'COMPAT-ROLLBACK-GUARD');
