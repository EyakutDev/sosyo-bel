/*
  V2 kurulumundan sonra salt-okunur doğrulama için kullanılır.
  Herhangi bir kullanıcı verisini değiştirmez.
*/

SET NOCOUNT ON;

DECLARE @BeklenenTablolar TABLE (TabloAdi sysname NOT NULL PRIMARY KEY);

INSERT INTO @BeklenenTablolar (TabloAdi)
VALUES
    (N'Belediyeler'),
    (N'KullaniciBelediyeleri'),
    (N'BasvuruDurumlari'),
    (N'CalismaDurumlari'),
    (N'EgitimDurumlari'),
    (N'Yakinliklar'),
    (N'YasamDurumlari'),
    (N'EngelTurleri'),
    (N'YardimTurleri'),
    (N'TalepGelisKanallari'),
    (N'Mahalleler'),
    (N'Sokaklar'),
    (N'Vatandaslar'),
    (N'AileFertleri'),
    (N'Basvurular'),
    (N'BasvuruAileFertleri'),
    (N'HaneSorulari'),
    (N'HaneSoruSecenekleri'),
    (N'BasvuruHaneCevaplari'),
    (N'BasvuruFotograflari'),
    (N'BasvuruDurumGecmisi'),
    (N'KurulIslemleri'),
    (N'SahaGorevleri'),
    (N'IslemGecmisleri'),
    (N'VeriAktarimIslemleri'),
    (N'VeriAktarimSatirHatalari'),
    (N'YenilemeTokenlari');

IF EXISTS
(
    SELECT 1
    FROM @BeklenenTablolar AS beklenen
    WHERE OBJECT_ID(N'sosyobel.' + QUOTENAME(beklenen.TabloAdi), N'U') IS NULL
)
BEGIN
    SELECT beklenen.TabloAdi AS EksikTablo
    FROM @BeklenenTablolar AS beklenen
    WHERE OBJECT_ID(N'sosyobel.' + QUOTENAME(beklenen.TabloAdi), N'U') IS NULL;

    THROW 51020, N'Sosyo-Bel V2 doğrulaması başarısız: eksik tablolar var.', 1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.check_constraints
    WHERE name = N'CK_BasvuruFotograflari_SiraNo'
      AND parent_object_id = OBJECT_ID(N'sosyobel.BasvuruFotograflari')
)
BEGIN
    THROW 51021, N'Fotoğraf sıra/sınır kontrolü bulunamadı.', 1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = N'UX_BasvuruFotograflari_AktifSira'
      AND object_id = OBJECT_ID(N'sosyobel.BasvuruFotograflari')
      AND is_unique = 1
)
BEGIN
    THROW 51022, N'Aktif fotoğraf sıra benzersizliği bulunamadı.', 1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.key_constraints
    WHERE name = N'UQ_Vatandaslar_Belediye_TcKimlikNo'
      AND parent_object_id = OBJECT_ID(N'sosyobel.Vatandaslar')
)
BEGIN
    THROW 51023, N'Belediye bazlı T.C. kimlik numarası benzersizliği bulunamadı.', 1;
END;

/* Kurulum özeti: tablo, foreign key, check constraint ve kullanıcı indeksleri. */
SELECT
    (SELECT COUNT(*)
     FROM sys.tables AS t
     INNER JOIN sys.schemas AS s ON s.schema_id = t.schema_id
     WHERE s.name = N'sosyobel') AS TabloSayisi,
    (SELECT COUNT(*)
     FROM sys.foreign_keys AS fk
     WHERE OBJECT_SCHEMA_NAME(fk.parent_object_id) = N'sosyobel') AS ForeignKeySayisi,
    (SELECT COUNT(*)
     FROM sys.check_constraints AS ck
     WHERE OBJECT_SCHEMA_NAME(ck.parent_object_id) = N'sosyobel') AS CheckConstraintSayisi,
    (SELECT COUNT(*)
     FROM sys.indexes AS i
     WHERE OBJECT_SCHEMA_NAME(i.object_id) = N'sosyobel'
       AND i.index_id > 1) AS IkincilIndeksSayisi;

/* Kesinleşmiş seed kayıtlarından eksik olanları gösterir; sonuç dönmemesi beklenir. */
DECLARE @BeklenenKodlar TABLE
(
    TabloAdi sysname NOT NULL,
    Kod nvarchar(80) NOT NULL
);

INSERT INTO @BeklenenKodlar (TabloAdi, Kod)
VALUES
    (N'BasvuruDurumlari', N'TASLAK'),
    (N'BasvuruDurumlari', N'KURUL_BEKLIYOR'),
    (N'BasvuruDurumlari', N'TAMAMLANDI'),
    (N'CalismaDurumlari', N'CALISIYOR'),
    (N'CalismaDurumlari', N'CALISMIYOR'),
    (N'CalismaDurumlari', N'EMEKLI'),
    (N'YasamDurumlari', N'SAG'),
    (N'YasamDurumlari', N'OLU'),
    (N'Yakinliklar', N'DIGER'),
    (N'TalepGelisKanallari', N'MOBIL_SAHA');

SELECT beklenen.TabloAdi, beklenen.Kod AS EksikKod
FROM @BeklenenKodlar AS beklenen
WHERE
    (beklenen.TabloAdi = N'BasvuruDurumlari' AND NOT EXISTS
        (SELECT 1 FROM sosyobel.BasvuruDurumlari WHERE Kod = beklenen.Kod))
 OR (beklenen.TabloAdi = N'CalismaDurumlari' AND NOT EXISTS
        (SELECT 1 FROM sosyobel.CalismaDurumlari WHERE Kod = beklenen.Kod))
 OR (beklenen.TabloAdi = N'YasamDurumlari' AND NOT EXISTS
        (SELECT 1 FROM sosyobel.YasamDurumlari WHERE Kod = beklenen.Kod))
 OR (beklenen.TabloAdi = N'Yakinliklar' AND NOT EXISTS
        (SELECT 1 FROM sosyobel.Yakinliklar WHERE Kod = beklenen.Kod))
 OR (beklenen.TabloAdi = N'TalepGelisKanallari' AND NOT EXISTS
        (SELECT 1 FROM sosyobel.TalepGelisKanallari WHERE Kod = beklenen.Kod));

/* Herhangi bir satır dönmesi, uygulama/API tarafından araştırılması gereken veri ihlalidir. */
SELECT BasvuruId, COUNT(*) AS AktifFotografSayisi
FROM sosyobel.BasvuruFotograflari
WHERE SilindiMi = 0
GROUP BY BasvuruId
HAVING COUNT(*) > 15;
