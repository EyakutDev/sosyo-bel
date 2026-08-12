/*
    Yalnız geçici HTTP doğrulama veritabanı için şirketin dbo.Basvurular ve
    çekirdek lookup kolonlarını tamamlar. Şirket ortamında çalıştırılmaz.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

ALTER TABLE dbo.BasvuruDurumlari ADD
    Name nvarchar(100) NOT NULL
        CONSTRAINT DF_Test_BasvuruDurumlari_Name DEFAULT (N''),
    Sil bit NOT NULL
        CONSTRAINT DF_Test_BasvuruDurumlari_Sil DEFAULT (0);

ALTER TABLE dbo.EngelTurleri ADD
    Name nvarchar(100) NOT NULL
        CONSTRAINT DF_Test_EngelTurleri_Name DEFAULT (N''),
    Sil bit NOT NULL
        CONSTRAINT DF_Test_EngelTurleri_Sil DEFAULT (0);

ALTER TABLE dbo.TalepGelisKanallari ADD
    Name nvarchar(100) NOT NULL
        CONSTRAINT DF_Test_TalepGelisKanallari_Name DEFAULT (N''),
    Sil bit NOT NULL
        CONSTRAINT DF_Test_TalepGelisKanallari_Sil DEFAULT (0);

ALTER TABLE dbo.YardimTurleri ADD
    Name nvarchar(150) NOT NULL
        CONSTRAINT DF_Test_YardimTurleri_Name DEFAULT (N''),
    Sil bit NOT NULL
        CONSTRAINT DF_Test_YardimTurleri_Sil DEFAULT (0);

ALTER TABLE dbo.Basvurular ADD
    VatandasId int NULL,
    BasvuruTarihi datetime2(7) NOT NULL
        CONSTRAINT DF_Test_Basvurular_BasvuruTarihi
            DEFAULT SYSUTCDATETIME(),
    TalepAciklamasi nvarchar(max) NULL,
    BasvuranAd nvarchar(max) NOT NULL
        CONSTRAINT DF_Test_Basvurular_BasvuranAd DEFAULT (N''),
    BasvuruAcikAdres nvarchar(max) NULL,
    BasvuranDogumTarihi nvarchar(max) NULL,
    BasvuranSoyad nvarchar(max) NOT NULL
        CONSTRAINT DF_Test_Basvurular_BasvuranSoyad DEFAULT (N''),
    BasvuranTcKimlikNo nvarchar(11) NOT NULL
        CONSTRAINT DF_Test_Basvurular_Tc DEFAULT (N''),
    BasvuranTelefon nvarchar(max) NOT NULL
        CONSTRAINT DF_Test_Basvurular_Telefon DEFAULT (N''),
    HaneFotografYolu nvarchar(max) NULL,
    IptalAciklamasi nvarchar(max) NULL,
    IptalTarihi datetime2(7) NULL,
    BasvuruDurumuId int NULL,
    MahalleId int NULL,
    SokakId int NULL,
    YardimTuruId int NULL,
    TalepGelisKanaliId int NULL,
    OlusturanUserId nvarchar(450) NULL,
    EngelDurumu bit NOT NULL
        CONSTRAINT DF_Test_Basvurular_Engel DEFAULT (0),
    EngelOrani int NULL,
    EngelTuruId int NULL,
    PublicToken nvarchar(32) NOT NULL
        CONSTRAINT DF_Test_Basvurular_PublicToken DEFAULT (N''),
    BasvuranCinsiyet nvarchar(max) NULL,
    BasvuranDogumYeri nvarchar(max) NULL,
    BasvuranMedeniHal nvarchar(max) NULL,
    BasvuruMahalle nvarchar(max) NULL,
    BasvuruSokak nvarchar(max) NULL,
    IlKodu int NULL,
    IlceKodu int NULL,
    MahalleKodu int NULL,
    SokakKodu int NULL,
    AdresNo bigint NULL;

-- Kolonlar önce nullable eklenir; boş fixture'da şirketin NOT NULL şekline
-- güvenle çevrilir. Bu yöntem canlı tablo için kullanılmaz.
ALTER TABLE dbo.Basvurular ALTER COLUMN BasvuruDurumuId int NOT NULL;
ALTER TABLE dbo.Basvurular ALTER COLUMN YardimTuruId int NOT NULL;
ALTER TABLE dbo.Basvurular ALTER COLUMN TalepGelisKanaliId int NOT NULL;

ALTER TABLE dbo.Basvurular WITH CHECK ADD
    CONSTRAINT FK_Test_Basvurular_Status
        FOREIGN KEY (BasvuruDurumuId) REFERENCES dbo.BasvuruDurumlari (Id),
    CONSTRAINT FK_Test_Basvurular_Help
        FOREIGN KEY (YardimTuruId) REFERENCES dbo.YardimTurleri (Id),
    CONSTRAINT FK_Test_Basvurular_Channel
        FOREIGN KEY (TalepGelisKanaliId) REFERENCES dbo.TalepGelisKanallari (Id),
    CONSTRAINT FK_Test_Basvurular_Disability
        FOREIGN KEY (EngelTuruId) REFERENCES dbo.EngelTurleri (Id),
    CONSTRAINT FK_Test_Basvurular_User
        FOREIGN KEY (OlusturanUserId) REFERENCES dbo.AspNetUsers (Id);
