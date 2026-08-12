/*
    Uyumluluk migration 004 icin salt-okunur yapi ve referans dogrulamasi.
*/

SET NOCOUNT ON;

IF OBJECT_ID(N'sosyobel.YasamDurumlari', N'U') IS NULL OR
   OBJECT_ID(N'sosyobel.BasvuruAileFertiUygulamaBilgileri', N'U') IS NULL
BEGIN
    THROW 51303, N'Uyumluluk 004 teknik tablolarindan biri bulunamadi.', 1;
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
    (N'YasamDurumlari', N'Id', N'int', NULL, 0),
    (N'YasamDurumlari', N'Kod', N'nvarchar', 100, 0),
    (N'YasamDurumlari', N'Ad', N'nvarchar', 200, 0),
    (N'YasamDurumlari', N'AktifMi', N'bit', NULL, 0),
    (N'YasamDurumlari', N'SiraNo', N'smallint', NULL, 0),
    (N'BasvuruAileFertiUygulamaBilgileri', N'BasvuruAileFertiId', N'int', NULL, 0),
    (N'BasvuruAileFertiUygulamaBilgileri', N'YakinlikDigerAciklama', N'nvarchar', 200, 1),
    (N'BasvuruAileFertiUygulamaBilgileri', N'EngelAciklamasi', N'nvarchar', 500, 1),
    (N'BasvuruAileFertiUygulamaBilgileri', N'YasamDurumuId', N'int', NULL, 0),
    (N'BasvuruAileFertiUygulamaBilgileri', N'OlusturanUserId', N'nvarchar', 900, 0),
    (N'BasvuruAileFertiUygulamaBilgileri', N'OlusturulmaTarihiUtc', N'datetime2', NULL, 0),
    (N'BasvuruAileFertiUygulamaBilgileri', N'RowVersion', N'timestamp', NULL, 0);

IF EXISTS
(
    SELECT 1
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
       OR
       (
           expected.MaxLengthBytes IS NOT NULL AND
           targetColumn.max_length <> expected.MaxLengthBytes
       )
       OR targetColumn.is_nullable <> expected.IsNullable
)
BEGIN
    THROW 51304, N'Uyumluluk 004 kolonlarindan biri beklenen sekilde degildir.', 1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'sosyobel.YasamDurumlari')
      AND name = N'UX_YasamDurumlari_Kod'
      AND is_unique = 1
      AND is_disabled = 0
)
BEGIN
    THROW 51305, N'Yasam durumu kodu benzersiz indeksi eksik.', 1;
END;

DECLARE @RequiredForeignKeys TABLE
(
    ConstraintName sysname NOT NULL PRIMARY KEY
);

INSERT INTO @RequiredForeignKeys (ConstraintName)
VALUES
    (N'FK_BasvuruAileFertiUygulama_AileFerti'),
    (N'FK_BasvuruAileFertiUygulama_YasamDurumu'),
    (N'FK_BasvuruAileFertiUygulama_OlusturanUser');

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
    THROW 51306, N'Uyumluluk 004 foreign key kurallarindan biri eksik.', 1;
END;

IF
(
    SELECT COUNT(*)
    FROM sosyobel.YasamDurumlari
    WHERE Kod IN (N'SAG', N'OLU')
      AND AktifMi = 1
) <> 2
BEGIN
    THROW 51307, N'SAG ve OLU yasam durumu kodlari aktif degildir.', 1;
END;

SELECT N'COMPATIBILITY_APPLICATION_FAMILY_OK' AS ResultCode;
