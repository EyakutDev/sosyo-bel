/*
    Sosyo-Bel şirket veritabanı salt-okunur şema kontrolü

    Amaç:
      - Paylaşılan sosyaldb.ipynb şemasının hedef veritabanında gerçekten bulunup
        bulunmadığını tablo, kritik kolon ve foreign key seviyesinde göstermek.
      - Uyumluluk migration'ı yazılmadan önce farklılıkları görünür kılmak.

    Güvenlik:
      - Bu betik hedef veritabanında CREATE, ALTER, UPDATE, DELETE veya INSERT
        çalıştırmaz.
      - Yalnız oturum içi tablo değişkenlerine beklenen şema tarifini yazar.
      - Vatandaş veya kullanıcı satırlarını ve kişisel verileri okumaz.

    Kullanım:
      1. SSMS'te doğru TEST veritabanını seçin.
      2. Betiği çalıştırın.
      3. Sonuç kümelerini saklayın ve DATABASE_COMPATIBILITY.md ile karşılaştırın.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF DB_NAME() IN (N'master', N'model', N'msdb', N'tempdb')
BEGIN
    THROW 51100, N'Sistem veritabanında uyumluluk kontrolü çalıştırılamaz.', 1;
END;

SELECT
    DB_NAME() AS DatabaseName,
    CONVERT(nvarchar(128), SERVERPROPERTY(N'ProductVersion')) AS SqlServerProductVersion,
    CONVERT(nvarchar(128), SERVERPROPERTY(N'ProductLevel')) AS SqlServerProductLevel,
    CONVERT(nvarchar(128), SERVERPROPERTY(N'Edition')) AS SqlServerEdition,
    d.compatibility_level AS CompatibilityLevel
FROM sys.databases AS d
WHERE d.database_id = DB_ID();

DECLARE @ExpectedTables TABLE
(
    SchemaName sysname NOT NULL,
    TableName sysname NOT NULL,
    Area nvarchar(40) NOT NULL,
    RequiredForMobile bit NOT NULL,
    PRIMARY KEY (SchemaName, TableName)
);

INSERT INTO @ExpectedTables (SchemaName, TableName, Area, RequiredForMobile)
VALUES
    (N'dbo', N'__EFMigrationsHistory', N'Metadata', 0),
    (N'dbo', N'AileFertleri', N'Aile', 0),
    (N'dbo', N'AspNetRoleClaims', N'Identity', 1),
    (N'dbo', N'AspNetRoles', N'Identity', 1),
    (N'dbo', N'AspNetUserClaims', N'Identity', 1),
    (N'dbo', N'AspNetUserLogins', N'Identity', 1),
    (N'dbo', N'AspNetUserRoles', N'Identity', 1),
    (N'dbo', N'AspNetUsers', N'Identity', 1),
    (N'dbo', N'AspNetUserTokens', N'Identity', 1),
    (N'dbo', N'BasvuruAileFertleri', N'Başvuru', 1),
    (N'dbo', N'BasvuruBelgeleri', N'Belge', 0),
    (N'dbo', N'BasvuruDurumlari', N'Referans', 1),
    (N'dbo', N'Basvurular', N'Başvuru', 1),
    (N'dbo', N'CalismaDurumlari', N'Referans', 1),
    (N'dbo', N'EgitimDurumlari', N'Referans', 1),
    (N'dbo', N'EngelTurleri', N'Referans', 1),
    (N'dbo', N'HaneFotograflari', N'Fotoğraf', 0),
    (N'dbo', N'IslemGecmisleri', N'Denetim', 0),
    (N'dbo', N'KurulIslemleri', N'Kurul', 0),
    (N'dbo', N'Mahalle', N'Adres', 0),
    (N'dbo', N'Mahalleler', N'Adres', 1),
    (N'dbo', N'MedeniDurumlar', N'Referans', 0),
    (N'dbo', N'Paketler', N'Yardım/Stok', 0),
    (N'dbo', N'PaketUrunler', N'Yardım/Stok', 0),
    (N'dbo', N'SahaAktiviteleri', N'Görev', 1),
    (N'dbo', N'SistemAyarlari', N'Ayar', 0),
    (N'dbo', N'Sokak', N'Adres', 0),
    (N'dbo', N'Sokaklar', N'Adres', 1),
    (N'dbo', N'SosyalYardimlar', N'Yardım/Stok', 0),
    (N'dbo', N'StokHareketleri', N'Yardım/Stok', 0),
    (N'dbo', N'StokUrunler', N'Yardım/Stok', 0),
    (N'dbo', N'TalepGelisKanallari', N'Referans', 1),
    (N'dbo', N'VatandasBelgeler', N'Belge', 0),
    (N'dbo', N'Vatandaslar', N'Vatandaş', 1),
    (N'dbo', N'Yakinliklar', N'Referans', 1),
    (N'dbo', N'YardimSekilleri', N'Yardım/Stok', 0),
    (N'dbo', N'YardimTipleri', N'Yardım/Stok', 0),
    (N'dbo', N'YardimTurleri', N'Referans', 1);

DECLARE @TableResults TABLE
(
    SchemaName sysname NOT NULL,
    TableName sysname NOT NULL,
    Area nvarchar(40) NOT NULL,
    RequiredForMobile bit NOT NULL,
    ResultCode varchar(20) NOT NULL
);

INSERT INTO @TableResults (SchemaName, TableName, Area, RequiredForMobile, ResultCode)
SELECT
    expected.SchemaName,
    expected.TableName,
    expected.Area,
    expected.RequiredForMobile,
    CASE WHEN target.object_id IS NULL THEN 'MISSING' ELSE 'OK' END
FROM @ExpectedTables AS expected
LEFT JOIN sys.schemas AS targetSchema
    ON targetSchema.name = expected.SchemaName
LEFT JOIN sys.tables AS target
    ON target.schema_id = targetSchema.schema_id
   AND target.name = expected.TableName;

SELECT
    SchemaName,
    TableName,
    Area,
    RequiredForMobile,
    ResultCode
FROM @TableResults
ORDER BY
    CASE ResultCode WHEN 'MISSING' THEN 0 ELSE 1 END,
    RequiredForMobile DESC,
    Area,
    TableName;

DECLARE @ExpectedColumns TABLE
(
    SchemaName sysname NOT NULL,
    TableName sysname NOT NULL,
    ColumnName sysname NOT NULL,
    ExpectedType sysname NOT NULL,
    ExpectedMaxLength int NULL,
    ExpectedNullable bit NOT NULL,
    PRIMARY KEY (SchemaName, TableName, ColumnName)
);

-- MaxLength karakter sayısıdır; nvarchar(max) için -1 kullanılır.
INSERT INTO @ExpectedColumns
    (SchemaName, TableName, ColumnName, ExpectedType, ExpectedMaxLength, ExpectedNullable)
VALUES
    (N'dbo', N'AspNetUsers', N'Id', N'nvarchar', 450, 0),
    (N'dbo', N'AspNetUsers', N'Ad', N'nvarchar', -1, 0),
    (N'dbo', N'AspNetUsers', N'Soyad', N'nvarchar', -1, 0),
    (N'dbo', N'AspNetUsers', N'UserName', N'nvarchar', 256, 1),
    (N'dbo', N'AspNetUsers', N'NormalizedUserName', N'nvarchar', 256, 1),
    (N'dbo', N'AspNetUsers', N'Email', N'nvarchar', 256, 1),
    (N'dbo', N'AspNetUsers', N'NormalizedEmail', N'nvarchar', 256, 1),
    (N'dbo', N'AspNetUsers', N'PasswordHash', N'nvarchar', -1, 1),
    (N'dbo', N'AspNetRoles', N'Id', N'nvarchar', 450, 0),
    (N'dbo', N'AspNetRoleClaims', N'RoleId', N'nvarchar', 450, 0),
    (N'dbo', N'AspNetUserClaims', N'UserId', N'nvarchar', 450, 0),
    (N'dbo', N'AspNetUserLogins', N'LoginProvider', N'nvarchar', 450, 0),
    (N'dbo', N'AspNetUserLogins', N'ProviderKey', N'nvarchar', 450, 0),
    (N'dbo', N'AspNetUserLogins', N'UserId', N'nvarchar', 450, 0),
    (N'dbo', N'AspNetUserRoles', N'UserId', N'nvarchar', 450, 0),
    (N'dbo', N'AspNetUserRoles', N'RoleId', N'nvarchar', 450, 0),
    (N'dbo', N'AspNetUserTokens', N'UserId', N'nvarchar', 450, 0),
    (N'dbo', N'AspNetUserTokens', N'LoginProvider', N'nvarchar', 450, 0),
    (N'dbo', N'AspNetUserTokens', N'Name', N'nvarchar', 450, 0),
    (N'dbo', N'Basvurular', N'Id', N'int', NULL, 0),
    (N'dbo', N'Basvurular', N'VatandasId', N'int', NULL, 1),
    (N'dbo', N'Basvurular', N'BasvuruTarihi', N'datetime2', NULL, 0),
    (N'dbo', N'Basvurular', N'TalepAciklamasi', N'nvarchar', -1, 1),
    (N'dbo', N'Basvurular', N'BasvuranAd', N'nvarchar', -1, 0),
    (N'dbo', N'Basvurular', N'BasvuruAcikAdres', N'nvarchar', -1, 1),
    (N'dbo', N'Basvurular', N'BasvuranDogumTarihi', N'nvarchar', -1, 1),
    (N'dbo', N'Basvurular', N'BasvuranSoyad', N'nvarchar', -1, 0),
    (N'dbo', N'Basvurular', N'BasvuranTcKimlikNo', N'nvarchar', 11, 0),
    (N'dbo', N'Basvurular', N'BasvuranTelefon', N'nvarchar', -1, 0),
    (N'dbo', N'Basvurular', N'HaneFotografYolu', N'nvarchar', -1, 1),
    (N'dbo', N'Basvurular', N'BasvuruDurumuId', N'int', NULL, 0),
    (N'dbo', N'Basvurular', N'YardimTuruId', N'int', NULL, 0),
    (N'dbo', N'Basvurular', N'TalepGelisKanaliId', N'int', NULL, 0),
    (N'dbo', N'Basvurular', N'OlusturanUserId', N'nvarchar', 450, 1),
    (N'dbo', N'Basvurular', N'EngelDurumu', N'bit', NULL, 0),
    (N'dbo', N'Basvurular', N'EngelOrani', N'int', NULL, 1),
    (N'dbo', N'Basvurular', N'EngelTuruId', N'int', NULL, 1),
    (N'dbo', N'Basvurular', N'PublicToken', N'nvarchar', 32, 0),
    (N'dbo', N'Basvurular', N'BasvuranCinsiyet', N'nvarchar', -1, 1),
    (N'dbo', N'Basvurular', N'BasvuranDogumYeri', N'nvarchar', -1, 1),
    (N'dbo', N'Basvurular', N'BasvuranMedeniHal', N'nvarchar', -1, 1),
    (N'dbo', N'Basvurular', N'IlKodu', N'int', NULL, 1),
    (N'dbo', N'Basvurular', N'IlceKodu', N'int', NULL, 1),
    (N'dbo', N'Basvurular', N'MahalleKodu', N'int', NULL, 1),
    (N'dbo', N'Basvurular', N'SokakKodu', N'int', NULL, 1),
    (N'dbo', N'Basvurular', N'AdresNo', N'bigint', NULL, 1),
    (N'dbo', N'BasvuruAileFertleri', N'Id', N'int', NULL, 0),
    (N'dbo', N'BasvuruAileFertleri', N'BasvuruId', N'int', NULL, 0),
    (N'dbo', N'BasvuruAileFertleri', N'AdSoyad', N'nvarchar', -1, 0),
    (N'dbo', N'BasvuruAileFertleri', N'Yas', N'int', NULL, 0),
    (N'dbo', N'BasvuruAileFertleri', N'EngelDurumu', N'bit', NULL, 0),
    (N'dbo', N'BasvuruAileFertleri', N'EngelTuruId', N'int', NULL, 1),
    (N'dbo', N'BasvuruAileFertleri', N'CalismaDurumuId', N'int', NULL, 1),
    (N'dbo', N'BasvuruAileFertleri', N'EgitimDurumuId', N'int', NULL, 1),
    (N'dbo', N'BasvuruAileFertleri', N'YakinlikId', N'int', NULL, 0),
    (N'dbo', N'HaneFotograflari', N'Id', N'int', NULL, 0),
    (N'dbo', N'HaneFotograflari', N'VatandasId', N'int', NULL, 0),
    (N'dbo', N'HaneFotograflari', N'FotografYolu', N'nvarchar', -1, 0),
    (N'dbo', N'HaneFotograflari', N'YuklenmeTarihi', N'datetime2', NULL, 0),
    (N'dbo', N'SahaAktiviteleri', N'Id', N'int', NULL, 0),
    (N'dbo', N'SahaAktiviteleri', N'VatandasId', N'int', NULL, 0),
    (N'dbo', N'SahaAktiviteleri', N'PersonelId', N'nvarchar', 450, 0),
    (N'dbo', N'SahaAktiviteleri', N'Durum', N'nvarchar', -1, 0),
    (N'dbo', N'SahaAktiviteleri', N'OlusturulmaTarihi', N'datetime2', NULL, 0),
    (N'dbo', N'Vatandaslar', N'Id', N'int', NULL, 0),
    (N'dbo', N'Vatandaslar', N'TcKimlikNo', N'nvarchar', 11, 0),
    (N'dbo', N'Vatandaslar', N'Ad', N'nvarchar', -1, 0),
    (N'dbo', N'Vatandaslar', N'Soyad', N'nvarchar', -1, 0),
    (N'dbo', N'Vatandaslar', N'DogumTarihi', N'datetime2', NULL, 0),
    (N'dbo', N'Vatandaslar', N'AcikAdres', N'nvarchar', -1, 0),
    (N'dbo', N'Vatandaslar', N'Telefon1', N'nvarchar', -1, 0),
    (N'dbo', N'Vatandaslar', N'EngelDurumu', N'bit', NULL, 0),
    (N'dbo', N'Vatandaslar', N'MahalleId', N'int', NULL, 0),
    (N'dbo', N'Vatandaslar', N'OlusturanUserId', N'nvarchar', 450, 1),
    (N'dbo', N'BasvuruDurumlari', N'Id', N'int', NULL, 0),
    (N'dbo', N'BasvuruDurumlari', N'Name', N'nvarchar', 100, 0),
    (N'dbo', N'BasvuruDurumlari', N'Sil', N'bit', NULL, 0),
    (N'dbo', N'CalismaDurumlari', N'Name', N'nvarchar', 50, 0),
    (N'dbo', N'CalismaDurumlari', N'Sil', N'bit', NULL, 0),
    (N'dbo', N'EgitimDurumlari', N'Name', N'nvarchar', 50, 0),
    (N'dbo', N'EgitimDurumlari', N'Sil', N'bit', NULL, 0),
    (N'dbo', N'EngelTurleri', N'Name', N'nvarchar', 100, 0),
    (N'dbo', N'EngelTurleri', N'Sil', N'bit', NULL, 0),
    (N'dbo', N'TalepGelisKanallari', N'Name', N'nvarchar', 100, 0),
    (N'dbo', N'TalepGelisKanallari', N'Sil', N'bit', NULL, 0),
    (N'dbo', N'Yakinliklar', N'Name', N'nvarchar', 50, 0),
    (N'dbo', N'Yakinliklar', N'Sil', N'bit', NULL, 0),
    (N'dbo', N'YardimTurleri', N'Name', N'nvarchar', 150, 0),
    (N'dbo', N'YardimTurleri', N'Sil', N'bit', NULL, 0);

DECLARE @ColumnResults TABLE
(
    SchemaName sysname NOT NULL,
    TableName sysname NOT NULL,
    ColumnName sysname NOT NULL,
    ExpectedDefinition nvarchar(160) NOT NULL,
    ActualDefinition nvarchar(160) NULL,
    ResultCode varchar(30) NOT NULL
);

INSERT INTO @ColumnResults
    (SchemaName, TableName, ColumnName, ExpectedDefinition, ActualDefinition, ResultCode)
SELECT
    expected.SchemaName,
    expected.TableName,
    expected.ColumnName,
    CONCAT(
        expected.ExpectedType,
        CASE
            WHEN expected.ExpectedMaxLength = -1 THEN N'(max)'
            WHEN expected.ExpectedMaxLength IS NOT NULL
                THEN CONCAT(N'(', expected.ExpectedMaxLength, N')')
            ELSE N''
        END,
        CASE expected.ExpectedNullable WHEN 1 THEN N' NULL' ELSE N' NOT NULL' END),
    CASE
        WHEN targetColumn.column_id IS NULL THEN NULL
        ELSE CONCAT(
            targetType.name,
            CASE
                WHEN targetType.name IN (N'nvarchar', N'nchar') AND targetColumn.max_length = -1
                    THEN N'(max)'
                WHEN targetType.name IN (N'nvarchar', N'nchar')
                    THEN CONCAT(N'(', targetColumn.max_length / 2, N')')
                WHEN targetType.name IN (N'varchar', N'char', N'varbinary', N'binary')
                    THEN CONCAT(N'(', targetColumn.max_length, N')')
                ELSE N''
            END,
            CASE targetColumn.is_nullable WHEN 1 THEN N' NULL' ELSE N' NOT NULL' END)
    END,
    CASE
        WHEN targetTable.object_id IS NULL THEN 'TABLE_MISSING'
        WHEN targetColumn.column_id IS NULL THEN 'COLUMN_MISSING'
        WHEN targetType.name <> expected.ExpectedType THEN 'TYPE_MISMATCH'
        WHEN expected.ExpectedMaxLength IS NOT NULL
             AND expected.ExpectedMaxLength <>
                 CASE
                     WHEN targetColumn.max_length = -1 THEN -1
                     WHEN targetType.name IN (N'nvarchar', N'nchar')
                         THEN targetColumn.max_length / 2
                     ELSE targetColumn.max_length
                 END THEN 'LENGTH_MISMATCH'
        WHEN targetColumn.is_nullable <> expected.ExpectedNullable THEN 'NULLABILITY_MISMATCH'
        ELSE 'OK'
    END
FROM @ExpectedColumns AS expected
LEFT JOIN sys.schemas AS targetSchema
    ON targetSchema.name = expected.SchemaName
LEFT JOIN sys.tables AS targetTable
    ON targetTable.schema_id = targetSchema.schema_id
   AND targetTable.name = expected.TableName
LEFT JOIN sys.columns AS targetColumn
    ON targetColumn.object_id = targetTable.object_id
   AND targetColumn.name = expected.ColumnName
LEFT JOIN sys.types AS targetType
    ON targetType.user_type_id = targetColumn.user_type_id;

SELECT
    SchemaName,
    TableName,
    ColumnName,
    ExpectedDefinition,
    ActualDefinition,
    ResultCode
FROM @ColumnResults
ORDER BY
    CASE ResultCode WHEN 'OK' THEN 1 ELSE 0 END,
    TableName,
    ColumnName;

DECLARE @ExpectedForeignKeys TABLE
(
    ParentTable sysname NOT NULL,
    ParentColumn sysname NOT NULL,
    ReferencedTable sysname NOT NULL,
    ReferencedColumn sysname NOT NULL,
    PRIMARY KEY (ParentTable, ParentColumn, ReferencedTable, ReferencedColumn)
);

INSERT INTO @ExpectedForeignKeys
    (ParentTable, ParentColumn, ReferencedTable, ReferencedColumn)
VALUES
    (N'Basvurular', N'OlusturanUserId', N'AspNetUsers', N'Id'),
    (N'Basvurular', N'BasvuruDurumuId', N'BasvuruDurumlari', N'Id'),
    (N'Basvurular', N'EngelTuruId', N'EngelTurleri', N'Id'),
    (N'Basvurular', N'TalepGelisKanaliId', N'TalepGelisKanallari', N'Id'),
    (N'Basvurular', N'VatandasId', N'Vatandaslar', N'Id'),
    (N'Basvurular', N'YardimTuruId', N'YardimTurleri', N'Id'),
    (N'BasvuruAileFertleri', N'BasvuruId', N'Basvurular', N'Id'),
    (N'BasvuruAileFertleri', N'CalismaDurumuId', N'CalismaDurumlari', N'Id'),
    (N'BasvuruAileFertleri', N'EgitimDurumuId', N'EgitimDurumlari', N'Id'),
    (N'BasvuruAileFertleri', N'EngelTuruId', N'EngelTurleri', N'Id'),
    (N'BasvuruAileFertleri', N'YakinlikId', N'Yakinliklar', N'Id'),
    (N'HaneFotograflari', N'VatandasId', N'Vatandaslar', N'Id'),
    (N'SahaAktiviteleri', N'PersonelId', N'AspNetUsers', N'Id'),
    (N'SahaAktiviteleri', N'VatandasId', N'Vatandaslar', N'Id');

SELECT
    expected.ParentTable,
    expected.ParentColumn,
    expected.ReferencedTable,
    expected.ReferencedColumn,
    foreignKey.name AS ForeignKeyName,
    foreignKey.is_disabled AS IsDisabled,
    foreignKey.is_not_trusted AS IsNotTrusted,
    CASE
        WHEN foreignKey.object_id IS NULL THEN 'MISSING'
        WHEN foreignKey.is_disabled = 1 THEN 'DISABLED'
        WHEN foreignKey.is_not_trusted = 1 THEN 'NOT_TRUSTED'
        ELSE 'OK'
    END AS ResultCode
FROM @ExpectedForeignKeys AS expected
LEFT JOIN sys.tables AS parentTable
    ON parentTable.schema_id = SCHEMA_ID(N'dbo')
   AND parentTable.name = expected.ParentTable
LEFT JOIN sys.columns AS parentColumn
    ON parentColumn.object_id = parentTable.object_id
   AND parentColumn.name = expected.ParentColumn
LEFT JOIN sys.tables AS referencedTable
    ON referencedTable.schema_id = SCHEMA_ID(N'dbo')
   AND referencedTable.name = expected.ReferencedTable
LEFT JOIN sys.columns AS referencedColumn
    ON referencedColumn.object_id = referencedTable.object_id
   AND referencedColumn.name = expected.ReferencedColumn
LEFT JOIN sys.foreign_key_columns AS link
    ON link.parent_object_id = parentTable.object_id
   AND link.parent_column_id = parentColumn.column_id
   AND link.referenced_object_id = referencedTable.object_id
   AND link.referenced_column_id = referencedColumn.column_id
LEFT JOIN sys.foreign_keys AS foreignKey
    ON foreignKey.object_id = link.constraint_object_id
ORDER BY
    CASE WHEN foreignKey.object_id IS NULL THEN 0 ELSE 1 END,
    expected.ParentTable,
    expected.ParentColumn;

-- Önceden oluşturulmuş sosyobel nesneleri varsa migration planı bunları ezmemelidir.
SELECT
    targetSchema.name AS SchemaName,
    target.name AS ObjectName,
    N'TABLE' AS ObjectType
FROM sys.tables AS target
INNER JOIN sys.schemas AS targetSchema
    ON targetSchema.schema_id = target.schema_id
WHERE targetSchema.name = N'sosyobel'
UNION ALL
SELECT
    targetSchema.name,
    target.name,
    N'SEQUENCE'
FROM sys.sequences AS target
INNER JOIN sys.schemas AS targetSchema
    ON targetSchema.schema_id = target.schema_id
WHERE targetSchema.name = N'sosyobel'
ORDER BY ObjectType, ObjectName;

SELECT
    (SELECT COUNT(*) FROM @TableResults WHERE ResultCode = 'MISSING') AS MissingTableCount,
    (SELECT COUNT(*) FROM @TableResults WHERE RequiredForMobile = 1 AND ResultCode = 'MISSING')
        AS MissingMobileTableCount,
    (SELECT COUNT(*) FROM @ColumnResults WHERE ResultCode <> 'OK')
        AS MismatchedCriticalColumnCount,
    CASE
        WHEN EXISTS
        (
            SELECT 1
            FROM @TableResults
            WHERE RequiredForMobile = 1
              AND ResultCode = 'MISSING'
        ) THEN N'BLOCKED: Mobil için gerekli şirket tabloları eksik.'
        WHEN EXISTS
        (
            SELECT 1
            FROM @ColumnResults
            WHERE ResultCode <> 'OK'
        ) THEN N'REVIEW: Kritik kolon farklılıkları incelenmeli.'
        ELSE N'BASELINE_OK: Paylaşılan kritik şema şekliyle uyumlu.'
    END AS OverallResult;
