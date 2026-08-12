/*
    Uyumluluk migration 001 için kontrollü geri alma betiği.

    Veri kaybını önlemek için tablolardan herhangi biri satır içeriyorsa işlem
    reddedilir. Betik sosyobel şemasını veya mevcut dbo nesnelerini silmez.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @ExistingCompatibilityTableCount int =
(
    SELECT COUNT(*)
    FROM
    (
        VALUES
            (N'sosyobel.BasvuruUygulamaBilgileri'),
            (N'sosyobel.ReferansKodlari'),
            (N'sosyobel.KullaniciUygulamaBilgileri')
    ) AS compatibilityTable(ObjectName)
    WHERE OBJECT_ID(compatibilityTable.ObjectName, N'U') IS NOT NULL
);

IF @ExistingCompatibilityTableCount = 0
BEGIN
    PRINT N'Uyumluluk 001 tabloları mevcut değil; geri alınacak nesne yok.';
    RETURN;
END;

-- sys.dm_db_partition_stats kullanımı, kısmen oluşturulmuş bir şemada dahi
-- bulunmayan tablo adlarına doğrudan SELECT yazmadan güvenli satır kontrolü sağlar.
IF EXISTS
(
    SELECT 1
    FROM sys.dm_db_partition_stats AS partitionInfo
    WHERE partitionInfo.object_id IN
    (
        OBJECT_ID(N'sosyobel.BasvuruUygulamaBilgileri', N'U'),
        OBJECT_ID(N'sosyobel.ReferansKodlari', N'U'),
        OBJECT_ID(N'sosyobel.KullaniciUygulamaBilgileri', N'U')
    )
      AND partitionInfo.index_id IN (0, 1)
      AND partitionInfo.row_count > 0
)
BEGIN
    THROW 51210, N'Uyumluluk 001 tabloları veri içeriyor. Otomatik geri alma veri kaybını önlemek için durduruldu.', 1;
END;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'sosyobel.BasvuruUygulamaBilgileri', N'U') IS NOT NULL
        EXEC(N'DROP TABLE sosyobel.BasvuruUygulamaBilgileri;');

    IF OBJECT_ID(N'sosyobel.ReferansKodlari', N'U') IS NOT NULL
        EXEC(N'DROP TABLE sosyobel.ReferansKodlari;');

    IF OBJECT_ID(N'sosyobel.KullaniciUygulamaBilgileri', N'U') IS NOT NULL
        EXEC(N'DROP TABLE sosyobel.KullaniciUygulamaBilgileri;');

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
