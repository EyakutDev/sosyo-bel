# Kimlik doğrulama doğrulama kaydı

## 28 Ağustos 2026

Mobil giriş akışı şirketin mevcut ASP.NET Core Identity tablo biçimine karşı,
gerçek HTTP istekleriyle doğrulandı. Test yalnız geçici SQL Server veritabanında
çalıştı; sosyobel şeması ve uygulama uyumluluk migration'ları kullanılmadı.
Geçici kullanıcı, token kayıtları ve veritabanı test sonunda kaldırıldı.

| Senaryo | Sonuç |
| --- | --- |
| Backend Release derlemesi | 0 hata, 0 uyarı |
| Backend birim testleri | 68/68 başarılı |
| Yanlış parola | 401 |
| Kullanıcı adı ve parolayla giriş | Başarılı |
| Mevcut Identity rolü | Personel |
| municipalityCode alanı | Dönmüyor |
| JWT ile /api/v1/auth/me | Başarılı |
| Refresh token rotasyonu | Başarılı |
| Çıkış | 204 |
| Çıkış sonrasında refresh token | 401 |

Tekrarlanabilir yerel doğrulama:

    ./backend/scripts/validate-identity-login.ps1

Betik yalnız SosyoBelIdentityValidation_<guid> adlı geçici veritabanı oluşturur.
Standart dbo.AspNetUsers, dbo.AspNetRoles ve diğer beş Identity tablosunu temsil
eden test fixture'ını kullanır. Şirketin test veya canlı veritabanına karşı
çalıştırılmamalıdır.

## Doğrulanan veri sınırı

- Kullanıcı ve roller mevcut dbo.AspNet* tablolarından okunur.
- Mobil API kullanıcı, rol veya belediye kaydı oluşturmaz.
- Admin, Kurul ve Personel rolleri mobil personel işlemlerine girebilir.
- Login isteğinde ve cevabında belediye kodu bulunmaz.
- Refresh tokenın açık değeri tutulmaz; hash ve oturum bilgisi mevcut
  dbo.AspNetUserTokens tablosunda SosyoBel.Api sağlayıcı adıyla saklanır.
