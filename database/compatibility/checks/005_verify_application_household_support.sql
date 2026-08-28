/*
    Uyumluluk migration 005 icin salt-okunur yapi, iliski ve referans kontrolu.
*/

SET NOCOUNT ON;

IF OBJECT_ID(N'sosyobel.HaneSorulari', N'U') IS NULL OR
   OBJECT_ID(N'sosyobel.HaneSoruSecenekleri', N'U') IS NULL OR
   OBJECT_ID(N'sosyobel.BasvuruHaneCevaplari', N'U') IS NULL
BEGIN
    THROW 51323, N'Uyumluluk 005 hane tablolarindan biri bulunamadi.', 1;
END;

DECLARE @ExpectedColumns TABLE
(
    TableName sysname NOT NULL,
    ColumnName sysname NOT NULL,
    TypeName sysname NOT NULL,
    MaxLengthBytes smallint NULL,
    IsNullable bit NOT NULL,
    NumericPrecision tinyint NULL,
    NumericScale tinyint NULL,
    PRIMARY KEY (TableName, ColumnName)
);

INSERT INTO @ExpectedColumns
    (TableName, ColumnName, TypeName, MaxLengthBytes, IsNullable, NumericPrecision, NumericScale)
VALUES
    (N'HaneSorulari', N'Id', N'int', NULL, 0, NULL, NULL),
    (N'HaneSorulari', N'Kod', N'nvarchar', 160, 0, NULL, NULL),
    (N'HaneSorulari', N'SoruMetni', N'nvarchar', 600, 0, NULL, NULL),
    (N'HaneSorulari', N'CevapTipi', N'nvarchar', 60, 0, NULL, NULL),
    (N'HaneSorulari', N'ZorunluMu', N'bit', NULL, 0, NULL, NULL),
    (N'HaneSorulari', N'Sira', N'smallint', NULL, 0, NULL, NULL),
    (N'HaneSorulari', N'AktifMi', N'bit', NULL, 0, NULL, NULL),
    (N'HaneSoruSecenekleri', N'Id', N'int', NULL, 0, NULL, NULL),
    (N'HaneSoruSecenekleri', N'SoruId', N'int', NULL, 0, NULL, NULL),
    (N'HaneSoruSecenekleri', N'Kod', N'nvarchar', 160, 0, NULL, NULL),
    (N'HaneSoruSecenekleri', N'Etiket', N'nvarchar', 400, 0, NULL, NULL),
    (N'HaneSoruSecenekleri', N'Sira', N'smallint', NULL, 0, NULL, NULL),
    (N'HaneSoruSecenekleri', N'AktifMi', N'bit', NULL, 0, NULL, NULL),
    (N'BasvuruHaneCevaplari', N'Id', N'int', NULL, 0, NULL, NULL),
    (N'BasvuruHaneCevaplari', N'BasvuruId', N'int', NULL, 0, NULL, NULL),
    (N'BasvuruHaneCevaplari', N'SoruId', N'int', NULL, 0, NULL, NULL),
    (N'BasvuruHaneCevaplari', N'SecenekId', N'int', NULL, 1, NULL, NULL),
    (N'BasvuruHaneCevaplari', N'SerbestMetinCevap', N'nvarchar', 2000, 1, NULL, NULL),
    (N'BasvuruHaneCevaplari', N'SayisalCevap', N'decimal', NULL, 1, 18, 2),
    (N'BasvuruHaneCevaplari', N'OlusturanUserId', N'nvarchar', 900, 0, NULL, NULL),
    (N'BasvuruHaneCevaplari', N'OlusturulmaTarihiUtc', N'datetime2', NULL, 0, NULL, NULL),
    (N'BasvuruHaneCevaplari', N'GuncellenmeTarihiUtc', N'datetime2', NULL, 1, NULL, NULL),
    (N'BasvuruHaneCevaplari', N'RowVersion', N'timestamp', NULL, 0, NULL, NULL);

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
       OR
       (
           expected.NumericPrecision IS NOT NULL AND
           targetColumn.precision <> expected.NumericPrecision
       )
       OR
       (
           expected.NumericScale IS NOT NULL AND
           targetColumn.scale <> expected.NumericScale
       )
)
BEGIN
    THROW 51324, N'Uyumluluk 005 kolonlarindan biri beklenen sekilde degildir.', 1;
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
    (N'HaneSorulari', N'UQ_HaneSorulari_Kod', 1),
    (N'HaneSoruSecenekleri', N'UQ_HaneSoruSecenekleri_Soru_Kod', 1),
    (N'BasvuruHaneCevaplari', N'UQ_BasvuruHaneCevaplari_Basvuru_Soru', 1),
    (N'BasvuruHaneCevaplari', N'IX_BasvuruHaneCevaplari_SoruId', 0);

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
       OR targetIndex.is_disabled = 1
       OR targetIndex.is_unique <> requiredIndex.MustBeUnique
)
BEGIN
    THROW 51325, N'Uyumluluk 005 indekslerinden biri eksik veya gecersiz.', 1;
END;

DECLARE @RequiredForeignKeys TABLE
(
    ConstraintName sysname NOT NULL PRIMARY KEY
);

INSERT INTO @RequiredForeignKeys (ConstraintName)
VALUES
    (N'FK_HaneSoruSecenekleri_HaneSorulari'),
    (N'FK_BasvuruHaneCevaplari_Basvurular'),
    (N'FK_BasvuruHaneCevaplari_HaneSorulari'),
    (N'FK_BasvuruHaneCevaplari_Secenek'),
    (N'FK_BasvuruHaneCevaplari_OlusturanUser');

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
    THROW 51326, N'Uyumluluk 005 foreign key kurallarindan biri eksik.', 1;
END;

DECLARE @ExpectedOptions TABLE
(
    SoruKodu nvarchar(80) NOT NULL,
    SecenekKodu nvarchar(80) NOT NULL,
    PRIMARY KEY (SoruKodu, SecenekKodu)
);

INSERT INTO @ExpectedOptions (SoruKodu, SecenekKodu)
VALUES
    (N'MULKIYET_DURUMU', N'EV_SAHIBI'),
    (N'MULKIYET_DURUMU', N'KIRACI'),
    (N'MULKIYET_DURUMU', N'LOJMAN'),
    (N'MULKIYET_DURUMU', N'DIGER'),
    (N'MULK_TIPI', N'APARTMAN_DAIRESI'),
    (N'MULK_TIPI', N'MUSTAKIL_EV'),
    (N'MULK_TIPI', N'GECEKONDU'),
    (N'MULK_TIPI', N'DIGER'),
    (N'EV_TEMIZLIGI', N'EVET'),
    (N'EV_TEMIZLIGI', N'HAYIR'),
    (N'BARINMA_DURUMU', N'IYI'),
    (N'BARINMA_DURUMU', N'ORTA'),
    (N'BARINMA_DURUMU', N'KOTU'),
    (N'EV_ESYALARI', N'YETERLI'),
    (N'EV_ESYALARI', N'KISMEN_YETERLI'),
    (N'EV_ESYALARI', N'YETERSIZ');

IF EXISTS
(
    SELECT 1
    FROM @ExpectedOptions AS expected
    LEFT JOIN sosyobel.HaneSorulari AS question
        ON question.Kod = expected.SoruKodu
       AND question.CevapTipi = N'TEK_SECIM'
       AND question.AktifMi = 1
    LEFT JOIN sosyobel.HaneSoruSecenekleri AS optionValue
        ON optionValue.SoruId = question.Id
       AND optionValue.Kod = expected.SecenekKodu
       AND optionValue.AktifMi = 1
    WHERE question.Id IS NULL OR optionValue.Id IS NULL
)
BEGIN
    THROW 51327, N'Uyumluluk 005 zorunlu hane soru veya secenek kodlarindan biri eksik.', 1;
END;

SELECT
    (SELECT COUNT_BIG(*) FROM sosyobel.HaneSorulari)
        AS SoruSayisi,
    (SELECT COUNT_BIG(*) FROM sosyobel.HaneSoruSecenekleri)
        AS SecenekSayisi,
    N'COMPATIBILITY_APPLICATION_HOUSEHOLD_OK' AS ResultCode;
