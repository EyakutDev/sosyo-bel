/* Belediye entegrasyon migration'ı için salt-okunur kontrol. */

SET NOCOUNT ON;

IF OBJECT_ID(N'sosyobel.BelediyeEntegrasyonlari', N'U') IS NULL
BEGIN
    THROW 51040, N'BelediyeEntegrasyonlari tablosu bulunamadı.', 1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID(N'sosyobel.BelediyeEntegrasyonlari')
      AND name = N'CK_BelediyeEntegrasyonlari_AktifYapilandirma'
)
BEGIN
    THROW 51041, N'Aktif entegrasyon yapılandırma kontrolü bulunamadı.', 1;
END;

IF EXISTS
(
    SELECT 1
    FROM sosyobel.BelediyeEntegrasyonlari
    WHERE SecretReference LIKE N'%password%'
       OR SecretReference LIKE N'%parola%'
       OR SecretReference LIKE N'%secret=%'
)
BEGIN
    THROW 51042, N'SecretReference alanında açık gizli bilgi olabilecek kayıt bulundu.', 1;
END;

SELECT
    COUNT(*) AS EntegrasyonSayisi,
    SUM(CASE WHEN AktifMi = 1 THEN 1 ELSE 0 END) AS AktifEntegrasyonSayisi
FROM sosyobel.BelediyeEntegrasyonlari;
