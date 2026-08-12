/*
    Şirket şeması uyumluluk migrationı 007.
    Yalnız uygulamaya ait sosyobel.KullaniciYetkileri kontrolünü genişletir.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'sosyobel.KullaniciYetkileri', N'U') IS NULL
BEGIN
    THROW 51360, N'Uyumluluk 007 için önce auth desteği kurulmalıdır.', 1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID(N'sosyobel.KullaniciYetkileri')
      AND name = N'CK_KullaniciYetkileri_YetkiKodu'
)
BEGIN
    THROW 51361, N'Yetki kodu kontrolünün sahipliği doğrulanamadı; migration durduruldu.', 1;
END;

IF EXISTS
(
    SELECT 1
    FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID(N'sosyobel.KullaniciYetkileri')
      AND name = N'CK_KullaniciYetkileri_YetkiKodu'
      AND definition LIKE N'%KPS_SORGULA%'
)
BEGIN
    PRINT N'Uyumluluk 007 zaten uygulanmış; migration yeniden uygulanmadı.';
    RETURN;
END;

BEGIN TRY
    BEGIN TRANSACTION;

    ALTER TABLE sosyobel.KullaniciYetkileri
        DROP CONSTRAINT CK_KullaniciYetkileri_YetkiKodu;

    ALTER TABLE sosyobel.KullaniciYetkileri WITH CHECK
        ADD CONSTRAINT CK_KullaniciYetkileri_YetkiKodu CHECK
        (
            YetkiKodu IN
            (
                N'KILITLI_BASVURU_DUZENLE',
                N'KPS_SORGULA'
            )
        );

    ALTER TABLE sosyobel.KullaniciYetkileri
        CHECK CONSTRAINT CK_KullaniciYetkileri_YetkiKodu;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
