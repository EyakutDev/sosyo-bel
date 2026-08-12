/* Uyumluluk 007 için veri kaybını engelleyen kontrollü geri alma betiği. */

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'sosyobel.KullaniciYetkileri', N'U') IS NULL
BEGIN
    PRINT N'Uyumluluk 007 yetki tablosu mevcut değil; geri alınacak nesne yok.';
    RETURN;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID(N'sosyobel.KullaniciYetkileri')
      AND name = N'CK_KullaniciYetkileri_YetkiKodu'
      AND definition LIKE N'%KPS_SORGULA%'
)
BEGIN
    PRINT N'Uyumluluk 007 zaten geri alınmış.';
    RETURN;
END;

IF EXISTS
(
    SELECT TOP (1) 1
    FROM sosyobel.KullaniciYetkileri
    WHERE YetkiKodu = N'KPS_SORGULA'
)
BEGIN
    THROW 51364, N'KPS yetki kaydı bulunduğu için uyumluluk 007 geri alınamadı.', 1;
END;

BEGIN TRY
    BEGIN TRANSACTION;

    ALTER TABLE sosyobel.KullaniciYetkileri
        DROP CONSTRAINT CK_KullaniciYetkileri_YetkiKodu;

    ALTER TABLE sosyobel.KullaniciYetkileri WITH CHECK
        ADD CONSTRAINT CK_KullaniciYetkileri_YetkiKodu CHECK
        (
            YetkiKodu IN (N'KILITLI_BASVURU_DUZENLE')
        );

    ALTER TABLE sosyobel.KullaniciYetkileri
        CHECK CONSTRAINT CK_KullaniciYetkileri_YetkiKodu;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
