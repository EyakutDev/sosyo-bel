# Şirket Veritabanı Uyumluluk Planı

## Belgenin amacı

Bu belge, Cats Yazılım tarafından paylaşılan `sosyaldb.ipynb` şeması ile
Sosyo-Bel backend'inin mevcut veri ihtiyaçlarını eşleştirir. Amaç, çalışan mobil
uygulamanın API sözleşmesini korurken şirketin mevcut `dbo` tablolarını veri
kaybına yol açmadan kullanmaktır.

Analizin ardından ilk eklemeli uyumluluk migration'ı hazırlanmış ve yalnız
benzersiz isimli geçici yerel veritabanında apply/check/smoke/rollback döngüsüyle
doğrulanmıştır. Herhangi bir şirket test veya canlı veritabanında migration
çalıştırılmamıştır.

## Kaynak ve doğrulama sınırı

- İncelenen notebook'taki DDL, `3 Ağustos 2026 19:17:54` tarihli şema çıktısıdır.
- Notebook, uyumluluk tasarımının üzerinde çalışılacağı şirket şeması olarak
  kabul edilir.
- Canlı/test veritabanının notebook ile aynı olduğu varsayılmaz. İlk kurulumdan
  önce `database/compatibility/000_inspect_company_schema.sql` salt-okunur
  betiği gerçek hedefte çalıştırılmalıdır.
- KPS entegrasyonu bu çalışmanın kapsamı dışındadır ve servis sözleşmesi
  sağlandıktan sonra ayrıca ele alınacaktır.

## Değiştirilmeyecek sınırlar

1. Mevcut `dbo` tabloları silinmeyecek veya yeniden adlandırılmayacak.
2. Mevcut kolonların veri tipi, uzunluğu ve null davranışı onay alınmadan
   değiştirilmeyecek.
3. Mevcut veriler toplu olarak güncellenmeyecek veya dönüştürülmeyecek.
4. Mobil ekranlar ve yayımlanmış API istek/cevap modelleri bu uyarlama nedeniyle
   değiştirilmeyecek.
5. Mobil uygulama SQL Server'a doğrudan bağlanmayacak; bütün erişim backend API
   üzerinden yapılacak.
6. Şirket veritabanında değişiklik yapılmadan önce yedek, test kopyası, yetkili
   onayı ve geri dönüş betiği bulunacak.

## En kritik bulgular

### Temiz kurulum migration zinciri şirkete uygulanamaz

`database/migrations/000_create_aspnet_identity_schema.sql`,
`dbo.AspNetUsers` mevcutsa bilinçli olarak çalışmayı reddeder. Şirket şemasında
bu tablo zaten vardır. `004_harden_identity_tasks_and_idempotency.sql` ise
mevcut `AspNetUsers` tablosuna yeni kolonlar eklemeye çalışır.

Bu nedenle `000`–`005` zinciri yalnız boş yerel geliştirme veritabanları içindir.
Şirket veritabanına sırayla veya parça parça uygulanmayacaktır. Şirket şeması
için ayrı, eklemeli ve yeniden çalıştırılabilir bir uyumluluk zinciri
hazırlanacaktır.

### Identity anahtar uzunluğu farklıdır

Şirket şemasındaki `AspNetUsers.Id`, `AspNetRoles.Id` ve bunlara bağlı kullanıcı
anahtarları `nvarchar(450)` kullanır. Mevcut backend modelinin temiz kurulum
eşlemesi bu alanları `nvarchar(128)` kabul eder.

Uyumluluk modelinde Identity anahtarları `450` karakter olarak eşlenecek. Yeni
tablolarda `AspNetUsers.Id` alanına bağlanan yabancı anahtarlar da aynı tip ve
uzunlukta oluşturulacaktır. Mevcut kullanıcı kimlikleri kısaltılmayacaktır.

### Başvuru tablosu kullanılabilir fakat API metadatası eksiktir

`dbo.Basvurular`, formdaki vatandaş, iletişim, engel, yardım, durum ve KPS adres
alanlarının büyük bölümünü zaten taşır. Bu tablo şirketin web başvurularıyla
ortak veri sınırı olabileceği için başvuru kaydının ana tablosu olarak korunur.

API'nin ihtiyaç duyduğu aşağıdaki teknik alanlar şirkette aynı anlamla yoktur:

- Kararlı dış kimlik (`Guid`)
- API'de gösterilen başvuru numarası
- Saha inceleme notu
- Son güncelleyen kullanıcı ve zaman
- Kurula gönderen kullanıcı ve zaman
- Eşzamanlı güncellemeyi koruyan `rowversion`

`PublicToken` alanının amacı doğrulanmadığı için bu alan `Guid` yerine
kullanılmayacaktır. Teknik alanlar, `dbo.Basvurular.Id` değerine bire bir bağlı
bir `sosyobel.BasvuruUygulamaBilgileri` tablosunda tutulacaktır.

## Tablo bazında uyumluluk matrisi

| Alan | Şirket şeması | Mevcut backend beklentisi | Güvenli hedef |
| --- | --- | --- | --- |
| Kullanıcılar | `dbo.AspNetUsers`; `Id` 450 karakter, `Ad` ve `Soyad` var | Aktiflik, audit ve `RowVersion` aynı tabloda | Identity tablosunu koru; uygulamaya özel hesap durumunu bire bir ek tabloda tut |
| Roller | `dbo.AspNetRoles` ve standart Identity ilişki tabloları | `ADMIN`, `PERSONEL` rollerini Identity üzerinden kullanır | Mevcut Identity tablolarını ve kayıtlarını doğrudan kullan |
| Başvurular | `dbo.Basvurular` | `sosyobel.Basvurular` ve ek teknik alanlar | İş verisini `dbo.Basvurular` içinde; API metadatasını bire bir ek tabloda tut |
| Başvuru durumu | `dbo.BasvuruDurumlari`: `Name`, `Sil` | Kararlı `Kod`, `AktifMi` | Eski satırları koru; kimliklere kararlı kod bağlayan ek eşleme tablosu kullan |
| Yardım/engel/kanal | `Name`, `Sil` içeren mevcut lookup tabloları | `Kod`, `AktifMi`, bazı kayıtlarda belediye kapsamı | Mevcut kimlikleri kullan; kodları ek eşleme tablosunda tut |
| Vatandaş | `dbo.Vatandaslar`; KPS ve adres kolonları mevcut | Normalize alanlar ve belediye kapsamı | Mevcut tabloyu kullan; tek belediye kararına göre gereksiz tenant kolonu ekleme |
| Başvuru aile fertleri | `dbo.BasvuruAileFertleri` temel alanları taşıyor | Yaşam durumu, diğer yakınlık açıklaması, engel açıklaması ve audit | Temel kaydı mevcut tabloda, eksik alanları bire bir ek tabloda tut |
| Kalıcı aile dizini | `dbo.AileFertleri` vatandaşa bağlı | `SaveToBeneficiaryDirectory` davranışı kesin değil | Tabloyu koru; iş kuralı onaylanana kadar otomatik yazma yapma |
| Hane soruları | Karşılık yok | Soru, seçenek ve başvuru cevabı tabloları | Yeni `sosyobel` tabloları ekle |
| Hane fotoğrafları | `dbo.HaneFotograflari` vatandaşa bağlı; `Basvurular` tek yol alanı taşıyor | Başvuruya bağlı, sıralı, silinebilir en fazla 15 fotoğraf | Eski alanları koru; yeni başvuruya bağlı fotoğraf tablosu ekle |
| Durum geçmişi | Karşılık yok | Her durum geçişi için audit kaydı | Yeni `sosyobel.BasvuruDurumGecmisi` ekle |
| Kurul işlemleri | `dbo.KurulIslemleri` vatandaşa bağlı | Başvuruya bağlı karar | Eski tabloyu koru; kurul akışı kesinleşince başvuru bağlantısı için ek tablo/bağlantı tasarla |
| Saha görevleri | `dbo.SahaAktiviteleri` vatandaşa ve personele bağlı | Başvuruya ve personele bağlı görev | Mevcut üretici akışını incelemeden yeni tabloya geçme; başvuru bağlantısı ayrıca doğrulanacak |
| Refresh token | Karşılık yok | Mobil oturum yenileme | Yeni `sosyobel.YenilemeTokenlari` ekle |
| Idempotency | Karşılık yok | Tekrarlanan oluşturma/yükleme isteğini güvenli karşılar | Yeni `sosyobel.IdempotencyKayitlari` ekle |
| Belediye üyeliği | Şemada doğrudan karşılık yok; `SistemAyarlari` bulunuyor | Belediye ve kullanıcı üyeliği | Tek belediye için ek tablolarda tek kayıt/üyelik kullan; iş tablolarına zorla `BelediyeId` ekleme |
| Stok/paket/yardım dağıtımı | Mevcut `dbo` tabloları var | Mevcut mobil akış kullanmıyor | Tabloları olduğu gibi koru; kapsam onayı olmadan backend'e alma |

## Tamamlayıcı tablo hedefleri

`BasvuruUygulamaBilgileri`, `ReferansKodlari` ve
`KullaniciUygulamaBilgileri`, compatibility 001 migration'ında eklemeli olarak
hazırlanmıştır. Giriş desteği için `Belediyeler`, `KullaniciBelediyeleri`,
`KullaniciYetkileri`, `IslemGecmisleri`, `IdempotencyKayitlari` ve
`YenilemeTokenlari` compatibility 002 migration'ında eklenmiştir.
`BasvuruDurumGecmisi` compatibility 003 migration'ında eklenmiştir.

`YasamDurumlari` ve `BasvuruAileFertiUygulamaBilgileri` compatibility 004
migration'ında hazırlanmıştır. Ana aile alanları yeni tabloya kopyalanmaz;
`dbo.BasvuruAileFertleri` doğrudan kullanılır.

`HaneSorulari`, `HaneSoruSecenekleri` ve `BasvuruHaneCevaplari`
compatibility 005 migration'ında hazırlanmıştır. Şirket şemasında bu işlevin
karşılığı olmadığı için tablolar yalnız `sosyobel` altında tutulur.

`BasvuruFotograflari` compatibility 006 migration'ında hazırlanmıştır.
Şirketin vatandaşa bağlı eski `dbo.HaneFotograflari` tablosu ve tek yol alanı
değiştirilmez. 001-006 migration zinciri yerel geçici şirket şeması kopyasında
tekrar çalıştırma, kontrol, smoke ve rollback testlerinden geçmiştir. Aile,
beş hane cevabı ve fotoğraf yükleme/değiştirme akışı ayrıca gerçek HTTP
istekleriyle doğrulanmıştır.

001-003 migration'ları seed veya mevcut kayıtlara backfill yapmaz. 004 yalnız
uygulamanın zorunlu teknik `SAG` ve `OLU` kodlarını kendi `sosyobel` tablosuna
ekler. 005, mobil formdaki beş soru ve on altı seçeneği yalnız kendi yeni
referans tablolarına ekler. 006 seed yazmaz ve yalnız fotoğraf metadatası için
yeni tablo oluşturur. Hiçbir migration `dbo` verisini güncellemez.
`BasvuruNo` kurum
biçimi kesinleşene kadar nullable'dır. Bu süre boyunca API yalnız gösterim için
`dbo.Basvurular.Id` değerini kullanır ve bunu kurum numarası olarak veritabanına
yazmaz. Listedeki diğer tablolar tasarım hedefidir ve ayrı görevlerde
hazırlanacaktır.

| Yeni tablo | Bağlantı | Amaç |
| --- | --- | --- |
| `sosyobel.BasvuruUygulamaBilgileri` | `dbo.Basvurular.Id` ile bire bir | PublicId, başvuru numarası, saha notu, gönderim/güncelleme bilgisi ve RowVersion |
| `sosyobel.BasvuruAileFertiUygulamaBilgileri` | `dbo.BasvuruAileFertleri.Id` ile bire bir | Yaşam durumu, diğer yakınlık ve engel açıklaması, audit |
| `sosyobel.YasamDurumlari` | Aile ferdi teknik uzantısı | Kararlı `SAG` ve `OLU` yaşam durumu kodları |
| `sosyobel.ReferansKodlari` | Referans türü + mevcut satır kimliği | API'nin kullandığı değişmez kodları mevcut lookup satırlarına bağlama |
| `sosyobel.HaneSorulari` | Bağımsız referans | Yönetilebilir hane soruları |
| `sosyobel.HaneSoruSecenekleri` | Hane sorusu | Yönetilebilir cevap seçenekleri |
| `sosyobel.BasvuruHaneCevaplari` | `dbo.Basvurular.Id` | Saha personelinin başvuru bazlı cevapları |
| `sosyobel.BasvuruFotograflari` | `dbo.Basvurular.Id` | En fazla 15 fotoğraf, sıra, dosya metadatası ve silme auditi |
| `sosyobel.BasvuruDurumGecmisi` | `dbo.Basvurular.Id` | Taslak ve kurul geçişlerinin geçmişi |
| `sosyobel.KullaniciUygulamaBilgileri` | `dbo.AspNetUsers.Id` ile bire bir | Aktiflik, hesap kapatma ve uygulama auditi |
| `sosyobel.YenilemeTokenlari` | `dbo.AspNetUsers.Id` | Hashlenmiş mobil refresh tokenları |
| `sosyobel.IdempotencyKayitlari` | `dbo.AspNetUsers.Id` | Tekrarlanan yazma isteklerini güvenli biçimde karşılama |

## API sözleşmesini koruyacak eşlemeler

| API alanı | Şirket veya ek tablo kaynağı |
| --- | --- |
| `applicationPublicId` | `sosyobel.BasvuruUygulamaBilgileri.PublicId` |
| `applicationNumber` | Kurum biçimi onaylanana kadar yalnız API cevabında `dbo.Basvurular.Id`; onay sonrası ek tablodaki `BasvuruNo` |
| `identityNumber` | `dbo.Basvurular.BasvuranTcKimlikNo` |
| `birthDate` | `dbo.Basvurular.BasvuranDogumTarihi`; yeni mobil kayıtlar ISO `yyyy-MM-dd`, mevcut kayıt biçimleri ayrıca doğrulanacak |
| `phoneNumber` | `dbo.Basvurular.BasvuranTelefon` |
| `helpTypeCode` | `dbo.Basvurular.YardimTuruId` + `sosyobel.ReferansKodlari` |
| `disabilityTypeCode` | `dbo.Basvurular.EngelTuruId` + `sosyobel.ReferansKodlari` |
| `statusCode` | `dbo.Basvurular.BasvuruDurumuId` + `sosyobel.ReferansKodlari` |
| `familyMembers` | `dbo.BasvuruAileFertleri` + aile ferdi ek bilgileri |
| `householdAnswers` | `sosyobel.BasvuruHaneCevaplari` |
| Fotoğraflar | `sosyobel.BasvuruFotograflari` |
| `rowVersion` | `sosyobel.BasvuruUygulamaBilgileri.RowVersion` |

## Uygulama aşamaları

### Aşama 1 — Salt-okunur keşif

1. Kontrol betiğini şirketin test veritabanında çalıştır.
2. Eksik/farklı tablo, kolon, tip, uzunluk ve foreign key sonuçlarını kaydet.
3. Mevcut lookup satırlarını ve başvuru doğum tarihi biçimlerini kişisel veri
   göstermeden özetle.
4. SQL Server sürümünü ve compatibility level değerini kaydet.

Bu aşamada hiçbir migration çalıştırılmaz.

### Aşama 2 — Backend uyumluluk katmanı

1. Identity anahtar uzunluğunu şirket şemasına eşle.
2. `ApplicationUser` içindeki şirkette bulunmayan alanları ayrı uygulama profili
   kaydına taşı.
3. Başvuru persistence modelini `dbo.Basvurular` ve tamamlayıcı tablo üzerinden
   çalışacak biçimde değiştir.
4. Lookup adlarına güvenmek yerine onaylı kod eşlemelerini kullan.
5. Mevcut HTTP endpointlerini ve Flutter repository sözleşmelerini değiştirme.

### Aşama 3 — Eklemeli migration

1. Yalnız yeni `sosyobel` tablolarını oluştur.
2. Bütün foreign key kolonlarını mevcut anahtarlarla aynı tipte tanımla.
3. Betiği yeniden çalıştırılabilir ve transaction kontrollü hazırla.
4. Önce boş şema kopyasında, sonra veri içeren anonim test kopyasında doğrula.
5. Migration ile birlikte ayrı doğrulama ve geri dönüş betiği sağla.

### Aşama 4 — Davranış doğrulaması

1. Mevcut web başvurusunun mobil bekleyen listesinde görüldüğünü doğrula.
2. Taslak kaydetme ve yeniden açma akışını doğrula.
3. Manuel aile bilgilerini doğrula.
4. On beş fotoğraf sınırı ve silme davranışını doğrula.
5. Kurula gönderilen başvurunun düzenlenemediğini doğrula.
6. Mevcut kullanıcılarla `ADMIN` ve `PERSONEL` yetkilerini doğrula.

## Kodlamadan önce cevaplanması gerekenler

- Test veritabanı gerçekten notebook ile aynı şema sürümünde mi?
- `BasvuranDogumTarihi` mevcut kayıtlarda hangi biçim veya biçimlerde tutuluyor?
- `PublicToken` mevcut web uygulamasında hangi amaçla kullanılıyor?
- Web uygulaması başvuru ve saha görevi oluştururken hangi tabloları yazıyor?
- `SahaAktiviteleri` satırı ile belirli bir başvuru arasında mevcut bir bağ var mı?
- Başvuru numarasının kurum tarafından beklenen biçimi nedir?
- Lookup tablolarındaki gerçek satırlar hangi API kodlarına karşılık geliyor?
- Yeni `sosyobel` şeması ve yeni tablolar için şirket DBA onayı var mı?

Bu sorular cevaplanmadan ilgili davranışlar için varsayımla veri dönüşümü veya
canlı migration yazılmayacaktır.
