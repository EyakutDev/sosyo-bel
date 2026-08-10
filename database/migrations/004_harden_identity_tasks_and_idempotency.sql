/*
  Kullanıcı yaşam döngüsü audit alanları, tenant güvenli görev ataması ve
  yönetim endpoint'leri için idempotency kaydı.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

IF OBJECT_ID(N'sosyobel.KullaniciYetkileri', N'U') IS NULL
BEGIN
    THROW 51070, N'Önce 003_create_access_control_and_audit.sql çalıştırılmalıdır.', 1;
END;

IF COL_LENGTH(N'sosyobel.SahaGorevleri', N'AtananKullaniciBelediyesiId') IS NOT NULL OR
   OBJECT_ID(N'sosyobel.IdempotencyKayitlari', N'U') IS NOT NULL
BEGIN
    THROW 51071, N'004 kimlik/görev sertleştirmesi zaten uygulanmış.', 1;
END;

BEGIN TRY
    BEGIN TRANSACTION;

    ALTER TABLE dbo.AspNetUsers
        ADD OlusturanUserId nvarchar(128) NULL,
            DevreDisiBirakanUserId nvarchar(128) NULL,
            DevreDisiTarihiUtc datetime2(3) NULL,
            DevreDisiGerekce nvarchar(1000) NULL;

    EXEC(N'
        ALTER TABLE dbo.AspNetUsers
            ADD CONSTRAINT FK_AspNetUsers_OlusturanUser FOREIGN KEY (OlusturanUserId)
                    REFERENCES dbo.AspNetUsers (Id),
                CONSTRAINT FK_AspNetUsers_DevreDisiBirakanUser FOREIGN KEY (DevreDisiBirakanUserId)
                    REFERENCES dbo.AspNetUsers (Id),
                CONSTRAINT CK_AspNetUsers_DevreDisiBilgisi CHECK
                (
                    (AktifMi = 1 AND DevreDisiBirakanUserId IS NULL AND
                     DevreDisiTarihiUtc IS NULL AND DevreDisiGerekce IS NULL) OR
                    (AktifMi = 0 AND DevreDisiBirakanUserId IS NOT NULL AND
                     DevreDisiTarihiUtc IS NOT NULL AND
                     LEN(LTRIM(RTRIM(DevreDisiGerekce))) >= 10)
                );
    ');

    ALTER TABLE sosyobel.KullaniciBelediyeleri
        ADD CONSTRAINT UQ_KullaniciBelediyeleri_Belediye_Id_User
            UNIQUE (BelediyeId, Id, UserId);

    ALTER TABLE sosyobel.SahaGorevleri
        ADD AtananKullaniciBelediyesiId bigint NULL,
            PublicId uniqueidentifier NOT NULL
                CONSTRAINT DF_SahaGorevleri_PublicId DEFAULT NEWSEQUENTIALID();

    EXEC(N'
        UPDATE gorev
        SET AtananKullaniciBelediyesiId = uyelik.Id
        FROM sosyobel.SahaGorevleri AS gorev
        INNER JOIN sosyobel.KullaniciBelediyeleri AS uyelik
            ON uyelik.BelediyeId = gorev.BelediyeId
           AND uyelik.UserId = gorev.AtananUserId;

        IF EXISTS
        (
            SELECT 1
            FROM sosyobel.SahaGorevleri
            WHERE AtananKullaniciBelediyesiId IS NULL
        )
        BEGIN
            THROW 51072, N''Üyelik kaydı bulunamayan mevcut saha görevi var.'', 1;
        END;

        ALTER TABLE sosyobel.SahaGorevleri
            ALTER COLUMN AtananKullaniciBelediyesiId bigint NOT NULL;

        ALTER TABLE sosyobel.SahaGorevleri
            ADD CONSTRAINT FK_SahaGorevleri_AtananUyelik FOREIGN KEY
                (BelediyeId, AtananKullaniciBelediyesiId, AtananUserId)
                REFERENCES sosyobel.KullaniciBelediyeleri (BelediyeId, Id, UserId);

        CREATE UNIQUE INDEX UX_SahaGorevleri_PublicId
            ON sosyobel.SahaGorevleri (PublicId);

        CREATE INDEX IX_SahaGorevleri_AtananUyelik_Durum
            ON sosyobel.SahaGorevleri
            (BelediyeId, AtananKullaniciBelediyesiId, DurumKodu, AtanmaTarihiUtc DESC);
    ');

    ALTER TABLE sosyobel.IslemGecmisleri
        ADD HedefUserId nvarchar(128) NULL;

    EXEC(N'
        ALTER TABLE sosyobel.IslemGecmisleri
            ADD CONSTRAINT FK_IslemGecmisleri_HedefUser FOREIGN KEY (HedefUserId)
                REFERENCES dbo.AspNetUsers (Id);
    ');

    CREATE TABLE sosyobel.IdempotencyKayitlari
    (
        Id                    bigint IDENTITY(1,1) NOT NULL,
        ActorUserId           nvarchar(128) NOT NULL,
        EndpointKodu          nvarchar(150) NOT NULL,
        IdempotencyKey        nvarchar(100) NOT NULL,
        IstekHash             binary(32) NOT NULL,
        HttpDurumKodu         int NULL,
        SonucJson             nvarchar(max) NULL,
        OlusturulmaTarihiUtc  datetime2(3) NOT NULL
            CONSTRAINT DF_IdempotencyKayitlari_OlusturulmaTarihiUtc DEFAULT SYSUTCDATETIME(),
        SonKullanmaTarihiUtc  datetime2(3) NOT NULL,
        CONSTRAINT PK_IdempotencyKayitlari PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT UQ_IdempotencyKayitlari_Actor_Endpoint_Key
            UNIQUE (ActorUserId, EndpointKodu, IdempotencyKey),
        CONSTRAINT FK_IdempotencyKayitlari_Actor FOREIGN KEY (ActorUserId)
            REFERENCES dbo.AspNetUsers (Id),
        CONSTRAINT CK_IdempotencyKayitlari_Key CHECK
            (LEN(LTRIM(RTRIM(IdempotencyKey))) BETWEEN 8 AND 100),
        CONSTRAINT CK_IdempotencyKayitlari_Http CHECK
            (HttpDurumKodu IS NULL OR HttpDurumKodu BETWEEN 200 AND 599),
        CONSTRAINT CK_IdempotencyKayitlari_Json CHECK
            (SonucJson IS NULL OR ISJSON(SonucJson) = 1),
        CONSTRAINT CK_IdempotencyKayitlari_Sure CHECK
            (SonKullanmaTarihiUtc > OlusturulmaTarihiUtc)
    );

    CREATE INDEX IX_IdempotencyKayitlari_SonKullanma
        ON sosyobel.IdempotencyKayitlari (SonKullanmaTarihiUtc);

    /* Audit kayıtları append-only'dir; düzeltme gerekiyorsa yeni olay yazılır. */
    EXEC(N'
        CREATE TRIGGER sosyobel.TR_IslemGecmisleri_AppendOnly
        ON sosyobel.IslemGecmisleri
        AFTER UPDATE, DELETE
        AS
        BEGIN
            SET NOCOUNT ON;
            THROW 51073, N''İşlem geçmişi kayıtları değiştirilemez veya silinemez.'', 1;
        END;
    ');

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
