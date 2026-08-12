/*
    Rollback 002'nin veri bulunan auth tablosunu silmeyi reddettiğini doğrulamak
    için sabit test kaydı oluşturur.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

INSERT INTO sosyobel.Belediyeler (Kod, Ad)
VALUES (N'ROLLBACK_GUARD', N'Rollback Koruma Test Belediyesi');
