# Sosyo-Bel

Sosyo-Bel, belediye personelinin sahada sosyal yardım başvurusu hazırlamasını,
vatandaş ve aile bilgilerini incelemesini, hane durumunu kaydetmesini, fotoğraf
eklemesini ve tamamlanan başvuruyu kurula göndermesini sağlayan Flutter
uygulamasıdır.

Bu repository mobil uygulamayı, ASP.NET Core API'yi ve otomatik testleri birlikte
içerir. Backend kodunu ilk kez okuyacak kişiler önce
[API mimarisi ve kod okuma rehberine](backend/API_ARCHITECTURE.md), kurulumu
yapacak kişiler ise [backend çalıştırma ve IIS rehberine](backend/README.md)
bakmalıdır.

## Güncel teknik kararlar

- Uygulama şimdilik tek belediye için çalışır; login isteğinde
  `municipalityCode` bulunmaz.
- Kullanıcı ve roller şirketin mevcut `dbo.AspNet*` tablolarından okunur.
  Admin, Kurul ve Personel rolleri mobil uygulamaya girebilir.
- API canlı veritabanında migration çalıştırmaz, yeni tablo veya kolon oluşturmaz.
- Tamamlanan başvuru tek HTTP isteği ve tek SQL transaction ile şirketin mevcut
  `dbo.Basvurular`, `dbo.BasvuruAileFertleri` ve
  `dbo.HaneFotograflari` tablolarına yazılır.
- Taslaklar API'ye gönderilmez; kurula gönderilene kadar yalnız telefonda tutulur.
- Hane cevapları, aile fertlerinin ölü/sağ bilgisi, diğer yakınlık açıklaması ve
  tamamla ekranındaki not, etiketli biçimde
  `dbo.Basvurular.TalepAciklamasi` alanına eklenir.
- Sunucuya ulaşan başvuru kurula gönderilmiş kabul edilir ve mobil uygulamada
  yeniden düzenlenmez.

## Teknolojiler

- Flutter ve Dart
- ASP.NET Core Minimal API, .NET 10
- ASP.NET Core Identity ve JWT
- Entity Framework Core ve SQL Server
- Swagger / OpenAPI

## Proje yapısı

```text
android/                 Android platform dosyaları
assets/                  Görsel, ikon ve fontlar
backend/                 API kaynak kodu, belgeler, scriptler ve backend testleri
database/                Yerel/uyumluluk SQL materyalleri; canlı DB'ye uygulanmaz
ios/                     iOS platform dosyaları
lib/                     Flutter uygulama kodu
test/                    Flutter testleri
tool/                    Geliştirici önizleme giriş noktaları
```

## Gereksinimler

- Git
- Flutter stable; Dart `>=3.11.5 <4.0.0`
- .NET 10 SDK; `backend/global.json` şu anda `10.0.302` ister
- SQL Server'a erişim ve şirket şemasının yerel/test kopyası
- Android için Android Studio, Android SDK ve emülatör veya fiziksel cihaz
- iOS için macOS, Xcode ve CocoaPods

iOS uygulaması Windows üzerinde derlenemez.

## İlk çalıştırma

Komutları repository kökünde çalıştırın:

```powershell
flutter pub get
dotnet restore backend\SosyoBel.Backend.sln
```

API, şirketin mevcut dbo şemasına bağlanır. Şirketin test/canlı veritabanında
`database/` altındaki SQL dosyalarını veya
`backend/scripts/initialize-local-development.ps1` scriptini
çalıştırmayın. API kendi şemasını üretmez.

Yerel test için önce bu PowerShell penceresine ayarları verin:

```powershell
$env:ASPNETCORE_ENVIRONMENT="Development"
$env:ConnectionStrings__SosyoBel="Server=localhost;Database=SirketDbTestKopyasi;Integrated Security=True;Encrypt=True;TrustServerCertificate=True"
$env:ApplicationPhotos__RootPath="C:\sosyobel-test\uploads\hanefotograflari"
$env:Kps__BaseUrl="http://localhost:8090"

# PowerShell 5.1 ve 7 ile uyumlu, en az 32 byte JWT anahtarı üretir.
$keyBytes = New-Object byte[] 32
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
try {
    $rng.GetBytes($keyBytes)
}
finally {
    $rng.Dispose()
}
$env:Authentication__Jwt__SigningKeyBase64=[Convert]::ToBase64String($keyBytes)
```

Ardından API'yi başlatın:

```powershell
dotnet run --project backend\src\SosyoBel.Api\SosyoBel.Api.csproj --urls http://localhost:5000
```

| Adres | Açıklama |
| --- | --- |
| `http://localhost:5000/` | Servis ve ortam bilgisi |
| `http://localhost:5000/health/live` | API süreci ayakta mı |
| `http://localhost:5000/health/ready` | API ve SQL bağlantısı hazır mı |
| `http://localhost:5000/swagger` | Development ortamındaki Swagger |

`/health/live` başarılıyken `/health/ready` başarısızsa süreç
çalışıyor fakat SQL bağlantısı veya gerekli dbo şeması hazır değildir.

## Kullanıcı hesabı ve Swagger

API kullanıcı veya rol oluşturmaz. Şirketin web panelinde bulunan ve Admin, Kurul
veya Personel rolüne sahip mevcut hesapla şu istek çalıştırılır:

```json
{
  "username": "mevcut-kullanici-adi",
  "password": "mevcut-sifre"
}
```

`POST /api/v1/auth/login` yanıtındaki `accessToken` kopyalanır.
Swagger'daki **Authorize** alanına yalnız token yapıştırılır; başına
`Bearer` yazılmaz. `traceId` token değildir.

API'nin güncel uygulama uçları:

| Metot | Endpoint | Amaç |
| --- | --- | --- |
| POST | `/api/v1/auth/login` | Oturum açar |
| POST | `/api/v1/auth/refresh` | Access token yeniler |
| POST | `/api/v1/auth/logout` | Refresh oturumunu kapatır |
| GET | `/api/v1/auth/me` | Aktif kullanıcıyı getirir |
| GET | `/api/v1/application-references` | Form seçeneklerini getirir |
| GET | `/api/v1/kps/profile` | KPS kişi ve adres sonucunu birleştirir |
| POST | `/api/v1/applications/submit` | Tamamlanan başvuruyu kurula gönderir |
| GET | `/api/v1/work-items/mine` | Başvuruları ve atanmış işleri listeler |

## Mobil uygulamayı çalıştırma

API açıkken ikinci terminalde:

```powershell
flutter devices
flutter run
```

Android emülatörü bilgisayardaki API'ye `http://10.0.2.2:5000` ile,
iOS simülatörü `http://localhost:5000` ile ulaşır. Fiziksel cihaz veya IIS
test ortamı için adres derleme sırasında verilir:

```powershell
flutter run --dart-define=SOSYOBEL_API_BASE_URL=https://test-api.example.com/
```

IIS altında alt uygulama kullanılıyorsa yol da eklenir:

```powershell
flutter run --dart-define=SOSYOBEL_API_BASE_URL=https://test.example.com/sosyobel/
```

Release sürümünde API adresi HTTPS olmalıdır.

## Başvuru ve fotoğraf akışı

`POST /api/v1/applications/submit` bir
`multipart/form-data` isteğidir:

- `payload` alanı kişi/talep, aile ve hane bilgilerini JSON olarak taşır.
- `photos` alanı en fazla 15 JPEG, PNG, HEIC veya HEIF dosyası taşır.
- Her fotoğraf en fazla 10 MB olabilir.
- `Idempotency-Key` başlığı 8-100 karakter olmalıdır; aynı gönderimin
  bağlantı sorunu nedeniyle tekrarlanması ikinci başvuru oluşturmaz.
- KPS bilgisi kayıt öncesinde sunucuda tekrar doğrulanır.
- Vatandaşın mevcut `dbo.Vatandaslar` kaydı bulunmak zorundadır; bu akış
  yeni vatandaş oluşturmaz.
- Başvuru kanalı mevcut `dbo.TalepGelisKanallari` tablosundaki tek etkin
  `Yüzyüze Görüşme` kaydından çözülür.

Development ortamında fotoğraf yolu
`backend/src/SosyoBel.Api/appsettings.Development.json` içinden gelir.
IIS'te `ApplicationPhotos__RootPath`, şirket web uygulamasının
`/uploads/hanefotograflari` adresi olarak sunduğu fiziksel klasör olmalıdır.
Kurumun bildirdiği klasör için IIS ortam ayarı:

```text
ApplicationPhotos__RootPath=C:\inetpub\wwwroot\sosyalyardim\wwwroot\uploads\hanefotograflari
```

API mevcut `dbo.HaneFotograflari.FotografYolu` alanına
`/uploads/hanefotograflari/<başvuru-kimliği>/<dosya>` biçiminde yol yazar.
Yeni tablo oluşturulmaz. Application Pool hesabının bu klasörde **Modify**
yetkisi olmalıdır. Ayrıntılar [backend kurulum notlarında](backend/README.md#6-fotoğraf-klasörü).

## API hata kayıtları

Sunucuda özel bir klasör belirlenip `FileErrorLogging__DirectoryPath` ayarına
verilir. Boşsa dosya oluşturulmaz; arındırılmış hata bilgisi konsola düşer.
Bu durum API'nin açılmasını engellemez, ancak konsol çıktısının kalıcı tutulduğu
varsayılmaz. Kayıtlar Türkiye saatini kullanır. Varsayılan sınırlar 14 gün,
dosya başına 10 MB ve toplam 200 MB'dır. Hassas istek bilgileri veya ham SQL
hata mesajları yazılmaz; yeni tablo oluşturulmaz. Ayrıntılar
[API kurulum belgesinde](backend/README.md#hata-kayıtları).

## KPS testi

Mobil uygulama KPS'ye doğrudan bağlanmaz. Sosyo-Bel API şu kurum uçlarına GET
isteği gönderir:

```text
GET /api/kps/sorgula?tcKimlikNo=...&dogumYil=...&dogumAy=...&dogumGun=...
GET /api/kpsadres/sorgula?tcKimlikNo=...&dogumYil=...&dogumAy=...&dogumGun=...
```

KPS tarafında şu an ek token/API anahtarı yoktur. Swagger'da oturum açıp token
tanıtıldıktan sonra şu uç çağrılır:

```text
GET /api/v1/kps/profile?tcKimlikNo=...&dogumYil=...&dogumAy=...&dogumGun=...
```

Yalnız kurumun test için onayladığı kimlik bilgilerini kullanın. Gerçek T.C. kimlik
numarası, parola, token veya ham KPS cevabı repository'ye eklenmemelidir.

## Taslaklar ve görev listesi

`Taslağı Kaydet` işlemi veriyi yalnız cihazda saklar. Sunucuda taslak
endpointi veya taslak tablosu yoktur. Başvuru kurula başarıyla gönderildiğinde
telefondaki taslak silinir.

`GET /api/v1/work-items/mine` şu iki kaynağı birleştirir:

- Kullanıcının oluşturduğu `dbo.Basvurular` kayıtları
- Kullanıcıya atanmış `dbo.SahaAktiviteleri` kayıtları

Sunucudaki kayıtlar mobil uygulamada salt okunurdur.

## Testler

Commit veya teslim öncesinde:

```powershell
flutter analyze
flutter test
dotnet build backend\SosyoBel.Backend.sln --configuration Release
dotnet test backend\SosyoBel.Backend.sln --configuration Release
```

`backend/scripts/validate-*.ps1` dosyaları yerel doğrulama içindir.
Bazıları geçici veritabanı oluşturabilir; şirket test veya canlı veritabanına karşı
çalıştırılmamalıdır.

## IIS

Yayın alma, uygulama havuzu, ortam değişkenleri, SQL izinleri, fotoğraf klasörü ve
kontrol sırası [backend README](backend/README.md) içinde açıklanmıştır.

Production ortamında Swagger varsayılan olarak kapalıdır. Yalnız güvenilir test
ortamında `OpenApi__Enabled=true` ile açılmalıdır.
