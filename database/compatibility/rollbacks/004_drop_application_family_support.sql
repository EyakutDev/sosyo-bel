/*
    Uyumluluk migration 004 icin kontrollu geri alma betigi.

    Yalniz bu migration'in sahiplik etiketiyle olusturdugu teknik tablolar
    kaldirilir. Aile metadata tablosunda veri varsa veri kaybini onlemek icin
    otomatik geri alma reddedilir. dbo nesnelerine dokunulmaz.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'sosyobel.BasvuruAileFertiUygulamaBilgileri', N'U') IS NULL AND
   OBJECT_ID(N'sosyobel.YasamDurumlari', N'U') IS NULL
BEGIN
    PRINT N'Uyumluluk 004 teknik tablolari mevcut degil; geri alinacak nesne yok.';
    RETURN;
END;

DECLARE @MetadataOwned bit =
    CASE WHEN CONVERT(nvarchar(20), OBJECTPROPERTYEX(
        OBJECT_ID(N'sosyobel.BasvuruAileFertiUygulamaBilgileri'),
        N'TableHasPrimaryKey')) IS NOT NULL
      AND CONVERT(nvarchar(20), (
          SELECT value
          FROM sys.extended_properties
          WHERE major_id = OBJECT_ID(N'sosyobel.BasvuruAileFertiUygulamaBilgileri')
            AND minor_id = 0
            AND name = N'SosyoBelOwnerMigration'
      )) = N'004'
    THEN 1 ELSE 0 END;

DECLARE @VitalOwned bit =
    CASE WHEN CONVERT(nvarchar(20), (
        SELECT value
        FROM sys.extended_properties
        WHERE major_id = OBJECT_ID(N'sosyobel.YasamDurumlari')
          AND minor_id = 0
          AND name = N'SosyoBelOwnerMigration'
    )) = N'004'
    THEN 1 ELSE 0 END;

IF @MetadataOwned = 1
BEGIN
    EXEC sys.sp_executesql N'
        IF EXISTS
        (
            SELECT TOP (1) 1
            FROM sosyobel.BasvuruAileFertiUygulamaBilgileri
        )
        BEGIN
            THROW 51309, N''Uyumluluk 004 aile metadata tablosu veri iceriyor. Geri alma durduruldu.'', 1;
        END;
    ';
END;

BEGIN TRY
    BEGIN TRANSACTION;

    IF @MetadataOwned = 1
        EXEC(N'DROP TABLE sosyobel.BasvuruAileFertiUygulamaBilgileri;');

    IF @VitalOwned = 1
    BEGIN
        IF EXISTS
        (
            SELECT 1
            FROM sys.foreign_keys
            WHERE referenced_object_id = OBJECT_ID(N'sosyobel.YasamDurumlari')
        )
        BEGIN
            THROW 51310, N'YasamDurumlari tablosuna baska bir FK bagli. Geri alma durduruldu.', 1;
        END;

        EXEC(N'DROP TABLE sosyobel.YasamDurumlari;');
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
