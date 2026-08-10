# Erişim kontrolü migration doğrulama kaydı

## 7 Ağustos 2026

Aşağıdaki zincir SQL Server 2022 üzerinde temiz ve geçici bir veritabanında
başarıyla çalıştırıldı:

1. `000_create_aspnet_identity_schema.sql`
2. `001_create_sosyobel_v2_schema.sql`
3. `002_create_municipality_integrations.sql`
4. `003_create_access_control_and_audit.sql`
5. `004_harden_identity_tasks_and_idempotency.sql`
6. `001_confirmed_reference_data.sql`
7. `000`-`004` doğrulama betikleri

Kullanılan komut:

```powershell
./backend/scripts/validate-schema.ps1 -SqlServer 'localhost\MSSQLSERVER01'
```

Sonuç: `SCHEMA_VALIDATION_OK`. Geçici
`SosyoBelSchemaValidation_a99a926d7f3c4101af1d86590befa8ca` veritabanı test
sonunda kaldırıldı.

Test sırasında SQL Server'ın aynı batch içinde yeni eklenen kolonları derleme
aşamasında çözemediği tespit edildi. `003` ve `004` migrationlarındaki ilgili
DML/DDL ifadeleri transaction korunarak dinamik batch'e alındı ve zincir yeniden
başarıyla doğrulandı.
