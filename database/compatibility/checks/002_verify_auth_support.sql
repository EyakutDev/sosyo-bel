/*
    Uyumluluk migration 002 için salt-okunur doğrulama.

    Auth destek tablolarının kritik kolon, indeks, foreign key, check constraint
    ve append-only trigger şekillerini denetler.
*/

SET NOCOUNT ON;

DECLARE @RequiredTables TABLE
(
    TableName sysname NOT NULL PRIMARY KEY
);

INSERT INTO @RequiredTables (TableName)
VALUES
    (N'Belediyeler'),
    (N'KullaniciBelediyeleri'),
    (N'KullaniciYetkileri'),
    (N'IslemGecmisleri'),
    (N'IdempotencyKayitlari'),
    (N'YenilemeTokenlari');

IF EXISTS
(
    SELECT 1
    FROM @RequiredTables AS requiredTable
    WHERE OBJECT_ID(N'sosyobel.' + requiredTable.TableName, N'U') IS NULL
)
BEGIN
    THROW 51250, N'Uyumluluk 002 auth tablolarından biri eksik.', 1;
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
    (N'Belediyeler', N'Id', N'int', NULL, 0),
    (N'Belediyeler', N'PublicId', N'uniqueidentifier', NULL, 0),
    (N'Belediyeler', N'Kod', N'nvarchar', 100, 0),
    (N'Belediyeler', N'Ad', N'nvarchar', 400, 0),
    (N'Belediyeler', N'AktifMi', N'bit', NULL, 0),
    (N'KullaniciBelediyeleri', N'Id', N'bigint', NULL, 0),
    (N'KullaniciBelediyeleri', N'UserId', N'nvarchar', 900, 0),
    (N'KullaniciBelediyeleri', N'BelediyeId', N'int', NULL, 0),
    (N'KullaniciBelediyeleri', N'RolKodu', N'nvarchar', 100, 0),
    (N'KullaniciBelediyeleri', N'AktifMi', N'bit', NULL, 0),
    (N'KullaniciYetkileri', N'UserId', N'nvarchar', 900, 0),
    (N'KullaniciYetkileri', N'BelediyeId', N'int', NULL, 0),
    (N'KullaniciYetkileri', N'YetkiKodu', N'nvarchar', 160, 0),
    (N'KullaniciYetkileri', N'VerenUserId', N'nvarchar', 900, 0),
    (N'KullaniciYetkileri', N'IptalEdenUserId', N'nvarchar', 900, 1),
    (N'IslemGecmisleri', N'BelediyeId', N'int', NULL, 0),
    (N'IslemGecmisleri', N'VarlikTuru', N'nvarchar', 200, 0),
    (N'IslemGecmisleri', N'IslemKodu', N'nvarchar', 200, 0),
    (N'IslemGecmisleri', N'OlusturanUserId', N'nvarchar', 900, 0),
    (N'IslemGecmisleri', N'CorrelationId', N'uniqueidentifier', NULL, 0),
    (N'IslemGecmisleri', N'HedefUserId', N'nvarchar', 900, 1),
    (N'IdempotencyKayitlari', N'ActorUserId', N'nvarchar', 900, 0),
    (N'IdempotencyKayitlari', N'ActorUserIdHash', N'binary', 32, 0),
    (N'IdempotencyKayitlari', N'EndpointKodu', N'nvarchar', 300, 0),
    (N'IdempotencyKayitlari', N'IdempotencyKey', N'nvarchar', 200, 0),
    (N'IdempotencyKayitlari', N'IstekHash', N'binary', 32, 0),
    (N'IdempotencyKayitlari', N'HttpDurumKodu', N'int', NULL, 1),
    (N'IdempotencyKayitlari', N'SonucJson', N'nvarchar', -1, 1),
    (N'YenilemeTokenlari', N'UserId', N'nvarchar', 900, 0),
    (N'YenilemeTokenlari', N'TokenHash', N'binary', 32, 0),
    (N'YenilemeTokenlari', N'CihazKimligi', N'nvarchar', 400, 1),
    (N'YenilemeTokenlari', N'OlusturanIp', N'varchar', 45, 1),
    (N'YenilemeTokenlari', N'IptalEdenIp', N'varchar', 45, 1);

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
    THROW 51251, N'Uyumluluk 002 kritik kolonlarından biri beklenen şekilde değildir.', 1;
END;

-- Eşzamanlı güncellemeyi koruyan iki tablo gerçek SQL Server rowversion taşımalıdır.
IF EXISTS
(
    SELECT 1
    FROM
    (
        VALUES
            (N'Belediyeler'),
            (N'KullaniciYetkileri')
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
    )
)
BEGIN
    THROW 51252, N'Uyumluluk 002 rowversion kolonlarından biri eksik.', 1;
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
    (N'Belediyeler', N'UQ_Belediyeler_PublicId', 1),
    (N'Belediyeler', N'UQ_Belediyeler_Kod', 1),
    (N'KullaniciBelediyeleri', N'UQ_KullaniciBelediyeleri_User_Belediye', 1),
    (N'KullaniciBelediyeleri', N'IX_KullaniciBelediyeleri_Belediye_Rol_Aktif', 0),
    (N'KullaniciYetkileri', N'UQ_KullaniciYetkileri_User_Belediye_Yetki', 1),
    (N'KullaniciYetkileri', N'IX_KullaniciYetkileri_Belediye_Yetki_Aktif', 0),
    (N'IslemGecmisleri', N'IX_IslemGecmisleri_Varlik_Tarih', 0),
    (N'IslemGecmisleri', N'IX_IslemGecmisleri_Belediye_Islem_Tarih', 0),
    (N'IdempotencyKayitlari', N'UQ_IdempotencyKayitlari_ActorHash_Endpoint_Key', 1),
    (N'IdempotencyKayitlari', N'IX_IdempotencyKayitlari_Actor_Endpoint', 0),
    (N'IdempotencyKayitlari', N'IX_IdempotencyKayitlari_SonKullanma', 0),
    (N'YenilemeTokenlari', N'UQ_YenilemeTokenlari_TokenHash', 1),
    (N'YenilemeTokenlari', N'IX_YenilemeTokenlari_User_SonKullanma', 0);

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
       OR
       (
           requiredIndex.MustBeUnique = 1 AND
           targetIndex.is_unique = 0
       )
)
BEGIN
    THROW 51253, N'Uyumluluk 002 indekslerinden biri eksik veya geçersiz.', 1;
END;

DECLARE @RequiredForeignKeys TABLE
(
    ConstraintName sysname NOT NULL PRIMARY KEY
);

INSERT INTO @RequiredForeignKeys (ConstraintName)
VALUES
    (N'FK_KullaniciBelediyeleri_Users'),
    (N'FK_KullaniciBelediyeleri_Belediyeler'),
    (N'FK_KullaniciYetkileri_Uyelik'),
    (N'FK_KullaniciYetkileri_VerenUser'),
    (N'FK_KullaniciYetkileri_IptalEdenUser'),
    (N'FK_IslemGecmisleri_Belediyeler'),
    (N'FK_IslemGecmisleri_OlusturanUser'),
    (N'FK_IslemGecmisleri_HedefUser'),
    (N'FK_IdempotencyKayitlari_Actor'),
    (N'FK_YenilemeTokenlari_Users');

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
       OR targetForeignKey.delete_referential_action <> 0
)
BEGIN
    THROW 51254, N'Uyumluluk 002 foreign key kurallarından biri eksik veya güvenilir değildir.', 1;
END;

DECLARE @RequiredChecks TABLE
(
    ConstraintName sysname NOT NULL PRIMARY KEY
);

INSERT INTO @RequiredChecks (ConstraintName)
VALUES
    (N'CK_Belediyeler_Kod'),
    (N'CK_Belediyeler_Ad'),
    (N'CK_KullaniciBelediyeleri_RolKodu'),
    (N'CK_KullaniciYetkileri_YetkiKodu'),
    (N'CK_KullaniciYetkileri_IptalBilgisi'),
    (N'CK_IslemGecmisleri_Json'),
    (N'CK_IslemGecmisleri_KilitliBasvuruGerekce'),
    (N'CK_IdempotencyKayitlari_Key'),
    (N'CK_IdempotencyKayitlari_Http'),
    (N'CK_IdempotencyKayitlari_Json'),
    (N'CK_IdempotencyKayitlari_Sonuc'),
    (N'CK_IdempotencyKayitlari_Sure'),
    (N'CK_YenilemeTokenlari_Sure');

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
    THROW 51255, N'Uyumluluk 002 check constraint kurallarından biri eksik.', 1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.triggers AS targetTrigger
    WHERE targetTrigger.parent_id = OBJECT_ID(N'sosyobel.IslemGecmisleri')
      AND targetTrigger.name = N'TR_IslemGecmisleri_AppendOnly'
      AND targetTrigger.is_disabled = 0
)
BEGIN
    THROW 51256, N'Yönetim audit append-only triggerı eksik veya devre dışıdır.', 1;
END;

SELECT
    (SELECT COUNT_BIG(*) FROM sosyobel.Belediyeler) AS BelediyeSayisi,
    (SELECT COUNT_BIG(*) FROM sosyobel.KullaniciBelediyeleri) AS UyelikSayisi,
    (SELECT COUNT_BIG(*) FROM sosyobel.YenilemeTokenlari) AS YenilemeTokeniSayisi,
    N'COMPATIBILITY_AUTH_SUPPORT_OK' AS ResultCode;
