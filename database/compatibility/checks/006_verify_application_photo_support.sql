/*
    Uyumluluk migration 006 icin salt-okunur kolon, indeks ve iliski kontrolu.
*/

SET NOCOUNT ON;

IF OBJECT_ID(N'sosyobel.BasvuruFotograflari', N'U') IS NULL
BEGIN
    THROW 51342, N'Uyumluluk 006 fotograf metadata tablosu bulunamadi.', 1;
END;

DECLARE @ExpectedColumns TABLE
(
    ColumnName sysname NOT NULL PRIMARY KEY,
    TypeName sysname NOT NULL,
    MaxLengthBytes smallint NULL,
    IsNullable bit NOT NULL
);

INSERT INTO @ExpectedColumns
    (ColumnName, TypeName, MaxLengthBytes, IsNullable)
VALUES
    (N'Id', N'int', NULL, 0),
    (N'BasvuruId', N'int', NULL, 0),
    (N'StorageKey', N'nvarchar', 1000, 0),
    (N'OrijinalDosyaAdi', N'nvarchar', 510, 1),
    (N'MimeType', N'varchar', 100, 0),
    (N'BoyutByte', N'bigint', NULL, 0),
    (N'Sha256', N'binary', 32, 0),
    (N'SiraNo', N'tinyint', NULL, 0),
    (N'TaramaDurumuKodu', N'nvarchar', 60, 0),
    (N'ExifTemizlendiMi', N'bit', NULL, 0),
    (N'SilindiMi', N'bit', NULL, 0),
    (N'OlusturanUserId', N'nvarchar', 900, 0),
    (N'OlusturulmaTarihiUtc', N'datetime2', NULL, 0),
    (N'SilenUserId', N'nvarchar', 900, 1),
    (N'SilinmeTarihiUtc', N'datetime2', NULL, 1),
    (N'RowVersion', N'timestamp', NULL, 0);

IF EXISTS
(
    SELECT 1
    FROM @ExpectedColumns AS expected
    LEFT JOIN sys.columns AS targetColumn
        ON targetColumn.object_id = OBJECT_ID(N'sosyobel.BasvuruFotograflari')
       AND targetColumn.name = expected.ColumnName
    LEFT JOIN sys.types AS targetType
        ON targetType.user_type_id = targetColumn.user_type_id
    WHERE targetColumn.column_id IS NULL
       OR targetType.name <> expected.TypeName
       OR
       (
           expected.MaxLengthBytes IS NOT NULL AND
           targetColumn.max_length <> expected.MaxLengthBytes
       )
       OR targetColumn.is_nullable <> expected.IsNullable
)
BEGIN
    THROW 51343, N'Uyumluluk 006 kolonlarindan biri beklenen sekilde degildir.', 1;
END;

DECLARE @RequiredIndexes TABLE
(
    IndexName sysname NOT NULL PRIMARY KEY,
    MustBeUnique bit NOT NULL
);

INSERT INTO @RequiredIndexes (IndexName, MustBeUnique)
VALUES
    (N'UX_BasvuruFotograflari_AktifSira', 1),
    (N'UX_BasvuruFotograflari_AktifStorageKey', 1),
    (N'IX_BasvuruFotograflari_BasvuruId', 0);

IF EXISTS
(
    SELECT 1
    FROM @RequiredIndexes AS requiredIndex
    LEFT JOIN sys.indexes AS targetIndex
        ON targetIndex.object_id = OBJECT_ID(N'sosyobel.BasvuruFotograflari')
       AND targetIndex.name = requiredIndex.IndexName
    WHERE targetIndex.index_id IS NULL
       OR targetIndex.is_disabled = 1
       OR targetIndex.is_unique <> requiredIndex.MustBeUnique
)
BEGIN
    THROW 51344, N'Uyumluluk 006 indekslerinden biri eksik veya gecersiz.', 1;
END;

DECLARE @RequiredForeignKeys TABLE
(
    ConstraintName sysname NOT NULL PRIMARY KEY
);

INSERT INTO @RequiredForeignKeys (ConstraintName)
VALUES
    (N'FK_BasvuruFotograflari_Basvurular'),
    (N'FK_BasvuruFotograflari_OlusturanUser'),
    (N'FK_BasvuruFotograflari_SilenUser');

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
    THROW 51345, N'Uyumluluk 006 foreign key kurallarindan biri eksik.', 1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.foreign_keys
    WHERE parent_object_id = OBJECT_ID(N'sosyobel.BasvuruFotograflari')
      AND name = N'FK_BasvuruFotograflari_Basvurular'
      AND delete_referential_action = 1
)
BEGIN
    THROW 51346, N'Basvuru silme davranisi fotograf metadata tablosuna aktarilmiyor.', 1;
END;

DECLARE @RequiredChecks TABLE
(
    ConstraintName sysname NOT NULL PRIMARY KEY
);

INSERT INTO @RequiredChecks (ConstraintName)
VALUES
    (N'CK_BasvuruFotograflari_SiraNo'),
    (N'CK_BasvuruFotograflari_Boyut'),
    (N'CK_BasvuruFotograflari_MimeType'),
    (N'CK_BasvuruFotograflari_TaramaDurumu'),
    (N'CK_BasvuruFotograflari_SilmeBilgisi');

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
    THROW 51347, N'Uyumluluk 006 check kurallarindan biri eksik.', 1;
END;

SELECT
    (SELECT COUNT_BIG(*) FROM sosyobel.BasvuruFotograflari)
        AS FotografMetadataSayisi,
    N'COMPATIBILITY_APPLICATION_PHOTO_OK' AS ResultCode;
