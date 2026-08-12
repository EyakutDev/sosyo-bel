/*
    Uyumluluk migration 006 icin kontrollu geri alma betigi.

    Yalniz 006 sahiplik etiketiyle olusturulan tablo kaldirilir. Metadata kaydi
    varsa veri kaybini onlemek icin islem reddedilir. dbo nesnelerine dokunulmaz.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'sosyobel.BasvuruFotograflari', N'U') IS NULL
BEGIN
    PRINT N'Uyumluluk 006 fotograf tablosu mevcut degil; geri alinacak nesne yok.';
    RETURN;
END;

IF ISNULL(CONVERT(nvarchar(20), (
    SELECT value
    FROM sys.extended_properties
    WHERE major_id = OBJECT_ID(N'sosyobel.BasvuruFotograflari')
      AND minor_id = 0
      AND name = N'SosyoBelOwnerMigration'
)), N'') <> N'006'
BEGIN
    THROW 51349, N'Uyumluluk 006 tablo sahipligi dogrulanamadi. Otomatik geri alma durduruldu.', 1;
END;

IF EXISTS (SELECT TOP (1) 1 FROM sosyobel.BasvuruFotograflari)
BEGIN
    THROW 51350, N'Uyumluluk 006 fotograf metadata tablosu veri iceriyor. Geri alma durduruldu.', 1;
END;

DROP TABLE sosyobel.BasvuruFotograflari;
