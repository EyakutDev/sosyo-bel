/*
    Sosyo-Bel şirket şeması uyumluluk migration'ı 002

    Giriş ve kullanıcı yönetimi için şirket şemasında bulunmayan teknik tabloları
    ekler. Mevcut dbo tablolarını değiştirmez ve hiçbir kullanıcı/rol/belediye
    verisi üretmez.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

IF OBJECT_ID(N'dbo.AspNetUsers', N'U') IS NULL OR
   OBJECT_ID(N'sosyobel.KullaniciUygulamaBilgileri', N'U') IS NULL
BEGIN
    THROW 51240, N'Önce uyumluluk migration 001 uygulanmalıdır.', 1;
END;

DECLARE @ExistingAuthTableCount int =
(
    SELECT COUNT(*)
    FROM
    (
        VALUES
            (N'sosyobel.Belediyeler'),
            (N'sosyobel.KullaniciBelediyeleri'),
            (N'sosyobel.KullaniciYetkileri'),
            (N'sosyobel.IslemGecmisleri'),
            (N'sosyobel.IdempotencyKayitlari'),
            (N'sosyobel.YenilemeTokenlari')
    ) AS authTable(ObjectName)
    WHERE OBJECT_ID(authTable.ObjectName, N'U') IS NOT NULL
);

IF @ExistingAuthTableCount = 6
BEGIN
    PRINT N'Uyumluluk 002 tabloları zaten mevcut; migration yeniden uygulanmadı.';
    RETURN;
END;

IF @ExistingAuthTableCount > 0
BEGIN
    THROW 51241, N'Uyumluluk 002 kısmen uygulanmış görünüyor. Önce şema denetimi yapılmalıdır.', 1;
END;

BEGIN TRY
    BEGIN TRANSACTION;

    /*
      Tek belediye kararı uygulama davranışıdır. Tabloda kurum kaydı otomatik
      oluşturulmaz; gerçek kod ve ad şirketten geldiğinde açıkça eklenecektir.
    */
    CREATE TABLE sosyobel.Belediyeler
    (
        Id                    int IDENTITY(1,1) NOT NULL,
        PublicId              uniqueidentifier NOT NULL
            CONSTRAINT DF_Belediyeler_PublicId DEFAULT NEWSEQUENTIALID(),
        Kod                   nvarchar(50) NOT NULL,
        Ad                    nvarchar(200) NOT NULL,
        LogoStorageKey        nvarchar(500) NULL,
        AktifMi               bit NOT NULL
            CONSTRAINT DF_Belediyeler_AktifMi DEFAULT (1),
        OlusturulmaTarihiUtc  datetime2(3) NOT NULL
            CONSTRAINT DF_Belediyeler_OlusturulmaTarihiUtc DEFAULT SYSUTCDATETIME(),
        GuncellenmeTarihiUtc  datetime2(3) NULL,
        RowVersion            rowversion NOT NULL,
        CONSTRAINT PK_Belediyeler PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT UQ_Belediyeler_PublicId UNIQUE NONCLUSTERED (PublicId),
        CONSTRAINT UQ_Belediyeler_Kod UNIQUE NONCLUSTERED (Kod),
        CONSTRAINT CK_Belediyeler_Kod CHECK
            (LEN(LTRIM(RTRIM(Kod))) > 0),
        CONSTRAINT CK_Belediyeler_Ad CHECK
            (LEN(LTRIM(RTRIM(Ad))) > 0)
    );

    CREATE TABLE sosyobel.KullaniciBelediyeleri
    (
        Id                    bigint IDENTITY(1,1) NOT NULL,
        UserId                nvarchar(450) NOT NULL,
        BelediyeId            int NOT NULL,
        RolKodu               nvarchar(50) NOT NULL,
        AktifMi               bit NOT NULL
            CONSTRAINT DF_KullaniciBelediyeleri_AktifMi DEFAULT (1),
        OlusturulmaTarihiUtc  datetime2(3) NOT NULL
            CONSTRAINT DF_KullaniciBelediyeleri_OlusturulmaTarihiUtc
                DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_KullaniciBelediyeleri PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT UQ_KullaniciBelediyeleri_User_Belediye
            UNIQUE NONCLUSTERED (UserId, BelediyeId),
        CONSTRAINT FK_KullaniciBelediyeleri_Users
            FOREIGN KEY (UserId) REFERENCES dbo.AspNetUsers (Id),
        CONSTRAINT FK_KullaniciBelediyeleri_Belediyeler
            FOREIGN KEY (BelediyeId) REFERENCES sosyobel.Belediyeler (Id),
        CONSTRAINT CK_KullaniciBelediyeleri_RolKodu CHECK
        (
            RolKodu IN (N'BELEDIYE_YONETICISI', N'PERSONEL')
        )
    );

    CREATE INDEX IX_KullaniciBelediyeleri_Belediye_Rol_Aktif
        ON sosyobel.KullaniciBelediyeleri
        (BelediyeId, RolKodu, AktifMi);

    CREATE TABLE sosyobel.KullaniciYetkileri
    (
        Id                    bigint IDENTITY(1,1) NOT NULL,
        UserId                nvarchar(450) NOT NULL,
        BelediyeId            int NOT NULL,
        YetkiKodu             nvarchar(80) NOT NULL,
        AktifMi               bit NOT NULL
            CONSTRAINT DF_KullaniciYetkileri_AktifMi DEFAULT (1),
        VerenUserId           nvarchar(450) NOT NULL,
        VerilmeTarihiUtc      datetime2(3) NOT NULL
            CONSTRAINT DF_KullaniciYetkileri_VerilmeTarihiUtc
                DEFAULT SYSUTCDATETIME(),
        IptalEdenUserId       nvarchar(450) NULL,
        IptalTarihiUtc        datetime2(3) NULL,
        RowVersion            rowversion NOT NULL,
        CONSTRAINT PK_KullaniciYetkileri PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT UQ_KullaniciYetkileri_User_Belediye_Yetki
            UNIQUE NONCLUSTERED (UserId, BelediyeId, YetkiKodu),
        CONSTRAINT FK_KullaniciYetkileri_Uyelik
            FOREIGN KEY (UserId, BelediyeId)
            REFERENCES sosyobel.KullaniciBelediyeleri (UserId, BelediyeId),
        CONSTRAINT FK_KullaniciYetkileri_VerenUser
            FOREIGN KEY (VerenUserId) REFERENCES dbo.AspNetUsers (Id),
        CONSTRAINT FK_KullaniciYetkileri_IptalEdenUser
            FOREIGN KEY (IptalEdenUserId) REFERENCES dbo.AspNetUsers (Id),
        CONSTRAINT CK_KullaniciYetkileri_YetkiKodu CHECK
            (YetkiKodu IN (N'KILITLI_BASVURU_DUZENLE')),
        CONSTRAINT CK_KullaniciYetkileri_IptalBilgisi CHECK
        (
            (AktifMi = 1 AND IptalEdenUserId IS NULL AND IptalTarihiUtc IS NULL) OR
            (AktifMi = 0 AND IptalEdenUserId IS NOT NULL AND IptalTarihiUtc IS NOT NULL)
        )
    );

    CREATE INDEX IX_KullaniciYetkileri_Belediye_Yetki_Aktif
        ON sosyobel.KullaniciYetkileri
        (BelediyeId, YetkiKodu, AktifMi, UserId);

    /*
      Yönetim audit'i append-only tutulur. Parola ve token gibi sırlar bu tabloya
      yazılmaz; yalnız işlem özeti ve güvenli istek metadatası kaydedilir.
    */
    CREATE TABLE sosyobel.IslemGecmisleri
    (
        Id                    bigint IDENTITY(1,1) NOT NULL,
        BelediyeId            int NOT NULL,
        VarlikTuru            nvarchar(100) NOT NULL,
        VarlikPublicId        uniqueidentifier NULL,
        IslemKodu             nvarchar(100) NOT NULL,
        Aciklama              nvarchar(1000) NULL,
        DegisiklikOzetiJson   nvarchar(max) NULL,
        OlusturanUserId       nvarchar(450) NOT NULL,
        OlusturulmaTarihiUtc  datetime2(3) NOT NULL
            CONSTRAINT DF_IslemGecmisleri_OlusturulmaTarihiUtc
                DEFAULT SYSUTCDATETIME(),
        Gerekce               nvarchar(1000) NULL,
        OlusturanIp           varchar(45) NULL,
        CihazKimligi          nvarchar(200) NULL,
        CorrelationId         uniqueidentifier NOT NULL,
        HedefUserId           nvarchar(450) NULL,
        CONSTRAINT PK_IslemGecmisleri PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_IslemGecmisleri_Belediyeler
            FOREIGN KEY (BelediyeId) REFERENCES sosyobel.Belediyeler (Id),
        CONSTRAINT FK_IslemGecmisleri_OlusturanUser
            FOREIGN KEY (OlusturanUserId) REFERENCES dbo.AspNetUsers (Id),
        CONSTRAINT FK_IslemGecmisleri_HedefUser
            FOREIGN KEY (HedefUserId) REFERENCES dbo.AspNetUsers (Id),
        CONSTRAINT CK_IslemGecmisleri_Json CHECK
            (DegisiklikOzetiJson IS NULL OR ISJSON(DegisiklikOzetiJson) = 1),
        CONSTRAINT CK_IslemGecmisleri_KilitliBasvuruGerekce CHECK
        (
            IslemKodu <> N'KILITLI_BASVURU_GUNCELLE' OR
            (
                Gerekce IS NOT NULL AND
                LEN(LTRIM(RTRIM(Gerekce))) >= 10 AND
                DegisiklikOzetiJson IS NOT NULL
            )
        )
    );

    CREATE INDEX IX_IslemGecmisleri_Varlik_Tarih
        ON sosyobel.IslemGecmisleri
        (BelediyeId, VarlikTuru, VarlikPublicId, OlusturulmaTarihiUtc DESC);

    CREATE INDEX IX_IslemGecmisleri_Belediye_Islem_Tarih
        ON sosyobel.IslemGecmisleri
        (BelediyeId, IslemKodu, OlusturulmaTarihiUtc DESC);

    /*
      ActorUserId nvarchar(450) olduğu için Actor+Endpoint+Key doğrudan benzersiz
      indeks yapılırsa SQL Server indeks anahtarı sınırı aşılabilir. Kullanıcı
      kimliğinin SHA-256 özeti aynı benzersizlik sınırını sabit boyutta kurar.
    */
    CREATE TABLE sosyobel.IdempotencyKayitlari
    (
        Id                    bigint IDENTITY(1,1) NOT NULL,
        ActorUserId           nvarchar(450) NOT NULL,
        ActorUserIdHash       binary(32) NOT NULL,
        EndpointKodu          nvarchar(150) NOT NULL,
        IdempotencyKey        nvarchar(100) NOT NULL,
        IstekHash             binary(32) NOT NULL,
        HttpDurumKodu         int NULL,
        SonucJson             nvarchar(max) NULL,
        OlusturulmaTarihiUtc  datetime2(3) NOT NULL
            CONSTRAINT DF_IdempotencyKayitlari_OlusturulmaTarihiUtc
                DEFAULT SYSUTCDATETIME(),
        SonKullanmaTarihiUtc  datetime2(3) NOT NULL,
        CONSTRAINT PK_IdempotencyKayitlari PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_IdempotencyKayitlari_Actor
            FOREIGN KEY (ActorUserId) REFERENCES dbo.AspNetUsers (Id),
        CONSTRAINT CK_IdempotencyKayitlari_Key CHECK
            (LEN(LTRIM(RTRIM(IdempotencyKey))) BETWEEN 8 AND 100),
        CONSTRAINT CK_IdempotencyKayitlari_Http CHECK
            (HttpDurumKodu IS NULL OR HttpDurumKodu BETWEEN 200 AND 599),
        CONSTRAINT CK_IdempotencyKayitlari_Json CHECK
            (SonucJson IS NULL OR ISJSON(SonucJson) = 1),
        CONSTRAINT CK_IdempotencyKayitlari_Sonuc CHECK
        (
            (HttpDurumKodu IS NULL AND SonucJson IS NULL) OR
            (HttpDurumKodu IS NOT NULL AND SonucJson IS NOT NULL)
        ),
        CONSTRAINT CK_IdempotencyKayitlari_Sure CHECK
            (SonKullanmaTarihiUtc > OlusturulmaTarihiUtc)
    );

    CREATE UNIQUE INDEX UQ_IdempotencyKayitlari_ActorHash_Endpoint_Key
        ON sosyobel.IdempotencyKayitlari
        (ActorUserIdHash, EndpointKodu, IdempotencyKey);

    CREATE INDEX IX_IdempotencyKayitlari_Actor_Endpoint
        ON sosyobel.IdempotencyKayitlari (ActorUserId, EndpointKodu)
        INCLUDE (IdempotencyKey);

    CREATE INDEX IX_IdempotencyKayitlari_SonKullanma
        ON sosyobel.IdempotencyKayitlari (SonKullanmaTarihiUtc);

    CREATE TABLE sosyobel.YenilemeTokenlari
    (
        Id                    bigint IDENTITY(1,1) NOT NULL,
        UserId                nvarchar(450) NOT NULL,
        TokenHash             binary(32) NOT NULL,
        CihazKimligi          nvarchar(200) NULL,
        OlusturanIp           varchar(45) NULL,
        OlusturulmaTarihiUtc  datetime2(3) NOT NULL
            CONSTRAINT DF_YenilemeTokenlari_OlusturulmaTarihiUtc
                DEFAULT SYSUTCDATETIME(),
        SonKullanmaTarihiUtc  datetime2(3) NOT NULL,
        IptalTarihiUtc        datetime2(3) NULL,
        IptalEdenIp           varchar(45) NULL,
        CONSTRAINT PK_YenilemeTokenlari PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT UQ_YenilemeTokenlari_TokenHash UNIQUE NONCLUSTERED (TokenHash),
        CONSTRAINT FK_YenilemeTokenlari_Users
            FOREIGN KEY (UserId) REFERENCES dbo.AspNetUsers (Id),
        CONSTRAINT CK_YenilemeTokenlari_Sure CHECK
            (SonKullanmaTarihiUtc > OlusturulmaTarihiUtc)
    );

    CREATE INDEX IX_YenilemeTokenlari_User_SonKullanma
        ON sosyobel.YenilemeTokenlari (UserId, SonKullanmaTarihiUtc DESC);

    EXEC(N'
        CREATE TRIGGER sosyobel.TR_IslemGecmisleri_AppendOnly
        ON sosyobel.IslemGecmisleri
        AFTER UPDATE, DELETE
        AS
        BEGIN
            SET NOCOUNT ON;
            THROW 51242, N''İşlem geçmişi kayıtları değiştirilemez veya silinemez.'', 1;
        END;
    ');

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
