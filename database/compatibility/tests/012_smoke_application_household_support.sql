/*
    Yalniz gecici uyumluluk veritabaninda 005 hane cevabi ve FK davranisini
    dogrular. Transaction geri alindigi icin kalici test verisi birakmaz.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRANSACTION;

INSERT INTO dbo.AspNetUsers (Id)
VALUES (N'application-household-test-user');

INSERT INTO dbo.Basvurular DEFAULT VALUES;
DECLARE @ApplicationId int = CONVERT(int, SCOPE_IDENTITY());

INSERT INTO sosyobel.Belediyeler (Kod, Ad)
VALUES (N'HANE_TEST', N'Hane Test Belediyesi');
DECLARE @MunicipalityId int = CONVERT(int, SCOPE_IDENTITY());

DECLARE @QuestionId int =
(
    SELECT Id
    FROM sosyobel.HaneSorulari
    WHERE BelediyeId IS NULL
      AND Kod = N'MULKIYET_DURUMU'
);

DECLARE @OptionId int =
(
    SELECT Id
    FROM sosyobel.HaneSoruSecenekleri
    WHERE SoruId = @QuestionId
      AND Kod = N'KIRACI'
);

INSERT INTO sosyobel.BasvuruHaneCevaplari
(
    BelediyeId,
    BasvuruId,
    SoruId,
    SecenekId,
    OlusturanUserId
)
VALUES
(
    @MunicipalityId,
    @ApplicationId,
    @QuestionId,
    @OptionId,
    N'application-household-test-user'
);

IF NOT EXISTS
(
    SELECT 1
    FROM sosyobel.BasvuruHaneCevaplari AS answer
    INNER JOIN dbo.Basvurular AS application
        ON application.Id = answer.BasvuruId
    INNER JOIN sosyobel.HaneSorulari AS question
        ON question.Id = answer.SoruId
    INNER JOIN sosyobel.HaneSoruSecenekleri AS optionValue
        ON optionValue.SoruId = answer.SoruId
       AND optionValue.Id = answer.SecenekId
    WHERE answer.BasvuruId = @ApplicationId
      AND answer.BelediyeId = @MunicipalityId
      AND question.Kod = N'MULKIYET_DURUMU'
      AND optionValue.Kod = N'KIRACI'
)
BEGIN
    THROW 51328, N'Uyumluluk 005 smoke hane cevabi baglantilariyla yazilamadi.', 1;
END;

ROLLBACK TRANSACTION;

SELECT N'COMPATIBILITY_APPLICATION_HOUSEHOLD_SMOKE_OK' AS ResultCode;
