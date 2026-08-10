/*
  Sosyo-Bel V2 iş veritabanı şeması

  Amaç:
  - Mevcut dbo tablolarını silmeden veya değiştirmeden temiz bir V2 alanı kurmak.
  - Flutter uygulamasındaki başvuru, aile, hane, fotoğraf ve kurul akışını
    SQL Server üzerinde veri bütünlüğü kurallarıyla temsil etmek.
  - Bir veya birden fazla belediye kurulumunu aynı modelle desteklemek.

  Önemli:
  - Bu betik gerçek sunucuda henüz çalıştırılmamıştır.
  - ASP.NET Core Identity tabloları önce oluşturulmuş olmalıdır.
  - Bütün zaman alanları UTC tutulur; yerel saat dönüşümü API/istemci katmanındadır.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

IF OBJECT_ID(N'dbo.AspNetUsers', N'U') IS NULL
BEGIN
    THROW 51000, N'Önce ASP.NET Identity şeması oluşturulmalıdır: dbo.AspNetUsers bulunamadı.', 1;
END;

IF OBJECT_ID(N'sosyobel.Basvurular', N'U') IS NOT NULL
BEGIN
    THROW 51001, N'Sosyo-Bel V2 şeması zaten mevcut. Betik ikinci kez çalıştırılmadı.', 1;
END;

BEGIN TRY
    BEGIN TRANSACTION;

    IF SCHEMA_ID(N'sosyobel') IS NULL
    BEGIN
        EXEC(N'CREATE SCHEMA sosyobel AUTHORIZATION dbo;');
    END;

    /*
      Belediye bilgisi ayrı bir tabloya alınır. Eski SistemAyarlari tablosundaki
      tek satırlı yaklaşım yerine her kayıt açıkça bir belediyeye bağlanabilir.
    */
    CREATE TABLE sosyobel.Belediyeler
    (
        Id                  int IDENTITY(1,1) NOT NULL,
        PublicId            uniqueidentifier NOT NULL
            CONSTRAINT DF_Belediyeler_PublicId DEFAULT NEWSEQUENTIALID(),
        Kod                 nvarchar(50) NOT NULL,
        Ad                  nvarchar(200) NOT NULL,
        LogoStorageKey      nvarchar(500) NULL,
        AktifMi             bit NOT NULL
            CONSTRAINT DF_Belediyeler_AktifMi DEFAULT (1),
        OlusturulmaTarihiUtc datetime2(3) NOT NULL
            CONSTRAINT DF_Belediyeler_OlusturulmaTarihiUtc DEFAULT SYSUTCDATETIME(),
        GuncellenmeTarihiUtc datetime2(3) NULL,
        RowVersion          rowversion NOT NULL,
        CONSTRAINT PK_Belediyeler PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT UQ_Belediyeler_PublicId UNIQUE (PublicId),
        CONSTRAINT UQ_Belediyeler_Kod UNIQUE (Kod)
    );

    /*
      Kullanıcı hesabı Identity tarafından yönetilir. Bu eşleme, kullanıcıya ait
      belediye kapsamını istemciden gelen bir değere güvenmeden belirlemeyi sağlar.
    */
    CREATE TABLE sosyobel.KullaniciBelediyeleri
    (
        Id                  bigint IDENTITY(1,1) NOT NULL,
        UserId              nvarchar(128) NOT NULL,
        BelediyeId          int NOT NULL,
        AktifMi             bit NOT NULL
            CONSTRAINT DF_KullaniciBelediyeleri_AktifMi DEFAULT (1),
        OlusturulmaTarihiUtc datetime2(3) NOT NULL
            CONSTRAINT DF_KullaniciBelediyeleri_OlusturulmaTarihiUtc DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_KullaniciBelediyeleri PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT UQ_KullaniciBelediyeleri_User_Belediye
            UNIQUE NONCLUSTERED (UserId, BelediyeId),
        CONSTRAINT FK_KullaniciBelediyeleri_Users FOREIGN KEY (UserId)
            REFERENCES dbo.AspNetUsers (Id),
        CONSTRAINT FK_KullaniciBelediyeleri_Belediyeler FOREIGN KEY (BelediyeId)
            REFERENCES sosyobel.Belediyeler (Id)
    );

    CREATE INDEX IX_KullaniciBelediyeleri_BelediyeId
        ON sosyobel.KullaniciBelediyeleri (BelediyeId, AktifMi);

    /* Kararlı Kod alanları API'nin değişebilen Türkçe etiketlere bağımlılığını kaldırır. */
    CREATE TABLE sosyobel.BasvuruDurumlari
    (
        Id          int IDENTITY(1,1) NOT NULL,
        Kod         nvarchar(50) NOT NULL,
        Ad          nvarchar(100) NOT NULL,
        Sira        smallint NOT NULL,
        AktifMi     bit NOT NULL CONSTRAINT DF_BasvuruDurumlari_AktifMi DEFAULT (1),
        CONSTRAINT PK_BasvuruDurumlari PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT UQ_BasvuruDurumlari_Kod UNIQUE (Kod),
        CONSTRAINT CK_BasvuruDurumlari_Sira CHECK (Sira > 0)
    );

    CREATE TABLE sosyobel.CalismaDurumlari
    (
        Id      int IDENTITY(1,1) NOT NULL,
        Kod     nvarchar(50) NOT NULL,
        Ad      nvarchar(100) NOT NULL,
        Sira    smallint NOT NULL,
        AktifMi bit NOT NULL CONSTRAINT DF_CalismaDurumlari_AktifMi DEFAULT (1),
        CONSTRAINT PK_CalismaDurumlari PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT UQ_CalismaDurumlari_Kod UNIQUE (Kod),
        CONSTRAINT CK_CalismaDurumlari_Sira CHECK (Sira > 0)
    );

    CREATE TABLE sosyobel.EgitimDurumlari
    (
        Id      int IDENTITY(1,1) NOT NULL,
        Kod     nvarchar(50) NOT NULL,
        Ad      nvarchar(100) NOT NULL,
        Sira    smallint NOT NULL,
        AktifMi bit NOT NULL CONSTRAINT DF_EgitimDurumlari_AktifMi DEFAULT (1),
        CONSTRAINT PK_EgitimDurumlari PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT UQ_EgitimDurumlari_Kod UNIQUE (Kod),
        CONSTRAINT CK_EgitimDurumlari_Sira CHECK (Sira > 0)
    );

    CREATE TABLE sosyobel.Yakinliklar
    (
        Id      int IDENTITY(1,1) NOT NULL,
        Kod     nvarchar(50) NOT NULL,
        Ad      nvarchar(100) NOT NULL,
        Sira    smallint NOT NULL,
        AktifMi bit NOT NULL CONSTRAINT DF_Yakinliklar_AktifMi DEFAULT (1),
        CONSTRAINT PK_Yakinliklar PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT UQ_Yakinliklar_Kod UNIQUE (Kod),
        CONSTRAINT CK_Yakinliklar_Sira CHECK (Sira > 0)
    );

    CREATE TABLE sosyobel.YasamDurumlari
    (
        Id      int IDENTITY(1,1) NOT NULL,
        Kod     nvarchar(50) NOT NULL,
        Ad      nvarchar(100) NOT NULL,
        Sira    smallint NOT NULL,
        AktifMi bit NOT NULL CONSTRAINT DF_YasamDurumlari_AktifMi DEFAULT (1),
        CONSTRAINT PK_YasamDurumlari PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT UQ_YasamDurumlari_Kod UNIQUE (Kod),
        CONSTRAINT CK_YasamDurumlari_Sira CHECK (Sira > 0)
    );

    /* Engel ve yardım listeleri belediyeye özel veya bütün sistem için ortak olabilir. */
    CREATE TABLE sosyobel.EngelTurleri
    (
        Id          int IDENTITY(1,1) NOT NULL,
        BelediyeId  int NULL,
        Kod         nvarchar(50) NOT NULL,
        Ad          nvarchar(150) NOT NULL,
        Sira        smallint NOT NULL,
        AktifMi     bit NOT NULL CONSTRAINT DF_EngelTurleri_AktifMi DEFAULT (1),
        CONSTRAINT PK_EngelTurleri PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_EngelTurleri_Belediyeler FOREIGN KEY (BelediyeId)
            REFERENCES sosyobel.Belediyeler (Id),
        CONSTRAINT CK_EngelTurleri_Sira CHECK (Sira > 0)
    );

    CREATE UNIQUE INDEX UX_EngelTurleri_GlobalKod
        ON sosyobel.EngelTurleri (Kod)
        WHERE BelediyeId IS NULL;

    CREATE UNIQUE INDEX UX_EngelTurleri_BelediyeKod
        ON sosyobel.EngelTurleri (BelediyeId, Kod)
        WHERE BelediyeId IS NOT NULL;

    CREATE TABLE sosyobel.YardimTurleri
    (
        Id          int IDENTITY(1,1) NOT NULL,
        BelediyeId  int NULL,
        Kod         nvarchar(50) NOT NULL,
        Ad          nvarchar(150) NOT NULL,
        Sira        smallint NOT NULL,
        AktifMi     bit NOT NULL CONSTRAINT DF_YardimTurleri_AktifMi DEFAULT (1),
        CONSTRAINT PK_YardimTurleri PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_YardimTurleri_Belediyeler FOREIGN KEY (BelediyeId)
            REFERENCES sosyobel.Belediyeler (Id),
        CONSTRAINT CK_YardimTurleri_Sira CHECK (Sira > 0)
    );

    CREATE UNIQUE INDEX UX_YardimTurleri_GlobalKod
        ON sosyobel.YardimTurleri (Kod)
        WHERE BelediyeId IS NULL;

    CREATE UNIQUE INDEX UX_YardimTurleri_BelediyeKod
        ON sosyobel.YardimTurleri (BelediyeId, Kod)
        WHERE BelediyeId IS NOT NULL;

    CREATE TABLE sosyobel.TalepGelisKanallari
    (
        Id      int IDENTITY(1,1) NOT NULL,
        Kod     nvarchar(50) NOT NULL,
        Ad      nvarchar(100) NOT NULL,
        Sira    smallint NOT NULL,
        AktifMi bit NOT NULL CONSTRAINT DF_TalepGelisKanallari_AktifMi DEFAULT (1),
        CONSTRAINT PK_TalepGelisKanallari PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT UQ_TalepGelisKanallari_Kod UNIQUE (Kod),
        CONSTRAINT CK_TalepGelisKanallari_Sira CHECK (Sira > 0)
    );

    /* Eski Mahalle/Mahalleler ve Sokak/Sokaklar çiftleri tek yapıda birleştirilir. */
    CREATE TABLE sosyobel.Mahalleler
    (
        Id          int IDENTITY(1,1) NOT NULL,
        BelediyeId  int NOT NULL,
        Kod         nvarchar(50) NULL,
        Ad          nvarchar(200) NOT NULL,
        AktifMi     bit NOT NULL CONSTRAINT DF_Mahalleler_AktifMi DEFAULT (1),
        CONSTRAINT PK_Mahalleler PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_Mahalleler_Belediyeler FOREIGN KEY (BelediyeId)
            REFERENCES sosyobel.Belediyeler (Id),
        CONSTRAINT UQ_Mahalleler_Belediye_Id UNIQUE (BelediyeId, Id)
    );

    CREATE UNIQUE INDEX UX_Mahalleler_Belediye_Ad
        ON sosyobel.Mahalleler (BelediyeId, Ad);

    CREATE UNIQUE INDEX UX_Mahalleler_Belediye_Kod
        ON sosyobel.Mahalleler (BelediyeId, Kod)
        WHERE Kod IS NOT NULL;

    CREATE TABLE sosyobel.Sokaklar
    (
        Id          int IDENTITY(1,1) NOT NULL,
        BelediyeId  int NOT NULL,
        MahalleId   int NOT NULL,
        Kod         nvarchar(50) NULL,
        Ad          nvarchar(200) NOT NULL,
        AktifMi     bit NOT NULL CONSTRAINT DF_Sokaklar_AktifMi DEFAULT (1),
        CONSTRAINT PK_Sokaklar PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_Sokaklar_Mahalleler FOREIGN KEY (BelediyeId, MahalleId)
            REFERENCES sosyobel.Mahalleler (BelediyeId, Id),
        CONSTRAINT UQ_Sokaklar_Belediye_Id UNIQUE (BelediyeId, Id)
    );

    CREATE UNIQUE INDEX UX_Sokaklar_Mahalle_Ad
        ON sosyobel.Sokaklar (BelediyeId, MahalleId, Ad);

    CREATE UNIQUE INDEX UX_Sokaklar_Mahalle_Kod
        ON sosyobel.Sokaklar (BelediyeId, MahalleId, Kod)
        WHERE Kod IS NOT NULL;

    CREATE TABLE sosyobel.Vatandaslar
    (
        Id                    int IDENTITY(1,1) NOT NULL,
        PublicId              uniqueidentifier NOT NULL
            CONSTRAINT DF_Vatandaslar_PublicId DEFAULT NEWSEQUENTIALID(),
        BelediyeId            int NOT NULL,
        TcKimlikNo            char(11) NOT NULL,
        Ad                    nvarchar(100) NOT NULL,
        Soyad                 nvarchar(100) NOT NULL,
        DogumTarihi           date NOT NULL,
        Telefon1              varchar(16) NULL,
        Telefon2              varchar(16) NULL,
        Email                 nvarchar(254) NULL,
        AcikAdres             nvarchar(500) NULL,
        MahalleId             int NULL,
        SokakId               int NULL,
        IlKodu                int NULL,
        IlceKodu              int NULL,
        MahalleKodu           int NULL,
        SokakKodu             int NULL,
        AdresNo               bigint NULL,
        CinsiyetKodu          nvarchar(30) NULL,
        DogumYeri             nvarchar(100) NULL,
        MedeniDurumKodu       nvarchar(50) NULL,
        CocukSayisi           smallint NULL,
        EngelDurumu           bit NULL,
        EngelOrani            tinyint NULL,
        EngelTuruId           int NULL,
        CalismaDurumuId       int NULL,
        EgitimDurumuId        int NULL,
        KaynakKodu            nvarchar(30) NOT NULL,
        KaynakGuncellemeUtc   datetime2(3) NULL,
        AktifMi               bit NOT NULL CONSTRAINT DF_Vatandaslar_AktifMi DEFAULT (1),
        OlusturanUserId       nvarchar(128) NULL,
        OlusturulmaTarihiUtc  datetime2(3) NOT NULL
            CONSTRAINT DF_Vatandaslar_OlusturulmaTarihiUtc DEFAULT SYSUTCDATETIME(),
        GuncelleyenUserId     nvarchar(128) NULL,
        GuncellenmeTarihiUtc  datetime2(3) NULL,
        RowVersion            rowversion NOT NULL,
        CONSTRAINT PK_Vatandaslar PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT UQ_Vatandaslar_PublicId UNIQUE (PublicId),
        CONSTRAINT UQ_Vatandaslar_Belediye_Id UNIQUE (BelediyeId, Id),
        CONSTRAINT UQ_Vatandaslar_Belediye_TcKimlikNo UNIQUE (BelediyeId, TcKimlikNo),
        CONSTRAINT FK_Vatandaslar_Belediyeler FOREIGN KEY (BelediyeId)
            REFERENCES sosyobel.Belediyeler (Id),
        CONSTRAINT FK_Vatandaslar_Mahalleler FOREIGN KEY (BelediyeId, MahalleId)
            REFERENCES sosyobel.Mahalleler (BelediyeId, Id),
        CONSTRAINT FK_Vatandaslar_Sokaklar FOREIGN KEY (BelediyeId, SokakId)
            REFERENCES sosyobel.Sokaklar (BelediyeId, Id),
        CONSTRAINT FK_Vatandaslar_EngelTurleri FOREIGN KEY (EngelTuruId)
            REFERENCES sosyobel.EngelTurleri (Id),
        CONSTRAINT FK_Vatandaslar_CalismaDurumlari FOREIGN KEY (CalismaDurumuId)
            REFERENCES sosyobel.CalismaDurumlari (Id),
        CONSTRAINT FK_Vatandaslar_EgitimDurumlari FOREIGN KEY (EgitimDurumuId)
            REFERENCES sosyobel.EgitimDurumlari (Id),
        CONSTRAINT FK_Vatandaslar_OlusturanUser FOREIGN KEY (OlusturanUserId)
            REFERENCES dbo.AspNetUsers (Id),
        CONSTRAINT FK_Vatandaslar_GuncelleyenUser FOREIGN KEY (GuncelleyenUserId)
            REFERENCES dbo.AspNetUsers (Id),
        CONSTRAINT CK_Vatandaslar_TcKimlikNo CHECK
            (LEN(TcKimlikNo) = 11 AND TcKimlikNo NOT LIKE '%[^0-9]%'),
        CONSTRAINT CK_Vatandaslar_CocukSayisi CHECK
            (CocukSayisi IS NULL OR CocukSayisi BETWEEN 0 AND 50),
        CONSTRAINT CK_Vatandaslar_EngelOrani CHECK
            (EngelOrani IS NULL OR EngelOrani BETWEEN 0 AND 100)
    );

    CREATE INDEX IX_Vatandaslar_Belediye_AdSoyad
        ON sosyobel.Vatandaslar (BelediyeId, Soyad, Ad);

    CREATE INDEX IX_Vatandaslar_MahalleId
        ON sosyobel.Vatandaslar (MahalleId);

    /* Güncel yakın bilgileri; her başvuru ayrıca kendi değişmez anlık kopyasını tutar. */
    CREATE TABLE sosyobel.AileFertleri
    (
        Id                    int IDENTITY(1,1) NOT NULL,
        BelediyeId            int NOT NULL,
        VatandasId            int NOT NULL,
        AdSoyad               nvarchar(200) NOT NULL,
        Yas                   smallint NOT NULL,
        YakinlikId            int NOT NULL,
        YakinlikDigerAciklama nvarchar(100) NULL,
        EngelDurumu           bit NOT NULL CONSTRAINT DF_AileFertleri_EngelDurumu DEFAULT (0),
        EngelTuruId           int NULL,
        EngelAciklamasi       nvarchar(250) NULL,
        CalismaDurumuId       int NULL,
        EgitimDurumuId        int NULL,
        YasamDurumuId         int NOT NULL,
        AktifMi               bit NOT NULL CONSTRAINT DF_AileFertleri_AktifMi DEFAULT (1),
        OlusturanUserId       nvarchar(128) NOT NULL,
        OlusturulmaTarihiUtc  datetime2(3) NOT NULL
            CONSTRAINT DF_AileFertleri_OlusturulmaTarihiUtc DEFAULT SYSUTCDATETIME(),
        GuncelleyenUserId     nvarchar(128) NULL,
        GuncellenmeTarihiUtc  datetime2(3) NULL,
        RowVersion            rowversion NOT NULL,
        CONSTRAINT PK_AileFertleri PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT UQ_AileFertleri_Belediye_Id UNIQUE (BelediyeId, Id),
        CONSTRAINT FK_AileFertleri_Vatandaslar FOREIGN KEY (BelediyeId, VatandasId)
            REFERENCES sosyobel.Vatandaslar (BelediyeId, Id),
        CONSTRAINT FK_AileFertleri_Yakinliklar FOREIGN KEY (YakinlikId)
            REFERENCES sosyobel.Yakinliklar (Id),
        CONSTRAINT FK_AileFertleri_EngelTurleri FOREIGN KEY (EngelTuruId)
            REFERENCES sosyobel.EngelTurleri (Id),
        CONSTRAINT FK_AileFertleri_CalismaDurumlari FOREIGN KEY (CalismaDurumuId)
            REFERENCES sosyobel.CalismaDurumlari (Id),
        CONSTRAINT FK_AileFertleri_EgitimDurumlari FOREIGN KEY (EgitimDurumuId)
            REFERENCES sosyobel.EgitimDurumlari (Id),
        CONSTRAINT FK_AileFertleri_YasamDurumlari FOREIGN KEY (YasamDurumuId)
            REFERENCES sosyobel.YasamDurumlari (Id),
        CONSTRAINT FK_AileFertleri_OlusturanUser FOREIGN KEY (OlusturanUserId)
            REFERENCES dbo.AspNetUsers (Id),
        CONSTRAINT FK_AileFertleri_GuncelleyenUser FOREIGN KEY (GuncelleyenUserId)
            REFERENCES dbo.AspNetUsers (Id),
        CONSTRAINT CK_AileFertleri_Yas CHECK (Yas BETWEEN 0 AND 130)
    );

    CREATE INDEX IX_AileFertleri_VatandasId
        ON sosyobel.AileFertleri (VatandasId, AktifMi);

    CREATE TABLE sosyobel.Basvurular
    (
        Id                       int IDENTITY(1,1) NOT NULL,
        PublicId                 uniqueidentifier NOT NULL
            CONSTRAINT DF_Basvurular_PublicId DEFAULT NEWSEQUENTIALID(),
        BelediyeId               int NOT NULL,
        BasvuruNo                nvarchar(40) NOT NULL,
        VatandasId               int NULL,
        BasvuranTcKimlikNo       char(11) NOT NULL,
        BasvuranAd               nvarchar(100) NULL,
        BasvuranSoyad            nvarchar(100) NULL,
        BasvuranDogumTarihi      date NOT NULL,
        BasvuranTelefon          varchar(16) NOT NULL,
        BasvuruAcikAdres         nvarchar(500) NULL,
        BasvuruMahalle           nvarchar(200) NULL,
        BasvuruSokak             nvarchar(200) NULL,
        IlKodu                   int NULL,
        IlceKodu                 int NULL,
        MahalleKodu              int NULL,
        SokakKodu                int NULL,
        AdresNo                  bigint NULL,
        BasvuranCinsiyetKodu     nvarchar(30) NULL,
        BasvuranDogumYeri        nvarchar(100) NULL,
        BasvuranMedeniDurumKodu  nvarchar(50) NULL,
        EngelDurumu              bit NULL,
        EngelOrani               tinyint NULL,
        EngelTuruId              int NULL,
        YardimTuruId             int NOT NULL,
        TalepGelisKanaliId       int NOT NULL,
        TalepAciklamasi          nvarchar(1000) NULL,
        SahaIncelemeNotu         nvarchar(2000) NULL,
        BasvuruDurumuId          int NOT NULL,
        OlusturanUserId          nvarchar(128) NOT NULL,
        OlusturulmaTarihiUtc     datetime2(3) NOT NULL
            CONSTRAINT DF_Basvurular_OlusturulmaTarihiUtc DEFAULT SYSUTCDATETIME(),
        GuncelleyenUserId        nvarchar(128) NULL,
        GuncellenmeTarihiUtc     datetime2(3) NULL,
        KurulaGonderenUserId     nvarchar(128) NULL,
        KurulaGonderilmeTarihiUtc datetime2(3) NULL,
        TamamlayanUserId         nvarchar(128) NULL,
        TamamlanmaTarihiUtc      datetime2(3) NULL,
        IptalTarihiUtc           datetime2(3) NULL,
        IptalAciklamasi          nvarchar(1000) NULL,
        RowVersion               rowversion NOT NULL,
        CONSTRAINT PK_Basvurular PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT UQ_Basvurular_PublicId UNIQUE (PublicId),
        CONSTRAINT UQ_Basvurular_Belediye_Id UNIQUE (BelediyeId, Id),
        CONSTRAINT UQ_Basvurular_Belediye_BasvuruNo UNIQUE (BelediyeId, BasvuruNo),
        CONSTRAINT FK_Basvurular_Belediyeler FOREIGN KEY (BelediyeId)
            REFERENCES sosyobel.Belediyeler (Id),
        CONSTRAINT FK_Basvurular_Vatandaslar FOREIGN KEY (BelediyeId, VatandasId)
            REFERENCES sosyobel.Vatandaslar (BelediyeId, Id),
        CONSTRAINT FK_Basvurular_EngelTurleri FOREIGN KEY (EngelTuruId)
            REFERENCES sosyobel.EngelTurleri (Id),
        CONSTRAINT FK_Basvurular_YardimTurleri FOREIGN KEY (YardimTuruId)
            REFERENCES sosyobel.YardimTurleri (Id),
        CONSTRAINT FK_Basvurular_TalepGelisKanallari FOREIGN KEY (TalepGelisKanaliId)
            REFERENCES sosyobel.TalepGelisKanallari (Id),
        CONSTRAINT FK_Basvurular_BasvuruDurumlari FOREIGN KEY (BasvuruDurumuId)
            REFERENCES sosyobel.BasvuruDurumlari (Id),
        CONSTRAINT FK_Basvurular_OlusturanUser FOREIGN KEY (OlusturanUserId)
            REFERENCES dbo.AspNetUsers (Id),
        CONSTRAINT FK_Basvurular_GuncelleyenUser FOREIGN KEY (GuncelleyenUserId)
            REFERENCES dbo.AspNetUsers (Id),
        CONSTRAINT FK_Basvurular_KurulaGonderenUser FOREIGN KEY (KurulaGonderenUserId)
            REFERENCES dbo.AspNetUsers (Id),
        CONSTRAINT FK_Basvurular_TamamlayanUser FOREIGN KEY (TamamlayanUserId)
            REFERENCES dbo.AspNetUsers (Id),
        CONSTRAINT CK_Basvurular_TcKimlikNo CHECK
            (LEN(BasvuranTcKimlikNo) = 11 AND BasvuranTcKimlikNo NOT LIKE '%[^0-9]%'),
        CONSTRAINT CK_Basvurular_EngelOrani CHECK
            (EngelOrani IS NULL OR EngelOrani BETWEEN 0 AND 100)
    );

    CREATE INDEX IX_Basvurular_Belediye_Durum_Tarih
        ON sosyobel.Basvurular (BelediyeId, BasvuruDurumuId, OlusturulmaTarihiUtc DESC);

    CREATE INDEX IX_Basvurular_Belediye_TcKimlikNo
        ON sosyobel.Basvurular (BelediyeId, BasvuranTcKimlikNo, OlusturulmaTarihiUtc DESC);

    CREATE INDEX IX_Basvurular_OlusturanUserId
        ON sosyobel.Basvurular (OlusturanUserId, BasvuruDurumuId);

    /* Başvuru anındaki aile bilgisi ayrıca saklanır; sonraki profil güncellemeleri geçmişi değiştirmez. */
    CREATE TABLE sosyobel.BasvuruAileFertleri
    (
        Id                    int IDENTITY(1,1) NOT NULL,
        BelediyeId            int NOT NULL,
        BasvuruId             int NOT NULL,
        KaynakAileFerdiId     int NULL,
        AdSoyad               nvarchar(200) NOT NULL,
        Yas                   smallint NOT NULL,
        YakinlikId            int NOT NULL,
        YakinlikDigerAciklama nvarchar(100) NULL,
        EngelDurumu           bit NOT NULL CONSTRAINT DF_BasvuruAileFertleri_EngelDurumu DEFAULT (0),
        EngelTuruId           int NULL,
        EngelAciklamasi       nvarchar(250) NULL,
        CalismaDurumuId       int NULL,
        EgitimDurumuId        int NULL,
        YasamDurumuId         int NOT NULL,
        OlusturanUserId       nvarchar(128) NOT NULL,
        OlusturulmaTarihiUtc  datetime2(3) NOT NULL
            CONSTRAINT DF_BasvuruAileFertleri_OlusturulmaTarihiUtc DEFAULT SYSUTCDATETIME(),
        RowVersion            rowversion NOT NULL,
        CONSTRAINT PK_BasvuruAileFertleri PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_BasvuruAileFertleri_Basvurular FOREIGN KEY (BelediyeId, BasvuruId)
            REFERENCES sosyobel.Basvurular (BelediyeId, Id),
        CONSTRAINT FK_BasvuruAileFertleri_KaynakAileFerdi FOREIGN KEY (BelediyeId, KaynakAileFerdiId)
            REFERENCES sosyobel.AileFertleri (BelediyeId, Id),
        CONSTRAINT FK_BasvuruAileFertleri_Yakinliklar FOREIGN KEY (YakinlikId)
            REFERENCES sosyobel.Yakinliklar (Id),
        CONSTRAINT FK_BasvuruAileFertleri_EngelTurleri FOREIGN KEY (EngelTuruId)
            REFERENCES sosyobel.EngelTurleri (Id),
        CONSTRAINT FK_BasvuruAileFertleri_CalismaDurumlari FOREIGN KEY (CalismaDurumuId)
            REFERENCES sosyobel.CalismaDurumlari (Id),
        CONSTRAINT FK_BasvuruAileFertleri_EgitimDurumlari FOREIGN KEY (EgitimDurumuId)
            REFERENCES sosyobel.EgitimDurumlari (Id),
        CONSTRAINT FK_BasvuruAileFertleri_YasamDurumlari FOREIGN KEY (YasamDurumuId)
            REFERENCES sosyobel.YasamDurumlari (Id),
        CONSTRAINT FK_BasvuruAileFertleri_OlusturanUser FOREIGN KEY (OlusturanUserId)
            REFERENCES dbo.AspNetUsers (Id),
        CONSTRAINT CK_BasvuruAileFertleri_Yas CHECK (Yas BETWEEN 0 AND 130)
    );

    CREATE INDEX IX_BasvuruAileFertleri_BasvuruId
        ON sosyobel.BasvuruAileFertleri (BasvuruId);

    /* Hane soruları sabit kolonlar yerine yönetilebilir soru/seçenek yapısında tutulur. */
    CREATE TABLE sosyobel.HaneSorulari
    (
        Id          int IDENTITY(1,1) NOT NULL,
        BelediyeId  int NULL,
        Kod         nvarchar(80) NOT NULL,
        SoruMetni   nvarchar(300) NOT NULL,
        CevapTipi   nvarchar(30) NOT NULL,
        ZorunluMu   bit NOT NULL CONSTRAINT DF_HaneSorulari_ZorunluMu DEFAULT (0),
        Sira        smallint NOT NULL,
        AktifMi     bit NOT NULL CONSTRAINT DF_HaneSorulari_AktifMi DEFAULT (1),
        CONSTRAINT PK_HaneSorulari PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_HaneSorulari_Belediyeler FOREIGN KEY (BelediyeId)
            REFERENCES sosyobel.Belediyeler (Id),
        CONSTRAINT CK_HaneSorulari_CevapTipi CHECK
            (CevapTipi IN (N'TEK_SECIM', N'COKLU_SECIM', N'METIN', N'SAYI', N'EVET_HAYIR')),
        CONSTRAINT CK_HaneSorulari_Sira CHECK (Sira BETWEEN 1 AND 32767)
    );

    CREATE UNIQUE INDEX UX_HaneSorulari_GlobalKod
        ON sosyobel.HaneSorulari (Kod)
        WHERE BelediyeId IS NULL;

    CREATE UNIQUE INDEX UX_HaneSorulari_BelediyeKod
        ON sosyobel.HaneSorulari (BelediyeId, Kod)
        WHERE BelediyeId IS NOT NULL;

    CREATE TABLE sosyobel.HaneSoruSecenekleri
    (
        Id          int IDENTITY(1,1) NOT NULL,
        SoruId      int NOT NULL,
        Kod         nvarchar(80) NOT NULL,
        Etiket      nvarchar(200) NOT NULL,
        Sira        smallint NOT NULL,
        AktifMi     bit NOT NULL CONSTRAINT DF_HaneSoruSecenekleri_AktifMi DEFAULT (1),
        CONSTRAINT PK_HaneSoruSecenekleri PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT UQ_HaneSoruSecenekleri_Soru_Id UNIQUE (SoruId, Id),
        CONSTRAINT UQ_HaneSoruSecenekleri_Soru_Kod UNIQUE (SoruId, Kod),
        CONSTRAINT FK_HaneSoruSecenekleri_HaneSorulari FOREIGN KEY (SoruId)
            REFERENCES sosyobel.HaneSorulari (Id),
        CONSTRAINT CK_HaneSoruSecenekleri_Sira CHECK (Sira BETWEEN 1 AND 32767)
    );

    CREATE TABLE sosyobel.BasvuruHaneCevaplari
    (
        Id                    int IDENTITY(1,1) NOT NULL,
        BelediyeId            int NOT NULL,
        BasvuruId             int NOT NULL,
        SoruId                int NOT NULL,
        SecenekId             int NULL,
        SerbestMetinCevap     nvarchar(1000) NULL,
        SayisalCevap          decimal(18,2) NULL,
        OlusturanUserId       nvarchar(128) NOT NULL,
        OlusturulmaTarihiUtc  datetime2(3) NOT NULL
            CONSTRAINT DF_BasvuruHaneCevaplari_OlusturulmaTarihiUtc DEFAULT SYSUTCDATETIME(),
        GuncellenmeTarihiUtc  datetime2(3) NULL,
        RowVersion            rowversion NOT NULL,
        CONSTRAINT PK_BasvuruHaneCevaplari PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT UQ_BasvuruHaneCevaplari_Basvuru_Soru UNIQUE (BasvuruId, SoruId),
        CONSTRAINT FK_BasvuruHaneCevaplari_Basvurular FOREIGN KEY (BelediyeId, BasvuruId)
            REFERENCES sosyobel.Basvurular (BelediyeId, Id),
        CONSTRAINT FK_BasvuruHaneCevaplari_HaneSorulari FOREIGN KEY (SoruId)
            REFERENCES sosyobel.HaneSorulari (Id),
        CONSTRAINT FK_BasvuruHaneCevaplari_Secenek FOREIGN KEY (SoruId, SecenekId)
            REFERENCES sosyobel.HaneSoruSecenekleri (SoruId, Id),
        CONSTRAINT FK_BasvuruHaneCevaplari_OlusturanUser FOREIGN KEY (OlusturanUserId)
            REFERENCES dbo.AspNetUsers (Id),
        CONSTRAINT CK_BasvuruHaneCevaplari_TekCevap CHECK
        (
            (CASE WHEN SecenekId IS NULL THEN 0 ELSE 1 END) +
            (CASE WHEN SerbestMetinCevap IS NULL THEN 0 ELSE 1 END) +
            (CASE WHEN SayisalCevap IS NULL THEN 0 ELSE 1 END) = 1
        )
    );

    CREATE INDEX IX_BasvuruHaneCevaplari_SoruId
        ON sosyobel.BasvuruHaneCevaplari (SoruId);

    /*
      Dosyanın kendisi SQL Server'a yazılmaz. StorageKey özel dosya deposundaki
      nesneyi gösterir. Sıra 1..15 ve benzersiz olduğu için aktif fotoğraf sayısı
      veritabanı seviyesinde de 15'i geçemez.
    */
    CREATE TABLE sosyobel.BasvuruFotograflari
    (
        Id                    int IDENTITY(1,1) NOT NULL,
        BelediyeId            int NOT NULL,
        BasvuruId             int NOT NULL,
        StorageKey            nvarchar(500) NOT NULL,
        OrijinalDosyaAdi      nvarchar(255) NULL,
        MimeType              varchar(100) NOT NULL,
        BoyutByte             bigint NOT NULL,
        Sha256                binary(32) NOT NULL,
        SiraNo                tinyint NOT NULL,
        TaramaDurumuKodu      nvarchar(30) NOT NULL
            CONSTRAINT DF_BasvuruFotograflari_TaramaDurumu DEFAULT (N'BEKLIYOR'),
        ExifTemizlendiMi      bit NOT NULL
            CONSTRAINT DF_BasvuruFotograflari_ExifTemizlendiMi DEFAULT (0),
        SilindiMi             bit NOT NULL
            CONSTRAINT DF_BasvuruFotograflari_SilindiMi DEFAULT (0),
        OlusturanUserId       nvarchar(128) NOT NULL,
        OlusturulmaTarihiUtc  datetime2(3) NOT NULL
            CONSTRAINT DF_BasvuruFotograflari_OlusturulmaTarihiUtc DEFAULT SYSUTCDATETIME(),
        SilenUserId           nvarchar(128) NULL,
        SilinmeTarihiUtc      datetime2(3) NULL,
        RowVersion            rowversion NOT NULL,
        CONSTRAINT PK_BasvuruFotograflari PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT UQ_BasvuruFotograflari_StorageKey UNIQUE (StorageKey),
        CONSTRAINT FK_BasvuruFotograflari_Basvurular FOREIGN KEY (BelediyeId, BasvuruId)
            REFERENCES sosyobel.Basvurular (BelediyeId, Id),
        CONSTRAINT FK_BasvuruFotograflari_OlusturanUser FOREIGN KEY (OlusturanUserId)
            REFERENCES dbo.AspNetUsers (Id),
        CONSTRAINT FK_BasvuruFotograflari_SilenUser FOREIGN KEY (SilenUserId)
            REFERENCES dbo.AspNetUsers (Id),
        CONSTRAINT CK_BasvuruFotograflari_SiraNo CHECK (SiraNo BETWEEN 1 AND 15),
        CONSTRAINT CK_BasvuruFotograflari_Boyut CHECK (BoyutByte > 0),
        CONSTRAINT CK_BasvuruFotograflari_TaramaDurumu CHECK
            (TaramaDurumuKodu IN (N'BEKLIYOR', N'TEMIZ', N'KARANTINA', N'REDDEDILDI')),
        CONSTRAINT CK_BasvuruFotograflari_SilmeBilgisi CHECK
        (
            (SilindiMi = 0 AND SilenUserId IS NULL AND SilinmeTarihiUtc IS NULL) OR
            (SilindiMi = 1 AND SilenUserId IS NOT NULL AND SilinmeTarihiUtc IS NOT NULL)
        )
    );

    CREATE UNIQUE INDEX UX_BasvuruFotograflari_AktifSira
        ON sosyobel.BasvuruFotograflari (BasvuruId, SiraNo)
        WHERE SilindiMi = 0;

    CREATE INDEX IX_BasvuruFotograflari_BasvuruId
        ON sosyobel.BasvuruFotograflari (BasvuruId, SilindiMi);

    CREATE TABLE sosyobel.BasvuruDurumGecmisi
    (
        Id                    bigint IDENTITY(1,1) NOT NULL,
        BelediyeId            int NOT NULL,
        BasvuruId             int NOT NULL,
        OncekiDurumId         int NULL,
        YeniDurumId           int NOT NULL,
        Aciklama              nvarchar(1000) NULL,
        OlusturanUserId       nvarchar(128) NOT NULL,
        OlusturulmaTarihiUtc  datetime2(3) NOT NULL
            CONSTRAINT DF_BasvuruDurumGecmisi_OlusturulmaTarihiUtc DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_BasvuruDurumGecmisi PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_BasvuruDurumGecmisi_Basvurular FOREIGN KEY (BelediyeId, BasvuruId)
            REFERENCES sosyobel.Basvurular (BelediyeId, Id),
        CONSTRAINT FK_BasvuruDurumGecmisi_OncekiDurum FOREIGN KEY (OncekiDurumId)
            REFERENCES sosyobel.BasvuruDurumlari (Id),
        CONSTRAINT FK_BasvuruDurumGecmisi_YeniDurum FOREIGN KEY (YeniDurumId)
            REFERENCES sosyobel.BasvuruDurumlari (Id),
        CONSTRAINT FK_BasvuruDurumGecmisi_OlusturanUser FOREIGN KEY (OlusturanUserId)
            REFERENCES dbo.AspNetUsers (Id)
    );

    CREATE INDEX IX_BasvuruDurumGecmisi_Basvuru_Tarih
        ON sosyobel.BasvuruDurumGecmisi (BasvuruId, OlusturulmaTarihiUtc DESC);

    /* Kurul kararı artık vatandaşa değil doğrudan ilgili başvuruya bağlanır. */
    CREATE TABLE sosyobel.KurulIslemleri
    (
        Id                    int IDENTITY(1,1) NOT NULL,
        BelediyeId            int NOT NULL,
        BasvuruId             int NOT NULL,
        KararKodu             nvarchar(50) NOT NULL,
        KararAciklamasi       nvarchar(2000) NULL,
        ReddetmeSebebi        nvarchar(1000) NULL,
        KararTarihiUtc        datetime2(3) NOT NULL,
        OlusturanUserId       nvarchar(128) NOT NULL,
        OlusturulmaTarihiUtc  datetime2(3) NOT NULL
            CONSTRAINT DF_KurulIslemleri_OlusturulmaTarihiUtc DEFAULT SYSUTCDATETIME(),
        RowVersion            rowversion NOT NULL,
        CONSTRAINT PK_KurulIslemleri PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_KurulIslemleri_Basvurular FOREIGN KEY (BelediyeId, BasvuruId)
            REFERENCES sosyobel.Basvurular (BelediyeId, Id),
        CONSTRAINT FK_KurulIslemleri_OlusturanUser FOREIGN KEY (OlusturanUserId)
            REFERENCES dbo.AspNetUsers (Id)
    );

    CREATE INDEX IX_KurulIslemleri_Basvuru_Tarih
        ON sosyobel.KurulIslemleri (BasvuruId, KararTarihiUtc DESC);

    /* Görev, vatandaş yerine başvuruya bağlanır; aynı vatandaşın farklı başvuruları karışmaz. */
    CREATE TABLE sosyobel.SahaGorevleri
    (
        Id                    int IDENTITY(1,1) NOT NULL,
        BelediyeId            int NOT NULL,
        BasvuruId             int NOT NULL,
        AtananUserId          nvarchar(128) NOT NULL,
        DurumKodu             nvarchar(50) NOT NULL,
        Aciklama              nvarchar(1000) NULL,
        AtanmaTarihiUtc       datetime2(3) NOT NULL
            CONSTRAINT DF_SahaGorevleri_AtanmaTarihiUtc DEFAULT SYSUTCDATETIME(),
        BaslamaTarihiUtc      datetime2(3) NULL,
        TamamlanmaTarihiUtc   datetime2(3) NULL,
        RowVersion            rowversion NOT NULL,
        CONSTRAINT PK_SahaGorevleri PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_SahaGorevleri_Basvurular FOREIGN KEY (BelediyeId, BasvuruId)
            REFERENCES sosyobel.Basvurular (BelediyeId, Id),
        CONSTRAINT FK_SahaGorevleri_AtananUser FOREIGN KEY (AtananUserId)
            REFERENCES dbo.AspNetUsers (Id)
    );

    CREATE INDEX IX_SahaGorevleri_User_Durum
        ON sosyobel.SahaGorevleri (AtananUserId, DurumKodu, AtanmaTarihiUtc DESC);

    /* Genel audit kaydı; hassas değerlerin kendisi yerine gerektiğinde maskeli JSON tutulur. */
    CREATE TABLE sosyobel.IslemGecmisleri
    (
        Id                    bigint IDENTITY(1,1) NOT NULL,
        BelediyeId            int NOT NULL,
        VarlikTuru            nvarchar(100) NOT NULL,
        VarlikPublicId        uniqueidentifier NULL,
        IslemKodu             nvarchar(100) NOT NULL,
        Aciklama              nvarchar(1000) NULL,
        DegisiklikOzetiJson   nvarchar(max) NULL,
        OlusturanUserId       nvarchar(128) NULL,
        OlusturulmaTarihiUtc  datetime2(3) NOT NULL
            CONSTRAINT DF_IslemGecmisleri_OlusturulmaTarihiUtc DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_IslemGecmisleri PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_IslemGecmisleri_Belediyeler FOREIGN KEY (BelediyeId)
            REFERENCES sosyobel.Belediyeler (Id),
        CONSTRAINT FK_IslemGecmisleri_OlusturanUser FOREIGN KEY (OlusturanUserId)
            REFERENCES dbo.AspNetUsers (Id),
        CONSTRAINT CK_IslemGecmisleri_Json CHECK
            (DegisiklikOzetiJson IS NULL OR ISJSON(DegisiklikOzetiJson) = 1)
    );

    CREATE INDEX IX_IslemGecmisleri_Varlik_Tarih
        ON sosyobel.IslemGecmisleri
        (BelediyeId, VarlikTuru, VarlikPublicId, OlusturulmaTarihiUtc DESC);

    /* CSV ve ilerideki diğer veri aktarım biçimleri aynı izlenebilir iş modeliyle yürür. */
    CREATE TABLE sosyobel.VeriAktarimIslemleri
    (
        Id                    bigint IDENTITY(1,1) NOT NULL,
        PublicId              uniqueidentifier NOT NULL
            CONSTRAINT DF_VeriAktarimIslemleri_PublicId DEFAULT NEWSEQUENTIALID(),
        BelediyeId            int NOT NULL,
        KaynakTuruKodu        nvarchar(50) NOT NULL,
        KaynakDosyaAdi        nvarchar(255) NULL,
        KaynakDosyaSha256     binary(32) NULL,
        DurumKodu             nvarchar(30) NOT NULL,
        ToplamSatir           int NULL,
        BasariliSatir         int NULL,
        HataliSatir           int NULL,
        BaslatanUserId        nvarchar(128) NOT NULL,
        BaslamaTarihiUtc      datetime2(3) NOT NULL
            CONSTRAINT DF_VeriAktarimIslemleri_BaslamaTarihiUtc DEFAULT SYSUTCDATETIME(),
        BitisTarihiUtc        datetime2(3) NULL,
        CONSTRAINT PK_VeriAktarimIslemleri PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT UQ_VeriAktarimIslemleri_PublicId UNIQUE (PublicId),
        CONSTRAINT FK_VeriAktarimIslemleri_Belediyeler FOREIGN KEY (BelediyeId)
            REFERENCES sosyobel.Belediyeler (Id),
        CONSTRAINT FK_VeriAktarimIslemleri_BaslatanUser FOREIGN KEY (BaslatanUserId)
            REFERENCES dbo.AspNetUsers (Id),
        CONSTRAINT CK_VeriAktarimIslemleri_Durum CHECK
            (DurumKodu IN (N'BEKLIYOR', N'ISLENIYOR', N'TAMAMLANDI', N'HATALI', N'IPTAL')),
        CONSTRAINT CK_VeriAktarimIslemleri_Sayilar CHECK
        (
            (ToplamSatir IS NULL OR ToplamSatir >= 0) AND
            (BasariliSatir IS NULL OR BasariliSatir >= 0) AND
            (HataliSatir IS NULL OR HataliSatir >= 0)
        )
    );

    CREATE INDEX IX_VeriAktarimIslemleri_Belediye_Durum
        ON sosyobel.VeriAktarimIslemleri (BelediyeId, DurumKodu, BaslamaTarihiUtc DESC);

    CREATE TABLE sosyobel.VeriAktarimSatirHatalari
    (
        Id                    bigint IDENTITY(1,1) NOT NULL,
        VeriAktarimIslemiId   bigint NOT NULL,
        SatirNo               int NOT NULL,
        HataKodu              nvarchar(100) NOT NULL,
        HataMesaji            nvarchar(1000) NOT NULL,
        MaskeliSatirJson      nvarchar(max) NULL,
        OlusturulmaTarihiUtc  datetime2(3) NOT NULL
            CONSTRAINT DF_VeriAktarimSatirHatalari_OlusturulmaTarihiUtc DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_VeriAktarimSatirHatalari PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_VeriAktarimSatirHatalari_Aktarim FOREIGN KEY (VeriAktarimIslemiId)
            REFERENCES sosyobel.VeriAktarimIslemleri (Id),
        CONSTRAINT CK_VeriAktarimSatirHatalari_SatirNo CHECK (SatirNo > 0),
        CONSTRAINT CK_VeriAktarimSatirHatalari_Json CHECK
            (MaskeliSatirJson IS NULL OR ISJSON(MaskeliSatirJson) = 1)
    );

    CREATE INDEX IX_VeriAktarimSatirHatalari_Aktarim_Satir
        ON sosyobel.VeriAktarimSatirHatalari (VeriAktarimIslemiId, SatirNo);

    /* Refresh tokenın açık değeri değil SHA-256 özeti tutulur. */
    CREATE TABLE sosyobel.YenilemeTokenlari
    (
        Id                    bigint IDENTITY(1,1) NOT NULL,
        UserId                nvarchar(128) NOT NULL,
        TokenHash             binary(32) NOT NULL,
        CihazKimligi          nvarchar(200) NULL,
        OlusturanIp           varchar(45) NULL,
        OlusturulmaTarihiUtc  datetime2(3) NOT NULL
            CONSTRAINT DF_YenilemeTokenlari_OlusturulmaTarihiUtc DEFAULT SYSUTCDATETIME(),
        SonKullanmaTarihiUtc  datetime2(3) NOT NULL,
        IptalTarihiUtc        datetime2(3) NULL,
        IptalEdenIp           varchar(45) NULL,
        CONSTRAINT PK_YenilemeTokenlari PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT UQ_YenilemeTokenlari_TokenHash UNIQUE (TokenHash),
        CONSTRAINT FK_YenilemeTokenlari_Users FOREIGN KEY (UserId)
            REFERENCES dbo.AspNetUsers (Id),
        CONSTRAINT CK_YenilemeTokenlari_Sure CHECK
            (SonKullanmaTarihiUtc > OlusturulmaTarihiUtc)
    );

    CREATE INDEX IX_YenilemeTokenlari_User_SonKullanma
        ON sosyobel.YenilemeTokenlari (UserId, SonKullanmaTarihiUtc DESC);

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
