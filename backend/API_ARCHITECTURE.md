# Sosyo-Bel API Mimarisi

Bu belge, Sosyo-Bel backend kodunu ilk kez okuyacak geliştiricinin sistemin
sorumluluklarını, katmanlarını ve temel istek akışlarını hızlıca anlaması için
hazırlanmıştır. Belge çalışma zamanı yapılandırmalarının yerini tutmaz; kurulum
komutları ve ortam değişkenleri için repository kökündeki `README.md` esas
alınmalıdır.

## 1. API'nin sistemdeki görevi

Mobil uygulama SQL Server'a, KPS'ye veya fotoğraf klasörüne doğrudan erişmez.
Bütün dış sistem erişimleri Sosyo-Bel API üzerinden gerçekleştirilir.

```text
Flutter mobil uygulama
        |
        | HTTPS + JWT
        v
SosyoBel.Api
        |
        +--> SQL Server
        |      +--> şirketin mevcut dbo tabloları
        |      +--> Sosyo-Bel teknik uzantı tabloları
        |
        +--> Kurumun KPS kişi ve adres servisleri
        |
        +--> Özel fotoğraf depolama klasörü
```

Bu sınır sayesinde:

- Veritabanı bağlantı bilgileri mobil uygulamaya verilmez.
- KPS erişimi ve personel yetkisi sunucuda denetlenir.
- Belediye kapsamı her korumalı istekte doğrulanır.
- Fotoğrafların fiziksel yolu istemciye açıklanmaz.
- İş kuralları Android ve iOS uygulamalarından bağımsız, tek yerde uygulanır.

## 2. Solution ve proje yapısı

Backend solution dosyası `backend/SosyoBel.Backend.sln` dosyasıdır.

| Proje | Sorumluluk |
| --- | --- |
| `SosyoBel.Api` | HTTP endpointleri, authentication/authorization middleware'i, Swagger ve health check tanımları |
| `SosyoBel.Application` | Kullanım senaryolarının arayüzleri, komut/sonuç modelleri, doğrulama kuralları ve kararlı durum kodları |
| `SosyoBel.Infrastructure` | SQL Server, ASP.NET Core Identity, KPS HTTP istemcisi ve fotoğraf depolamasının gerçek uygulamaları |
| `SosyoBel.Domain` | Belediye ve entegrasyon gibi altyapıdan bağımsız temel alan modelleri |
| `SosyoBel.Bootstrap` | İlk sistem yöneticisini güvenli biçimde oluşturmak için kullanılan komut satırı aracı |
| `SosyoBel.UnitTests` | İş kuralları, güvenlik sınırları, KPS sözleşmesi ve veri modeli testleri |

Bağımlılık yönü aşağıdaki gibidir:

```text
Api -------------> Application -------------> Domain
 |
 +---------------> Infrastructure ----------> Domain
                         |
                         +-------------------> Application
```

`Application` katmanı SQL Server, HTTP veya dosya sistemi ayrıntılarını bilmez.
Bu ayrıntılar interface'lerin gerçek uygulamalarını sağlayan `Infrastructure`
katmanında kalır.

## 3. API başlangıcı ve servis kaydı

Ana giriş noktası `src/SosyoBel.Api/Program.cs` dosyasıdır. Dosya üç işi yapar:

1. Gerekli servisleri dependency injection container'a kaydeder.
2. Middleware sırasını kurar.
3. Endpoint gruplarını uygulamaya bağlar.

Önemli kayıt noktaları:

- `AddSosyoBelInfrastructure`: SQL, başvuru, KPS ve fotoğraf servisleri
- `AddSosyoBelIdentity`: kullanıcı, rol, üyelik, yetki ve refresh token servisleri
- `AddSosyoBelAuthentication`: JWT doğrulama ve authorization politikaları
- `AddSosyoBelOpenApi`: Swagger/OpenAPI üretimi
- `AddHealthChecks`: süreç ve SQL hazır olma kontrolleri

Middleware sırası güvenlik açısından önemlidir. Önce genel hata yönetimi ve rate
limiting, sonra authentication, en son authorization çalışır. Endpointler bu
zincir tamamlandıktan sonra çağrılır.

## 4. API katmanı: HTTP sınırı

`SosyoBel.Api` içindeki `*Endpoints.cs` dosyaları Minimal API endpointlerini
tanımlar. Bu dosyaların görevi:

- route, HTTP metodu ve authorization politikasını belirlemek,
- query, header veya body değerlerinin biçimsel doğrulamasını yapmak,
- token claim'lerinden kullanıcı ve belediye kapsamını okumak,
- isteği `Application` katmanındaki sözleşmeye dönüştürmek,
- servis sonucunu uygun HTTP cevabına çevirmektir.

Kalıcı veri yazma ve ana iş kararları endpoint içinde yapılmamalıdır.

| Dosya | Temel route | Açıklama |
| --- | --- | --- |
| `Authentication/AuthenticationEndpoints.cs` | `/api/v1/auth` | Login, token yenileme, logout ve aktif kullanıcı bilgisi |
| `Administration/AdministrationEndpoints.cs` | `/api/v1/system`, `/api/v1/municipality/personnel` | Belediye, yönetici, personel, parola ve işlem yetkisi yönetimi |
| `Applications/ApplicationEndpoints.cs` | `/api/v1/applications` | Başvuru taslağı, saha verisi, fotoğraf, yeniden açma ve kurula gönderme |
| `Kps/KpsEndpoints.cs` | `/api/v1/kps/profile` | KPS kişi ve adres sonuçlarını tek güvenli profile dönüştüren endpoint |
| `References/ApplicationReferenceEndpoints.cs` | `/api/v1/application-references` | Formda kullanılan referans seçenekleri |
| `WorkItems/WorkItemEndpoints.cs` | `/api/v1/work-items/mine` | Personelin kendi bekleyen ve tamamlanan başvuruları |
| `FieldTasks/FieldTaskEndpoints.cs` | `/api/v1/tasks/assigned` | Personele atanmış saha görevleri için ayrı okuma endpointi |
| `Auditing/AuditEndpoints.cs` | `/api/v1/*/audit` | Yetki kapsamına göre denetim kayıtları |

Swagger açıklamaları endpoint tanımlarıyla birlikte tutulur. Böylece route ile
dokümantasyonun birbirinden kopması önlenir.

## 5. Application katmanı: sözleşmeler ve iş dili

`SosyoBel.Application` dış sistemlerden bağımsız kullanım senaryosu sınırıdır.
Başlıca içerikleri şunlardır:

- `IAuthenticationService`: login, refresh ve logout sözleşmesi
- `IAccountAdministrationService`: kullanıcı ve yetki yönetimi sözleşmesi
- `IApplicationLifecycleService`: başvuru yaşam döngüsü sözleşmesi
- `IApplicationPhotoService`: fotoğraf yükleme ve indirme sözleşmesi
- `IKpsProfileQuery` ve `IKpsClient`: KPS sorgu orkestrasyonu ve taşıma sınırı
- `IUserWorkItemQuery`: personelin kendi iş listesi
- `IAssignedFieldTaskQuery`: atanmış saha görevleri
- `IAuditEventQuery`: denetim kayıtlarını okuma

Endpointler bu interface'lere bağımlıdır. Böylece HTTP ayrıntıları ile SQL/KPS
ayrıntıları iş modellerine karışmaz ve kullanım senaryoları test edilebilir kalır.

## 6. Infrastructure katmanı: dış sistemler

`SosyoBel.Infrastructure`, Application interface'lerinin gerçek uygulamalarını
içerir.

### Identity

`Identity` klasörü aşağıdaki sorumlulukları taşır:

- kullanıcı ve rol kayıtları,
- belediye üyeliği ve aktiflik kontrolü,
- işlem bazlı yetkiler,
- access token üretimine giden oturum bilgileri,
- tek kullanımlık refresh token rotasyonu,
- hesap kilitleme ve parola kuralları,
- kullanıcı yönetimi denetim kayıtları.

`AuthenticationDbContext` şirketin mevcut ASP.NET Identity tablolarını ve
`sosyobel` teknik kimlik tablolarını aynı SQL bağlantısı üzerinden açıkça eşler.

### Persistence

`Persistence` klasörü başvuru ve okuma modellerinin SQL Server uygulamalarını
içerir:

- `SosyoBelDbContext`: EF Core bağlantısı ve ana model kaydı
- `ApplicationLifecycleService`: taslak oluşturma, güncelleme, saha verisi ve
  kurula gönderme
- `ApplicationPhotoService`: fotoğraf metadata yaşam döngüsü
- `UserWorkItemQuery`: personelin kendi başvurularını listeleme
- `AssignedFieldTaskQuery`: atanmış görevleri belediye/personel kapsamında okuma
- `ApplicationReferenceQuery`: form referanslarını okuma
- `AuditEventQuery`: denetim kayıtlarını okuma

### Storage

`LocalApplicationPhotoStorage`, fotoğraf dosyasını web kökü dışındaki özel bir
klasöre yazar. SQL Server yalnız metadata, sıralama, dosya anahtarı ve SHA-256
özetini tutar. İndirme işlemi tekrar yetkilendirilmiş API endpointi üzerinden
yapılır.

### KPS

KPS entegrasyonu dört ana parçadan oluşur:

- `KpsClient`: kurumun iki KPS endpointine GET isteği gönderir.
- `KpsResponseReader`: ham JSON'u uygulamanın kullandığı kimlik/adres modellerine
  dönüştürür.
- `KpsProfileQuery`: personel yetkisini kontrol eder, kişi ve adres sorgularını
  çalıştırır ve sonuçları birleştirir.
- `KpsOptions`: taban adresi ve zaman aşımı ayarlarını taşır.

Mobil uygulama KPS'nin ham cevabını veya kurum içi adresini görmez.

## 7. Kimlik doğrulama ve yetkilendirme

Oturum iki anahtarla yönetilir:

- **Access token:** Kısa ömürlü JWT'dir ve korumalı API isteklerinde kullanılır.
- **Refresh token:** Access token yenilemek için kullanılır; her başarılı
  yenilemede döndürülür ve eski değer tekrar kullanılamaz.

JWT claim'leri kullanıcı kimliğinin yanında aktif belediye ve üyelik kapsamını da
taşır. Bununla birlikte kritik yetkiler yalnız token içeriğine bırakılmaz. Örneğin
KPS sorgusunda `KPS_SORGULA` yetkisi her istekte güncel veritabanından yeniden
kontrol edilir.

Başlıca authorization politikaları:

- sistem yöneticisi,
- belediye yöneticisi,
- aktif belediye personeli,
- kilitli başvuruyu düzenleme istisnası.

## 8. Başvuru yaşam döngüsü

Temel akış:

```text
Taslak oluştur
    -> profil ve form verisini güncelle
    -> aile/hane saha verisini kaydet
    -> fotoğrafları yükle
    -> kurula gönder
    -> kayıt kilitlenir
```

Başvuru yazma işlemlerinde iki koruma birlikte kullanılır:

- **Idempotency-Key:** Ağ tekrarında aynı işlemin ikinci kez kayıt oluşturmasını
  engeller.
- **RowVersion:** Kullanıcının eski bir kayıt kopyası üzerinden yeni veriyi ezmesini
  engeller; çakışmada `409 Conflict` döner.

Kurula gönderme, durum değişikliği ve geçmiş kaydını aynı transaction içinde
tamamlar. Normal personel akışında kurula gönderilen başvuru tekrar düzenlenemez.

## 9. Veritabanı sınırı

Tek SQL bağlantısı içinde iki farklı sorumluluk alanı bulunur:

- `dbo`: şirketin sağladığı mevcut iş ve ASP.NET Identity tabloları,
- `sosyobel`: mobil API'nin ihtiyaç duyduğu teknik uzantı, güvenlik, eşleme,
  geçmiş ve metadata tabloları.

Şirket tabloları EF migration tarafından sahiplenilmez; ilgili eşlemelerde
`ExcludeFromMigrations()` kullanılır. API'nin şirket şemasını yeniden yaratması
veya değiştirmesi amaçlanmaz. `sosyobel` tabloları, mevcut tabloları kopyalamak
yerine mobil uygulamanın eksik teknik alanlarını tamamlar.

Başvuru verisinde örnek olarak:

```text
dbo.Basvurular
        +
sosyobel.BasvuruUygulamaBilgileri
        =
API'nin kullandığı birleşik başvuru modeli
```

Bu eşlemelerin merkezi
`Infrastructure/Persistence/ApplicationPersistenceModelConfiguration.cs`
dosyasıdır.

## 10. KPS istek akışı

```text
Flutter
  -> GET /api/v1/kps/profile
  -> KpsEndpoints
  -> KpsProfileQuery
       -> güncel KPS_SORGULA yetkisi kontrolü
       -> KpsClient kişi GET isteği
       -> KpsClient adres GET isteği
       -> KpsResponseReader
  -> birleştirilmiş KpsProfile
  -> Flutter profil ekranı
```

KPS taban adresi kaynak koda sabitlenmez. `Kps__BaseUrl` ortam değişkeniyle
verilir. Bilinmeyen veya sözleşmeye uymayan cevaplarda ham kişisel veri hata
mesajına ya da istemci cevabına eklenmez.

## 11. Yapılandırma ve gizli bilgiler

`appsettings.json` yalnız yapılandırma şeklini ve güvenli varsayılanları içerir.
Aşağıdaki gerçek değerler source control'e yazılmamalıdır:

- `ConnectionStrings__SosyoBel`
- `Authentication__Jwt__SigningKeyBase64`
- `Kps__BaseUrl`
- varsa ileride kullanılacak KPS kimlik doğrulama sırrı
- gerçek kullanıcı parolaları ve tokenlar

IIS ortamında bu değerler sunucu yapılandırmasından verilmelidir. JWT imza anahtarı
kalıcı ve en az 32 byte olmalıdır; API her yeniden başladığında değiştirilirse
mevcut oturumların access tokenları geçersiz olur.

## 12. Health check ve Swagger

- `/health/live`: API süreci ayakta mı kontrol eder; SQL'i sınamaz.
- `/health/ready`: API'nin SQL bağlantısıyla birlikte trafik almaya hazır olup
  olmadığını kontrol eder.
- `/swagger`: Development ortamında veya açıkça etkinleştirilen güvenilir test
  ortamında API sözleşmesini gösterir.

Swagger canlı ve internete açık ortamda korumasız bırakılmamalıdır.

## 13. Hata sözleşmesi

API, hata cevaplarında mümkün olduğunca `ProblemDetails` ve kararlı bir `code`
alanı kullanır. Genel anlamlar:

| HTTP durumu | Anlamı |
| --- | --- |
| `400` | İstek doğrulaması başarısız |
| `401` | Oturum yok, geçersiz veya süresi dolmuş |
| `403` | Oturum geçerli fakat işlem yetkisi yok |
| `404` | Kapsam içindeki kayıt bulunamadı |
| `409` | RowVersion veya idempotency çakışması |
| `423` | Hesap geçici olarak kilitli |
| `502` | Dış servis cevabı beklenen sözleşmeye uymuyor |
| `503` | Dış servis veya gerekli bağımlılık erişilemiyor |

İstemci yalnız Türkçe hata metnine göre karar vermemeli; mümkün olduğunda kararlı
`code` alanını ve HTTP durumunu kullanmalıdır.

## 14. Test yaklaşımı

Backend testleri `backend/tests/SosyoBel.UnitTests` altındadır. Önemli gruplar:

- `ApplicationLifecycleTests`: başvuru durumları, idempotency ve kilitleme
- `KpsClientTests`: KPS GET adresleri ve taşıma hataları
- `KpsResponseReaderTests`: kişi/adres JSON sözleşmesi
- `KpsProfileQueryTests`: yetki kontrolü ve profil birleştirme
- `AuthenticationDbContextModelTests`: Identity ve teknik tablo eşlemeleri
- `SensitiveDataBoundaryTests`: hassas verilerin güvenli sınırda kalması

Değişiklikten sonra en az şu komutlar çalıştırılmalıdır:

```powershell
dotnet build backend\SosyoBel.Backend.sln --configuration Release
dotnet test backend\SosyoBel.Backend.sln --configuration Release
```

Mobil sözleşme de değiştiyse ayrıca:

```powershell
flutter analyze
flutter test
```

## 15. Kodu okuma sırası

Projeyi ilk kez inceleyen geliştirici için önerilen sıra:

1. `src/SosyoBel.Api/Program.cs`
2. İlgili `*Endpoints.cs` dosyası
3. `SosyoBel.Application` içindeki interface ve modeller
4. `SosyoBel.Infrastructure` içindeki gerçek servis
5. İlgili EF eşlemesi, SQL sorgusu, KPS istemcisi veya storage sınıfı
6. Aynı kullanım senaryosunun test dosyası

KPS örneği:

```text
KpsEndpoints.cs
  -> IKpsProfileQuery.cs
  -> KpsProfileQuery.cs
  -> IKpsClient.cs
  -> KpsClient.cs
  -> KpsResponseReader.cs
  -> Kps*Tests.cs
```

Başvuru örneği:

```text
ApplicationEndpoints.cs
  -> IApplicationLifecycleService.cs
  -> ApplicationLifecycleModels.cs
  -> ApplicationLifecycleService.cs
  -> ApplicationPersistenceModelConfiguration.cs
  -> ApplicationLifecycleTests.cs
```

## 16. Yeni özellik eklerken izlenecek sınır

Yeni bir kullanım senaryosunda genel sıra şöyledir:

1. İhtiyaç duyulan komut, sonuç modeli ve interface `Application` katmanına eklenir.
2. SQL, HTTP veya dosya sistemi uygulaması `Infrastructure` katmanında yazılır.
3. Servis dependency injection kaydına eklenir.
4. Endpoint yalnız HTTP doğrulaması ve sonuç eşlemesi yapacak şekilde `Api`
   katmanına eklenir.
5. Başarılı akışın yanında yetkisiz, hatalı, çakışmalı ve dış servis hatası
   senaryoları test edilir.

Bu düzen korunursa ekran, veritabanı ve dış servis değişiklikleri birbirini gereksiz
yere etkilemez; kod devralan geliştirici sorumluluğun hangi katmanda olduğunu daha
kolay bulur.
