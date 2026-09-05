# Sosyo-Bel API

Bu belge API'yi yerelde çalıştıracak veya IIS'e kuracak ekip içindir. API,
şirketin mevcut SQL Server veritabanını kullanır; canlı veritabanına migration
uygulamaz, yeni tablo veya kolon üretmez.

Kodun katmanları ve okuma sırası `backend/API_ARCHITECTURE.md`
dosyasında açıklanmıştır.

## Veritabanı sözleşmesi

API'nin aktif akışı yalnız mevcut `dbo` tablolarına bağlıdır:

- Kimlik doğrulama: `AspNetUsers`, `AspNetRoles`,
  `AspNetUserRoles` ve diğer standart Identity tabloları
- Refresh oturumu: mevcut `AspNetUserTokens`
- Başvuru: `Basvurular`, `BasvuruAileFertleri`,
  `HaneFotograflari`
- Vatandaş: `Vatandaslar`
- İş listesi: `Basvurular`, `BasvuruDurumlari`,
  `SahaAktiviteleri`
- Referanslar: `YardimTurleri`, `EngelTurleri`,
  `TalepGelisKanallari`, `Yakinliklar`,
  `CalismaDurumlari`, `EgitimDurumlari`,
  `Mahalleler` ve `Sokaklar`

`database/` ve `backend/scripts/initialize-local-development.ps1`
yerel/uyumluluk çalışmalarından kalmıştır. Şirket test veya canlı veritabanında
çalıştırılmaz.

## Yerelde çalıştırma

Repository kökünde:

```powershell
dotnet restore backend\SosyoBel.Backend.sln

$env:ASPNETCORE_ENVIRONMENT="Development"
$env:ConnectionStrings__SosyoBel="Server=localhost;Database=SirketDbTestKopyasi;Integrated Security=True;Encrypt=True;TrustServerCertificate=True"
$env:ApplicationPhotos__RootPath="C:\sosyobel-test\uploads\hanefotograflari"
$env:Kps__BaseUrl="http://localhost:8090"

$keyBytes = New-Object byte[] 32
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
try {
    $rng.GetBytes($keyBytes)
}
finally {
    $rng.Dispose()
}
$env:Authentication__Jwt__SigningKeyBase64=[Convert]::ToBase64String($keyBytes)

dotnet run --project backend\src\SosyoBel.Api\SosyoBel.Api.csproj --urls http://localhost:5000
```

API şema üretmediği için test veritabanında gerekli dbo tabloları ve referans
kayıtları önceden bulunmalıdır.

## Yapılandırma

Gizli veya ortama özel değerleri repository'ye yazmayın. Ortam değişkenlerinde
JSON'daki iki nokta yerine çift alt çizgi kullanılır.

| Ortam değişkeni | Zorunlu | Açıklama |
| --- | --- | --- |
| `ConnectionStrings__SosyoBel` | Evet | Şirket SQL Server bağlantısı |
| `Authentication__Jwt__SigningKeyBase64` | Evet | En az 32 byte Base64 JWT anahtarı |
| `Authentication__Jwt__Issuer` | Hayır | Varsayılan `SosyoBel.Api` |
| `Authentication__Jwt__Audience` | Hayır | Varsayılan `SosyoBel.Mobile` |
| `Authentication__Jwt__AccessTokenMinutes` | Hayır | 5-60 dakika, varsayılan 15 |
| `Authentication__Session__RefreshTokenDays` | Hayır | 1-90 gün, varsayılan 30 |
| `ApplicationPhotos__RootPath` | Evet | Fotoğrafların fiziksel kök klasörü |
| `FileErrorLogging__DirectoryPath` | Dosya logu için evet | Sunucudaki özel log klasörü; boşsa güvenli konsol çıktısı |
| `FileErrorLogging__RetentionDays` | Hayır | Varsayılan 14 gün |
| `FileErrorLogging__MaxFileSizeMB` | Hayır | Tek dosya sınırı; varsayılan 10 MB |
| `FileErrorLogging__MaxTotalSizeMB` | Hayır | Bu API'nin loglarının toplam sınırı; varsayılan 200 MB |
| `Kps__BaseUrl` | KPS için evet | Kurum KPS servisinin kök adresi |
| `Kps__TimeoutSeconds` | Hayır | Varsayılan 30 saniye |
| `OpenApi__Enabled` | Hayır | Swagger; Production'da varsayılan kapalı |

JWT anahtarı tüm API düğümlerinde aynı olmalı ve güvenli şekilde saklanmalıdır.
Anahtar değişirse mevcut access tokenlar geçersiz olur.

## Güncel endpointler

| Metot | Endpoint |
| --- | --- |
| GET | `/` |
| GET | `/health/live` |
| GET | `/health/ready` |
| POST | `/api/v1/auth/login` |
| POST | `/api/v1/auth/refresh` |
| POST | `/api/v1/auth/logout` |
| GET | `/api/v1/auth/me` |
| GET | `/api/v1/application-references` |
| GET | `/api/v1/kps/profile` |
| POST | `/api/v1/applications/submit` |
| GET | `/api/v1/work-items/mine` |

Swagger bu listenin çalıştırılabilir sözleşmesidir. Kaynak kodda yardımcı metot
bulunması, o metodun endpoint olarak yayımlandığı anlamına gelmez.

## Swagger ile doğrulama

Development ortamında `http://localhost:5000/swagger` adresini açın.
Önce `POST /api/v1/auth/login` ile şirketin mevcut Admin, Kurul veya
Personel hesabını kullanın. Başarılı yanıttaki `accessToken` değerini
**Authorize** alanına tek başına yapıştırın.

Önerilen sıra:

1. `GET /health/live`
2. `GET /health/ready`
3. `POST /api/v1/auth/login`
4. `GET /api/v1/auth/me`
5. `GET /api/v1/application-references`
6. Onaylı test verisiyle `GET /api/v1/kps/profile`
7. Hazırlanan örnekle `POST /api/v1/applications/submit`
8. `GET /api/v1/work-items/mine`

Başvuru gönderimi `multipart/form-data` kullanır. `payload` JSON,
`photos` dosya alanıdır ve 8-100 karakterlik
`Idempotency-Key` başlığı zorunludur.

## IIS'e yayın

### 1. Sunucu gereksinimleri

- Windows Server ve IIS
- ASP.NET Core Hosting Bundle / .NET 10 Runtime
- SQL Server'a ağ erişimi
- Kurum KPS servisine sunucudan ağ erişimi
- Geçerli HTTPS sertifikası

Hosting Bundle IIS'ten sonra kurulmalı; kurulumdan sonra IIS yeniden
başlatılmalıdır.

### 2. Publish çıktısı

Repository kökünde:

```powershell
dotnet publish backend\src\SosyoBel.Api\SosyoBel.Api.csproj --configuration Release --output .\artifacts\publish\api
```

`artifacts\publish\api` içeriğini sunucudaki sürümlü bir klasöre
kopyalayın. Kaynak kodu veya `database/` klasörünü IIS dizinine koymak
gerekmez.

### 3. Application Pool

- Ayrı bir Application Pool kullanın.
- **.NET CLR Version**: **No Managed Code**
- **Managed pipeline mode**: **Integrated**
- 64 bit kurulumda **Enable 32-Bit Applications**: **False**
- Application Pool kimliğini SQL ve fotoğraf klasörü izinlerinde kullanın.

Site altında ayrı bir IIS Application oluşturulabilir. Örneğin uygulama yolu
`/sosyobel` ise mobil taban adresi
`https://test.example.com/sosyobel/` olur.

### 4. Ortam ayarları

Production değerlerini kaynak koda veya README'ye yazmayın. IIS Configuration
Editor içindeki `system.webServer/aspNetCore` environment variables alanı,
sunucu seviyesindeki güvenli ortam değişkenleri veya kurumun secret yönetimi
kullanılabilir.

En az şu değerler tanımlanmalıdır:

```text
ASPNETCORE_ENVIRONMENT=Production
ConnectionStrings__SosyoBel=...
Authentication__Jwt__SigningKeyBase64=...
ApplicationPhotos__RootPath=...
Kps__BaseUrl=...
Kps__TimeoutSeconds=30
OpenApi__Enabled=false
```

Güvenilir test ortamında Swagger gerekiyorsa
`OpenApi__Enabled=true` verilebilir. İnternete açık canlı ortamda anonim
Swagger bırakılmamalıdır.

### 5. SQL erişimi

Windows Authentication kullanılacaksa Application Pool kimliği SQL Server'da
login/user olarak tanımlanır. API'nin çalışma hesabı:

- Identity tablolarında login ve refresh oturumu için okuma/yazma,
- başvuru tablolarında gerekli okuma ve ekleme,
- vatandaş, görev, adres ve referans tablolarında okuma

yetkisine sahip olmalıdır. Yetkiyi `db_owner` vermek yerine kurumun DBA
ekibi kullanılan tablolara en az ayrıcalık ilkesine göre vermelidir.

API migration çalıştırmaz; IIS kurulumu sırasında
`dotnet ef database update` veya herhangi bir compatibility SQL'i
çalıştırılmaz.

### 6. Fotoğraf klasörü

Şirket web uygulaması `dbo.HaneFotograflari.FotografYolu` değerini
`/uploads/hanefotograflari/...` biçiminde kullanır. `ApplicationPhotos__RootPath`,
doğrudan bu alt klasörün fiziksel yolu olmalıdır; yalnız `uploads` klasörünü
göstermemelidir. Kurumun bildirdiği yol için IIS ortam ayarı:

```text
ApplicationPhotos__RootPath=C:\inetpub\wwwroot\sosyalyardim\wwwroot\uploads\hanefotograflari
```

Bu değer sunucuda tanımlanır; uygulama koduna veya varsayılan `appsettings.json`
dosyasına sabitlenmez. Ortam değişkeni adı `ApplicationPhotos__RootPath`, JSON
ayar karşılığı ise `ApplicationPhotos:RootPath` şeklindedir.

API, bu klasörün altında başvuru kimliğiyle bir alt klasör açar. Dosya adı
`01-<sha256>.jpg` gibi sıra numarası, içerik özeti ve dosya uzantısından oluşur.
Örneğin fiziksel dosya
`C:\inetpub\wwwroot\sosyalyardim\wwwroot\uploads\hanefotograflari\<başvuru-kimliği>\01-<sha256>.jpg`
ise veritabanına `/uploads/hanefotograflari/<başvuru-kimliği>/01-<sha256>.jpg`
yazılır. Mevcut `dbo.HaneFotograflari` tablosu kullanılır; yeni tablo veya
migration gerekmez. Mevcut fotoğraflar ve veritabanı yolları değiştirilmez.

API Application Pool kimliğine bu klasör ve alt klasörlerinde **Modify** izni
verin. Web uygulamasının Application Pool kimliği de dosyaları okuyabilmelidir.
Bu izin dosya oluşturma, yeniden adlandırma ve başarısız bir gönderimin yeni
dosyalarını temizleme için gerekir. Klasörü API publish çıktısıyla ezmeyin;
web veya API güncellemelerinde silinmesini önleyin ve ayrıca yedekleyin.

Yeni sürümü yayınlayıp ortam ayarını verdikten sonra API Application Pool'unu
yeniden başlatın. Onaylı test vatandaşıyla tek fotoğraflı başvuru gönderip
dosyanın bu klasörde oluştuğunu, `FotografYolu` kaydını ve fotoğrafın webde
göründüğünü kontrol edin. `/health/ready` sonucu klasöre yazma yetkisini doğrulamaz.

### 7. İlk kontrol

Uygulama havuzunu recycle ettikten sonra:

1. `/health/live` için `Healthy`
2. `/health/ready` için `Healthy`
3. Test ortamında Swagger açılışı
4. Mevcut Identity kullanıcısıyla login
5. `/api/v1/auth/me`
6. Referans ve KPS sorgusu
7. Kontrollü test başvurusu, dbo kayıtları ve fotoğraf dosyası
8. İş listesinde yeni başvurunun görünmesi

`health/live` çalışıp `health/ready` çalışmıyorsa bağlantı
cümlesi, SQL ağ erişimi, tablo şeması ve SQL yetkileri kontrol edilir.

## Hata kayıtları

Warning/Error/Critical kayıtları güvenli JSON satırları olarak dosyaya yazılır.
Normal istekler ve başarılı başvurular ayrıca loglanmaz. Konsolda sunucunun
açılış/kapanış bilgileri kalır. Genel hata yakalayıcısına ulaşan exception'lar,
fotoğraf yazım/temizlik hataları ve başvurunun veritabanı kayıt çakışmaları
kaydedilir. Doğrulama hatası gibi her 400/409 cevabı otomatik log değildir.

Log klasörünü IIS sunucusunu yöneten ekip belirler. Klasör webden erişilebilir
olmamalı ve publish sırasında silinmemelidir. Ayrı bir klasör bunu kolaylaştırır.
SosyalApi Application Pool hesabına klasör ve alt klasörlerinde **Modify**
yetkisi verilmelidir; fotoğraf klasörü izni bunun yerine geçmez.

Sunucuda tanımlanacak ayar (yol belirlenmediyse bu örneği uygulamayın):

```text
FileErrorLogging__DirectoryPath=<yetkilinin-verdiği-tam-fiziksel-yol>
```

Yeni sürümü yayınlayıp ayarı verdikten sonra API Application Pool'unu yeniden
başlatın. Varsayılan `DirectoryPath` boştur; kaynak kodda gerçek sunucu yolu
yoktur. Yerelde ayrı bir geçici klasörle denenebilir. `/health/ready`, log yazma
yetkisini sınamaz.

- Saat ve günlük dosya tarihi Türkiye saatidir (`Europe/Istanbul`, mevcut
  ofset `+03:00`); sunucunun saat dilimine bağlı değildir.
- Adlandırma: `sosyobel-20260904-0001.log`. Gün veya boyut değişince yeni dosya
  açılır. Türkçe açıklamalar UTF-8 olarak okunabilir.
- Varsayılan sınırlar 14 gün, dosya başına 10 MB ve toplam 200 MB'dır
  (MB = 1024 × 1024 byte). Hangisi önce dolarsa eski kayıtlar silinir; yoğun
  hata döneminde 14 günün tamamını saklama garantisi yoktur.
- Temizlik yazımda ve yeni hata gelmese bile saatlik yapılır. Yalnız log
  klasörünün doğrudan altındaki `sosyobel-YYYYMMDD-NNNN.log` dosyaları yönetilir.
  Başka adlı dosyalara, alt klasörlere ve dosya bağlantılarına dokunulmaz.
- Eksik/geçersiz yol, disk/izin sorunu, çok büyük tek kayıt veya başka worker'ın
  dosya kilidi nedeniyle yazılamazsa arındırılmış kayıt konsola düşer.
  Log sorunu API isteğinin sonucunu değiştirmez. Konsol çıktısının ayrıca kalıcı
  tutulduğu varsayılmaz; `file_log_unavailable` uyarısının nedeni giderilmelidir.
- Süre/boyutlar pozitif, toplam boyut en az tek dosya sınırı olmalıdır.
  Geçersiz ayar uygulamayı durdurmaz, dosya yerine konsol kullanılır.
  Ayar değişikliği sonrası API yeniden başlatılır.

Kayıtta zaman, seviye, kaynak, event ID, sabit endpoint şablonu, `traceId`,
başvuru aşaması, exception türü/HResult, metot adları ve varsa SQL hata
numarası/state/severity bulunur. Ham exception mesajı/stack trace, SQL metni,
HTTP query/body/header, kullanıcı bilgileri, T.C. kimlik numarası, parola,
token, fotoğraf adı/yolu ve içeriği kaydedilmez. SQL teşhisinde hata numarası
ve aşama kullanılır; ham mesajdaki veri değerleri dışarı verilmez.

`stage` örnekleri: `InitializePhotoStorage` (fotoğraf deposunu açma),
`ResolveCitizen` (vatandaş kaydı), `VerifyKps` (KPS doğrulama),
`StorePhotos` (fotoğrafı yazma), `CreateApplication` (başvuru kaydı),
`SaveFamilyAndPhotos` (aile/fotoğraf satırları), `CommitTransaction` (tamamlama).
1001 fotoğraf yazma, 1002 veritabanı çakışması, 1003 dosya temizleme hatasının
event ID'sidir. Bunlar HTTP veya kurum KPS hata kodu değildir.

Beklenmeyen HTTP hatası aynı genel ProblemDetails cevabını döndürür; teknik
ayrıntılar Swagger'a/mobile açılmaz. Hatalı isteği tekrar deneyip cevaptaki
`traceId` ile kaydı bulun. Görünmüyorsa Türkiye saatiyle deneme zamanı ve
endpoint kullanılabilir. Yalnız ilgili arındırılmış kaydı paylaşın.
Log eklenmeden önceki hatalar geriye dönük kaydedilemez. Yeni veritabanı
tablosu veya log okuma endpointi yoktur.

Önceki commit ve IIS publish çıktısı geri dönüş için korunmalıdır. Veritabanı
şeması değişmediğinden migration geri alma gerekmez. Saklama sınırıyla silinen
loglar, kaynak kod eski sürüme döndürülerek geri getirilemez.

## Güvenli güncelleme ve geri dönüş

- Her publish çıktısını ayrı sürümlü klasörde tutun.
- Güncellemeden önce çalışan ayarları ve fotoğraf kökünü not edin.
- IIS Application'ın physical path değerini yeni publish klasörüne alın.
- Kontroller başarısızsa physical path'i önceki sürüme döndürüp Application Pool'u
  recycle edin.
- Fotoğraf klasörünü sürüm değişiminde taşımayın.
- JWT anahtarını her publishte yenilemeyin.

## Testler

Kod değişikliği teslim edilmeden önce:

```powershell
dotnet build backend\SosyoBel.Backend.sln --configuration Release
dotnet test backend\SosyoBel.Backend.sln --configuration Release
```

`backend/scripts/validate-*.ps1` scriptleri yalnız kontrollü yerel test
ortamında kullanılmalıdır. Şirket test veya canlı veritabanına karşı
çalıştırılmamalıdır.
