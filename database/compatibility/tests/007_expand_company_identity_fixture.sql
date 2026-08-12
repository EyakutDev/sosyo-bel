/*
    Yalnız geçici HTTP auth doğrulaması için tam ASP.NET Core Identity fixture'ı.

    000_create_minimal_company_fixture.sql tarafından oluşturulan boş
    dbo.AspNetUsers tablosunu, sosyaldb.ipynb içindeki şirket kolonlarıyla
    genişletir ve standart Identity ilişki tablolarını nvarchar(450) anahtarlarla
    oluşturur. Şirket ortamında çalıştırılmaz.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

IF OBJECT_ID(N'dbo.AspNetUsers', N'U') IS NULL
BEGIN
    THROW 51280, N'Önce minimal şirket fixture oluşturulmalıdır.', 1;
END;

IF COL_LENGTH(N'dbo.AspNetUsers', N'UserName') IS NOT NULL OR
   OBJECT_ID(N'dbo.AspNetRoles', N'U') IS NOT NULL
BEGIN
    THROW 51281, N'Identity fixture daha önce uygulanmış veya kısmen mevcut.', 1;
END;

BEGIN TRY
    BEGIN TRANSACTION;

    ALTER TABLE dbo.AspNetUsers
        ADD Ad                   nvarchar(max) NOT NULL,
            Soyad                nvarchar(max) NOT NULL,
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
            AccessFailedCount    int NOT NULL;

    CREATE TABLE dbo.AspNetRoles
    (
        Id                nvarchar(450) NOT NULL,
        Name              nvarchar(256) NULL,
        NormalizedName    nvarchar(256) NULL,
        ConcurrencyStamp  nvarchar(max) NULL,
        CONSTRAINT PK_AspNetRoles PRIMARY KEY CLUSTERED (Id)
    );

    CREATE TABLE dbo.AspNetRoleClaims
    (
        Id          int IDENTITY(1,1) NOT NULL,
        RoleId      nvarchar(450) NOT NULL,
        ClaimType   nvarchar(max) NULL,
        ClaimValue  nvarchar(max) NULL,
        CONSTRAINT PK_AspNetRoleClaims PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_AspNetRoleClaims_AspNetRoles_RoleId
            FOREIGN KEY (RoleId) REFERENCES dbo.AspNetRoles (Id)
            ON DELETE CASCADE
    );

    CREATE TABLE dbo.AspNetUserClaims
    (
        Id          int IDENTITY(1,1) NOT NULL,
        UserId      nvarchar(450) NOT NULL,
        ClaimType   nvarchar(max) NULL,
        ClaimValue  nvarchar(max) NULL,
        CONSTRAINT PK_AspNetUserClaims PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_AspNetUserClaims_AspNetUsers_UserId
            FOREIGN KEY (UserId) REFERENCES dbo.AspNetUsers (Id)
            ON DELETE CASCADE
    );

    CREATE TABLE dbo.AspNetUserLogins
    (
        LoginProvider        nvarchar(450) NOT NULL,
        ProviderKey          nvarchar(450) NOT NULL,
        ProviderDisplayName  nvarchar(max) NULL,
        UserId               nvarchar(450) NOT NULL,
        CONSTRAINT PK_AspNetUserLogins
            PRIMARY KEY CLUSTERED (LoginProvider, ProviderKey),
        CONSTRAINT FK_AspNetUserLogins_AspNetUsers_UserId
            FOREIGN KEY (UserId) REFERENCES dbo.AspNetUsers (Id)
            ON DELETE CASCADE
    );

    CREATE TABLE dbo.AspNetUserRoles
    (
        UserId  nvarchar(450) NOT NULL,
        RoleId  nvarchar(450) NOT NULL,
        CONSTRAINT PK_AspNetUserRoles PRIMARY KEY CLUSTERED (UserId, RoleId),
        CONSTRAINT FK_AspNetUserRoles_AspNetUsers_UserId
            FOREIGN KEY (UserId) REFERENCES dbo.AspNetUsers (Id)
            ON DELETE CASCADE,
        CONSTRAINT FK_AspNetUserRoles_AspNetRoles_RoleId
            FOREIGN KEY (RoleId) REFERENCES dbo.AspNetRoles (Id)
            ON DELETE CASCADE
    );

    CREATE TABLE dbo.AspNetUserTokens
    (
        UserId         nvarchar(450) NOT NULL,
        LoginProvider  nvarchar(450) NOT NULL,
        Name           nvarchar(450) NOT NULL,
        Value          nvarchar(max) NULL,
        CONSTRAINT PK_AspNetUserTokens
            PRIMARY KEY CLUSTERED (UserId, LoginProvider, Name),
        CONSTRAINT FK_AspNetUserTokens_AspNetUsers_UserId
            FOREIGN KEY (UserId) REFERENCES dbo.AspNetUsers (Id)
            ON DELETE CASCADE
    );

    CREATE UNIQUE INDEX RoleNameIndex
        ON dbo.AspNetRoles (NormalizedName)
        WHERE NormalizedName IS NOT NULL;

    /*
      Kolonlar bu batch içinde ALTER TABLE ile eklendiği için SQL Server'ın
      derleme anında yeni adları çözebilmesi adına indeksler ayrı batch'te kurulur.
    */
    EXEC(N'
        CREATE INDEX EmailIndex
            ON dbo.AspNetUsers (NormalizedEmail);

        CREATE UNIQUE INDEX UserNameIndex
            ON dbo.AspNetUsers (NormalizedUserName)
            WHERE NormalizedUserName IS NOT NULL;
    ');

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
