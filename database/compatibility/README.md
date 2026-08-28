# Şirket Veritabanı Uyumluluk Betikleri

Bu klasör, Cats Yazılım tarafından paylaşılan mevcut `dbo` şemasını koruyarak
Sosyo-Bel mobil API ihtiyaçlarını ek tablolarla tamamlar. Buradaki dosyalar,
`database/migrations` altındaki boş veritabanı kurulum zincirinden bağımsızdır.

## Güvenli çalışma sırası

Şirket ortamında herhangi bir değişiklik yapılmadan önce:

1. Veritabanı yedeği ve yetkili DBA onayı alınır.
2. `000_inspect_company_schema.sql` salt-okunur çalıştırılır.
3. Sonuçlarda zorunlu `dbo` tabloları, kolonlar, PK/FK tipleri ve lookup yapıları
   doğrulanır; belirsizlik varsa hiçbir migration çalıştırılmaz.
4. Aynı şemanın veri içeren anonim test kopyası hazırlanır.
5. `migrations/001_create_foundation_extensions.sql` test kopyasında uygulanır.
6. `checks/001_verify_foundation_extensions.sql` çalıştırılır.
7. `migrations/002_create_auth_support.sql` test kopyasında uygulanır.
8. `checks/002_verify_auth_support.sql` çalıştırılır.
9. `migrations/003_create_application_core_support.sql` test kopyasında uygulanır.
10. `checks/003_verify_application_core_support.sql` çalıştırılır.
11. `migrations/004_create_application_family_support.sql` test kopyasında uygulanır.
12. `checks/004_verify_application_family_support.sql` çalıştırılır.
13. `migrations/005_create_application_household_support.sql` test kopyasında uygulanır.
14. `checks/005_verify_application_household_support.sql` çalıştırılır.
15. `migrations/006_create_application_photo_support.sql` test kopyasında uygulanır.
16. `checks/006_verify_application_photo_support.sql` çalıştırılır.
17. `migrations/007_add_kps_lookup_permission.sql` test kopyasında uygulanır.
18. `checks/007_verify_kps_lookup_permission.sql` çalıştırılır.
19. `migrations/008_remove_application_municipality_scope.sql` test kopyasında uygulanır.
20. `checks/008_verify_application_single_municipality.sql` çalıştırılır.
21. API uyumluluk testleri tamamlanmadan canlı veritabanına geçilmez.

## 001 foundation kapsamı

Migration yalnız şu yeni tabloları oluşturur:

- `sosyobel.BasvuruUygulamaBilgileri`
- `sosyobel.ReferansKodlari`
- `sosyobel.KullaniciUygulamaBilgileri`

Mevcut `dbo` tablolarında `ALTER`, veri güncelleme veya otomatik backfill
yapılmaz. Lookup adlarından API kodu tahmin edilmez ve seed eklenmez.
`BasvuruNo`, kurumun numara biçimi kesinleşmediği için bu aşamada nullable'dır.

Yeni kullanıcı foreign key alanları, şirket şemasındaki
`dbo.AspNetUsers.Id = nvarchar(450)` yapısıyla aynı uzunluktadır. Migration bu
tipi, kolasyonu, başvuru anahtarını ve lookup primary key yapılarını başlamadan
önce doğrular.

## 002 auth destek kapsamı

Migration yalnız giriş ve kullanıcı yönetimi için gereken şu yeni tabloları
oluşturur:

- `sosyobel.Belediyeler`
- `sosyobel.KullaniciBelediyeleri`
- `sosyobel.KullaniciYetkileri`
- `sosyobel.IslemGecmisleri`
- `sosyobel.IdempotencyKayitlari`
- `sosyobel.YenilemeTokenlari`

Kullanıcı foreign key alanları şirket Identity anahtarıyla aynı
`nvarchar(450)` tipindedir. Migration belediye, kullanıcı üyeliği veya rol seed'i
yazmaz. Gerçek kurum değerleri doğrulanmadan mevcut `dbo.AspNetRoles` kayıtları
değiştirilmez.

## 003 başvuru çekirdeği kapsamı

Migration yalnız `sosyobel.BasvuruDurumGecmisi` tablosunu oluşturur. Ana form
verisi `dbo.Basvurular`, teknik kimlik ve eşzamanlılık bilgisi ise
`sosyobel.BasvuruUygulamaBilgileri` içinde kalır. Durum geçmişi append-only'dir;
mevcut `dbo` nesnelerine kolon veya veri eklenmez.

## 004 aile bilgileri kapsamı

Ana aile kaydı şirketin mevcut `dbo.BasvuruAileFertleri` tablosuna yazılır.
Migration yalnız bu tabloda bulunmayan yaşam durumu ve audit alanları için
`sosyobel.BasvuruAileFertiUygulamaBilgileri` tablosunu, kararlı `SAG` ve
`OLU` kodları için de `sosyobel.YasamDurumlari` tablosunu oluşturur.
Şirketin `dbo` tablolarına kolon, seed veya backfill yazmaz.

## 005 hane durumu kapsamı

Şirket şemasında hane sorusu ve başvuru cevabı karşılığı bulunmadığı için
migration yalnız `sosyobel.HaneSorulari`, `sosyobel.HaneSoruSecenekleri` ve
`sosyobel.BasvuruHaneCevaplari` tablolarını oluşturur. Mobil formdaki beş soru
ve on altı seçenek kararlı kodlarla bu yeni referans tablolarına eklenir.
Cevaplar şirketin `dbo.Basvurular.Id` kaydına foreign key ile bağlanır;
hiçbir mevcut `dbo` tablosu veya satırı değiştirilmez.

## 006 fotoğraf kapsamı

Şirketin `dbo.HaneFotograflari` tablosu vatandaşa, 
`dbo.Basvurular.HaneFotografYolu` alanı tek bir yola bağlıdır. Mobil akışın
başvuruya bağlı, sıralı ve en fazla 15 fotoğraf ihtiyacı
`sosyobel.BasvuruFotograflari` tablosunda tutulur. SQL Server dosya içeriğini
değil; özel depolama anahtarı, MIME türü, boyut, sıra ve SHA-256 özetini saklar.
Taslakta yeni toplu yükleme aktif fotoğraf anlık kopyasını değiştirir. Eski
metadata audit için silinmiş olarak kalır; artık kullanılmayan fiziksel dosya
kontrollü biçimde temizlenir. Kurula gönderilmiş başvuruda yükleme reddedilir.

## 007 KPS yetkisi kapsamı

Migration yeni tablo veya kullanıcı yetki kaydı oluşturmaz.
`sosyobel.KullaniciYetkileri` tablosundaki uygulamaya ait kontrol kısıtını,
`KILITLI_BASVURU_DUZENLE` yanında `KPS_SORGULA` koduna da izin verecek şekilde genişletir.
Beklenen kontrol kısıtının sahipliği doğrulanamazsa işlem durur; yeniden
çalıştırıldığında mevcut kurulum korunur ve hiçbir `dbo` nesnesine dokunulmaz.

## 008 tek belediye başvuru kapsamı

Mobil uygulama tek belediyeye ait olduğu için hane soruları, hane cevapları ve
fotoğraf metadata kayıtları ayrı bir `BelediyeId` taşımaz. 008, daha önce eski
005/006 betikleriyle kurulmuş tablolardaki bu teknik kolonu ve ilişkileri kaldırır.
Aynı soru kodundan birden fazla kayıt varsa hangisinin korunacağına karar vermez;
veri silmek yerine güvenli biçimde durur. Mevcut `dbo` tablolarını değiştirmez.

## Yerel doğrulama

Geçici veritabanında apply/check/smoke/rollback döngüsü:

```powershell
./backend/scripts/validate-database-compatibility.ps1
```

Script yalnız `SosyoBelCompatibilityValidation_<guid>` biçiminde oluşturduğu
geçici veritabanını hedefler ve test sonunda kaldırır. Fixture ve smoke SQL
dosyaları şirket ortamında çalıştırılmaz.

Şirketle uyumlu Identity şemasında giriş/oturum işlemlerinin yanında taslak
başvuru oluşturma, okuma, güncelleme, kurula gönderme, manuel aile/hane kaydı,
multipart fotoğraf yükleme, idempotency replay, taslak fotoğraf değiştirme ve
gönderim sonrası düzenleme kilidini gerçek HTTP istekleriyle doğrulamak için:

```powershell
./backend/scripts/validate-auth-flow.ps1
```

Bu script de yalnız `SosyoBelAuthValidation_<guid>` adlı geçici veritabanını ve
sistem temp klasöründeki izole API derlemesini kullanır; test hesabı dahil tüm
geçici verileri çalışma sonunda kaldırır.
`tests/007_expand_company_identity_fixture.sql` ve
`tests/009_expand_company_application_fixture.sql` ile
`tests/010_expand_company_family_fixture.sql` ve
`tests/014_expand_company_photo_fixture.sql` ve
`tests/016_expand_company_field_task_fixture.sql` yalnız bu yerel doğrulama
için şirket tablolarını taklit eder ve şirket ortamında çalıştırılmaz.

## Rollback

`rollbacks/001_drop_foundation_extensions.sql` yalnız 001 ile eklenen üç tabloyu,
`rollbacks/002_drop_auth_support.sql` yalnız 002 ile eklenen altı tabloyu hedefler.
`rollbacks/003_drop_application_core_support.sql` yalnız durum geçmişi tablosunu
hedefler. `rollbacks/004_drop_application_family_support.sql` ise yalnız 004
sahiplik etiketiyle oluşturulan aile teknik tablolarını hedefler.
`rollbacks/005_drop_application_household_support.sql` yalnız 005 sahiplik
etiketli hane tablolarını, önce cevap sonra seçenek ve soru sırasıyla hedefler.
`rollbacks/006_drop_application_photo_support.sql` yalnız 006 sahiplik etiketli
fotoğraf metadata tablosunu hedefler.
`rollbacks/007_remove_kps_lookup_permission.sql`, yalnız hiç `KPS_SORGULA`
yetki kaydı yoksa kontrol kısıtını önceki kapsama döndürür; herhangi bir kullanıcı
yetki kaydını silmez.
İlgili tablolardan herhangi biri veri içeriyorsa veri kaybını önlemek için işlem
reddedilir. Betikler `sosyobel` şemasını ve hiçbir `dbo` nesnesini silmez.

Rollback canlı ortamda olağan sürüm düşürme yöntemi değildir. Veri oluşmuşsa
önce şirketin saklama/aktarım kararı ve DBA onayı gerekir.
