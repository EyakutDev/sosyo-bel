/*
    Yalniz gecici auth-flow veritabaninda sirketin saha gorevi okuma tablolarini
    taklit eder. Canli sirket veritabaninda calistirilmaz.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.Vatandaslar', N'U') IS NULL OR
   COL_LENGTH(N'dbo.Vatandaslar', N'Id') IS NULL OR
   OBJECT_ID(N'dbo.SahaAktiviteleri', N'U') IS NOT NULL
BEGIN
    THROW 51380, N'Saha gorevi fixture onkosullari saglanmiyor.', 1;
END;

/* 014 fixture yalniz Id kolonunu kurar; görev sorgusunun okuduğu alanlar eklenir. */
IF COL_LENGTH(N'dbo.Vatandaslar', N'Ad') IS NULL
    ALTER TABLE dbo.Vatandaslar
        ADD Ad nvarchar(max) NOT NULL
            CONSTRAINT DF_AuthFixture_Vatandaslar_Ad DEFAULT N'';

IF COL_LENGTH(N'dbo.Vatandaslar', N'Soyad') IS NULL
    ALTER TABLE dbo.Vatandaslar
        ADD Soyad nvarchar(max) NOT NULL
            CONSTRAINT DF_AuthFixture_Vatandaslar_Soyad DEFAULT N'';

IF COL_LENGTH(N'dbo.Vatandaslar', N'AcikAdres') IS NULL
    ALTER TABLE dbo.Vatandaslar
        ADD AcikAdres nvarchar(max) NOT NULL
            CONSTRAINT DF_AuthFixture_Vatandaslar_AcikAdres DEFAULT N'';

CREATE TABLE dbo.SahaAktiviteleri
(
    Id                  int IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_AuthFixture_SahaAktiviteleri PRIMARY KEY,
    VatandasId          int NOT NULL,
    PersonelId          nvarchar(450) NOT NULL,
    Aciklama            nvarchar(max) NOT NULL,
    Durum               nvarchar(max) NOT NULL,
    ReddetmeSebebi      nvarchar(max) NULL,
    OlusturulmaTarihi   datetime2(7) NOT NULL,
    CONSTRAINT FK_AuthFixture_SahaAktiviteleri_Vatandas
        FOREIGN KEY (VatandasId) REFERENCES dbo.Vatandaslar (Id),
    CONSTRAINT FK_AuthFixture_SahaAktiviteleri_Personel
        FOREIGN KEY (PersonelId) REFERENCES dbo.AspNetUsers (Id)
);
