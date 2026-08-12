/*
    Uyumluluk migration 001 için salt-okunur doğrulama.

    Tablo/kolon şekillerini, benzersiz indeksleri, güvenilir foreign key ve check
    constraint'lerini doğrular. Kaynak iş tablolarına veri yazmaz.
*/

SET NOCOUNT ON;

IF OBJECT_ID(N'sosyobel.BasvuruUygulamaBilgileri', N'U') IS NULL OR
   OBJECT_ID(N'sosyobel.ReferansKodlari', N'U') IS NULL OR
   OBJECT_ID(N'sosyobel.KullaniciUygulamaBilgileri', N'U') IS NULL
BEGIN
    THROW 51220, N'Uyumluluk 001 tablolarından biri eksik.', 1;
END;

DECLARE @ExpectedColumns TABLE
(
    TableName sysname NOT NULL,
    ColumnName sysname NOT NULL,
    TypeName sysname NOT NULL,
    MaxLengthBytes smallint NULL,
    IsNullable bit NOT NULL,
    PRIMARY KEY (TableName, ColumnName)
);

INSERT INTO @ExpectedColumns
    (TableName, ColumnName, TypeName, MaxLengthBytes, IsNullable)
VALUES
    (N'BasvuruUygulamaBilgileri', N'BasvuruId', N'int', NULL, 0),
    (N'BasvuruUygulamaBilgileri', N'PublicId', N'uniqueidentifier', NULL, 0),
    (N'BasvuruUygulamaBilgileri', N'BasvuruNo', N'nvarchar', 80, 1),
    (N'BasvuruUygulamaBilgileri', N'SahaIncelemeNotu', N'nvarchar', 4000, 1),
    (N'BasvuruUygulamaBilgileri', N'GuncelleyenUserId', N'nvarchar', 900, 1),
    (N'BasvuruUygulamaBilgileri', N'GuncellenmeTarihiUtc', N'datetime2', NULL, 1),
    (N'BasvuruUygulamaBilgileri', N'KurulaGonderenUserId', N'nvarchar', 900, 1),
    (N'BasvuruUygulamaBilgileri', N'KurulaGonderilmeTarihiUtc', N'datetime2', NULL, 1),
    (N'BasvuruUygulamaBilgileri', N'OlusturulmaTarihiUtc', N'datetime2', NULL, 0),
    (N'ReferansKodlari', N'Id', N'int', NULL, 0),
    (N'ReferansKodlari', N'ReferansTuruKodu', N'nvarchar', 100, 0),
    (N'ReferansKodlari', N'KaynakId', N'int', NULL, 0),
    (N'ReferansKodlari', N'Kod', N'nvarchar', 160, 0),
    (N'ReferansKodlari', N'OlusturulmaTarihiUtc', N'datetime2', NULL, 0),
    (N'ReferansKodlari', N'GuncellenmeTarihiUtc', N'datetime2', NULL, 1),
    (N'KullaniciUygulamaBilgileri', N'UserId', N'nvarchar', 900, 0),
    (N'KullaniciUygulamaBilgileri', N'AktifMi', N'bit', NULL, 0),
    (N'KullaniciUygulamaBilgileri', N'OlusturanUserId', N'nvarchar', 900, 1),
    (N'KullaniciUygulamaBilgileri', N'OlusturulmaTarihiUtc', N'datetime2', NULL, 0),
    (N'KullaniciUygulamaBilgileri', N'GuncelleyenUserId', N'nvarchar', 900, 1),
    (N'KullaniciUygulamaBilgileri', N'GuncellenmeTarihiUtc', N'datetime2', NULL, 1),
    (N'KullaniciUygulamaBilgileri', N'DevreDisiBirakanUserId', N'nvarchar', 900, 1),
    (N'KullaniciUygulamaBilgileri', N'DevreDisiTarihiUtc', N'datetime2', NULL, 1),
    (N'KullaniciUygulamaBilgileri', N'DevreDisiGerekce', N'nvarchar', 2000, 1);

DECLARE @ColumnErrors TABLE
(
    TableName sysname NOT NULL,
    ColumnName sysname NOT NULL,
    ErrorCode varchar(30) NOT NULL
);

INSERT INTO @ColumnErrors (TableName, ColumnName, ErrorCode)
SELECT
    expected.TableName,
    expected.ColumnName,
    CASE
        WHEN targetColumn.column_id IS NULL THEN 'COLUMN_MISSING'
        WHEN targetType.name <> expected.TypeName THEN 'TYPE_MISMATCH'
        WHEN expected.MaxLengthBytes IS NOT NULL
             AND targetColumn.max_length <> expected.MaxLengthBytes THEN 'LENGTH_MISMATCH'
        WHEN targetColumn.is_nullable <> expected.IsNullable THEN 'NULLABILITY_MISMATCH'
        ELSE 'UNKNOWN'
    END
FROM @ExpectedColumns AS expected
LEFT JOIN sys.tables AS targetTable
    ON targetTable.schema_id = SCHEMA_ID(N'sosyobel')
   AND targetTable.name = expected.TableName
LEFT JOIN sys.columns AS targetColumn
    ON targetColumn.object_id = targetTable.object_id
   AND targetColumn.name = expected.ColumnName
LEFT JOIN sys.types AS targetType
    ON targetType.user_type_id = targetColumn.user_type_id
WHERE targetColumn.column_id IS NULL
   OR targetType.name <> expected.TypeName
   OR (expected.MaxLengthBytes IS NOT NULL
       AND targetColumn.max_length <> expected.MaxLengthBytes)
   OR targetColumn.is_nullable <> expected.IsNullable;

-- rowversion, SQL Server kataloglarında timestamp sistem tipiyle gösterilir.
INSERT INTO @ColumnErrors (TableName, ColumnName, ErrorCode)
SELECT requiredRowVersion.TableName, N'RowVersion', 'ROWVERSION_MISSING'
FROM
(
    VALUES
        (N'BasvuruUygulamaBilgileri'),
        (N'ReferansKodlari'),
        (N'KullaniciUygulamaBilgileri')
) AS requiredRowVersion(TableName)
WHERE NOT EXISTS
(
    SELECT 1
    FROM sys.tables AS targetTable
    INNER JOIN sys.columns AS targetColumn
        ON targetColumn.object_id = targetTable.object_id
    WHERE targetTable.schema_id = SCHEMA_ID(N'sosyobel')
      AND targetTable.name = requiredRowVersion.TableName
      AND targetColumn.name = N'RowVersion'
      AND targetColumn.system_type_id = 189
      AND targetColumn.is_nullable = 0
);

IF EXISTS (SELECT 1 FROM @ColumnErrors)
BEGIN
    SELECT TableName, ColumnName, ErrorCode
    FROM @ColumnErrors
    ORDER BY TableName, ColumnName;

    THROW 51221, N'Uyumluluk 001 kritik kolonlarından biri beklenen şekilde değildir.', 1;
END;

DECLARE @RequiredIndexes TABLE
(
    TableName sysname NOT NULL,
    IndexName sysname NOT NULL,
    MustBeUnique bit NOT NULL,
    PRIMARY KEY (TableName, IndexName)
);

INSERT INTO @RequiredIndexes (TableName, IndexName, MustBeUnique)
VALUES
    (N'BasvuruUygulamaBilgileri', N'UQ_BasvuruUygulamaBilgileri_PublicId', 1),
    (N'BasvuruUygulamaBilgileri', N'UX_BasvuruUygulamaBilgileri_BasvuruNo', 1),
    (N'ReferansKodlari', N'UQ_ReferansKodlari_Tur_Kaynak', 1),
    (N'ReferansKodlari', N'UQ_ReferansKodlari_Tur_Kod', 1);

IF EXISTS
(
    SELECT 1
    FROM @RequiredIndexes AS requiredIndex
    LEFT JOIN sys.tables AS targetTable
        ON targetTable.schema_id = SCHEMA_ID(N'sosyobel')
       AND targetTable.name = requiredIndex.TableName
    LEFT JOIN sys.indexes AS targetIndex
        ON targetIndex.object_id = targetTable.object_id
       AND targetIndex.name = requiredIndex.IndexName
    WHERE targetIndex.index_id IS NULL
       OR (requiredIndex.MustBeUnique = 1 AND targetIndex.is_unique = 0)
       OR targetIndex.is_disabled = 1
)
BEGIN
    THROW 51222, N'Uyumluluk 001 benzersiz indekslerinden biri eksik veya devre dışıdır.', 1;
END;

DECLARE @RequiredForeignKeys TABLE
(
    ConstraintName sysname NOT NULL PRIMARY KEY
);

INSERT INTO @RequiredForeignKeys (ConstraintName)
VALUES
    (N'FK_BasvuruUygulamaBilgileri_Basvurular'),
    (N'FK_BasvuruUygulamaBilgileri_GuncelleyenUser'),
    (N'FK_BasvuruUygulamaBilgileri_KurulaGonderenUser'),
    (N'FK_KullaniciUygulamaBilgileri_User'),
    (N'FK_KullaniciUygulamaBilgileri_OlusturanUser'),
    (N'FK_KullaniciUygulamaBilgileri_GuncelleyenUser'),
    (N'FK_KullaniciUygulamaBilgileri_DevreDisiBirakanUser');

IF EXISTS
(
    SELECT 1
    FROM @RequiredForeignKeys AS requiredForeignKey
    LEFT JOIN sys.foreign_keys AS targetForeignKey
        ON targetForeignKey.schema_id = SCHEMA_ID(N'sosyobel')
       AND targetForeignKey.name = requiredForeignKey.ConstraintName
    WHERE targetForeignKey.object_id IS NULL
       OR targetForeignKey.is_disabled = 1
       OR targetForeignKey.is_not_trusted = 1
)
BEGIN
    THROW 51223, N'Uyumluluk 001 foreign key kurallarından biri eksik veya güvenilir değildir.', 1;
END;

DECLARE @RequiredChecks TABLE
(
    ConstraintName sysname NOT NULL PRIMARY KEY
);

INSERT INTO @RequiredChecks (ConstraintName)
VALUES
    (N'CK_BasvuruUygulamaBilgileri_BasvuruNo'),
    (N'CK_BasvuruUygulamaBilgileri_Guncelleme'),
    (N'CK_BasvuruUygulamaBilgileri_KurulaGonderim'),
    (N'CK_ReferansKodlari_Tur'),
    (N'CK_ReferansKodlari_KaynakId'),
    (N'CK_ReferansKodlari_Kod'),
    (N'CK_KullaniciUygulamaBilgileri_Guncelleme'),
    (N'CK_KullaniciUygulamaBilgileri_DevreDisiBilgisi');

IF EXISTS
(
    SELECT 1
    FROM @RequiredChecks AS requiredCheck
    LEFT JOIN sys.check_constraints AS targetCheck
        ON targetCheck.schema_id = SCHEMA_ID(N'sosyobel')
       AND targetCheck.name = requiredCheck.ConstraintName
    WHERE targetCheck.object_id IS NULL
       OR targetCheck.is_disabled = 1
       OR targetCheck.is_not_trusted = 1
)
BEGIN
    THROW 51224, N'Uyumluluk 001 check constraint kurallarından biri eksik veya güvenilir değildir.', 1;
END;

-- ReferansKodlari polimorfik bir eşlemedir. Her türün KaynakId değeri ilgili
-- şirket lookup tablosunda gerçekten bulunmalıdır.
IF EXISTS
(
    SELECT 1
    FROM sosyobel.ReferansKodlari AS mapping
    WHERE
        (mapping.ReferansTuruKodu = N'BASVURU_DURUMU' AND
         NOT EXISTS (SELECT 1 FROM dbo.BasvuruDurumlari WHERE Id = mapping.KaynakId)) OR
        (mapping.ReferansTuruKodu = N'CALISMA_DURUMU' AND
         NOT EXISTS (SELECT 1 FROM dbo.CalismaDurumlari WHERE Id = mapping.KaynakId)) OR
        (mapping.ReferansTuruKodu = N'EGITIM_DURUMU' AND
         NOT EXISTS (SELECT 1 FROM dbo.EgitimDurumlari WHERE Id = mapping.KaynakId)) OR
        (mapping.ReferansTuruKodu = N'ENGEL_TURU' AND
         NOT EXISTS (SELECT 1 FROM dbo.EngelTurleri WHERE Id = mapping.KaynakId)) OR
        (mapping.ReferansTuruKodu = N'TALEP_GELIS_KANALI' AND
         NOT EXISTS (SELECT 1 FROM dbo.TalepGelisKanallari WHERE Id = mapping.KaynakId)) OR
        (mapping.ReferansTuruKodu = N'YAKINLIK' AND
         NOT EXISTS (SELECT 1 FROM dbo.Yakinliklar WHERE Id = mapping.KaynakId)) OR
        (mapping.ReferansTuruKodu = N'YARDIM_TURU' AND
         NOT EXISTS (SELECT 1 FROM dbo.YardimTurleri WHERE Id = mapping.KaynakId))
)
BEGIN
    THROW 51225, N'Kaynak lookup satırı bulunmayan bir referans kodu eşlemesi var.', 1;
END;

SELECT
    (SELECT COUNT_BIG(*) FROM sosyobel.BasvuruUygulamaBilgileri)
        AS BasvuruUygulamaBilgisiSayisi,
    (SELECT COUNT_BIG(*) FROM sosyobel.ReferansKodlari)
        AS ReferansKoduSayisi,
    (SELECT COUNT_BIG(*) FROM sosyobel.KullaniciUygulamaBilgileri)
        AS KullaniciUygulamaBilgisiSayisi,
    N'COMPATIBILITY_FOUNDATION_OK' AS ResultCode;
