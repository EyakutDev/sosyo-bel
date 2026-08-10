/* ASP.NET Core Identity şeması için salt-okunur doğrulama. */

SET NOCOUNT ON;

DECLARE @RequiredTables TABLE (TableName sysname NOT NULL PRIMARY KEY);

INSERT INTO @RequiredTables (TableName)
VALUES
    (N'AspNetRoles'),
    (N'AspNetUsers'),
    (N'AspNetRoleClaims'),
    (N'AspNetUserClaims'),
    (N'AspNetUserLogins'),
    (N'AspNetUserRoles'),
    (N'AspNetUserTokens');

IF EXISTS
(
    SELECT 1
    FROM @RequiredTables AS required
    WHERE OBJECT_ID(N'dbo.' + required.TableName, N'U') IS NULL
)
BEGIN
    THROW 51011, N'ASP.NET Identity şemasında eksik tablo bulundu.', 1;
END;

IF COL_LENGTH(N'dbo.AspNetUsers', N'Ad') IS NULL OR
   COL_LENGTH(N'dbo.AspNetUsers', N'Soyad') IS NULL OR
   COL_LENGTH(N'dbo.AspNetUsers', N'AktifMi') IS NULL OR
   COL_LENGTH(N'dbo.AspNetUsers', N'RowVersion') IS NULL
BEGIN
    THROW 51012, N'Sosyo-Bel kullanıcı alanlarından biri eksik.', 1;
END;

SELECT
    COUNT(*) AS IdentityTabloSayisi
FROM @RequiredTables;
