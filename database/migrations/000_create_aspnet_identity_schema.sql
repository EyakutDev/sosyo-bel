/*
  ASP.NET Core Identity şeması.

  Kullanıcı parolalarının kendisi tutulmaz; Identity yalnız güçlü parola özetini
  AspNetUsers.PasswordHash alanına yazar. Sosyo-Bel V2 migration'ı bu tablolara
  foreign key verdiği için bu betik 001'den önce çalıştırılmalıdır.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

IF OBJECT_ID(N'dbo.AspNetUsers', N'U') IS NOT NULL
BEGIN
    THROW 51010, N'ASP.NET Identity şeması zaten mevcut. Betik ikinci kez çalıştırılmadı.', 1;
END;

BEGIN TRY
    BEGIN TRANSACTION;

    CREATE TABLE dbo.AspNetRoles
    (
        Id               nvarchar(128) NOT NULL,
        Name             nvarchar(256) NULL,
        NormalizedName   nvarchar(256) NULL,
        ConcurrencyStamp nvarchar(max) NULL,
        CONSTRAINT PK_AspNetRoles PRIMARY KEY CLUSTERED (Id)
    );

    CREATE TABLE dbo.AspNetUsers
    (
        Id                   nvarchar(128) NOT NULL,
        UserName             nvarchar(256) NULL,
        NormalizedUserName   nvarchar(256) NULL,
        Email                nvarchar(256) NULL,
        NormalizedEmail      nvarchar(256) NULL,
        EmailConfirmed       bit NOT NULL,
        PasswordHash         nvarchar(max) NULL,
        SecurityStamp        nvarchar(max) NULL,
        ConcurrencyStamp     nvarchar(max) NULL,
        PhoneNumber          nvarchar(max) NULL,
        PhoneNumberConfirmed bit NOT NULL,
        TwoFactorEnabled     bit NOT NULL,
        LockoutEnd           datetimeoffset(7) NULL,
        LockoutEnabled       bit NOT NULL,
        AccessFailedCount    int NOT NULL,
        Ad                   nvarchar(100) NOT NULL,
        Soyad                nvarchar(100) NOT NULL,
        AktifMi              bit NOT NULL
            CONSTRAINT DF_AspNetUsers_AktifMi DEFAULT (1),
        OlusturulmaTarihiUtc datetime2(3) NOT NULL
            CONSTRAINT DF_AspNetUsers_OlusturulmaTarihiUtc DEFAULT SYSUTCDATETIME(),
        GuncellenmeTarihiUtc datetime2(3) NULL,
        RowVersion           rowversion NOT NULL,
        CONSTRAINT PK_AspNetUsers PRIMARY KEY CLUSTERED (Id)
    );

    CREATE TABLE dbo.AspNetRoleClaims
    (
        Id         int IDENTITY(1,1) NOT NULL,
        RoleId     nvarchar(128) NOT NULL,
        ClaimType  nvarchar(max) NULL,
        ClaimValue nvarchar(max) NULL,
        CONSTRAINT PK_AspNetRoleClaims PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_AspNetRoleClaims_AspNetRoles_RoleId FOREIGN KEY (RoleId)
            REFERENCES dbo.AspNetRoles (Id) ON DELETE CASCADE
    );

    CREATE TABLE dbo.AspNetUserClaims
    (
        Id         int IDENTITY(1,1) NOT NULL,
        UserId     nvarchar(128) NOT NULL,
        ClaimType  nvarchar(max) NULL,
        ClaimValue nvarchar(max) NULL,
        CONSTRAINT PK_AspNetUserClaims PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_AspNetUserClaims_AspNetUsers_UserId FOREIGN KEY (UserId)
            REFERENCES dbo.AspNetUsers (Id) ON DELETE CASCADE
    );

    CREATE TABLE dbo.AspNetUserLogins
    (
        LoginProvider       nvarchar(128) NOT NULL,
        ProviderKey         nvarchar(128) NOT NULL,
        ProviderDisplayName nvarchar(max) NULL,
        UserId              nvarchar(128) NOT NULL,
        CONSTRAINT PK_AspNetUserLogins PRIMARY KEY CLUSTERED (LoginProvider, ProviderKey),
        CONSTRAINT FK_AspNetUserLogins_AspNetUsers_UserId FOREIGN KEY (UserId)
            REFERENCES dbo.AspNetUsers (Id) ON DELETE CASCADE
    );

    CREATE TABLE dbo.AspNetUserRoles
    (
        UserId nvarchar(128) NOT NULL,
        RoleId nvarchar(128) NOT NULL,
        CONSTRAINT PK_AspNetUserRoles PRIMARY KEY CLUSTERED (UserId, RoleId),
        CONSTRAINT FK_AspNetUserRoles_AspNetUsers_UserId FOREIGN KEY (UserId)
            REFERENCES dbo.AspNetUsers (Id) ON DELETE CASCADE,
        CONSTRAINT FK_AspNetUserRoles_AspNetRoles_RoleId FOREIGN KEY (RoleId)
            REFERENCES dbo.AspNetRoles (Id) ON DELETE CASCADE
    );

    CREATE TABLE dbo.AspNetUserTokens
    (
        UserId       nvarchar(128) NOT NULL,
        LoginProvider nvarchar(128) NOT NULL,
        Name          nvarchar(128) NOT NULL,
        Value         nvarchar(max) NULL,
        CONSTRAINT PK_AspNetUserTokens PRIMARY KEY CLUSTERED (UserId, LoginProvider, Name),
        CONSTRAINT FK_AspNetUserTokens_AspNetUsers_UserId FOREIGN KEY (UserId)
            REFERENCES dbo.AspNetUsers (Id) ON DELETE CASCADE
    );

    CREATE UNIQUE INDEX RoleNameIndex
        ON dbo.AspNetRoles (NormalizedName)
        WHERE NormalizedName IS NOT NULL;

    CREATE INDEX EmailIndex
        ON dbo.AspNetUsers (NormalizedEmail);

    CREATE UNIQUE INDEX UserNameIndex
        ON dbo.AspNetUsers (NormalizedUserName)
        WHERE NormalizedUserName IS NOT NULL;

    CREATE INDEX IX_AspNetRoleClaims_RoleId
        ON dbo.AspNetRoleClaims (RoleId);

    CREATE INDEX IX_AspNetUserClaims_UserId
        ON dbo.AspNetUserClaims (UserId);

    CREATE INDEX IX_AspNetUserLogins_UserId
        ON dbo.AspNetUserLogins (UserId);

    CREATE INDEX IX_AspNetUserRoles_RoleId
        ON dbo.AspNetUserRoles (RoleId);

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
