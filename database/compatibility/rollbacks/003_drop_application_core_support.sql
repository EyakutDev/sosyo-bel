/*
    Uyumluluk migration 003 için kontrollü geri alma betiği.

    Durum geçmişinde veri varsa audit kaybını önlemek için otomatik geri alma
    reddedilir. Hiçbir dbo nesnesi veya veri değiştirilmez.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'sosyobel.BasvuruDurumGecmisi', N'U') IS NULL
BEGIN
    PRINT N'Uyumluluk 003 tablosu mevcut değil; geri alınacak nesne yok.';
    RETURN;
END;

IF EXISTS (SELECT TOP (1) 1 FROM sosyobel.BasvuruDurumGecmisi)
BEGIN
    THROW 51278, N'Uyumluluk 003 tablosu veri içeriyor. Otomatik geri alma durduruldu.', 1;
END;

BEGIN TRY
    BEGIN TRANSACTION;
    DROP TABLE sosyobel.BasvuruDurumGecmisi;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
