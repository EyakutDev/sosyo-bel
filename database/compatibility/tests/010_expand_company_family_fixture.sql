/*
    Yalniz gecici dogrulama veritabani icin sirketin aile tablosunu ve ilgili
    lookup kolonlarini tamamlar. Sirket veya canli ortamda calistirilmaz.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.Basvurular', N'U') IS NULL OR
   OBJECT_ID(N'dbo.CalismaDurumlari', N'U') IS NULL OR
   OBJECT_ID(N'dbo.EgitimDurumlari', N'U') IS NULL OR
   OBJECT_ID(N'dbo.EngelTurleri', N'U') IS NULL OR
   OBJECT_ID(N'dbo.Yakinliklar', N'U') IS NULL
BEGIN
    THROW 51300, N'Once minimal sirket fixture olusturulmalidir.', 1;
END;

IF OBJECT_ID(N'dbo.BasvuruAileFertleri', N'U') IS NOT NULL OR
   COL_LENGTH(N'dbo.CalismaDurumlari', N'Name') IS NOT NULL OR
   COL_LENGTH(N'dbo.EgitimDurumlari', N'Name') IS NOT NULL OR
   COL_LENGTH(N'dbo.Yakinliklar', N'Name') IS NOT NULL
BEGIN
    THROW 51301, N'Aile fixture daha once uygulanmis veya kismen mevcut.', 1;
END;

ALTER TABLE dbo.CalismaDurumlari ADD
    Name nvarchar(50) NOT NULL
        CONSTRAINT DF_Test_CalismaDurumlari_Name DEFAULT (N''),
    Sil bit NOT NULL
        CONSTRAINT DF_Test_CalismaDurumlari_Sil DEFAULT (0);

ALTER TABLE dbo.EgitimDurumlari ADD
    Name nvarchar(50) NOT NULL
        CONSTRAINT DF_Test_EgitimDurumlari_Name DEFAULT (N''),
    Sil bit NOT NULL
        CONSTRAINT DF_Test_EgitimDurumlari_Sil DEFAULT (0);

ALTER TABLE dbo.Yakinliklar ADD
    Name nvarchar(50) NOT NULL
        CONSTRAINT DF_Test_Yakinliklar_Name DEFAULT (N''),
    Sil bit NOT NULL
        CONSTRAINT DF_Test_Yakinliklar_Sil DEFAULT (0);

CREATE TABLE dbo.BasvuruAileFertleri
(
    Id                  int IDENTITY(1,1) NOT NULL,
    BasvuruId           int NOT NULL,
    AdSoyad             nvarchar(max) NOT NULL,
    Yas                 int NOT NULL,
    EngelDurumu         bit NOT NULL,
    EngelTuruId         int NULL,
    CalismaDurumuId     int NULL,
    EgitimDurumuId      int NULL,
    YakinlikId          int NOT NULL,
    CONSTRAINT PK_Test_BasvuruAileFertleri PRIMARY KEY CLUSTERED (Id),
    CONSTRAINT FK_Test_BasvuruAileFertleri_Basvurular
        FOREIGN KEY (BasvuruId) REFERENCES dbo.Basvurular (Id)
        ON DELETE CASCADE,
    CONSTRAINT FK_Test_BasvuruAileFertleri_Calisma
        FOREIGN KEY (CalismaDurumuId) REFERENCES dbo.CalismaDurumlari (Id),
    CONSTRAINT FK_Test_BasvuruAileFertleri_Egitim
        FOREIGN KEY (EgitimDurumuId) REFERENCES dbo.EgitimDurumlari (Id),
    CONSTRAINT FK_Test_BasvuruAileFertleri_Engel
        FOREIGN KEY (EngelTuruId) REFERENCES dbo.EngelTurleri (Id),
    CONSTRAINT FK_Test_BasvuruAileFertleri_Yakinlik
        FOREIGN KEY (YakinlikId) REFERENCES dbo.Yakinliklar (Id)
);
