/*
  Yalnızca proje görüşmelerinde açıkça kesinleşen ortak seçenekleri ekler.

  Özellikle aşağıdakiler bu dosyada bilinçli olarak yoktur:
  - Belediye kaydı ve logosu
  - Yardım türleri
  - Engel türleri
  - Hane sorularının kesin seçenekleri

  Bu değerler şirket/belediye tarafından doğrulanmadan üretim verisi yapılmaz.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'sosyobel.BasvuruDurumlari', N'U') IS NULL
BEGIN
    THROW 51010, N'Önce 001_create_sosyobel_v2_schema.sql çalıştırılmalıdır.', 1;
END;

BEGIN TRY
    BEGIN TRANSACTION;

    ;WITH Kaynak (Kod, Ad, Sira) AS
    (
        SELECT N'TASLAK', N'Taslak', 1 UNION ALL
        SELECT N'KURUL_BEKLIYOR', N'Kurul Bekliyor', 2 UNION ALL
        SELECT N'TAMAMLANDI', N'Tamamlandı', 3
    )
    INSERT INTO sosyobel.BasvuruDurumlari (Kod, Ad, Sira)
    SELECT k.Kod, k.Ad, k.Sira
    FROM Kaynak AS k
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM sosyobel.BasvuruDurumlari AS mevcut
        WHERE mevcut.Kod = k.Kod
    );

    ;WITH Kaynak (Kod, Ad, Sira) AS
    (
        SELECT N'CALISIYOR', N'Çalışıyor', 1 UNION ALL
        SELECT N'CALISMIYOR', N'Çalışmıyor', 2 UNION ALL
        SELECT N'EMEKLI', N'Emekli', 3
    )
    INSERT INTO sosyobel.CalismaDurumlari (Kod, Ad, Sira)
    SELECT k.Kod, k.Ad, k.Sira
    FROM Kaynak AS k
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM sosyobel.CalismaDurumlari AS mevcut
        WHERE mevcut.Kod = k.Kod
    );

    ;WITH Kaynak (Kod, Ad, Sira) AS
    (
        SELECT N'OKURYAZAR_DEGIL', N'Okuryazar Değil', 1 UNION ALL
        SELECT N'OKURYAZAR', N'Okuryazar', 2 UNION ALL
        SELECT N'ILKOKUL', N'İlkokul', 3 UNION ALL
        SELECT N'ILKOGRETIM_TERK', N'İlk Öğretim Terk', 4 UNION ALL
        SELECT N'ORTAOKUL', N'Ortaokul', 5 UNION ALL
        SELECT N'LISE', N'Lise', 6 UNION ALL
        SELECT N'ON_LISANS', N'Ön Lisans', 7 UNION ALL
        SELECT N'LISANS', N'Lisans', 8 UNION ALL
        SELECT N'YUKSEK_LISANS', N'Yüksek Lisans', 9 UNION ALL
        SELECT N'DOKTORA', N'Doktora', 10
    )
    INSERT INTO sosyobel.EgitimDurumlari (Kod, Ad, Sira)
    SELECT k.Kod, k.Ad, k.Sira
    FROM Kaynak AS k
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM sosyobel.EgitimDurumlari AS mevcut
        WHERE mevcut.Kod = k.Kod
    );

    ;WITH Kaynak (Kod, Ad, Sira) AS
    (
        SELECT N'ES', N'Eş', 1 UNION ALL
        SELECT N'ANNE', N'Anne', 2 UNION ALL
        SELECT N'BABA', N'Baba', 3 UNION ALL
        SELECT N'COCUK', N'Çocuk', 4 UNION ALL
        SELECT N'KARDES', N'Kardeş', 5 UNION ALL
        SELECT N'BUYUKANNE', N'Büyükanne', 6 UNION ALL
        SELECT N'BUYUKBABA', N'Büyükbaba', 7 UNION ALL
        SELECT N'TORUN', N'Torun', 8 UNION ALL
        SELECT N'GELIN', N'Gelin', 9 UNION ALL
        SELECT N'DAMAT', N'Damat', 10 UNION ALL
        SELECT N'KAYINVALIDE', N'Kayınvalide', 11 UNION ALL
        SELECT N'KAYINPEDER', N'Kayınpeder', 12 UNION ALL
        SELECT N'DIGER', N'Diğer', 13
    )
    INSERT INTO sosyobel.Yakinliklar (Kod, Ad, Sira)
    SELECT k.Kod, k.Ad, k.Sira
    FROM Kaynak AS k
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM sosyobel.Yakinliklar AS mevcut
        WHERE mevcut.Kod = k.Kod
    );

    ;WITH Kaynak (Kod, Ad, Sira) AS
    (
        SELECT N'SAG', N'Sağ', 1 UNION ALL
        SELECT N'OLU', N'Ölü', 2
    )
    INSERT INTO sosyobel.YasamDurumlari (Kod, Ad, Sira)
    SELECT k.Kod, k.Ad, k.Sira
    FROM Kaynak AS k
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM sosyobel.YasamDurumlari AS mevcut
        WHERE mevcut.Kod = k.Kod
    );

    ;WITH Kaynak (Kod, Ad, Sira) AS
    (
        SELECT N'MOBIL_SAHA', N'Mobil Saha Uygulaması', 1 UNION ALL
        SELECT N'VERI_AKTARIMI', N'Veri Aktarımı', 2
    )
    INSERT INTO sosyobel.TalepGelisKanallari (Kod, Ad, Sira)
    SELECT k.Kod, k.Ad, k.Sira
    FROM Kaynak AS k
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM sosyobel.TalepGelisKanallari AS mevcut
        WHERE mevcut.Kod = k.Kod
    );

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
