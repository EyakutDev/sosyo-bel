/*
  YALNIZCA YEREL GELISTIRME/TEST ICINDIR.

  Hane sorularinin kesin kurum verisi henuz verilmedi. Bu kayitlar, mobil
  tasarimda su an bulunan gecici sorulari uctan uca deneyebilmek icin tutulur.
  Uretim kurulumunda bu dosya calistirilmaz; kurumun yonetilen verisi kullanilir.
*/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'sosyobel.HaneSorulari', N'U') IS NULL OR
   OBJECT_ID(N'sosyobel.HaneSoruSecenekleri', N'U') IS NULL
BEGIN
    THROW 51060, N'Once SosyoBel V2 semasi olusturulmalidir.', 1;
END;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @Sorular TABLE
    (
        Kod nvarchar(80) NOT NULL,
        SoruMetni nvarchar(300) NOT NULL,
        Sira smallint NOT NULL
    );

    INSERT INTO @Sorular (Kod, SoruMetni, Sira)
    VALUES
        (N'MULKIYET_DURUMU', N'Mülkiyet Durumu', 1),
        (N'MULK_TIPI', N'Mülkün Tipi ?', 2),
        (N'EV_TEMIZLIGI', N'Ev Temiz mi?', 3),
        (N'BARINMA_DURUMU', N'Barındığın Yeri Durumu?', 4),
        (N'EV_ESYALARI', N'Evdeki Eşyalar', 5);

    INSERT INTO sosyobel.HaneSorulari
        (BelediyeId, Kod, SoruMetni, CevapTipi, ZorunluMu, Sira, AktifMi)
    SELECT NULL, kaynak.Kod, kaynak.SoruMetni, N'TEK_SECIM', 0, kaynak.Sira, 1
    FROM @Sorular AS kaynak
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM sosyobel.HaneSorulari AS mevcut
        WHERE mevcut.BelediyeId IS NULL AND mevcut.Kod = kaynak.Kod
    );

    DECLARE @Secenekler TABLE
    (
        SoruKodu nvarchar(80) NOT NULL,
        Kod nvarchar(80) NOT NULL,
        Etiket nvarchar(200) NOT NULL,
        Sira smallint NOT NULL
    );

    INSERT INTO @Secenekler (SoruKodu, Kod, Etiket, Sira)
    VALUES
        (N'MULKIYET_DURUMU', N'EV_SAHIBI', N'Ev Sahibi', 1),
        (N'MULKIYET_DURUMU', N'KIRACI', N'Kiracı', 2),
        (N'MULKIYET_DURUMU', N'LOJMAN', N'Lojman', 3),
        (N'MULKIYET_DURUMU', N'DIGER', N'Diğer', 4),
        (N'MULK_TIPI', N'APARTMAN_DAIRESI', N'Apartman Dairesi', 1),
        (N'MULK_TIPI', N'MUSTAKIL_EV', N'Müstakil Ev', 2),
        (N'MULK_TIPI', N'GECEKONDU', N'Gecekondu', 3),
        (N'MULK_TIPI', N'DIGER', N'Diğer', 4),
        (N'EV_TEMIZLIGI', N'EVET', N'Evet', 1),
        (N'EV_TEMIZLIGI', N'HAYIR', N'Hayır', 2),
        (N'BARINMA_DURUMU', N'IYI', N'İyi', 1),
        (N'BARINMA_DURUMU', N'ORTA', N'Orta', 2),
        (N'BARINMA_DURUMU', N'KOTU', N'Kötü', 3),
        (N'EV_ESYALARI', N'YETERLI', N'Yeterli', 1),
        (N'EV_ESYALARI', N'KISMEN_YETERLI', N'Kısmen Yeterli', 2),
        (N'EV_ESYALARI', N'YETERSIZ', N'Yetersiz', 3);

    INSERT INTO sosyobel.HaneSoruSecenekleri
        (SoruId, Kod, Etiket, Sira, AktifMi)
    SELECT soru.Id, kaynak.Kod, kaynak.Etiket, kaynak.Sira, 1
    FROM @Secenekler AS kaynak
    INNER JOIN sosyobel.HaneSorulari AS soru
        ON soru.BelediyeId IS NULL AND soru.Kod = kaynak.SoruKodu
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM sosyobel.HaneSoruSecenekleri AS mevcut
        WHERE mevcut.SoruId = soru.Id AND mevcut.Kod = kaynak.Kod
    );

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
