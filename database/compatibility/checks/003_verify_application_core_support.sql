/*
    Uyumluluk migration 003 için salt-okunur yapı doğrulaması.
*/

SET NOCOUNT ON;

IF OBJECT_ID(N'sosyobel.BasvuruDurumGecmisi', N'U') IS NULL
BEGIN
    THROW 51272, N'BasvuruDurumGecmisi tablosu bulunamadı.', 1;
END;

DECLARE @ExpectedColumns TABLE
(
    ColumnName sysname NOT NULL PRIMARY KEY,
    TypeName sysname NOT NULL,
    MaxLengthBytes smallint NULL,
    IsNullable bit NOT NULL
);

INSERT INTO @ExpectedColumns (ColumnName, TypeName, MaxLengthBytes, IsNullable)
VALUES
    (N'Id', N'bigint', NULL, 0),
    (N'BasvuruId', N'int', NULL, 0),
    (N'OncekiDurumId', N'int', NULL, 1),
    (N'YeniDurumId', N'int', NULL, 0),
    (N'Aciklama', N'nvarchar', 2000, 1),
    (N'OlusturanUserId', N'nvarchar', 900, 0),
    (N'OlusturulmaTarihiUtc', N'datetime2', NULL, 0);

IF EXISTS
(
    SELECT 1
    FROM @ExpectedColumns AS expected
    LEFT JOIN sys.columns AS targetColumn
        ON targetColumn.object_id =
            OBJECT_ID(N'sosyobel.BasvuruDurumGecmisi')
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
    THROW 51273, N'Uyumluluk 003 kolonlarından biri beklenen şekilde değildir.', 1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'sosyobel.BasvuruDurumGecmisi')
      AND name = N'IX_BasvuruDurumGecmisi_Basvuru_Tarih'
      AND is_disabled = 0
)
BEGIN
    THROW 51274, N'Uyumluluk 003 başvuru/tarih indeksi eksik.', 1;
END;

DECLARE @RequiredForeignKeys TABLE (ConstraintName sysname NOT NULL PRIMARY KEY);

INSERT INTO @RequiredForeignKeys (ConstraintName)
VALUES
    (N'FK_BasvuruDurumGecmisi_Basvurular'),
    (N'FK_BasvuruDurumGecmisi_OncekiDurum'),
    (N'FK_BasvuruDurumGecmisi_YeniDurum'),
    (N'FK_BasvuruDurumGecmisi_OlusturanUser');

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
    THROW 51275, N'Uyumluluk 003 foreign key kurallarından biri eksik.', 1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.triggers
    WHERE parent_id = OBJECT_ID(N'sosyobel.BasvuruDurumGecmisi')
      AND name = N'TR_BasvuruDurumGecmisi_AppendOnly'
      AND is_disabled = 0
)
BEGIN
    THROW 51276, N'Uyumluluk 003 append-only tetikleyicisi eksik.', 1;
END;

SELECT N'COMPATIBILITY_APPLICATION_CORE_OK' AS ResultCode;
