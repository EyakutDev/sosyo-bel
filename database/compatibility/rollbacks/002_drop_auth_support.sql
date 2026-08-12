/*
    Uyumluluk migration 002 için kontrollü geri alma betiği.

    Altı auth destek tablosundan herhangi biri veri içeriyorsa veri kaybını
    önlemek için işlem reddedilir. Mevcut dbo tabloları ve migration 001
    nesneleri bu betik tarafından silinmez.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @ExistingAuthTableCount int =
(
    SELECT COUNT(*)
    FROM
    (
        VALUES
            (N'sosyobel.Belediyeler'),
            (N'sosyobel.KullaniciBelediyeleri'),
            (N'sosyobel.KullaniciYetkileri'),
            (N'sosyobel.IslemGecmisleri'),
            (N'sosyobel.IdempotencyKayitlari'),
            (N'sosyobel.YenilemeTokenlari')
    ) AS authTable(ObjectName)
    WHERE OBJECT_ID(authTable.ObjectName, N'U') IS NOT NULL
);

IF @ExistingAuthTableCount = 0
BEGIN
    PRINT N'Uyumluluk 002 tabloları mevcut değil; geri alınacak nesne yok.';
    RETURN;
END;

IF EXISTS
(
    SELECT 1
    FROM sys.dm_db_partition_stats AS partitionInfo
    WHERE partitionInfo.object_id IN
    (
        OBJECT_ID(N'sosyobel.Belediyeler', N'U'),
        OBJECT_ID(N'sosyobel.KullaniciBelediyeleri', N'U'),
        OBJECT_ID(N'sosyobel.KullaniciYetkileri', N'U'),
        OBJECT_ID(N'sosyobel.IslemGecmisleri', N'U'),
        OBJECT_ID(N'sosyobel.IdempotencyKayitlari', N'U'),
        OBJECT_ID(N'sosyobel.YenilemeTokenlari', N'U')
    )
      AND partitionInfo.index_id IN (0, 1)
      AND partitionInfo.row_count > 0
)
BEGIN
    THROW 51260, N'Uyumluluk 002 tabloları veri içeriyor. Otomatik geri alma durduruldu.', 1;
END;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'sosyobel.KullaniciYetkileri', N'U') IS NOT NULL
        EXEC(N'DROP TABLE sosyobel.KullaniciYetkileri;');

    IF OBJECT_ID(N'sosyobel.IslemGecmisleri', N'U') IS NOT NULL
        EXEC(N'DROP TABLE sosyobel.IslemGecmisleri;');

    IF OBJECT_ID(N'sosyobel.IdempotencyKayitlari', N'U') IS NOT NULL
        EXEC(N'DROP TABLE sosyobel.IdempotencyKayitlari;');

    IF OBJECT_ID(N'sosyobel.YenilemeTokenlari', N'U') IS NOT NULL
        EXEC(N'DROP TABLE sosyobel.YenilemeTokenlari;');

    IF OBJECT_ID(N'sosyobel.KullaniciBelediyeleri', N'U') IS NOT NULL
        EXEC(N'DROP TABLE sosyobel.KullaniciBelediyeleri;');

    IF OBJECT_ID(N'sosyobel.Belediyeler', N'U') IS NOT NULL
        EXEC(N'DROP TABLE sosyobel.Belediyeler;');

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
