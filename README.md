# Sosyo-Bel

Sosyo-Bel; belediye saha personelinin sosyal yardım başvurusu oluşturmasını,
vatandaş ve aile bilgilerini incelemesini, hane sorularını cevaplamasını, fotoğraf
eklemesini ve başvuruyu kurula göndermesini sağlayan mobil uygulamadır.

Repository; Flutter mobil uygulamasını, ASP.NET Core API'yi, SQL Server
dosyalarını ve otomatik testleri birlikte içerir.

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
backend/                 API, bootstrap aracı ve backend testleri
database/                Migration, seed ve SQL doğrulama dosyaları
docs/                    Proje kararları ve teknik notlar
ios/                     iOS platform dosyaları
lib/                     Flutter uygulama kodu
test/                    Flutter testleri
tool/                    Geliştirici önizleme giriş noktaları
```

## Gereksinimler

- Git
- Flutter stable; kullanılan sürüm Dart `>=3.11.5 <4.0.0` sağlamalıdır
- .NET 10 SDK; `backend/global.json` şu anda `10.0.302` sürümünü ister
- PowerShell
- SQL Server Developer veya SQL Server Express
- Android için Android Studio, Android SDK ve emülatör/fiziksel cihaz
- iOS için macOS, Xcode ve CocoaPods

iOS uygulaması Windows üzerinde derlenemez. iOS geliştirme ve derleme işlemleri
Mac üzerinde yapılmalıdır.

Kurulumları kontrol etmek için:

```powershell
flutter doctor
dotnet --version
```

## İlk kurulum

Komutlar repository kökünde çalıştırılmalıdır.

### 1. Bağımlılıkları yükleme

```powershell
flutter pub get
dotnet restore backend\SosyoBel.Backend.sln
```

### 2. Yerel veritabanını hazırlama

Varsayılan yerel SQL Server için:

```powershell
powershell -ExecutionPolicy Bypass -File backend\scripts\initialize-local-development.ps1
```

SQL Server Express kullanılıyorsa:

```powershell
powershell -ExecutionPolicy Bypass -File backend\scripts\initialize-local-development.ps1 -SqlServer ".\SQLEXPRESS"
```

Farklı bir yerel veritabanı adı kullanılabilir:

```powershell
powershell -ExecutionPolicy Bypass -File backend\scripts\initialize-local-development.ps1 -SqlServer ".\SQLEXPRESS" -DatabaseName "SosyoBelDev"
```

Script yalnızca yerel SQL Server instance'larında çalışır. Yeni veritabanında
migration ve geliştirme seed dosyalarını uygular, ardından şemayı doğrular.
Mevcut veritabanını silmez.

### 3. API ortam değişkenlerini tanımlama

Aşağıdaki değerler yalnız açık PowerShell penceresi için geçerlidir. Terminal
kapatıldığında yeniden tanımlanmalıdır.

```powershell
$env:ASPNETCORE_ENVIRONMENT="Development"
$env:ConnectionStrings__SosyoBel="Server=localhost;Database=SosyoBel;Integrated Security=True;Encrypt=True;TrustServerCertificate=True"

# PowerShell 5.1 ve PowerShell 7 ile uyumlu 32 byte rastgele JWT anahtarı.
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

SQL Server Express kullanılıyorsa bağlantı cümlesi de değiştirilmelidir:

```powershell
$env:ConnectionStrings__SosyoBel="Server=.\SQLEXPRESS;Database=SosyoBel;Integrated Security=True;Encrypt=True;TrustServerCertificate=True"
```

### 4. API'yi çalıştırma

Ortam değişkenlerinin tanımlandığı PowerShell penceresinde:

```powershell
dotnet run --project backend\src\SosyoBel.Api\SosyoBel.Api.csproj --urls http://localhost:5000
```

API çalışırken terminal açık tutulmalıdır.

| Adres | Açıklama |
| --- | --- |
| `http://localhost:5000/` | Servis ve ortam bilgisi |
| `http://localhost:5000/health/live` | API süreci çalışıyor mu |
| `http://localhost:5000/health/ready` | API ve SQL Server hazır mı |
| `http://localhost:5000/swagger` | Swagger arayüzü |
| `http://localhost:5000/swagger/v1/swagger.json` | OpenAPI JSON belgesi |

Swagger ayrı bir program değildir; API Development ortamında çalışınca otomatik
olarak açılır.

## İlk kullanıcıların oluşturulması

Repository içinde varsayılan kullanıcı veya parola yoktur. Yerel bilgisayardaki
mevcut bir kullanıcı hesabı commit ile başka bilgisayara aktarılmaz.

Kullanıcı oluşturma sırası:

1. Bootstrap aracıyla ilk sistem yöneticisi oluşturulur.
2. Sistem yöneticisi Swagger üzerinden belediyeyi ve belediye yöneticisini açar.
3. Belediye yöneticisi Swagger üzerinden saha personelini açar.
4. Mobil uygulamaya saha personeli hesabıyla giriş yapılır.

### Sistem yöneticisi oluşturma

Bağlantı cümlesinin tanımlı olduğu PowerShell penceresinde:

```powershell
$env:SOSYOBEL_BOOTSTRAP_EMAIL="system.admin@example.com"
$env:SOSYOBEL_BOOTSTRAP_FIRST_NAME="Cats"
$env:SOSYOBEL_BOOTSTRAP_LAST_NAME="Administrator"

dotnet run --project backend\src\SosyoBel.Bootstrap\SosyoBel.Bootstrap.csproj
```

Parola ortam değişkeninde verilmezse terminalde gizli olarak istenir. Parola en
az 10 karakter, büyük harf, küçük harf, rakam ve en az dört benzersiz karakter
içermelidir.

### Swagger ile oturum açma

`POST /api/v1/auth/login` isteği çalıştırılır:

```json
{
  "email": "system.admin@example.com",
  "password": "YerelGucluParola123",
  "municipalityCode": null
}
```

Başarılı yanıttaki `accessToken` kopyalanır. Swagger'ın sağ üstündeki
**Authorize** alanına yalnız token yapıştırılır; başına `Bearer` yazılmaz.
`traceId` erişim tokenı değildir.

### Belediye ve ilk belediye yöneticisi

Sistem yöneticisi tokenı ile `POST /api/v1/system/municipalities` çalıştırılır.
`Idempotency-Key` başlığına 8-100 karakterlik benzersiz bir değer yazılır; örnek:
`create-local-municipality-001`.

```json
{
  "code": "DEMO",
  "name": "Demo Belediyesi",
  "administrator": {
    "email": "yonetici@demo.example",
    "firstName": "Demo",
    "lastName": "Yonetici",
    "initialPassword": "YerelYonetici123"
  }
}
```

### Saha personeli

Belediye yöneticisi hesabıyla tekrar login olunur ve yeni token Swagger'a
tanıtılır. `POST /api/v1/municipality/personnel/` çalıştırılır.
`Idempotency-Key` örneği: `create-local-personnel-001`.

```json
{
  "email": "personel@demo.example",
  "firstName": "Demo",
  "lastName": "Personel",
  "initialPassword": "YerelPersonel123"
}
```

Bu bilgiler yalnız yerel geliştirme örneğidir. Gerçek hesap ve parolalar kaynak
koda veya README'ye yazılmamalıdır.

## Mobil uygulamayı çalıştırma

API çalışırken ikinci bir terminal açılır:

```powershell
flutter devices
flutter run
```

Varsayılan geliştirme API adresleri:

| Platform | API adresi |
| --- | --- |
| Android emülatörü | `http://10.0.2.2:5000` |
| iOS simülatörü | `http://localhost:5000` |

Android emülatöründe `localhost` emülatörün kendisidir. Bilgisayarda çalışan
API'ye `10.0.2.2` ile ulaşılır ve uygulama bu adresi otomatik seçer.

Fiziksel cihaz veya ortak test API'si için adres build sırasında verilir:

```powershell
flutter run --dart-define=SOSYOBEL_API_BASE_URL=https://test-api.example.com/
```

IIS sanal dizini kullanılıyorsa dizin de adrese eklenir:

```powershell
flutter run --dart-define=SOSYOBEL_API_BASE_URL=https://test.example.com/sosyobel/
```

Release derlemelerinde API adresi HTTPS olmak zorundadır.

## Testler

Commit veya Pull Request öncesinde:

```powershell
flutter analyze
flutter test
dotnet build backend\SosyoBel.Backend.sln --configuration Release
dotnet test backend\SosyoBel.Backend.sln --configuration Release
```

`backend/scripts/validate-*.ps1` dosyaları daha kapsamlı yerel SQL/API testleri
içindir. Bazıları geçici veritabanı oluşturup test sonunda kaldırır. Şirket test
veya canlı veritabanına karşı çalıştırılmamalıdır.

## Yapılandırma ve gizli bilgiler

Temel ortam değişkenleri:

| Değişken | Açıklama |
| --- | --- |
| `ConnectionStrings__SosyoBel` | Ana SQL Server bağlantısı |
| `Authentication__Jwt__SigningKeyBase64` | En az 32 byte Base64 JWT anahtarı |
| `OpenApi__Enabled` | Swagger'ı açar veya kapatır |
| `ApplicationPhotos__RootPath` | Fotoğraf depolama klasörü |
| `SOSYOBEL_BOOTSTRAP_*` | İlk sistem yöneticisi bilgileri |

`backend/.env.example` yalnız değişken adlarını gösterir. API `.env` dosyasını
otomatik yüklemez. Gerçek değerler çalışma ortamı, IIS veya secret store üzerinden
verilmelidir.

Aşağıdakiler commit edilmemelidir:

- Gerçek `.env` dosyaları, bağlantı cümleleri ve parolalar
- JWT anahtarları ve Bitbucket/API tokenları
- Sertifika, keystore ve imzalama dosyaları
- `android/local.properties`
- APK, AAB, IPA ve build çıktıları
- `.dart_tool`, `bin`, `obj`, `.gradle` ve IDE önbellekleri
- Çalışma zamanı fotoğrafları, loglar ve SQL yedekleri

## Fotoğraf depolama

Development ortamında fotoğraflar Git tarafından izlenmeyen
`.application-photos/` klasörüne yazılır. Bir başvuruya en fazla 15 JPEG, PNG,
HEIC veya HEIF fotoğraf eklenebilir; her dosya en fazla 10 MB olabilir.

IIS veya ortak test ortamında `ApplicationPhotos__RootPath`, publish klasörü
dışındaki kalıcı bir klasöre verilmelidir. API'yi çalıştıran kullanıcıya bu klasör
için yazma izni gerekir.

## IIS notu

Yerel geliştirmede IIS gerekli değildir. IIS üzerinde çalıştırılacaksa API önce
publish edilir, sunucuda uygun .NET Hosting Bundle bulunur ve bağlantı/JWT/fotoğraf
ayarları IIS ortam değişkenleriyle verilir.

```powershell
dotnet publish backend\src\SosyoBel.Api\SosyoBel.Api.csproj --configuration Release --output .\artifacts\publish\api
```

Production ortamında Swagger varsayılan olarak kapalıdır. Güvenilir test ortamında
`OpenApi__Enabled=true` ile açılabilir. Swagger etkin olduğunda anonim erişime açık
olduğu için internetten erişilen canlı ortamda korumasız bırakılmamalıdır.

## Sık karşılaşılan sorunlar

### `localhost:5000` açılmıyor

- API terminalinin açık olduğunu kontrol edin.
- Başlangıç hatasını API terminalinden okuyun.
- Portu başka bir uygulamanın kullanmadığını kontrol edin.

### `JWT imza anahtarı en az 32 byte olmalıdır`

Bu README'deki `RandomNumberGenerator.Create()` örneğiyle yeni anahtar üretin.
PowerShell 5.1 statik `RandomNumberGenerator.GetBytes(32)` çağrısını desteklemez.

### Swagger yanıtında yalnız `traceId` görünüyor

`traceId` token değildir; sunucu hatasının izleme kimliğidir. API terminalindeki
hata incelenmelidir. Token yalnız başarılı login yanıtındaki `accessToken` alanıdır.

### `/health/live` başarılı, `/health/ready` başarısız

API çalışıyor fakat SQL Server bağlantısı veya şeması hazır değildir. Bağlantı
cümlesi, SQL Server servisi, kullanıcı yetkisi ve migration sırası kontrol edilir.

### Android emülatörü API'ye bağlanamıyor

- API'nin `localhost:5000` üzerinde çalıştığını kontrol edin.
- Emülatör için adresin `10.0.2.2:5000` olduğundan emin olun.
- VPN, güvenlik duvarı ve proxy ayarlarını kontrol edin.

### Login `401` dönüyor

Kullanıcı/parola, kullanıcının aktifliği ve belediye kodu kontrol edilmelidir.
Beş başarısız denemeden sonra hesap 15 dakika kilitlenebilir.

### Korumalı istek `403` dönüyor

Token geçerlidir ancak kullanıcının rolü, aktif belediye üyeliği veya işlem yetkisi
yeterli değildir.

### IIS'te `/swagger` adresi `404` dönüyor

Production ortamında beklenen davranıştır. Yalnız güvenilir test ortamında
`OpenApi__Enabled=true` tanımlanıp uygulama yeniden başlatılır.

## Ek belgeler

- `docs/PROJECT_BRIEF.md`: Ürün kapsamı
- `docs/DECISIONS.md`: Onaylanmış kararlar
- `docs/OPEN_QUESTIONS.md`: Cevap bekleyen konular
- `docs/MERNIS_KPS_NOTES.md`: MERNİS/KPS sınırları
- `docs/DATABASE_V2.md`: Veritabanı ve migration sırası
- `backend/ACCESS_CONTROL.md`: Rol ve yetki modeli
- `backend/BOOTSTRAP.md`: İlk sistem yöneticisi kurulumu
- `backend/AUTH_VALIDATION.md`: Kimlik doğrulama notları
