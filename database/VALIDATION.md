# Sosyo-Bel V2 SQL doğrulama kaydı

## 5 Ağustos 2026

V2 migration, seed ve doğrulama betikleri yerel ve geçici bir SQL Server
veritabanında uçtan uca çalıştırıldı.

- SQL Server: `16.0.1000.6` (SQL Server 2022 Developer Edition, 64-bit)
- Geçici veritabanı: `SosyoBelV2Validation_20260805_03`
- Sonuç: Başarılı
- Geçici veritabanı test sonunda kaldırıldı.

Doğrulanan sıra:

1. Boş geçici veritabanı oluşturuldu.
2. V2'nin foreign key ön koşulu için yalnız kimlik sütunlarını içeren geçici
   `dbo.AspNetUsers` ve `dbo.AspNetRoles` tabloları oluşturuldu.
3. `migrations/001_create_sosyobel_v2_schema.sql` uygulandı.
4. `seed/001_confirmed_reference_data.sql` uygulandı.
5. `checks/001_verify_sosyobel_v2.sql` çalıştırıldı.
6. Geçici veritabanı kaldırıldı.

Kontrol sonucu:

| Ölçüm | Sonuç |
|---|---:|
| `sosyobel` tablo sayısı | 27 |
| Foreign key sayısı | 63 |
| Check constraint sayısı | 29 |
| İkincil indeks sayısı | 52 |
| Eksik kesinleşmiş seed kodu | 0 |
| 15 fotoğraf sınırını aşan kayıt | 0 |

İlk çalışma sırasında gerçek SQL Server'ın yakaladığı ve düzeltilen noktalar:

- Filtreli indeksler için `ANSI_NULLS` ve `QUOTED_IDENTIFIER` açıldı.
- Uzun Identity kullanıcı kimliği ile birleşik clustered key kullanımı kaldırıldı;
  `KullaniciBelediyeleri` için sayısal clustered primary key ve ayrıca benzersiz
  kullanıcı/belediye anahtarı kullanıldı.
- Doğrulama sorgusundaki yanlış sistem fonksiyonu `OBJECT_SCHEMA_NAME` ile
  düzeltildi.

## Henüz doğrulanmayanlar

- Belediyenin kullanacağı kesin SQL Server sürümü
- Tam ASP.NET Core Identity migration'ı ile birlikte çalışma
- Eski `dbo` verilerinin V2'ye aktarımı
- Gerçek belediye, yardım türü, engel türü ve hane soru verileri
- API transaction'ları ve kurula gönderildikten sonraki değişiklik kilidi
- Yük ve performans testi

Bu nedenle dosyalar SQL sözdizimi ve temel ilişkiler açısından doğrulanmıştır;
henüz belediye canlı ortamı için dağıtım onayı anlamına gelmez.
