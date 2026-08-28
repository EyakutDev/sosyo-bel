/*
    Sosyo-Bel sirket semasi uyumluluk migration'i 005

    Sirket semasinda hane soru ve cevap tablolari bulunmadigi icin bu migration
    yalniz sosyobel semasinda yonetilebilir soru, secenek ve basvuru cevabi
    tablolarini olusturur. Mevcut dbo nesnelerini veya verilerini degistirmez.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

IF OBJECT_ID(N'dbo.AspNetUsers', N'U') IS NULL OR
   OBJECT_ID(N'dbo.Basvurular', N'U') IS NULL
BEGIN
    THROW 51320, N'Uyumluluk 005 icin dbo kullanici ve basvuru tablolari gereklidir.', 1;
END;

DECLARE @ExistingTableCount int =
(
    SELECT COUNT(*)
    FROM
    (
        VALUES
            (N'sosyobel.HaneSorulari'),
            (N'sosyobel.HaneSoruSecenekleri'),
            (N'sosyobel.BasvuruHaneCevaplari')
    ) AS requiredTable(ObjectName)
    WHERE OBJECT_ID(requiredTable.ObjectName, N'U') IS NOT NULL
);

IF @ExistingTableCount > 0 AND @ExistingTableCount < 3
BEGIN
    THROW 51321, N'Uyumluluk 005 kismen uygulanmis gorunuyor. Once sema denetimi yapilmalidir.', 1;
END;

IF @ExistingTableCount = 3 AND
(
    ISNULL(CONVERT(nvarchar(20), (
        SELECT value
        FROM sys.extended_properties
        WHERE major_id = OBJECT_ID(N'sosyobel.HaneSorulari')
          AND minor_id = 0
          AND name = N'SosyoBelOwnerMigration'
    )), N'') <> N'005' OR
    ISNULL(CONVERT(nvarchar(20), (
        SELECT value
        FROM sys.extended_properties
        WHERE major_id = OBJECT_ID(N'sosyobel.HaneSoruSecenekleri')
          AND minor_id = 0
          AND name = N'SosyoBelOwnerMigration'
    )), N'') <> N'005' OR
    ISNULL(CONVERT(nvarchar(20), (
        SELECT value
        FROM sys.extended_properties
        WHERE major_id = OBJECT_ID(N'sosyobel.BasvuruHaneCevaplari')
          AND minor_id = 0
          AND name = N'SosyoBelOwnerMigration'
    )), N'') <> N'005'
)
BEGIN
    THROW 51322, N'Mevcut hane tablolarinin 005 migration sahipligi dogrulanamadi.', 1;
END;

BEGIN TRY
    BEGIN TRANSACTION;

    IF @ExistingTableCount = 0
    BEGIN
        /* Uygulama tek belediyeye ait oldugu icin soru kodu kurum icinde tektir. */
        CREATE TABLE sosyobel.HaneSorulari
        (
            Id          int IDENTITY(1,1) NOT NULL,
            Kod         nvarchar(80) NOT NULL,
            SoruMetni   nvarchar(300) NOT NULL,
            CevapTipi   nvarchar(30) NOT NULL,
            ZorunluMu   bit NOT NULL
                CONSTRAINT DF_HaneSorulari_ZorunluMu DEFAULT (0),
            Sira        smallint NOT NULL,
            AktifMi     bit NOT NULL
                CONSTRAINT DF_HaneSorulari_AktifMi DEFAULT (1),
            CONSTRAINT PK_HaneSorulari PRIMARY KEY CLUSTERED (Id),
            CONSTRAINT UQ_HaneSorulari_Kod UNIQUE (Kod),
            CONSTRAINT CK_HaneSorulari_CevapTipi CHECK
                (CevapTipi IN
                    (N'TEK_SECIM', N'COKLU_SECIM', N'METIN', N'SAYI', N'EVET_HAYIR')),
            CONSTRAINT CK_HaneSorulari_Sira CHECK (Sira BETWEEN 1 AND 32767)
        );

        CREATE TABLE sosyobel.HaneSoruSecenekleri
        (
            Id          int IDENTITY(1,1) NOT NULL,
            SoruId      int NOT NULL,
            Kod         nvarchar(80) NOT NULL,
            Etiket      nvarchar(200) NOT NULL,
            Sira        smallint NOT NULL,
            AktifMi     bit NOT NULL
                CONSTRAINT DF_HaneSoruSecenekleri_AktifMi DEFAULT (1),
            CONSTRAINT PK_HaneSoruSecenekleri PRIMARY KEY CLUSTERED (Id),
            CONSTRAINT UQ_HaneSoruSecenekleri_Soru_Id UNIQUE (SoruId, Id),
            CONSTRAINT UQ_HaneSoruSecenekleri_Soru_Kod UNIQUE (SoruId, Kod),
            CONSTRAINT FK_HaneSoruSecenekleri_HaneSorulari
                FOREIGN KEY (SoruId)
                REFERENCES sosyobel.HaneSorulari (Id),
            CONSTRAINT CK_HaneSoruSecenekleri_Sira
                CHECK (Sira BETWEEN 1 AND 32767)
        );

        /* Cevaplar sirketin dbo basvurusuna baglanir; dbo tablosu degistirilmez. */
        CREATE TABLE sosyobel.BasvuruHaneCevaplari
        (
            Id                    int IDENTITY(1,1) NOT NULL,
            BasvuruId             int NOT NULL,
            SoruId                int NOT NULL,
            SecenekId             int NULL,
            SerbestMetinCevap     nvarchar(1000) NULL,
            SayisalCevap          decimal(18,2) NULL,
            OlusturanUserId       nvarchar(450) NOT NULL,
            OlusturulmaTarihiUtc  datetime2(3) NOT NULL
                CONSTRAINT DF_BasvuruHaneCevaplari_Olusturulma
                    DEFAULT SYSUTCDATETIME(),
            GuncellenmeTarihiUtc  datetime2(3) NULL,
            RowVersion            rowversion NOT NULL,
            CONSTRAINT PK_BasvuruHaneCevaplari PRIMARY KEY CLUSTERED (Id),
            CONSTRAINT UQ_BasvuruHaneCevaplari_Basvuru_Soru
                UNIQUE (BasvuruId, SoruId),
            CONSTRAINT FK_BasvuruHaneCevaplari_Basvurular
                FOREIGN KEY (BasvuruId)
                REFERENCES dbo.Basvurular (Id)
                ON DELETE CASCADE,
            CONSTRAINT FK_BasvuruHaneCevaplari_HaneSorulari
                FOREIGN KEY (SoruId)
                REFERENCES sosyobel.HaneSorulari (Id),
            CONSTRAINT FK_BasvuruHaneCevaplari_Secenek
                FOREIGN KEY (SoruId, SecenekId)
                REFERENCES sosyobel.HaneSoruSecenekleri (SoruId, Id),
            CONSTRAINT FK_BasvuruHaneCevaplari_OlusturanUser
                FOREIGN KEY (OlusturanUserId)
                REFERENCES dbo.AspNetUsers (Id),
            CONSTRAINT CK_BasvuruHaneCevaplari_TekCevap CHECK
            (
                (CASE WHEN SecenekId IS NULL THEN 0 ELSE 1 END) +
                (CASE WHEN SerbestMetinCevap IS NULL THEN 0 ELSE 1 END) +
                (CASE WHEN SayisalCevap IS NULL THEN 0 ELSE 1 END) = 1
            )
        );

        CREATE INDEX IX_BasvuruHaneCevaplari_SoruId
            ON sosyobel.BasvuruHaneCevaplari (SoruId);

        EXEC sys.sp_addextendedproperty
            @name = N'SosyoBelOwnerMigration',
            @value = N'005',
            @level0type = N'SCHEMA',
            @level0name = N'sosyobel',
            @level1type = N'TABLE',
            @level1name = N'HaneSorulari';

        EXEC sys.sp_addextendedproperty
            @name = N'SosyoBelOwnerMigration',
            @value = N'005',
            @level0type = N'SCHEMA',
            @level0name = N'sosyobel',
            @level1type = N'TABLE',
            @level1name = N'HaneSoruSecenekleri';

        EXEC sys.sp_addextendedproperty
            @name = N'SosyoBelOwnerMigration',
            @value = N'005',
            @level0type = N'SCHEMA',
            @level0name = N'sosyobel',
            @level1type = N'TABLE',
            @level1name = N'BasvuruHaneCevaplari';
    END;

    /* Mobil formun mevcut bes sorusu kararli kodlarla global tanimlanir. */
    DECLARE @Questions TABLE
    (
        Kod nvarchar(80) NOT NULL PRIMARY KEY,
        SoruMetni nvarchar(300) NOT NULL,
        Sira smallint NOT NULL
    );

    INSERT INTO @Questions (Kod, SoruMetni, Sira)
    VALUES
        (N'MULKIYET_DURUMU', N'Mülkiyet Durumu', 1),
        (N'MULK_TIPI', N'Mülkün Tipi?', 2),
        (N'EV_TEMIZLIGI', N'Ev Temiz mi?', 3),
        (N'BARINMA_DURUMU', N'Barındığın Yerin Durumu?', 4),
        (N'EV_ESYALARI', N'Evdeki Eşyalar', 5);

    INSERT INTO sosyobel.HaneSorulari
        (Kod, SoruMetni, CevapTipi, ZorunluMu, Sira)
    SELECT
        sourceQuestion.Kod,
        sourceQuestion.SoruMetni,
        N'TEK_SECIM',
        1,
        sourceQuestion.Sira
    FROM @Questions AS sourceQuestion
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM sosyobel.HaneSorulari AS targetQuestion
        WHERE targetQuestion.Kod = sourceQuestion.Kod
    );

    DECLARE @Options TABLE
    (
        SoruKodu nvarchar(80) NOT NULL,
        Kod nvarchar(80) NOT NULL,
        Etiket nvarchar(200) NOT NULL,
        Sira smallint NOT NULL,
        PRIMARY KEY (SoruKodu, Kod)
    );

    INSERT INTO @Options (SoruKodu, Kod, Etiket, Sira)
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
        (SoruId, Kod, Etiket, Sira)
    SELECT
        targetQuestion.Id,
        sourceOption.Kod,
        sourceOption.Etiket,
        sourceOption.Sira
    FROM @Options AS sourceOption
    INNER JOIN sosyobel.HaneSorulari AS targetQuestion
        ON targetQuestion.Kod = sourceOption.SoruKodu
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM sosyobel.HaneSoruSecenekleri AS targetOption
        WHERE targetOption.SoruId = targetQuestion.Id
          AND targetOption.Kod = sourceOption.Kod
    );

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
