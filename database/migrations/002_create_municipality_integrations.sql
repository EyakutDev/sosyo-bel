/*
  Belediye sunucusu henüz belli değilken bağlantı türünü ve secret referansını
  modellemek için eklenir. Kullanıcı adı, parola, API anahtarı veya sertifika özel
  anahtarı bu tabloda tutulmaz.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

IF OBJECT_ID(N'sosyobel.Belediyeler', N'U') IS NULL
BEGIN
    THROW 51030, N'Önce 001_create_sosyobel_v2_schema.sql çalıştırılmalıdır.', 1;
END;

IF OBJECT_ID(N'sosyobel.BelediyeEntegrasyonlari', N'U') IS NOT NULL
BEGIN
    THROW 51031, N'BelediyeEntegrasyonlari zaten mevcut. Betik ikinci kez çalıştırılmadı.', 1;
END;

BEGIN TRY
    BEGIN TRANSACTION;

    CREATE TABLE sosyobel.BelediyeEntegrasyonlari
    (
        Id                         int IDENTITY(1,1) NOT NULL,
        PublicId                   uniqueidentifier NOT NULL
            CONSTRAINT DF_BelediyeEntegrasyonlari_PublicId DEFAULT NEWSEQUENTIALID(),
        BelediyeId                 int NOT NULL,
        Ad                         nvarchar(150) NOT NULL,
        EntegrasyonTuruKodu        nvarchar(30) NOT NULL,
        YetkiKapsamiKodu           nvarchar(30) NOT NULL,
        KimlikDogrulamaTuruKodu    nvarchar(30) NULL,
        SunucuAdresi               nvarchar(255) NULL,
        Port                       int NULL,
        VeritabaniAdi              nvarchar(128) NULL,
        ApiBaseUrl                 nvarchar(500) NULL,
        SecretReference            nvarchar(300) NULL,
        EkAyarlarJson              nvarchar(max) NULL,
        BaglantiZamanAsimiSaniye   smallint NOT NULL
            CONSTRAINT DF_BelediyeEntegrasyonlari_Timeout DEFAULT (30),
        YenidenDenemeSayisi        tinyint NOT NULL
            CONSTRAINT DF_BelediyeEntegrasyonlari_Retry DEFAULT (3),
        AktifMi                    bit NOT NULL
            CONSTRAINT DF_BelediyeEntegrasyonlari_AktifMi DEFAULT (0),
        SonBasariliBaglantiUtc     datetime2(3) NULL,
        SonHataKodu                nvarchar(100) NULL,
        OlusturanUserId            nvarchar(128) NULL,
        OlusturulmaTarihiUtc       datetime2(3) NOT NULL
            CONSTRAINT DF_BelediyeEntegrasyonlari_OlusturulmaTarihiUtc DEFAULT SYSUTCDATETIME(),
        GuncelleyenUserId          nvarchar(128) NULL,
        GuncellenmeTarihiUtc       datetime2(3) NULL,
        RowVersion                 rowversion NOT NULL,
        CONSTRAINT PK_BelediyeEntegrasyonlari PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT UQ_BelediyeEntegrasyonlari_PublicId UNIQUE (PublicId),
        CONSTRAINT UQ_BelediyeEntegrasyonlari_Belediye_Ad UNIQUE (BelediyeId, Ad),
        CONSTRAINT FK_BelediyeEntegrasyonlari_Belediyeler FOREIGN KEY (BelediyeId)
            REFERENCES sosyobel.Belediyeler (Id),
        CONSTRAINT FK_BelediyeEntegrasyonlari_OlusturanUser FOREIGN KEY (OlusturanUserId)
            REFERENCES dbo.AspNetUsers (Id),
        CONSTRAINT FK_BelediyeEntegrasyonlari_GuncelleyenUser FOREIGN KEY (GuncelleyenUserId)
            REFERENCES dbo.AspNetUsers (Id),
        CONSTRAINT CK_BelediyeEntegrasyonlari_Tur CHECK
            (EntegrasyonTuruKodu IN (N'SQL_SERVER', N'REST_API', N'CSV', N'DEMO')),
        CONSTRAINT CK_BelediyeEntegrasyonlari_Yetki CHECK
            (YetkiKapsamiKodu IN (N'OKUMA', N'OKUMA_YAZMA')),
        CONSTRAINT CK_BelediyeEntegrasyonlari_KimlikDogrulama CHECK
        (
            KimlikDogrulamaTuruKodu IS NULL OR
            KimlikDogrulamaTuruKodu IN
                (N'SQL_HESABI', N'WINDOWS_AD', N'OAUTH2', N'API_KEY', N'MTLS', N'YOK')
        ),
        CONSTRAINT CK_BelediyeEntegrasyonlari_Port CHECK
            (Port IS NULL OR Port BETWEEN 1 AND 65535),
        CONSTRAINT CK_BelediyeEntegrasyonlari_Timeout CHECK
            (BaglantiZamanAsimiSaniye BETWEEN 1 AND 120),
        CONSTRAINT CK_BelediyeEntegrasyonlari_Retry CHECK
            (YenidenDenemeSayisi BETWEEN 0 AND 10),
        CONSTRAINT CK_BelediyeEntegrasyonlari_Json CHECK
            (EkAyarlarJson IS NULL OR ISJSON(EkAyarlarJson) = 1),
        /*
          Pasif kayıt eksik hazırlanabilir. Aktif hale getirilirken ilgili bağlantı
          türünün zorunlu alanları tamamlanmış olmalıdır.
        */
        CONSTRAINT CK_BelediyeEntegrasyonlari_AktifYapilandirma CHECK
        (
            AktifMi = 0 OR
            (
                EntegrasyonTuruKodu = N'SQL_SERVER' AND
                SunucuAdresi IS NOT NULL AND Port IS NOT NULL AND
                VeritabaniAdi IS NOT NULL AND SecretReference IS NOT NULL
            ) OR
            (
                EntegrasyonTuruKodu = N'REST_API' AND
                ApiBaseUrl IS NOT NULL AND SecretReference IS NOT NULL
            ) OR
            EntegrasyonTuruKodu IN (N'CSV', N'DEMO')
        )
    );

    CREATE INDEX IX_BelediyeEntegrasyonlari_Belediye_Tur_Aktif
        ON sosyobel.BelediyeEntegrasyonlari
        (BelediyeId, EntegrasyonTuruKodu, AktifMi);

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
