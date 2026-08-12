/*
  Ana geliştirme şemasındaki kullanıcı hesaplarına uygulama yaşam döngüsü
  bilgilerini ekler. Mevcut dbo.AspNetUsers tablosu veya kolonları değiştirilmez.

  Şirket şeması için aynı sorumluluk compatibility/001 migrationındadır. Bu
  dosya yalnız database/migrations ile kurulan bağımsız yerel şema içindir.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.AspNetUsers', N'U') IS NULL
BEGIN
    THROW 51090, N'Önce ASP.NET Identity şeması oluşturulmalıdır.', 1;
END;

IF OBJECT_ID(N'sosyobel.IdempotencyKayitlari', N'U') IS NULL
BEGIN
    THROW 51096, N'Önce kimlik ve idempotency migrationları çalıştırılmalıdır.', 1;
END;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'sosyobel.KullaniciUygulamaBilgileri', N'U') IS NULL
    BEGIN
    CREATE TABLE sosyobel.KullaniciUygulamaBilgileri
    (
        UserId                    nvarchar(128) NOT NULL,
        AktifMi                   bit NOT NULL
            CONSTRAINT DF_KullaniciUygulamaBilgileri_AktifMi DEFAULT (1),
        OlusturanUserId           nvarchar(128) NULL,
        OlusturulmaTarihiUtc      datetime2(3) NOT NULL
            CONSTRAINT DF_KullaniciUygulamaBilgileri_OlusturulmaTarihiUtc
                DEFAULT SYSUTCDATETIME(),
        GuncelleyenUserId         nvarchar(128) NULL,
        GuncellenmeTarihiUtc      datetime2(3) NULL,
        DevreDisiBirakanUserId    nvarchar(128) NULL,
        DevreDisiTarihiUtc        datetime2(3) NULL,
        DevreDisiGerekce          nvarchar(1000) NULL,
        RowVersion                rowversion NOT NULL,
        CONSTRAINT PK_KullaniciUygulamaBilgileri
            PRIMARY KEY CLUSTERED (UserId),
        CONSTRAINT FK_KullaniciUygulamaBilgileri_User
            FOREIGN KEY (UserId) REFERENCES dbo.AspNetUsers (Id),
        CONSTRAINT FK_KullaniciUygulamaBilgileri_OlusturanUser
            FOREIGN KEY (OlusturanUserId) REFERENCES dbo.AspNetUsers (Id),
        CONSTRAINT FK_KullaniciUygulamaBilgileri_GuncelleyenUser
            FOREIGN KEY (GuncelleyenUserId) REFERENCES dbo.AspNetUsers (Id),
        CONSTRAINT FK_KullaniciUygulamaBilgileri_DevreDisiBirakanUser
            FOREIGN KEY (DevreDisiBirakanUserId) REFERENCES dbo.AspNetUsers (Id),
        CONSTRAINT CK_KullaniciUygulamaBilgileri_Guncelleme CHECK
        (
            (GuncelleyenUserId IS NULL AND GuncellenmeTarihiUtc IS NULL) OR
            (GuncelleyenUserId IS NOT NULL AND GuncellenmeTarihiUtc IS NOT NULL)
        ),
        CONSTRAINT CK_KullaniciUygulamaBilgileri_DevreDisiBilgisi CHECK
        (
            (
                AktifMi = 1 AND
                DevreDisiBirakanUserId IS NULL AND
                DevreDisiTarihiUtc IS NULL AND
                DevreDisiGerekce IS NULL
            ) OR
            (
                AktifMi = 0 AND
                DevreDisiBirakanUserId IS NOT NULL AND
                DevreDisiTarihiUtc IS NOT NULL AND
                DevreDisiGerekce IS NOT NULL AND
                LEN(LTRIM(RTRIM(DevreDisiGerekce))) >= 10
            )
        )
    );

    /*
      Migration öncesinde yerel veritabanında oluşturulmuş hesaplar varsa aktiflik
      durumları korunur. Yeni hesapların kaydını uygulama, kullanıcıyla aynı işlemde
      otomatik oluşturur.
    */
    INSERT INTO sosyobel.KullaniciUygulamaBilgileri
    (
        UserId,
        AktifMi,
        OlusturulmaTarihiUtc,
        DevreDisiBirakanUserId,
        DevreDisiTarihiUtc,
        DevreDisiGerekce
    )
    SELECT
        users.Id,
        users.AktifMi,
        users.OlusturulmaTarihiUtc,
        CASE WHEN users.AktifMi = 0 THEN users.Id END,
        CASE WHEN users.AktifMi = 0
            THEN COALESCE(users.GuncellenmeTarihiUtc, users.OlusturulmaTarihiUtc)
        END,
        CASE WHEN users.AktifMi = 0
            THEN N'Migration öncesinde devre dışı bırakılmış yerel hesap.'
        END
    FROM dbo.AspNetUsers AS users;
    END;

    /*
      Geniş şirket kullanıcı anahtarlarını da destekleyen güncel model, benzersiz
      idempotency indeksinde sabit boyutlu kullanıcı özeti kullanır. Ana geliştirme
      şemasındaki eski birleşik constraint güvenli biçimde bu indekse dönüştürülür.
    */
    IF COL_LENGTH(N'sosyobel.IdempotencyKayitlari', N'ActorUserIdHash') IS NULL
    BEGIN
        ALTER TABLE sosyobel.IdempotencyKayitlari
            ADD ActorUserIdHash binary(32) NULL;

        /* Yeni kolon aynı batch içinde dinamik SQL ile doldurulup zorunlu yapılır. */
        EXEC(N'
            UPDATE sosyobel.IdempotencyKayitlari
            SET ActorUserIdHash = HASHBYTES
            (
                ''SHA2_256'',
                CONVERT
                (
                    varbinary(max),
                    CONVERT
                    (
                        varchar(max),
                        ActorUserId COLLATE Latin1_General_100_BIN2_UTF8
                    )
                )
            );

            ALTER TABLE sosyobel.IdempotencyKayitlari
                ALTER COLUMN ActorUserIdHash binary(32) NOT NULL;
        ');

        IF EXISTS
        (
            SELECT 1
            FROM sys.key_constraints
            WHERE parent_object_id = OBJECT_ID(N'sosyobel.IdempotencyKayitlari')
              AND name = N'UQ_IdempotencyKayitlari_Actor_Endpoint_Key'
        )
        BEGIN
            ALTER TABLE sosyobel.IdempotencyKayitlari
                DROP CONSTRAINT UQ_IdempotencyKayitlari_Actor_Endpoint_Key;
        END;

        CREATE UNIQUE INDEX UQ_IdempotencyKayitlari_ActorHash_Endpoint_Key
            ON sosyobel.IdempotencyKayitlari
            (ActorUserIdHash, EndpointKodu, IdempotencyKey);

        CREATE INDEX IX_IdempotencyKayitlari_Actor_Endpoint
            ON sosyobel.IdempotencyKayitlari (ActorUserId, EndpointKodu)
            INCLUDE (IdempotencyKey);
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
