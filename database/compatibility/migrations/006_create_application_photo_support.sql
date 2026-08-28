/*
    Sosyo-Bel sirket semasi uyumluluk migration'i 006

    Sirketin dbo.HaneFotograflari tablosu vatandasa, Basvurular.HaneFotografYolu
    ise tek bir yola baglidir. Mobil saha akisi basvuruya bagli 1-15 sirali
    fotograf gerektirdigi icin bu migration yalniz sosyobel semasinda metadata
    tablosu olusturur; mevcut dbo nesnelerini veya verilerini degistirmez.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

IF OBJECT_ID(N'dbo.AspNetUsers', N'U') IS NULL OR
   OBJECT_ID(N'dbo.Basvurular', N'U') IS NULL
BEGIN
    THROW 51340, N'Uyumluluk 006 icin dbo kullanici ve basvuru tablolari gereklidir.', 1;
END;

IF OBJECT_ID(N'sosyobel.BasvuruFotograflari', N'U') IS NOT NULL
BEGIN
    IF ISNULL(CONVERT(nvarchar(20), (
        SELECT value
        FROM sys.extended_properties
        WHERE major_id = OBJECT_ID(N'sosyobel.BasvuruFotograflari')
          AND minor_id = 0
          AND name = N'SosyoBelOwnerMigration'
    )), N'') <> N'006'
    BEGIN
        THROW 51341, N'Mevcut BasvuruFotograflari tablosunun 006 migration sahipligi dogrulanamadi.', 1;
    END;

    PRINT N'Uyumluluk 006 tablosu zaten mevcut; migration yeniden uygulanmadi.';
    RETURN;
END;

BEGIN TRY
    BEGIN TRANSACTION;

    /*
      Dosya icerigi SQL Server'a yazilmaz. StorageKey, IIS disindaki ozel klasor
      veya ilerideki object storage nesnesini gosterir.
    */
    CREATE TABLE sosyobel.BasvuruFotograflari
    (
        Id                    int IDENTITY(1,1) NOT NULL,
        BasvuruId             int NOT NULL,
        StorageKey            nvarchar(500) NOT NULL,
        OrijinalDosyaAdi      nvarchar(255) NULL,
        MimeType              varchar(100) NOT NULL,
        BoyutByte             bigint NOT NULL,
        Sha256                binary(32) NOT NULL,
        SiraNo                tinyint NOT NULL,
        TaramaDurumuKodu      nvarchar(30) NOT NULL
            CONSTRAINT DF_BasvuruFotograflari_TaramaDurumu
                DEFAULT (N'BEKLIYOR'),
        ExifTemizlendiMi      bit NOT NULL
            CONSTRAINT DF_BasvuruFotograflari_ExifTemizlendi
                DEFAULT (0),
        SilindiMi             bit NOT NULL
            CONSTRAINT DF_BasvuruFotograflari_Silindi
                DEFAULT (0),
        OlusturanUserId       nvarchar(450) NOT NULL,
        OlusturulmaTarihiUtc  datetime2(3) NOT NULL
            CONSTRAINT DF_BasvuruFotograflari_Olusturulma
                DEFAULT SYSUTCDATETIME(),
        SilenUserId           nvarchar(450) NULL,
        SilinmeTarihiUtc      datetime2(3) NULL,
        RowVersion            rowversion NOT NULL,
        CONSTRAINT PK_BasvuruFotograflari PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_BasvuruFotograflari_Basvurular
            FOREIGN KEY (BasvuruId)
            REFERENCES dbo.Basvurular (Id)
            ON DELETE CASCADE,
        CONSTRAINT FK_BasvuruFotograflari_OlusturanUser
            FOREIGN KEY (OlusturanUserId)
            REFERENCES dbo.AspNetUsers (Id),
        CONSTRAINT FK_BasvuruFotograflari_SilenUser
            FOREIGN KEY (SilenUserId)
            REFERENCES dbo.AspNetUsers (Id),
        CONSTRAINT CK_BasvuruFotograflari_SiraNo
            CHECK (SiraNo BETWEEN 1 AND 15),
        CONSTRAINT CK_BasvuruFotograflari_Boyut
            CHECK (BoyutByte BETWEEN 1 AND 10485760),
        CONSTRAINT CK_BasvuruFotograflari_MimeType
            CHECK (MimeType IN
                ('image/jpeg', 'image/png', 'image/heic', 'image/heif')),
        CONSTRAINT CK_BasvuruFotograflari_TaramaDurumu
            CHECK (TaramaDurumuKodu IN
                (N'BEKLIYOR', N'TEMIZ', N'KARANTINA', N'REDDEDILDI')),
        CONSTRAINT CK_BasvuruFotograflari_SilmeBilgisi CHECK
        (
            (SilindiMi = 0 AND SilenUserId IS NULL AND SilinmeTarihiUtc IS NULL) OR
            (SilindiMi = 1 AND SilenUserId IS NOT NULL AND SilinmeTarihiUtc IS NOT NULL)
        )
    );

    /*
      Sira 1-15 araliginda ve aktif kayit icin benzersiz oldugundan bir
      basvurunun aktif fotograf sayisi veritabani seviyesinde de 15'i gecemez.
    */
    CREATE UNIQUE INDEX UX_BasvuruFotograflari_AktifSira
        ON sosyobel.BasvuruFotograflari (BasvuruId, SiraNo)
        WHERE SilindiMi = 0;

    CREATE UNIQUE INDEX UX_BasvuruFotograflari_AktifStorageKey
        ON sosyobel.BasvuruFotograflari (StorageKey)
        WHERE SilindiMi = 0;

    CREATE INDEX IX_BasvuruFotograflari_BasvuruId
        ON sosyobel.BasvuruFotograflari (BasvuruId, SilindiMi);

    EXEC sys.sp_addextendedproperty
        @name = N'SosyoBelOwnerMigration',
        @value = N'006',
        @level0type = N'SCHEMA',
        @level0name = N'sosyobel',
        @level1type = N'TABLE',
        @level1name = N'BasvuruFotograflari';

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
