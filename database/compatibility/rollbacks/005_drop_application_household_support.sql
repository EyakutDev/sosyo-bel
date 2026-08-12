/*
    Uyumluluk migration 005 icin kontrollu geri alma betigi.

    Yalniz 005 sahiplik etiketiyle olusturulan tablolar kaldirilir. Basvuru
    cevabi varsa veri kaybini onlemek icin otomatik geri alma reddedilir.
    Mevcut dbo nesnelerine dokunulmaz.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @ExistingTableCount int =
(
    SELECT COUNT(*)
    FROM
    (
        VALUES
            (N'sosyobel.HaneSorulari'),
            (N'sosyobel.HaneSoruSecenekleri'),
            (N'sosyobel.BasvuruHaneCevaplari')
    ) AS requiredTable(ObjectName)
    WHERE OBJECT_ID(requiredTable.ObjectName, N'U') IS NOT NULL
);

IF @ExistingTableCount = 0
BEGIN
    PRINT N'Uyumluluk 005 hane tablolari mevcut degil; geri alinacak nesne yok.';
    RETURN;
END;

IF @ExistingTableCount <> 3
BEGIN
    THROW 51329, N'Uyumluluk 005 hane tablolari kismi durumda. Otomatik geri alma durduruldu.', 1;
END;

IF
(
    ISNULL(CONVERT(nvarchar(20), (
        SELECT value
        FROM sys.extended_properties
        WHERE major_id = OBJECT_ID(N'sosyobel.HaneSorulari')
          AND minor_id = 0
          AND name = N'SosyoBelOwnerMigration'
    )), N'') <> N'005' OR
    ISNULL(CONVERT(nvarchar(20), (
        SELECT value
        FROM sys.extended_properties
        WHERE major_id = OBJECT_ID(N'sosyobel.HaneSoruSecenekleri')
          AND minor_id = 0
          AND name = N'SosyoBelOwnerMigration'
    )), N'') <> N'005' OR
    ISNULL(CONVERT(nvarchar(20), (
        SELECT value
        FROM sys.extended_properties
        WHERE major_id = OBJECT_ID(N'sosyobel.BasvuruHaneCevaplari')
          AND minor_id = 0
          AND name = N'SosyoBelOwnerMigration'
    )), N'') <> N'005'
)
BEGIN
    THROW 51330, N'Uyumluluk 005 tablo sahipligi dogrulanamadi. Otomatik geri alma durduruldu.', 1;
END;

IF EXISTS (SELECT TOP (1) 1 FROM sosyobel.BasvuruHaneCevaplari)
BEGIN
    THROW 51331, N'Uyumluluk 005 hane cevap tablosu veri iceriyor. Geri alma durduruldu.', 1;
END;

BEGIN TRY
    BEGIN TRANSACTION;

    DROP TABLE sosyobel.BasvuruHaneCevaplari;
    DROP TABLE sosyobel.HaneSoruSecenekleri;
    DROP TABLE sosyobel.HaneSorulari;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
