# ASP.NET Core Identity migration doğrulama kaydı

## 6 Ağustos 2026

Identity ve Sosyo-Bel migration zinciri temiz SQL Server 2022 veritabanında şu
sırayla başarıyla çalıştırıldı:

1. `migrations/000_create_aspnet_identity_schema.sql`
2. `checks/000_verify_aspnet_identity.sql`
3. `migrations/001_create_sosyobel_v2_schema.sql`
4. `migrations/002_create_municipality_integrations.sql`
5. `seed/001_confirmed_reference_data.sql`
6. 001 ve 002 doğrulama betikleri

Sonuç:

| Ölçüm | Sonuç |
|---|---:|
| Identity tablo sayısı | 7 |
| `sosyobel` tablo sayısı | 28 |
| Foreign key sayısı | 66 |
| Check constraint sayısı | 37 |
| İkincil indeks sayısı | 55 |

Kullanıcı ve rol anahtarları gerçek kullanımda GUID tabanlı olduğundan 128 karakterle
sınırlandı. Böylece SQL Server birleşik Identity indekslerinde gereksiz maksimum
anahtar uzunluğu uyarıları oluşmaz.
