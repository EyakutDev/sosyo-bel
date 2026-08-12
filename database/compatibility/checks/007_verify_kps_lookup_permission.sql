/* Uyumluluk 007 için salt okunur kontrol. */

SET NOCOUNT ON;

IF OBJECT_ID(N'sosyobel.KullaniciYetkileri', N'U') IS NULL OR NOT EXISTS
(
    SELECT 1
    FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID(N'sosyobel.KullaniciYetkileri')
      AND name = N'CK_KullaniciYetkileri_YetkiKodu'
      AND definition LIKE N'%KILITLI_BASVURU_DUZENLE%'
      AND definition LIKE N'%KPS_SORGULA%'
      AND is_disabled = 0
      AND is_not_trusted = 0
)
BEGIN
    THROW 51362, N'Uyumluluk 007 KPS yetki kontrolü doğrulanamadı.', 1;
END;
