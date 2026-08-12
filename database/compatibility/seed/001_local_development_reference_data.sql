/*
  YALNIZCA YEREL GELISTIRME/TEST ICINDIR.

  Sirket snapshot'i tablo yapisini icerir, veri icermez. Bu dosya mobil akisi
  yerelde deneyebilmek icin dbo lookup tablolarina ornek satirlar ve bu satirlara
  sosyobel.ReferansKodlari eslemeleri ekler. Canli veya sirket test veritabaninda
  calistirilmaz; orada kurumun gercek lookup satirlari eslenir.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.BasvuruDurumlari', N'U') IS NULL OR
   OBJECT_ID(N'dbo.YardimTurleri', N'U') IS NULL OR
   OBJECT_ID(N'dbo.EngelTurleri', N'U') IS NULL OR
   OBJECT_ID(N'dbo.TalepGelisKanallari', N'U') IS NULL OR
   OBJECT_ID(N'dbo.Yakinliklar', N'U') IS NULL OR
   OBJECT_ID(N'dbo.CalismaDurumlari', N'U') IS NULL OR
   OBJECT_ID(N'dbo.EgitimDurumlari', N'U') IS NULL OR
   OBJECT_ID(N'sosyobel.ReferansKodlari', N'U') IS NULL
BEGIN
    THROW 51300, N'Sirket dbo semasi ve compatibility 001 migrationi gereklidir.', 1;
END;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @Kaynak TABLE
    (
        ReferansTuruKodu nvarchar(50) NOT NULL,
        Kod nvarchar(80) NOT NULL,
        Ad nvarchar(150) NOT NULL,
        Sira int NOT NULL
    );

    INSERT INTO @Kaynak (ReferansTuruKodu, Kod, Ad, Sira)
    VALUES
        (N'BASVURU_DURUMU', N'TASLAK', N'Taslak', 1),
        (N'BASVURU_DURUMU', N'KURUL_BEKLIYOR', N'Kurul Bekliyor', 2),
        (N'BASVURU_DURUMU', N'TAMAMLANDI', N'Tamamlandı', 3),

        (N'YARDIM_TURU', N'GIDA', N'Gıda Yardımı', 1),
        (N'YARDIM_TURU', N'NAKDI', N'Nakdi Yardım', 2),
        (N'YARDIM_TURU', N'YAKACAK', N'Yakacak Yardımı', 3),
        (N'YARDIM_TURU', N'BARINMA', N'Barınma Yardımı', 4),
        (N'YARDIM_TURU', N'EGITIM', N'Eğitim Yardımı', 5),
        (N'YARDIM_TURU', N'SAGLIK', N'Sağlık Yardımı', 6),
        (N'YARDIM_TURU', N'DIGER', N'Diğer', 7),

        (N'ENGEL_TURU', N'ORTOPEDIK', N'Ortopedik', 1),
        (N'ENGEL_TURU', N'GORME', N'Görme', 2),
        (N'ENGEL_TURU', N'ISITME', N'İşitme', 3),
        (N'ENGEL_TURU', N'ZIHINSEL', N'Zihinsel', 4),
        (N'ENGEL_TURU', N'SUREGEN_HASTALIK', N'Süreğen Hastalık', 5),
        (N'ENGEL_TURU', N'DIGER', N'Diğer', 6),

        (N'TALEP_GELIS_KANALI', N'MOBIL_SAHA', N'Mobil Saha Uygulaması', 1),

        (N'YAKINLIK', N'ES', N'Eş', 1),
        (N'YAKINLIK', N'ANNE', N'Anne', 2),
        (N'YAKINLIK', N'BABA', N'Baba', 3),
        (N'YAKINLIK', N'COCUK', N'Çocuk', 4),
        (N'YAKINLIK', N'KARDES', N'Kardeş', 5),
        (N'YAKINLIK', N'BUYUKANNE', N'Büyükanne', 6),
        (N'YAKINLIK', N'BUYUKBABA', N'Büyükbaba', 7),
        (N'YAKINLIK', N'TORUN', N'Torun', 8),
        (N'YAKINLIK', N'GELIN', N'Gelin', 9),
        (N'YAKINLIK', N'DAMAT', N'Damat', 10),
        (N'YAKINLIK', N'KAYINVALIDE', N'Kayınvalide', 11),
        (N'YAKINLIK', N'KAYINPEDER', N'Kayınpeder', 12),
        (N'YAKINLIK', N'DIGER', N'Diğer', 13),

        (N'CALISMA_DURUMU', N'CALISIYOR', N'Çalışıyor', 1),
        (N'CALISMA_DURUMU', N'CALISMIYOR', N'Çalışmıyor', 2),
        (N'CALISMA_DURUMU', N'EMEKLI', N'Emekli', 3),

        (N'EGITIM_DURUMU', N'OKURYAZAR_DEGIL', N'Okuryazar Değil', 1),
        (N'EGITIM_DURUMU', N'OKURYAZAR', N'Okuryazar', 2),
        (N'EGITIM_DURUMU', N'ILKOKUL', N'İlkokul', 3),
        (N'EGITIM_DURUMU', N'ILKOGRETIM_TERK', N'İlk Öğretim Terk', 4),
        (N'EGITIM_DURUMU', N'ORTAOKUL', N'Ortaokul', 5),
        (N'EGITIM_DURUMU', N'LISE', N'Lise', 6),
        (N'EGITIM_DURUMU', N'ON_LISANS', N'Ön Lisans', 7),
        (N'EGITIM_DURUMU', N'LISANS', N'Lisans', 8),
        (N'EGITIM_DURUMU', N'YUKSEK_LISANS', N'Yüksek Lisans', 9),
        (N'EGITIM_DURUMU', N'DOKTORA', N'Doktora', 10);

    INSERT INTO dbo.BasvuruDurumlari (Name, Sil)
    SELECT kaynak.Ad, 0
    FROM @Kaynak AS kaynak
    WHERE kaynak.ReferansTuruKodu = N'BASVURU_DURUMU'
      AND NOT EXISTS
      (
          SELECT 1
          FROM dbo.BasvuruDurumlari AS mevcut
          WHERE mevcut.Name = kaynak.Ad
      );

    INSERT INTO dbo.YardimTurleri (Name, Sil)
    SELECT kaynak.Ad, 0
    FROM @Kaynak AS kaynak
    WHERE kaynak.ReferansTuruKodu = N'YARDIM_TURU'
      AND NOT EXISTS
      (
          SELECT 1
          FROM dbo.YardimTurleri AS mevcut
          WHERE mevcut.Name = kaynak.Ad
      );

    INSERT INTO dbo.EngelTurleri (Name, Sil)
    SELECT kaynak.Ad, 0
    FROM @Kaynak AS kaynak
    WHERE kaynak.ReferansTuruKodu = N'ENGEL_TURU'
      AND NOT EXISTS
      (
          SELECT 1
          FROM dbo.EngelTurleri AS mevcut
          WHERE mevcut.Name = kaynak.Ad
      );

    INSERT INTO dbo.TalepGelisKanallari (Name, Sil)
    SELECT kaynak.Ad, 0
    FROM @Kaynak AS kaynak
    WHERE kaynak.ReferansTuruKodu = N'TALEP_GELIS_KANALI'
      AND NOT EXISTS
      (
          SELECT 1
          FROM dbo.TalepGelisKanallari AS mevcut
          WHERE mevcut.Name = kaynak.Ad
      );

    INSERT INTO dbo.Yakinliklar (Name, Sil)
    SELECT kaynak.Ad, 0
    FROM @Kaynak AS kaynak
    WHERE kaynak.ReferansTuruKodu = N'YAKINLIK'
      AND NOT EXISTS
      (
          SELECT 1
          FROM dbo.Yakinliklar AS mevcut
          WHERE mevcut.Name = kaynak.Ad
      );

    INSERT INTO dbo.CalismaDurumlari (Name, Sil)
    SELECT kaynak.Ad, 0
    FROM @Kaynak AS kaynak
    WHERE kaynak.ReferansTuruKodu = N'CALISMA_DURUMU'
      AND NOT EXISTS
      (
          SELECT 1
          FROM dbo.CalismaDurumlari AS mevcut
          WHERE mevcut.Name = kaynak.Ad
      );

    INSERT INTO dbo.EgitimDurumlari (Name, Sil)
    SELECT kaynak.Ad, 0
    FROM @Kaynak AS kaynak
    WHERE kaynak.ReferansTuruKodu = N'EGITIM_DURUMU'
      AND NOT EXISTS
      (
          SELECT 1
          FROM dbo.EgitimDurumlari AS mevcut
          WHERE mevcut.Name = kaynak.Ad
      );

    DECLARE @Esleme TABLE
    (
        ReferansTuruKodu nvarchar(50) NOT NULL,
        KaynakId int NOT NULL,
        Kod nvarchar(80) NOT NULL
    );

    INSERT INTO @Esleme (ReferansTuruKodu, KaynakId, Kod)
    SELECT kaynak.ReferansTuruKodu, durum.Id, kaynak.Kod
    FROM @Kaynak AS kaynak
    INNER JOIN dbo.BasvuruDurumlari AS durum ON durum.Name = kaynak.Ad
    WHERE kaynak.ReferansTuruKodu = N'BASVURU_DURUMU'
    UNION ALL
    SELECT kaynak.ReferansTuruKodu, yardim.Id, kaynak.Kod
    FROM @Kaynak AS kaynak
    INNER JOIN dbo.YardimTurleri AS yardim ON yardim.Name = kaynak.Ad
    WHERE kaynak.ReferansTuruKodu = N'YARDIM_TURU'
    UNION ALL
    SELECT kaynak.ReferansTuruKodu, engel.Id, kaynak.Kod
    FROM @Kaynak AS kaynak
    INNER JOIN dbo.EngelTurleri AS engel ON engel.Name = kaynak.Ad
    WHERE kaynak.ReferansTuruKodu = N'ENGEL_TURU'
    UNION ALL
    SELECT kaynak.ReferansTuruKodu, kanal.Id, kaynak.Kod
    FROM @Kaynak AS kaynak
    INNER JOIN dbo.TalepGelisKanallari AS kanal ON kanal.Name = kaynak.Ad
    WHERE kaynak.ReferansTuruKodu = N'TALEP_GELIS_KANALI'
    UNION ALL
    SELECT kaynak.ReferansTuruKodu, yakinlik.Id, kaynak.Kod
    FROM @Kaynak AS kaynak
    INNER JOIN dbo.Yakinliklar AS yakinlik ON yakinlik.Name = kaynak.Ad
    WHERE kaynak.ReferansTuruKodu = N'YAKINLIK'
    UNION ALL
    SELECT kaynak.ReferansTuruKodu, calisma.Id, kaynak.Kod
    FROM @Kaynak AS kaynak
    INNER JOIN dbo.CalismaDurumlari AS calisma ON calisma.Name = kaynak.Ad
    WHERE kaynak.ReferansTuruKodu = N'CALISMA_DURUMU'
    UNION ALL
    SELECT kaynak.ReferansTuruKodu, egitim.Id, kaynak.Kod
    FROM @Kaynak AS kaynak
    INNER JOIN dbo.EgitimDurumlari AS egitim ON egitim.Name = kaynak.Ad
    WHERE kaynak.ReferansTuruKodu = N'EGITIM_DURUMU';

    INSERT INTO sosyobel.ReferansKodlari (ReferansTuruKodu, KaynakId, Kod)
    SELECT esleme.ReferansTuruKodu, esleme.KaynakId, esleme.Kod
    FROM @Esleme AS esleme
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM sosyobel.ReferansKodlari AS mevcut
        WHERE mevcut.ReferansTuruKodu = esleme.ReferansTuruKodu
          AND mevcut.KaynakId = esleme.KaynakId
    )
      AND NOT EXISTS
    (
        SELECT 1
        FROM sosyobel.ReferansKodlari AS mevcut
        WHERE mevcut.ReferansTuruKodu = esleme.ReferansTuruKodu
          AND mevcut.Kod = esleme.Kod
    );

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;

