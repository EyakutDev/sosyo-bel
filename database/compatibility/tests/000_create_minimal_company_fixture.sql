/*
    Yalnız geçici uyumluluk test veritabanı için minimal şirket şeması.

    Üretim/test şirket veritabanında çalıştırılmaz. Paylaşılan notebook'taki
    migration 001'in bağlandığı anahtar şekillerini küçük bir fixture ile temsil
    eder; böylece uyumluluk nesneleri izole biçimde sınanabilir.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

CREATE TABLE dbo.AspNetUsers
(
    Id nvarchar(450) NOT NULL,
    CONSTRAINT PK_Test_AspNetUsers PRIMARY KEY CLUSTERED (Id)
);

CREATE TABLE dbo.Basvurular
(
    Id int IDENTITY(1,1) NOT NULL,
    CONSTRAINT PK_Test_Basvurular PRIMARY KEY CLUSTERED (Id)
);

CREATE TABLE dbo.BasvuruDurumlari
(
    Id int IDENTITY(1,1) NOT NULL,
    CONSTRAINT PK_Test_BasvuruDurumlari PRIMARY KEY CLUSTERED (Id)
);

CREATE TABLE dbo.CalismaDurumlari
(
    Id int IDENTITY(1,1) NOT NULL,
    CONSTRAINT PK_Test_CalismaDurumlari PRIMARY KEY CLUSTERED (Id)
);

CREATE TABLE dbo.EgitimDurumlari
(
    Id int IDENTITY(1,1) NOT NULL,
    CONSTRAINT PK_Test_EgitimDurumlari PRIMARY KEY CLUSTERED (Id)
);

CREATE TABLE dbo.EngelTurleri
(
    Id int IDENTITY(1,1) NOT NULL,
    CONSTRAINT PK_Test_EngelTurleri PRIMARY KEY CLUSTERED (Id)
);

CREATE TABLE dbo.TalepGelisKanallari
(
    Id int IDENTITY(1,1) NOT NULL,
    CONSTRAINT PK_Test_TalepGelisKanallari PRIMARY KEY CLUSTERED (Id)
);

CREATE TABLE dbo.Yakinliklar
(
    Id int IDENTITY(1,1) NOT NULL,
    CONSTRAINT PK_Test_Yakinliklar PRIMARY KEY CLUSTERED (Id)
);

CREATE TABLE dbo.YardimTurleri
(
    Id int IDENTITY(1,1) NOT NULL,
    CONSTRAINT PK_Test_YardimTurleri PRIMARY KEY CLUSTERED (Id)
);
