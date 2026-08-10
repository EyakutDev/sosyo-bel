/*
  Mobil başvurular için Figma'da görülen sayısal Başvuru No değerini üretir.
  Proje şu an tek belediye düzeninde çalıştığı için sıra uygulama genelindedir.
  Sequence değerlerindeki boşluklar normaldir; silinen/geri alınan işlemlerde numara tekrar kullanılmaz.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF SCHEMA_ID(N'sosyobel') IS NULL OR OBJECT_ID(N'sosyobel.Basvurular', N'U') IS NULL
BEGIN
    THROW 51050, N'Önce SosyoBel V2 şeması oluşturulmalıdır.', 1;
END;

IF OBJECT_ID(N'sosyobel.BasvuruNumaralari', N'SO') IS NULL
BEGIN
    EXEC(N'CREATE SEQUENCE sosyobel.BasvuruNumaralari AS bigint START WITH 1 INCREMENT BY 1;');
END;

DECLARE @SonrakiNumara bigint =
(
    SELECT ISNULL(MAX(TRY_CONVERT(bigint, BasvuruNo)), 0) + 1
    FROM sosyobel.Basvurular
);

DECLARE @MevcutNumara bigint =
(
    SELECT CONVERT(bigint, current_value)
    FROM sys.sequences
    WHERE object_id = OBJECT_ID(N'sosyobel.BasvuruNumaralari')
);

IF @MevcutNumara IS NULL OR @MevcutNumara < @SonrakiNumara - 1
BEGIN
    DECLARE @SequenceSql nvarchar(200) =
        N'ALTER SEQUENCE sosyobel.BasvuruNumaralari RESTART WITH ' +
        CONVERT(nvarchar(30), @SonrakiNumara) + N';';
    EXEC sys.sp_executesql @SequenceSql;
END;
