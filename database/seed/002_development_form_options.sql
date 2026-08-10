/*
  YALNIZCA YEREL GELİŞTİRME/TEST İÇİNDİR.

  Şirket yardım ve engel türlerinin kesin kodlarını henüz vermedi. Bu kayıtlar
  Flutter'daki geçici seçeneklerle API akışını test edebilmek için ayrı tutulur.
  Üretim kurulumunda bu dosya çalıştırılmaz; belediyenin gerçek referans verisi kullanılır.
*/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    ;WITH Kaynak (Kod, Ad, Sira) AS
    (
        SELECT N'GIDA', N'Gıda Yardımı', 1 UNION ALL
        SELECT N'NAKDI', N'Nakdi Yardım', 2 UNION ALL
        SELECT N'YAKACAK', N'Yakacak Yardımı', 3 UNION ALL
        SELECT N'BARINMA', N'Barınma Yardımı', 4 UNION ALL
        SELECT N'EGITIM', N'Eğitim Yardımı', 5 UNION ALL
        SELECT N'SAGLIK', N'Sağlık Yardımı', 6 UNION ALL
        SELECT N'DIGER', N'Diğer', 7
    )
    INSERT INTO sosyobel.YardimTurleri (BelediyeId, Kod, Ad, Sira)
    SELECT NULL, kaynak.Kod, kaynak.Ad, kaynak.Sira
    FROM Kaynak AS kaynak
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM sosyobel.YardimTurleri AS mevcut
        WHERE mevcut.BelediyeId IS NULL AND mevcut.Kod = kaynak.Kod
    );

    ;WITH Kaynak (Kod, Ad, Sira) AS
    (
        SELECT N'ORTOPEDIK', N'Ortopedik', 1 UNION ALL
        SELECT N'GORME', N'Görme', 2 UNION ALL
        SELECT N'ISITME', N'İşitme', 3 UNION ALL
        SELECT N'ZIHINSEL', N'Zihinsel', 4 UNION ALL
        SELECT N'SUREGEN_HASTALIK', N'Süreğen Hastalık', 5 UNION ALL
        SELECT N'DIGER', N'Diğer', 6
    )
    INSERT INTO sosyobel.EngelTurleri (BelediyeId, Kod, Ad, Sira)
    SELECT NULL, kaynak.Kod, kaynak.Ad, kaynak.Sira
    FROM Kaynak AS kaynak
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM sosyobel.EngelTurleri AS mevcut
        WHERE mevcut.BelediyeId IS NULL AND mevcut.Kod = kaynak.Kod
    );

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
