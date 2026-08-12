/*
    Yalnız 005_seed_auth_rollback_guard.sql tarafından eklenen sabit test kaydını
    temizler.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DELETE FROM sosyobel.Belediyeler
WHERE Kod = N'ROLLBACK_GUARD'
  AND Ad = N'Rollback Koruma Test Belediyesi';

IF @@ROWCOUNT <> 1
BEGIN
    THROW 51273, N'Auth rollback koruma test kaydı beklenen şekilde temizlenemedi.', 1;
END;
