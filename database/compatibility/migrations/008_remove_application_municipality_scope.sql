/*
    Sosyo-Bel tek belediye uyumluluk migration'i 008

    Mobil uygulama tek kuruma ait oldugu icin hane sorusu, hane cevabi ve fotograf
    metadata kayitlarinda ayri BelediyeId kapsami tutulmaz. Bu betik yalniz daha
    once 005/006 ile kurulmus sosyobel tablolarindaki gereksiz kapsami kaldirir;
    dbo nesnelerini ve is verisini degistirmez.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'sosyobel.HaneSorulari', N'U') IS NULL OR
   OBJECT_ID(N'sosyobel.BasvuruHaneCevaplari', N'U') IS NULL OR
   OBJECT_ID(N'sosyobel.BasvuruFotograflari', N'U') IS NULL
BEGIN
    THROW 51370, N'Uyumluluk 008 icin once 005 ve 006 tablolarinin kurulmasi gerekir.', 1;
END;

/*
  Belediye bazli birden cok ayni soru kodu varsa hangisinin korunacagi kurum
  karari gerektirir. Betik veri silmek yerine guvenli bicimde durur.
*/
IF COL_LENGTH(N'sosyobel.HaneSorulari', N'BelediyeId') IS NOT NULL AND EXISTS
(
    SELECT Kod
    FROM sosyobel.HaneSorulari
    GROUP BY Kod
    HAVING COUNT_BIG(*) > 1
)
BEGIN
    THROW 51371, N'Ayni hane soru kodu birden cok kez bulundu. Tek belediye gecisi icin once kayitlar kararlastirilmalidir.', 1;
END;

BEGIN TRY
    BEGIN TRANSACTION;

    IF EXISTS
    (
        SELECT 1 FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'sosyobel.HaneSorulari')
          AND name = N'UX_HaneSorulari_GlobalKod'
    )
        DROP INDEX UX_HaneSorulari_GlobalKod ON sosyobel.HaneSorulari;

    IF EXISTS
    (
        SELECT 1 FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'sosyobel.HaneSorulari')
          AND name = N'UX_HaneSorulari_BelediyeKod'
    )
        DROP INDEX UX_HaneSorulari_BelediyeKod ON sosyobel.HaneSorulari;

    IF EXISTS
    (
        SELECT 1 FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'sosyobel.BasvuruHaneCevaplari')
          AND name = N'IX_BasvuruHaneCevaplari_BelediyeBasvuru'
    )
        DROP INDEX IX_BasvuruHaneCevaplari_BelediyeBasvuru
            ON sosyobel.BasvuruHaneCevaplari;

    IF EXISTS
    (
        SELECT 1 FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'sosyobel.BasvuruFotograflari')
          AND name = N'IX_BasvuruFotograflari_BelediyeBasvuru'
    )
        DROP INDEX IX_BasvuruFotograflari_BelediyeBasvuru
            ON sosyobel.BasvuruFotograflari;

    IF OBJECT_ID(N'sosyobel.FK_HaneSorulari_Belediyeler', N'F') IS NOT NULL
        ALTER TABLE sosyobel.HaneSorulari
            DROP CONSTRAINT FK_HaneSorulari_Belediyeler;

    IF OBJECT_ID(N'sosyobel.FK_BasvuruHaneCevaplari_Belediyeler', N'F') IS NOT NULL
        ALTER TABLE sosyobel.BasvuruHaneCevaplari
            DROP CONSTRAINT FK_BasvuruHaneCevaplari_Belediyeler;

    IF OBJECT_ID(N'sosyobel.FK_BasvuruFotograflari_Belediyeler', N'F') IS NOT NULL
        ALTER TABLE sosyobel.BasvuruFotograflari
            DROP CONSTRAINT FK_BasvuruFotograflari_Belediyeler;

    IF COL_LENGTH(N'sosyobel.HaneSorulari', N'BelediyeId') IS NOT NULL
        ALTER TABLE sosyobel.HaneSorulari DROP COLUMN BelediyeId;

    IF COL_LENGTH(N'sosyobel.BasvuruHaneCevaplari', N'BelediyeId') IS NOT NULL
        ALTER TABLE sosyobel.BasvuruHaneCevaplari DROP COLUMN BelediyeId;

    IF COL_LENGTH(N'sosyobel.BasvuruFotograflari', N'BelediyeId') IS NOT NULL
        ALTER TABLE sosyobel.BasvuruFotograflari DROP COLUMN BelediyeId;

    IF NOT EXISTS
    (
        SELECT 1 FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'sosyobel.HaneSorulari')
          AND name = N'UQ_HaneSorulari_Kod'
    )
        CREATE UNIQUE INDEX UQ_HaneSorulari_Kod
            ON sosyobel.HaneSorulari (Kod);

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;

PRINT N'Uyumluluk 008 tek belediye basvuru kapsami uygulandi.';
