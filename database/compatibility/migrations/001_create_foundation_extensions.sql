/*
    Sosyo-Bel şirket şeması uyumluluk migration'ı 001

    Bu migration yalnız yeni nesneler ekler. Mevcut dbo tablolarına kolon eklemez,
    kolon tipi değiştirmez ve veri yazmaz. Amaç, mobil API'nin teknik metadatasını
    şirketin mevcut iş tablolarından ayrı tutmaktır.

    Oluşturulan tablolar:
      - sosyobel.BasvuruUygulamaBilgileri
      - sosyobel.ReferansKodlari
      - sosyobel.KullaniciUygulamaBilgileri

    Bu dosya, temiz yerel V2 migration zincirinin parçası değildir.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

IF OBJECT_ID(N'dbo.AspNetUsers', N'U') IS NULL OR
   OBJECT_ID(N'dbo.Basvurular', N'U') IS NULL
BEGIN
    THROW 51200, N'Şirket temel tabloları bulunamadı: dbo.AspNetUsers ve dbo.Basvurular gereklidir.', 1;
END;

-- Şirket Identity anahtarları nvarchar(450) olarak paylaşılmıştır. Farklı bir
-- hedefe yanlış tipte foreign key oluşturmamak için bu özellik açıkça doğrulanır.
IF NOT EXISTS
(
    SELECT 1
    FROM sys.columns AS columnInfo
    INNER JOIN sys.types AS typeInfo
        ON typeInfo.user_type_id = columnInfo.user_type_id
    WHERE columnInfo.object_id = OBJECT_ID(N'dbo.AspNetUsers')
      AND columnInfo.name = N'Id'
      AND typeInfo.name = N'nvarchar'
      AND columnInfo.max_length = 900
      AND columnInfo.is_nullable = 0
      AND columnInfo.collation_name =
          CONVERT(sysname, DATABASEPROPERTYEX(DB_NAME(), N'Collation'))
)
BEGIN
    THROW 51201, N'dbo.AspNetUsers.Id beklenen nvarchar(450), NOT NULL ve veritabanı kolasyonunda değildir.', 1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.columns AS columnInfo
    INNER JOIN sys.types AS typeInfo
        ON typeInfo.user_type_id = columnInfo.user_type_id
    WHERE columnInfo.object_id = OBJECT_ID(N'dbo.Basvurular')
      AND columnInfo.name = N'Id'
      AND typeInfo.name = N'int'
      AND columnInfo.is_nullable = 0
)
BEGIN
    THROW 51202, N'dbo.Basvurular.Id beklenen int NOT NULL tipinde değildir.', 1;
END;

IF EXISTS
(
    SELECT 1
    FROM
    (
        VALUES
            (N'BasvuruDurumlari'),
            (N'CalismaDurumlari'),
            (N'EgitimDurumlari'),
            (N'EngelTurleri'),
            (N'TalepGelisKanallari'),
            (N'Yakinliklar'),
            (N'YardimTurleri')
    ) AS requiredTable(TableName)
    WHERE OBJECT_ID(N'dbo.' + requiredTable.TableName, N'U') IS NULL
)
BEGIN
    THROW 51203, N'Kod eşlemesi için gerekli şirket referans tablolarından biri eksik.', 1;
END;

-- Polimorfik ReferansKodlari.KaynakId alanı gerçek FK taşıyamadığı için bütün
-- kaynak lookup tablolarının tek kolonlu int(Id) primary key yapısı doğrulanır.
IF EXISTS
(
    SELECT 1
    FROM
    (
        VALUES
            (N'BasvuruDurumlari'),
            (N'CalismaDurumlari'),
            (N'EgitimDurumlari'),
            (N'EngelTurleri'),
            (N'TalepGelisKanallari'),
            (N'Yakinliklar'),
            (N'YardimTurleri')
    ) AS requiredLookup(TableName)
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM sys.tables AS lookupTable
        INNER JOIN sys.columns AS idColumn
            ON idColumn.object_id = lookupTable.object_id
           AND idColumn.name = N'Id'
        INNER JOIN sys.types AS idType
            ON idType.user_type_id = idColumn.user_type_id
        INNER JOIN sys.indexes AS primaryKey
            ON primaryKey.object_id = lookupTable.object_id
           AND primaryKey.is_primary_key = 1
        INNER JOIN sys.index_columns AS primaryKeyColumn
            ON primaryKeyColumn.object_id = primaryKey.object_id
           AND primaryKeyColumn.index_id = primaryKey.index_id
           AND primaryKeyColumn.column_id = idColumn.column_id
           AND primaryKeyColumn.key_ordinal = 1
        WHERE lookupTable.schema_id = SCHEMA_ID(N'dbo')
          AND lookupTable.name = requiredLookup.TableName
          AND idType.name = N'int'
          AND idColumn.is_nullable = 0
          AND
          (
              SELECT COUNT(*)
              FROM sys.index_columns AS allPrimaryKeyColumns
              WHERE allPrimaryKeyColumns.object_id = primaryKey.object_id
                AND allPrimaryKeyColumns.index_id = primaryKey.index_id
                AND allPrimaryKeyColumns.key_ordinal > 0
          ) = 1
    )
)
BEGIN
    THROW 51205, N'Şirket referans tablolarından birinin Id alanı tek kolonlu int primary key değildir.', 1;
END;

DECLARE @ExistingCompatibilityTableCount int =
(
    SELECT COUNT(*)
    FROM
    (
        VALUES
            (N'sosyobel.BasvuruUygulamaBilgileri'),
            (N'sosyobel.ReferansKodlari'),
            (N'sosyobel.KullaniciUygulamaBilgileri')
    ) AS compatibilityTable(ObjectName)
    WHERE OBJECT_ID(compatibilityTable.ObjectName, N'U') IS NOT NULL
);

IF @ExistingCompatibilityTableCount = 3
BEGIN
    PRINT N'Uyumluluk 001 tabloları zaten mevcut; migration yeniden uygulanmadı.';
    RETURN;
END;

IF @ExistingCompatibilityTableCount > 0
BEGIN
    THROW 51204, N'Uyumluluk 001 kısmen uygulanmış görünüyor. Önce şema denetimi yapılmalıdır.', 1;
END;

BEGIN TRY
    BEGIN TRANSACTION;

    IF SCHEMA_ID(N'sosyobel') IS NULL
    BEGIN
        EXEC(N'CREATE SCHEMA sosyobel AUTHORIZATION dbo;');
    END;

    /*
      Şirketin dbo.Basvurular kaydı iş verisinin sahibidir. Bu bire bir tablo
      yalnız mobil API'nin mevcut tabloda karşılığı olmayan teknik alanlarını
      taşır. BasvuruNo henüz kurum biçimi onaylanmadığı için nullable bırakılır.
    */
    CREATE TABLE sosyobel.BasvuruUygulamaBilgileri
    (
        BasvuruId                  int NOT NULL,
        PublicId                   uniqueidentifier NOT NULL
            CONSTRAINT DF_BasvuruUygulamaBilgileri_PublicId
                DEFAULT NEWSEQUENTIALID(),
        BasvuruNo                  nvarchar(40) NULL,
        SahaIncelemeNotu           nvarchar(2000) NULL,
        GuncelleyenUserId          nvarchar(450) NULL,
        GuncellenmeTarihiUtc       datetime2(3) NULL,
        KurulaGonderenUserId       nvarchar(450) NULL,
        KurulaGonderilmeTarihiUtc  datetime2(3) NULL,
        OlusturulmaTarihiUtc       datetime2(3) NOT NULL
            CONSTRAINT DF_BasvuruUygulamaBilgileri_OlusturulmaTarihiUtc
                DEFAULT SYSUTCDATETIME(),
        RowVersion                 rowversion NOT NULL,
        CONSTRAINT PK_BasvuruUygulamaBilgileri
            PRIMARY KEY CLUSTERED (BasvuruId),
        CONSTRAINT UQ_BasvuruUygulamaBilgileri_PublicId
            UNIQUE NONCLUSTERED (PublicId),
        CONSTRAINT FK_BasvuruUygulamaBilgileri_Basvurular
            FOREIGN KEY (BasvuruId)
            REFERENCES dbo.Basvurular (Id),
        CONSTRAINT FK_BasvuruUygulamaBilgileri_GuncelleyenUser
            FOREIGN KEY (GuncelleyenUserId)
            REFERENCES dbo.AspNetUsers (Id),
        CONSTRAINT FK_BasvuruUygulamaBilgileri_KurulaGonderenUser
            FOREIGN KEY (KurulaGonderenUserId)
            REFERENCES dbo.AspNetUsers (Id),
        CONSTRAINT CK_BasvuruUygulamaBilgileri_BasvuruNo CHECK
            (BasvuruNo IS NULL OR LEN(LTRIM(RTRIM(BasvuruNo))) > 0),
        CONSTRAINT CK_BasvuruUygulamaBilgileri_Guncelleme CHECK
        (
            (GuncelleyenUserId IS NULL AND GuncellenmeTarihiUtc IS NULL) OR
            (GuncelleyenUserId IS NOT NULL AND GuncellenmeTarihiUtc IS NOT NULL)
        ),
        CONSTRAINT CK_BasvuruUygulamaBilgileri_KurulaGonderim CHECK
        (
            (KurulaGonderenUserId IS NULL AND KurulaGonderilmeTarihiUtc IS NULL) OR
            (KurulaGonderenUserId IS NOT NULL AND KurulaGonderilmeTarihiUtc IS NOT NULL)
        )
    );

    CREATE UNIQUE INDEX UX_BasvuruUygulamaBilgileri_BasvuruNo
        ON sosyobel.BasvuruUygulamaBilgileri (BasvuruNo)
        WHERE BasvuruNo IS NOT NULL;

    /*
      Şirket lookup tablolarındaki değişebilen Türkçe Name alanları API sözleşmesi
      değildir. Bu tablo, mevcut satır kimliğini kararlı bir API koduna bağlar.
      Polimorfik KaynakId nedeniyle gerçek kaynak varlığı check betiğinde ayrıca
      doğrulanır; mevcut dbo tablolarına trigger veya kolon eklenmez.
    */
    CREATE TABLE sosyobel.ReferansKodlari
    (
        Id                    int IDENTITY(1,1) NOT NULL,
        ReferansTuruKodu      nvarchar(50) NOT NULL,
        KaynakId              int NOT NULL,
        Kod                   nvarchar(80) NOT NULL,
        OlusturulmaTarihiUtc  datetime2(3) NOT NULL
            CONSTRAINT DF_ReferansKodlari_OlusturulmaTarihiUtc
                DEFAULT SYSUTCDATETIME(),
        GuncellenmeTarihiUtc  datetime2(3) NULL,
        RowVersion            rowversion NOT NULL,
        CONSTRAINT PK_ReferansKodlari PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT UQ_ReferansKodlari_Tur_Kaynak
            UNIQUE NONCLUSTERED (ReferansTuruKodu, KaynakId),
        CONSTRAINT UQ_ReferansKodlari_Tur_Kod
            UNIQUE NONCLUSTERED (ReferansTuruKodu, Kod),
        CONSTRAINT CK_ReferansKodlari_Tur CHECK
        (
            ReferansTuruKodu IN
            (
                N'BASVURU_DURUMU',
                N'CALISMA_DURUMU',
                N'EGITIM_DURUMU',
                N'ENGEL_TURU',
                N'TALEP_GELIS_KANALI',
                N'YAKINLIK',
                N'YARDIM_TURU'
            )
        ),
        CONSTRAINT CK_ReferansKodlari_KaynakId CHECK (KaynakId > 0),
        CONSTRAINT CK_ReferansKodlari_Kod CHECK
            (LEN(LTRIM(RTRIM(Kod))) > 0)
    );

    /*
      Şirket AspNetUsers tablosunda bulunmayan mobil hesap yaşam döngüsü alanları
      bire bir ek tabloda tutulur. Böylece mevcut Identity kolonlarına dokunulmaz.
    */
    CREATE TABLE sosyobel.KullaniciUygulamaBilgileri
    (
        UserId                    nvarchar(450) NOT NULL,
        AktifMi                   bit NOT NULL
            CONSTRAINT DF_KullaniciUygulamaBilgileri_AktifMi DEFAULT (1),
        OlusturanUserId           nvarchar(450) NULL,
        OlusturulmaTarihiUtc      datetime2(3) NOT NULL
            CONSTRAINT DF_KullaniciUygulamaBilgileri_OlusturulmaTarihiUtc
                DEFAULT SYSUTCDATETIME(),
        GuncelleyenUserId         nvarchar(450) NULL,
        GuncellenmeTarihiUtc      datetime2(3) NULL,
        DevreDisiBirakanUserId    nvarchar(450) NULL,
        DevreDisiTarihiUtc        datetime2(3) NULL,
        DevreDisiGerekce          nvarchar(1000) NULL,
        RowVersion                rowversion NOT NULL,
        CONSTRAINT PK_KullaniciUygulamaBilgileri
            PRIMARY KEY CLUSTERED (UserId),
        CONSTRAINT FK_KullaniciUygulamaBilgileri_User
            FOREIGN KEY (UserId)
            REFERENCES dbo.AspNetUsers (Id),
        CONSTRAINT FK_KullaniciUygulamaBilgileri_OlusturanUser
            FOREIGN KEY (OlusturanUserId)
            REFERENCES dbo.AspNetUsers (Id),
        CONSTRAINT FK_KullaniciUygulamaBilgileri_GuncelleyenUser
            FOREIGN KEY (GuncelleyenUserId)
            REFERENCES dbo.AspNetUsers (Id),
        CONSTRAINT FK_KullaniciUygulamaBilgileri_DevreDisiBirakanUser
            FOREIGN KEY (DevreDisiBirakanUserId)
            REFERENCES dbo.AspNetUsers (Id),
        CONSTRAINT CK_KullaniciUygulamaBilgileri_Guncelleme CHECK
        (
            (GuncelleyenUserId IS NULL AND GuncellenmeTarihiUtc IS NULL) OR
            (GuncelleyenUserId IS NOT NULL AND GuncellenmeTarihiUtc IS NOT NULL)
        ),
        CONSTRAINT CK_KullaniciUygulamaBilgileri_DevreDisiBilgisi CHECK
        (
            (
                AktifMi = 1 AND
                DevreDisiBirakanUserId IS NULL AND
                DevreDisiTarihiUtc IS NULL AND
                DevreDisiGerekce IS NULL
            ) OR
            (
                AktifMi = 0 AND
                DevreDisiBirakanUserId IS NOT NULL AND
                DevreDisiTarihiUtc IS NOT NULL AND
                DevreDisiGerekce IS NOT NULL AND
                LEN(LTRIM(RTRIM(DevreDisiGerekce))) >= 10
            )
        )
    );

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
