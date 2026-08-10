/* Belediye kapsamlı rol/yetki ve audit şeması için salt-okunur doğrulama. */

SET NOCOUNT ON;

IF COL_LENGTH(N'sosyobel.KullaniciBelediyeleri', N'RolKodu') IS NULL
BEGIN
    THROW 51060, N'KullaniciBelediyeleri.RolKodu bulunamadı.', 1;
END;

IF OBJECT_ID(N'sosyobel.KullaniciYetkileri', N'U') IS NULL
BEGIN
    THROW 51061, N'KullaniciYetkileri tablosu bulunamadı.', 1;
END;

IF COL_LENGTH(N'sosyobel.IslemGecmisleri', N'Gerekce') IS NULL OR
   COL_LENGTH(N'sosyobel.IslemGecmisleri', N'CorrelationId') IS NULL
BEGIN
    THROW 51062, N'IslemGecmisleri audit alanları eksik.', 1;
END;

IF EXISTS
(
    SELECT 1
    FROM sosyobel.KullaniciBelediyeleri
    WHERE RolKodu NOT IN (N'BELEDIYE_YONETICISI', N'PERSONEL')
)
BEGIN
    THROW 51063, N'Bilinmeyen belediye rolü bulundu.', 1;
END;

IF EXISTS
(
    SELECT 1
    FROM sosyobel.IslemGecmisleri
    WHERE IslemKodu = N'KILITLI_BASVURU_GUNCELLE'
      AND (Gerekce IS NULL OR DegisiklikOzetiJson IS NULL)
)
BEGIN
    THROW 51064, N'Gerekçesiz veya değişiklik özetsiz kilitli başvuru işlemi bulundu.', 1;
END;

SELECT
    COUNT(*) AS UyelikSayisi,
    SUM(CASE WHEN AktifMi = 1 THEN 1 ELSE 0 END) AS AktifUyelikSayisi
FROM sosyobel.KullaniciBelediyeleri;

/* Çoklu aktif üyelik şema tarafından engellenmez; servis kuralını izlemek için raporlanır. */
SELECT
    UserId,
    COUNT(*) AS AktifBelediyeSayisi
FROM sosyobel.KullaniciBelediyeleri
WHERE AktifMi = 1
GROUP BY UserId
HAVING COUNT(*) > 1;
