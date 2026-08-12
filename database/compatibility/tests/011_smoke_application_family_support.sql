/*
    Yalniz gecici uyumluluk veritabaninda 004 tablo bolme ve FK davranisini
    dogrular. Transaction geri alindigi icin kalici test verisi birakmaz.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRANSACTION;

INSERT INTO dbo.AspNetUsers (Id)
VALUES (N'application-family-test-user');

INSERT INTO dbo.Basvurular DEFAULT VALUES;
DECLARE @ApplicationId int = CONVERT(int, SCOPE_IDENTITY());

INSERT INTO dbo.Yakinliklar DEFAULT VALUES;
DECLARE @RelationshipId int = CONVERT(int, SCOPE_IDENTITY());

INSERT INTO dbo.CalismaDurumlari DEFAULT VALUES;
DECLARE @EmploymentId int = CONVERT(int, SCOPE_IDENTITY());

INSERT INTO dbo.EgitimDurumlari DEFAULT VALUES;
DECLARE @EducationId int = CONVERT(int, SCOPE_IDENTITY());

DECLARE @VitalStatusId int =
(
    SELECT Id
    FROM sosyobel.YasamDurumlari
    WHERE Kod = N'SAG'
);

INSERT INTO dbo.BasvuruAileFertleri
(
    BasvuruId,
    AdSoyad,
    Yas,
    EngelDurumu,
    CalismaDurumuId,
    EgitimDurumuId,
    YakinlikId
)
VALUES
(
    @ApplicationId,
    N'Test Aile Uyesi',
    42,
    0,
    @EmploymentId,
    @EducationId,
    @RelationshipId
);

DECLARE @FamilyMemberId int = CONVERT(int, SCOPE_IDENTITY());

INSERT INTO sosyobel.BasvuruAileFertiUygulamaBilgileri
(
    BasvuruAileFertiId,
    YasamDurumuId,
    OlusturanUserId
)
VALUES
(
    @FamilyMemberId,
    @VitalStatusId,
    N'application-family-test-user'
);

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.BasvuruAileFertleri AS familyMember
    INNER JOIN sosyobel.BasvuruAileFertiUygulamaBilgileri AS metadata
        ON metadata.BasvuruAileFertiId = familyMember.Id
    INNER JOIN sosyobel.YasamDurumlari AS vitalStatus
        ON vitalStatus.Id = metadata.YasamDurumuId
    WHERE familyMember.Id = @FamilyMemberId
      AND familyMember.BasvuruId = @ApplicationId
      AND vitalStatus.Kod = N'SAG'
)
BEGIN
    THROW 51308, N'Uyumluluk 004 smoke kaydi iki tabloya birlikte yazilamadi.', 1;
END;

ROLLBACK TRANSACTION;

SELECT N'COMPATIBILITY_APPLICATION_FAMILY_SMOKE_OK' AS ResultCode;
