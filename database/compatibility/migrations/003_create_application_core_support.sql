/*
    Sosyo-Bel şirket şeması uyumluluk migration'ı 003

    dbo.Basvurular ana kayıt olmaya devam eder. Bu migration yalnız mobil API'nin
    taslak ve kurula gönderim geçişlerini değişmez biçimde izleyen durum geçmişi
    tablosunu ekler; mevcut dbo nesnelerine veya verilerine dokunmaz.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.AspNetUsers', N'U') IS NULL OR
   OBJECT_ID(N'dbo.Basvurular', N'U') IS NULL OR
   OBJECT_ID(N'dbo.BasvuruDurumlari', N'U') IS NULL OR
   OBJECT_ID(N'sosyobel.BasvuruUygulamaBilgileri', N'U') IS NULL
BEGIN
    THROW 51270, N'Uyumluluk 003 için gereken şirket veya 001 tabloları eksik.', 1;
END;

IF OBJECT_ID(N'sosyobel.BasvuruDurumGecmisi', N'U') IS NOT NULL
BEGIN
    PRINT N'Uyumluluk 003 daha önce uygulanmış; yeni nesne oluşturulmadı.';
    RETURN;
END;

BEGIN TRY
    BEGIN TRANSACTION;

    CREATE TABLE sosyobel.BasvuruDurumGecmisi
    (
        Id                      bigint IDENTITY(1,1) NOT NULL,
        BasvuruId               int NOT NULL,
        OncekiDurumId           int NULL,
        YeniDurumId             int NOT NULL,
        Aciklama                nvarchar(1000) NULL,
        OlusturanUserId         nvarchar(450) NOT NULL,
        OlusturulmaTarihiUtc    datetime2(3) NOT NULL
            CONSTRAINT DF_BasvuruDurumGecmisi_Olusturulma
                DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_BasvuruDurumGecmisi
            PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_BasvuruDurumGecmisi_Basvurular
            FOREIGN KEY (BasvuruId) REFERENCES dbo.Basvurular (Id),
        CONSTRAINT FK_BasvuruDurumGecmisi_OncekiDurum
            FOREIGN KEY (OncekiDurumId) REFERENCES dbo.BasvuruDurumlari (Id),
        CONSTRAINT FK_BasvuruDurumGecmisi_YeniDurum
            FOREIGN KEY (YeniDurumId) REFERENCES dbo.BasvuruDurumlari (Id),
        CONSTRAINT FK_BasvuruDurumGecmisi_OlusturanUser
            FOREIGN KEY (OlusturanUserId) REFERENCES dbo.AspNetUsers (Id),
        CONSTRAINT CK_BasvuruDurumGecmisi_DurumDegisimi CHECK
            (OncekiDurumId IS NULL OR OncekiDurumId <> YeniDurumId)
    );

    CREATE INDEX IX_BasvuruDurumGecmisi_Basvuru_Tarih
        ON sosyobel.BasvuruDurumGecmisi
            (BasvuruId, OlusturulmaTarihiUtc DESC);

    EXEC(N'
        CREATE TRIGGER sosyobel.TR_BasvuruDurumGecmisi_AppendOnly
        ON sosyobel.BasvuruDurumGecmisi
        INSTEAD OF UPDATE, DELETE
        AS
        BEGIN
            SET NOCOUNT ON;
            THROW 51271, N''Başvuru durum geçmişi değiştirilemez veya silinemez.'', 1;
        END;
    ');

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
