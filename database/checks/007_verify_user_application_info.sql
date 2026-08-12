/*
  Ana geliştirme şemasındaki kullanıcı uygulama bilgileri tablosunu salt okunur
  doğrular. Şirketin dbo tablolarında herhangi bir değişiklik yapmaz.
*/

SET NOCOUNT ON;

IF OBJECT_ID(N'sosyobel.KullaniciUygulamaBilgileri', N'U') IS NULL
BEGIN
    THROW 51091, N'Kullanıcı uygulama bilgileri tablosu bulunamadı.', 1;
END;

IF EXISTS
(
    SELECT expected.Name
    FROM
    (
        VALUES
            (N'UserId'),
            (N'AktifMi'),
            (N'OlusturanUserId'),
            (N'OlusturulmaTarihiUtc'),
            (N'GuncelleyenUserId'),
            (N'GuncellenmeTarihiUtc'),
            (N'DevreDisiBirakanUserId'),
            (N'DevreDisiTarihiUtc'),
            (N'DevreDisiGerekce'),
            (N'RowVersion')
    ) AS expected(Name)
    WHERE COL_LENGTH(N'sosyobel.KullaniciUygulamaBilgileri', expected.Name) IS NULL
)
BEGIN
    THROW 51092, N'Kullanıcı uygulama bilgileri tablosunda beklenen kolonlar eksik.', 1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.key_constraints
    WHERE parent_object_id = OBJECT_ID(N'sosyobel.KullaniciUygulamaBilgileri')
      AND type = N'PK'
      AND name = N'PK_KullaniciUygulamaBilgileri'
)
BEGIN
    THROW 51093, N'Kullanıcı uygulama bilgileri birincil anahtarı bulunamadı.', 1;
END;

IF
(
    SELECT COUNT(*)
    FROM sys.foreign_keys
    WHERE parent_object_id = OBJECT_ID(N'sosyobel.KullaniciUygulamaBilgileri')
      AND is_disabled = 0
      AND is_not_trusted = 0
) <> 4
BEGIN
    THROW 51094, N'Kullanıcı uygulama bilgileri foreign keyleri beklenen biçimde değil.', 1;
END;

IF EXISTS
(
    SELECT 1
    FROM dbo.AspNetUsers AS users
    LEFT JOIN sosyobel.KullaniciUygulamaBilgileri AS info
        ON info.UserId = users.Id
    WHERE info.UserId IS NULL
)
BEGIN
    THROW 51095, N'Uygulama bilgisi bulunmayan kullanıcı kaydı var.', 1;
END;

IF COL_LENGTH(N'sosyobel.IdempotencyKayitlari', N'ActorUserIdHash') IS NULL OR
   EXISTS
   (
       SELECT 1
       FROM sosyobel.IdempotencyKayitlari
       WHERE ActorUserIdHash IS NULL
   )
BEGIN
    THROW 51097, N'Idempotency kullanıcı özeti kolonu bulunamadı veya boş kayıt içeriyor.', 1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'sosyobel.IdempotencyKayitlari')
      AND name = N'UQ_IdempotencyKayitlari_ActorHash_Endpoint_Key'
      AND is_unique = 1
) OR NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'sosyobel.IdempotencyKayitlari')
      AND name = N'IX_IdempotencyKayitlari_Actor_Endpoint'
      AND is_unique = 0
      AND is_disabled = 0
)
BEGIN
    THROW 51098, N'Idempotency indeksleri beklenen biçimde değil.', 1;
END;
