/* 004 kimlik/görev/idempotency sertleştirmesi için salt-okunur doğrulama. */

SET NOCOUNT ON;

IF COL_LENGTH(N'dbo.AspNetUsers', N'DevreDisiGerekce') IS NULL OR
   COL_LENGTH(N'sosyobel.SahaGorevleri', N'AtananKullaniciBelediyesiId') IS NULL OR
   COL_LENGTH(N'sosyobel.SahaGorevleri', N'PublicId') IS NULL OR
   OBJECT_ID(N'sosyobel.IdempotencyKayitlari', N'U') IS NULL
BEGIN
    THROW 51080, N'004 şema alanlarından biri eksik.', 1;
END;

IF OBJECT_ID(N'sosyobel.TR_IslemGecmisleri_AppendOnly', N'TR') IS NULL
BEGIN
    THROW 51081, N'Append-only audit triggerı bulunamadı.', 1;
END;

IF EXISTS
(
    SELECT 1
    FROM sosyobel.SahaGorevleri AS gorev
    LEFT JOIN sosyobel.KullaniciBelediyeleri AS uyelik
        ON uyelik.BelediyeId = gorev.BelediyeId
       AND uyelik.Id = gorev.AtananKullaniciBelediyesiId
       AND uyelik.UserId = gorev.AtananUserId
    WHERE uyelik.Id IS NULL
)
BEGIN
    THROW 51082, N'Belediye üyeliğiyle eşleşmeyen saha görevi bulundu.', 1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'sosyobel.SahaGorevleri')
      AND name = N'UX_SahaGorevleri_PublicId'
      AND is_unique = 1
)
BEGIN
    THROW 51083, N'Saha görevi PublicId benzersiz indeksi bulunamadı.', 1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID(N'dbo.AspNetUsers')
      AND name = N'CK_AspNetUsers_DevreDisiBilgisi'
)
BEGIN
    THROW 51084, N'Kullanıcı devre dışı bırakma bütünlük kuralı bulunamadı.', 1;
END;

SELECT
    COUNT(*) AS IdempotencyKaydiSayisi
FROM sosyobel.IdempotencyKayitlari;