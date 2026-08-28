/* Uyumluluk 008 icin salt okunur tek belediye kapsam kontrolu. */

SET NOCOUNT ON;

IF OBJECT_ID(N'sosyobel.HaneSorulari', N'U') IS NULL OR
   OBJECT_ID(N'sosyobel.BasvuruHaneCevaplari', N'U') IS NULL OR
   OBJECT_ID(N'sosyobel.BasvuruFotograflari', N'U') IS NULL
BEGIN
    THROW 51372, N'Uyumluluk 008 tablolari bulunamadi.', 1;
END;

IF COL_LENGTH(N'sosyobel.HaneSorulari', N'BelediyeId') IS NOT NULL OR
   COL_LENGTH(N'sosyobel.BasvuruHaneCevaplari', N'BelediyeId') IS NOT NULL OR
   COL_LENGTH(N'sosyobel.BasvuruFotograflari', N'BelediyeId') IS NOT NULL
BEGIN
    THROW 51373, N'Basvuru tablolarinda eski BelediyeId kapsami hala bulunuyor.', 1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'sosyobel.HaneSorulari')
      AND name = N'UQ_HaneSorulari_Kod'
      AND is_unique = 1
      AND is_disabled = 0
)
BEGIN
    THROW 51374, N'Hane soru kodu benzersizlik kurali bulunamadi.', 1;
END;

SELECT N'COMPATIBILITY_APPLICATION_SINGLE_MUNICIPALITY_OK' AS ResultCode;
