/*
    Uyumluluk foundation tabloları için transaction içi duman testi.

    Geçerli örnek kayıtlar eklenir, bağlantılar doğrulanır ve transaction her
    durumda geri alınır. Kalıcı test verisi bırakmaz.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @UserId nvarchar(450) = N'compatibility-test-user';
    INSERT INTO dbo.AspNetUsers (Id) VALUES (@UserId);

    INSERT INTO dbo.Basvurular DEFAULT VALUES;
    DECLARE @BasvuruId int = CONVERT(int, SCOPE_IDENTITY());

    INSERT INTO dbo.BasvuruDurumlari DEFAULT VALUES;
    DECLARE @BasvuruDurumuId int = CONVERT(int, SCOPE_IDENTITY());

    INSERT INTO dbo.CalismaDurumlari DEFAULT VALUES;
    DECLARE @CalismaDurumuId int = CONVERT(int, SCOPE_IDENTITY());

    INSERT INTO dbo.EgitimDurumlari DEFAULT VALUES;
    DECLARE @EgitimDurumuId int = CONVERT(int, SCOPE_IDENTITY());

    INSERT INTO dbo.EngelTurleri DEFAULT VALUES;
    DECLARE @EngelTuruId int = CONVERT(int, SCOPE_IDENTITY());

    INSERT INTO dbo.TalepGelisKanallari DEFAULT VALUES;
    DECLARE @TalepGelisKanaliId int = CONVERT(int, SCOPE_IDENTITY());

    INSERT INTO dbo.Yakinliklar DEFAULT VALUES;
    DECLARE @YakinlikId int = CONVERT(int, SCOPE_IDENTITY());

    INSERT INTO dbo.YardimTurleri DEFAULT VALUES;
    DECLARE @YardimTuruId int = CONVERT(int, SCOPE_IDENTITY());

    INSERT INTO sosyobel.KullaniciUygulamaBilgileri
        (UserId, OlusturanUserId)
    VALUES
        (@UserId, @UserId);

    INSERT INTO sosyobel.BasvuruUygulamaBilgileri
    (
        BasvuruId,
        BasvuruNo,
        GuncelleyenUserId,
        GuncellenmeTarihiUtc,
        KurulaGonderenUserId,
        KurulaGonderilmeTarihiUtc
    )
    VALUES
    (
        @BasvuruId,
        N'COMPAT-1',
        @UserId,
        SYSUTCDATETIME(),
        @UserId,
        SYSUTCDATETIME()
    );

    INSERT INTO sosyobel.ReferansKodlari
        (ReferansTuruKodu, KaynakId, Kod)
    VALUES
        (N'BASVURU_DURUMU', @BasvuruDurumuId, N'TASLAK'),
        (N'CALISMA_DURUMU', @CalismaDurumuId, N'CALISIYOR'),
        (N'EGITIM_DURUMU', @EgitimDurumuId, N'ILKOGRETIM'),
        (N'ENGEL_TURU', @EngelTuruId, N'ORTOPEDIK'),
        (N'TALEP_GELIS_KANALI', @TalepGelisKanaliId, N'MOBIL_SAHA'),
        (N'YAKINLIK', @YakinlikId, N'ES'),
        (N'YARDIM_TURU', @YardimTuruId, N'GIDA');

    IF (SELECT COUNT(*) FROM sosyobel.ReferansKodlari) <> 7 OR
       (SELECT COUNT(*) FROM sosyobel.BasvuruUygulamaBilgileri) <> 1 OR
       (SELECT COUNT(*) FROM sosyobel.KullaniciUygulamaBilgileri) <> 1
    BEGIN
        THROW 51230, N'Uyumluluk foundation duman testi beklenen kayıtları oluşturamadı.', 1;
    END;

    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
