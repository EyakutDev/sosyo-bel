# Belediye entegrasyonu migration doğrulama kaydı

## 5 Ağustos 2026

`001_create_sosyobel_v2_schema.sql` ile başlayan migration zincirine
`002_create_municipality_integrations.sql` eklenerek temiz ve geçici bir SQL Server
veritabanında uçtan uca çalıştırıldı.

- SQL Server: 2022 Developer Edition
- Geçici veritabanı: `SosyoBelV2Validation_20260805_04`
- Sonuç: Başarılı
- Geçici veritabanı test sonunda kaldırıldı.

Çalıştırılan sıra:

1. Geçici veritabanı ve yalnız foreign key ön koşulu için Identity tabloları oluşturuldu.
2. `migrations/001_create_sosyobel_v2_schema.sql` uygulandı.
3. `migrations/002_create_municipality_integrations.sql` uygulandı.
4. `seed/001_confirmed_reference_data.sql` uygulandı.
5. `checks/001_verify_sosyobel_v2.sql` çalıştırıldı.
6. `checks/002_verify_municipality_integrations.sql` çalıştırıldı.
7. Geçici veritabanı kaldırıldı.

Kontrol sonucu:

| Ölçüm | Sonuç |
|---|---:|
| `sosyobel` tablo sayısı | 28 |
| Foreign key sayısı | 66 |
| Check constraint sayısı | 37 |
| İkincil indeks sayısı | 55 |
| Test başlangıcındaki entegrasyon kaydı | 0 |

Bu test migration sırasını ve SQL bütünlük kurallarını doğrular. Gerçek belediye
sunucusuna bağlantı testi anlamına gelmez.
