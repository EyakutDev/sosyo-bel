/*
    Sosyo-Bel sirket semasi uyumluluk migration'i 004

    Aile kaydinin ana alanlari sirketin dbo.BasvuruAileFertleri tablosunda
    tutulur. Bu migration yalniz mobil uygulamaya ozel yasam durumu ve audit
    alanlarini ekler; mevcut dbo nesnelerini veya verilerini degistirmez.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.AspNetUsers', N'U') IS NULL OR
   OBJECT_ID(N'dbo.BasvuruAileFertleri', N'U') IS NULL OR
   OBJECT_ID(N'sosyobel.BasvuruUygulamaBilgileri', N'U') IS NULL
BEGIN
    THROW 51302, N'Uyumluluk 004 icin gereken sirket veya 001 tablolari eksik.', 1;
END;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'sosyobel.YasamDurumlari', N'U') IS NULL
    BEGIN
        CREATE TABLE sosyobel.YasamDurumlari
        (
            Id          int IDENTITY(1,1) NOT NULL,
            Kod         nvarchar(50) NOT NULL,
            Ad          nvarchar(100) NOT NULL,
            AktifMi     bit NOT NULL
                CONSTRAINT DF_YasamDurumlari_AktifMi DEFAULT (1),
            SiraNo      smallint NOT NULL
                CONSTRAINT DF_YasamDurumlari_SiraNo DEFAULT (0),
            CONSTRAINT PK_YasamDurumlari PRIMARY KEY CLUSTERED (Id)
        );

        CREATE UNIQUE INDEX UX_YasamDurumlari_Kod
            ON sosyobel.YasamDurumlari (Kod);

        EXEC sys.sp_addextendedproperty
            @name = N'SosyoBelOwnerMigration',
            @value = N'004',
            @level0type = N'SCHEMA',
            @level0name = N'sosyobel',
            @level1type = N'TABLE',
            @level1name = N'YasamDurumlari';
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sosyobel.YasamDurumlari
        WHERE Kod = N'SAG'
    )
    BEGIN
        INSERT INTO sosyobel.YasamDurumlari (Kod, Ad, SiraNo)
        VALUES (N'SAG', N'Sag', 10);
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sosyobel.YasamDurumlari
        WHERE Kod = N'OLU'
    )
    BEGIN
        INSERT INTO sosyobel.YasamDurumlari (Kod, Ad, SiraNo)
        VALUES (N'OLU', N'Olu', 20);
    END;

    IF OBJECT_ID(N'sosyobel.BasvuruAileFertiUygulamaBilgileri', N'U') IS NULL
    BEGIN
        CREATE TABLE sosyobel.BasvuruAileFertiUygulamaBilgileri
        (
            BasvuruAileFertiId         int NOT NULL,
            YakinlikDigerAciklama      nvarchar(100) NULL,
            EngelAciklamasi            nvarchar(250) NULL,
            YasamDurumuId              int NOT NULL,
            OlusturanUserId            nvarchar(450) NOT NULL,
            OlusturulmaTarihiUtc       datetime2(3) NOT NULL
                CONSTRAINT DF_BasvuruAileFertiUygulama_Olusturulma
                    DEFAULT SYSUTCDATETIME(),
            RowVersion                 rowversion NOT NULL,
            CONSTRAINT PK_BasvuruAileFertiUygulamaBilgileri
                PRIMARY KEY CLUSTERED (BasvuruAileFertiId),
            CONSTRAINT FK_BasvuruAileFertiUygulama_AileFerti
                FOREIGN KEY (BasvuruAileFertiId)
                REFERENCES dbo.BasvuruAileFertleri (Id)
                ON DELETE CASCADE,
            CONSTRAINT FK_BasvuruAileFertiUygulama_YasamDurumu
                FOREIGN KEY (YasamDurumuId)
                REFERENCES sosyobel.YasamDurumlari (Id),
            CONSTRAINT FK_BasvuruAileFertiUygulama_OlusturanUser
                FOREIGN KEY (OlusturanUserId)
                REFERENCES dbo.AspNetUsers (Id)
        );

        CREATE INDEX IX_BasvuruAileFertiUygulama_YasamDurumu
            ON sosyobel.BasvuruAileFertiUygulamaBilgileri (YasamDurumuId);

        EXEC sys.sp_addextendedproperty
            @name = N'SosyoBelOwnerMigration',
            @value = N'004',
            @level0type = N'SCHEMA',
            @level0name = N'sosyobel',
            @level1type = N'TABLE',
            @level1name = N'BasvuruAileFertiUygulamaBilgileri';
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
