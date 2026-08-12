/*
    Yalniz yerel uyumluluk testleri icin sirketin vatandas fotograf tablosunu
    taklit eder. Migration degildir ve sirket ortaminda calistirilmaz.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.Vatandaslar', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Vatandaslar
    (
        Id int IDENTITY(1,1) NOT NULL,
        CONSTRAINT PK_Test_Vatandaslar PRIMARY KEY CLUSTERED (Id)
    );
END;

IF OBJECT_ID(N'dbo.HaneFotograflari', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.HaneFotograflari
    (
        Id int IDENTITY(1,1) NOT NULL,
        VatandasId int NOT NULL,
        FotografYolu nvarchar(max) NOT NULL,
        Aciklama nvarchar(max) NULL,
        YuklenmeTarihi datetime2(7) NOT NULL,
        CONSTRAINT PK_Test_HaneFotograflari PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_Test_HaneFotograflari_Vatandaslar
            FOREIGN KEY (VatandasId)
            REFERENCES dbo.Vatandaslar (Id)
            ON DELETE CASCADE
    );
END;
