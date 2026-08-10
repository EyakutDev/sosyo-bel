SET NOCOUNT ON;

IF OBJECT_ID(N'sosyobel.BasvuruNumaralari', N'SO') IS NULL
BEGIN
    THROW 51051, N'Başvuru numarası sequence nesnesi bulunamadı.', 1;
END;

IF NOT EXISTS (SELECT 1 FROM sosyobel.BasvuruDurumlari WHERE Kod = N'TASLAK' AND AktifMi = 1) OR
   NOT EXISTS (SELECT 1 FROM sosyobel.BasvuruDurumlari WHERE Kod = N'KURUL_BEKLIYOR' AND AktifMi = 1) OR
   NOT EXISTS (SELECT 1 FROM sosyobel.TalepGelisKanallari WHERE Kod = N'MOBIL_SAHA' AND AktifMi = 1)
BEGIN
    THROW 51052, N'Başvuru yaşam döngüsünün zorunlu referans kodları eksik.', 1;
END;

SELECT N'Başvuru yaşam döngüsü veritabanı doğrulaması başarılı.' AS Sonuc;
