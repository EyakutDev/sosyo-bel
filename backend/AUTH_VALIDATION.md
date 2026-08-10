# E-posta/şifre kimlik doğrulama kaydı

## 6 Ağustos 2026

Kimlik doğrulama akışı temiz ve geçici bir SQL Server veritabanına karşı gerçek
HTTP istekleriyle doğrulandı. Test için kullanılan personel hesabı, token'lar ve
veritabanı test sonunda kaldırıldı.

Doğrulanan sonuçlar:

| Senaryo | Sonuç |
|---|---:|
| API readiness | `Healthy` |
| Yanlış şifre | `401` |
| E-posta/şifreyle giriş | Başarılı |
| Belediye kapsamı | `DEMO` |
| Personel rolü | `PERSONEL` |
| JWT ile `/api/v1/auth/me` | Başarılı |
| Refresh token rotasyonu | Başarılı |
| Eski refresh token'ı tekrar kullanma | `401` |
| Çıkış | `204` |
| Çıkış sonrası refresh token | `401` |

Tekrarlanabilir yerel doğrulama betiği:

```powershell
./backend/scripts/validate-auth-flow.ps1 -SqlServer 'localhost\MSSQLSERVER01'
```

Betik yalnız `SosyoBelAuthValidation_<process-id>` adlı geçici veritabanını oluşturur
ve `finally` bloğunda kaldırır. Canlı veya kalıcı kullanıcı verisi kullanmaz.

## 7 Ağustos 2026 erişim kontrolü notu

Auth betiği `003` ve `004` migrationları ile üyelik bazlı `PERSONEL` rolüne
uyarlandı. Yeni yönetim akışı için ayrıca
`scripts/validate-administration-flow.ps1` eklendi.

Yeni kod temiz derlendi ve birim/EF model testleri geçti. Migration zinciri gerçek
SQL Server üzerinde doğrulandı. Yerel SQL örneğinin aralıklı login zaman aşımı
nedeniyle yeni tam HTTP yönetim betiğinin başarılı koşusu henüz kaydedilmedi;
yukarıdaki 6 Ağustos sonucu yeni yönetim endpointleri için doğrulama iddiası değildir.
