/*
  Belediye kapsamlı roller, özel yetkiler ve denetlenebilir değişiklik gerekçesi.

  SISTEM_YONETICISI ASP.NET Identity rolüdür. BELEDIYE_YONETICISI ve PERSONEL
  rolleri belediye üyeliğinde tutulur; böylece rol başka belediyeye taşınamaz.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

IF OBJECT_ID(N'sosyobel.KullaniciBelediyeleri', N'U') IS NULL OR
   OBJECT_ID(N'sosyobel.IslemGecmisleri', N'U') IS NULL
BEGIN
    THROW 51050, N'Önce 001_create_sosyobel_v2_schema.sql çalıştırılmalıdır.', 1;
END;

IF COL_LENGTH(N'sosyobel.KullaniciBelediyeleri', N'RolKodu') IS NOT NULL OR
   OBJECT_ID(N'sosyobel.KullaniciYetkileri', N'U') IS NOT NULL
BEGIN
    THROW 51051, N'Erişim kontrolü şeması zaten mevcut. Betik ikinci kez çalıştırılmadı.', 1;
END;

BEGIN TRY
    BEGIN TRANSACTION;

    ALTER TABLE sosyobel.KullaniciBelediyeleri
        ADD RolKodu nvarchar(50) NULL;

    /*
      SQL Server yeni eklenen kolonu aynı batch'in derleme aşamasında çözemez.
      İlgili DML/DDL dinamik batch'te, aynı transaction içinde çalıştırılır.
    */
    EXEC(N'
        UPDATE sosyobel.KullaniciBelediyeleri
        SET RolKodu = N''PERSONEL''
        WHERE RolKodu IS NULL;

        ALTER TABLE sosyobel.KullaniciBelediyeleri
            ALTER COLUMN RolKodu nvarchar(50) NOT NULL;

        ALTER TABLE sosyobel.KullaniciBelediyeleri
            ADD CONSTRAINT DF_KullaniciBelediyeleri_RolKodu
                DEFAULT (N''PERSONEL'') FOR RolKodu;

        ALTER TABLE sosyobel.KullaniciBelediyeleri
            ADD CONSTRAINT CK_KullaniciBelediyeleri_RolKodu CHECK
            (
                RolKodu IN (N''BELEDIYE_YONETICISI'', N''PERSONEL'')
            );

        CREATE INDEX IX_KullaniciBelediyeleri_Belediye_Rol_Aktif
            ON sosyobel.KullaniciBelediyeleri (BelediyeId, RolKodu, AktifMi);
    ');

    CREATE TABLE sosyobel.KullaniciYetkileri
    (
        Id                    bigint IDENTITY(1,1) NOT NULL,
        UserId                nvarchar(128) NOT NULL,
        BelediyeId            int NOT NULL,
        YetkiKodu             nvarchar(80) NOT NULL,
        AktifMi               bit NOT NULL
            CONSTRAINT DF_KullaniciYetkileri_AktifMi DEFAULT (1),
        VerenUserId           nvarchar(128) NOT NULL,
        VerilmeTarihiUtc      datetime2(3) NOT NULL
            CONSTRAINT DF_KullaniciYetkileri_VerilmeTarihiUtc DEFAULT SYSUTCDATETIME(),
        IptalEdenUserId       nvarchar(128) NULL,
        IptalTarihiUtc        datetime2(3) NULL,
        RowVersion            rowversion NOT NULL,
        CONSTRAINT PK_KullaniciYetkileri PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT UQ_KullaniciYetkileri_User_Belediye_Yetki
            UNIQUE (UserId, BelediyeId, YetkiKodu),
        CONSTRAINT FK_KullaniciYetkileri_Uyelik FOREIGN KEY (UserId, BelediyeId)
            REFERENCES sosyobel.KullaniciBelediyeleri (UserId, BelediyeId),
        CONSTRAINT FK_KullaniciYetkileri_VerenUser FOREIGN KEY (VerenUserId)
            REFERENCES dbo.AspNetUsers (Id),
        CONSTRAINT FK_KullaniciYetkileri_IptalEdenUser FOREIGN KEY (IptalEdenUserId)
            REFERENCES dbo.AspNetUsers (Id),
        CONSTRAINT CK_KullaniciYetkileri_YetkiKodu CHECK
            (YetkiKodu IN (N'KILITLI_BASVURU_DUZENLE')),
        CONSTRAINT CK_KullaniciYetkileri_IptalBilgisi CHECK
        (
            (AktifMi = 1 AND IptalEdenUserId IS NULL AND IptalTarihiUtc IS NULL) OR
            (AktifMi = 0 AND IptalEdenUserId IS NOT NULL AND IptalTarihiUtc IS NOT NULL)
        )
    );

    CREATE INDEX IX_KullaniciYetkileri_Belediye_Yetki_Aktif
        ON sosyobel.KullaniciYetkileri (BelediyeId, YetkiKodu, AktifMi, UserId);

    ALTER TABLE sosyobel.IslemGecmisleri
        ADD Gerekce nvarchar(1000) NULL,
            OlusturanIp varchar(45) NULL,
            CihazKimligi nvarchar(200) NULL,
            CorrelationId uniqueidentifier NULL;

    /* Kilitli başvuruda gerekçe ve eski/yeni değer özeti veritabanında da zorunludur. */
    EXEC(N'
        ALTER TABLE sosyobel.IslemGecmisleri
            ADD CONSTRAINT CK_IslemGecmisleri_KilitliBasvuruGerekce CHECK
            (
                IslemKodu <> N''KILITLI_BASVURU_GUNCELLE'' OR
                (
                    Gerekce IS NOT NULL AND LEN(LTRIM(RTRIM(Gerekce))) >= 10 AND
                    DegisiklikOzetiJson IS NOT NULL
                )
            );
    ');

    CREATE INDEX IX_IslemGecmisleri_Belediye_Islem_Tarih
        ON sosyobel.IslemGecmisleri
        (BelediyeId, IslemKodu, OlusturulmaTarihiUtc DESC);

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
