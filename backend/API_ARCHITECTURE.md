# Sosyo-Bel API mimarisi

Bu belge backend kodunu ilk kez okuyacak geliştirici için güncel çalışma
sınırlarını ve dosya akışını açıklar.

## Temel sınırlar

- API tek belediye için çalışır.
- Kullanıcı ve roller şirketin mevcut ASP.NET Identity tablolarından gelir.
- API şirket veritabanında yeni tablo/kolon oluşturmaz ve migration çalıştırmaz.
- Taslaklar telefonda tutulur; backend yalnız tamamlanmış başvuruyu kabul eder.
- Başvuru, aile ve fotoğraf kayıtları tek transaction içinde mevcut dbo
  tablolarına yazılır.
- KPS çağrısı yalnız backend tarafından yapılır.

## Katmanlar

```text
SosyoBel.Api
  HTTP endpointleri, authentication, authorization ve Swagger

SosyoBel.Application
  Kullanım senaryosu sözleşmeleri, komut/sonuç modelleri ve saf doğrulamalar

SosyoBel.Infrastructure
  ASP.NET Identity, EF Core, SQL Server, KPS HTTP istemcisi ve dosya depolama
```

`Api` katmanı SQL yazmaz. `Application` katmanı veritabanı veya
HTTP ayrıntısını bilmez. `Infrastructure` bu sözleşmelerin gerçek
uygulamasını içerir.

## Uygulama başlangıcı

`src/SosyoBel.Api/Program.cs` şu sırayı kurar:

1. ProblemDetails ve health check
2. Infrastructure servisleri ve SQL bağlantısı
3. JWT authentication ve rol politikası
4. Swagger/OpenAPI
5. Endpoint grupları

Fallback policy nedeniyle açıkça `AllowAnonymous` verilmeyen yeni bir
endpoint varsayılan olarak kimlik doğrulaması ister.

## Yayınlanan endpoint grupları

| Dosya | Sorumluluk |
| --- | --- |
| `Authentication/AuthenticationEndpoints.cs` | Login, refresh, logout ve aktif kullanıcı |
| `References/ApplicationReferenceEndpoints.cs` | Mobil form seçenekleri |
| `Kps/KpsEndpoints.cs` | Birleştirilmiş kişi ve adres profili |
| `Applications/ApplicationEndpoints.cs` | Tek adımda tamamlanmış başvuru gönderimi |
| `WorkItems/WorkItemEndpoints.cs` | Kişinin başvuru ve atanmış iş listesi |

Bir sınıfta private yardımcı metot bulunması onu HTTP endpointi yapmaz. Gerçek
API yüzeyi yalnız `MapGet`, `MapPost` gibi çağrılarla kaydedilen
rotalardır; Swagger da bu yüzeyi gösterir.

## Kimlik doğrulama

Kod okuma sırası:

```text
AuthenticationEndpoints.cs
  -> IIdentityAuthenticationService
  -> IdentityAuthenticationService.cs
  -> AuthenticationDbContext.cs
  -> IdentityRefreshTokenStore.cs
  -> JwtAccessTokenIssuer.cs
```

`AuthenticationDbContext` şirketin mevcut `dbo.AspNet*`
tablolarını eşler. Migration üretmez. Refresh tokenın açık değeri veritabanında
saklanmaz; SHA-256 özeti ve oturum bilgileri mevcut
`dbo.AspNetUserTokens` tablosunda tutulur.

Mobil erişim politikası mevcut Identity rollerinden Admin, Kurul veya Personel
rollerinden en az birini ister. Belediye kodu veya ayrı üyelik tablosu yoktur.

## KPS akışı

Kod okuma sırası:

```text
KpsEndpoints.cs
  -> IKpsProfileQuery.cs
  -> KpsProfileQuery.cs
  -> IKpsClient.cs
  -> KpsClient.cs
  -> KpsResponseReader.cs
```

Mobil istemci yalnız `GET /api/v1/kps/profile` çağırır. Backend, kurumun
kişi ve adres uçlarına GET gönderir ve sonuçları tek güvenli profile dönüştürür.
Ham KPS cevabı istemciye açılmaz.

Bilinen kurum hata kodları güvenli uygulama hatalarına çevrilir. Ulaşım hataları,
zaman aşımı ve sözleşmeye uymayan JSON ayrı tutulur. Başvuru kaydından önce KPS
aynı bilgilerle sunucuda tekrar sorgulanır.

## Tamamlanmış başvuru akışı

Kod okuma sırası:

```text
ApplicationEndpoints.cs
  -> ICompletedApplicationSubmissionService.cs
  -> CompletedApplicationSubmissionService.cs
  -> CompanyApplicationCoreWriter.cs
  -> CompanyApplicationFamilyPreparer.cs
  -> CompanyApplicationHouseholdPreparer.cs
  -> CompanyApplicationPhotoPreparer.cs
  -> CompanyApplicationDescriptionComposer.cs
  -> CompanyApplicationModelConfiguration.cs
```

`POST /api/v1/applications/submit` şu akışı izler:

1. JWT kullanıcısı, `Idempotency-Key`, payload ve fotoğraflar doğrulanır.
2. Mevcut `dbo.Vatandaslar` kaydı T.C. kimlik numarasıyla çözülür.
3. KPS kişi/adres profili sunucudan tekrar alınır.
4. Fotoğraflar geçici olarak kalıcı klasöre hazırlanır.
5. Serializable SQL transaction açılır.
6. `dbo.Basvurular` satırı oluşturulur.
7. Aile fertleri `dbo.BasvuruAileFertleri` tablosuna eklenir.
8. Fotoğraf yolları `dbo.HaneFotograflari` tablosuna eklenir.
9. Transaction commit edilir.

Herhangi bir veritabanı adımı başarısız olursa transaction geri alınır. Bu istek
için oluşturulan fotoğraf dosyaları da temizlenir.

Ayrı kolon bulunmayan hane cevapları, ölü/sağ bilgisi, diğer yakınlık açıklaması
ve ekstra not `CompanyApplicationDescriptionComposer` tarafından etiketli
bir metne dönüştürülerek `Basvurular.TalepAciklamasi` sonuna eklenir.

Başvurunun mobil public kimliği, kullanıcı kimliği ve idempotency anahtarından
kararlı biçimde üretilir ve `Basvurular.PublicToken` alanında 32
hexadecimal karakter olarak tutulur. Aynı başarılı istek tekrar gelirse ikinci
başvuru oluşturulmaz.

## Fotoğraf depolama

`LocalApplicationPhotoStorage` dosyayı
`ApplicationPhotos:RootPath` altında saklar.
`CompanyApplicationPhotoPreparer` şirket web uygulamasının beklediği
`/uploads/...` yolunu `HaneFotograflari.FotografYolu` alanına
yazar.

Bu nedenle IIS'te fiziksel kök, şirket web uygulamasının `/uploads` olarak
sunduğu klasörle aynı olmalıdır. Bir başvuru en fazla 15 fotoğraf içerir; her
dosya en fazla 10 MB olabilir.

## İş listesi

Kod okuma sırası:

```text
WorkItemEndpoints.cs
  -> IUserWorkItemQuery.cs
  -> UserWorkItemQuery.cs
  -> AssignedFieldTaskQuery.cs
  -> CompanyWorkflowStatusMapper.cs
```

`UserWorkItemQuery` iki kaynağı birleştirir:

- Kullanıcının oluşturduğu `dbo.Basvurular` kayıtları
- Kullanıcıya `dbo.SahaAktiviteleri.PersonelId` üzerinden atanmış görevler

İki tablo arasında doğrulanmış başvuru foreign key'i olmadığı için kayıtlar yapay
bir ilişkiyle birleştirilmez. Sunucudaki bütün iş kartları
`isEditable=false` döner. Düzenlenebilir taslaklar yalnız telefondadır.

## Veritabanı contextleri

| Context | Görevi |
| --- | --- |
| `AuthenticationDbContext` | Mevcut ASP.NET Identity tabloları |
| `CompanyApplicationDbContext` | Mevcut şirket başvuru, vatandaş, fotoğraf ve referans tabloları |
| `SosyoBelDbContext` | Mevcut şirket saha aktivitesi sorgusu ve eski servislerin derleme sınırı |

`CompanyApplicationDbContext` yeni bir veritabanı değildir. Aynı
`ConnectionStrings:SosyoBel` bağlantısını kullanır ve yalnız EF
eşlemelerini kullanım senaryosuna göre ayırır.

## Yapılandırma

`src/SosyoBel.Api/appsettings.json` güvenli varsayılanları taşır. Bağlantı
cümlesi, JWT anahtarı, KPS adresi ve production fotoğraf yolu ortam değişkeni veya
secret yönetiminden gelir. Kaynak koda gerçek parola, token veya T.C. kimlik
numarası eklenmez.

Swagger Production'da varsayılan kapalıdır. `health/live` yalnız süreci,
`health/ready` SQL bağlantısını da sınar.

## Test yaklaşımı

Test dosyaları `tests/SosyoBel.UnitTests` altındadır. Bir değişiklikte
önce ilgili dar test grubu çalıştırılır; teslim öncesinde tüm solution build ve
testi alınır.

Önemli gruplar:

- Authentication ve rol modeli testleri
- KPS istemcisi, JSON okuyucu ve profil sorgusu testleri
- Tamamlanmış başvuru transaction/eşleme testleri
- İş listesi SQL üretimi testleri
- Fotoğraf doğrulama ve depolama testleri

## Yeni özellik eklerken

1. Sözleşme ve modeller `SosyoBel.Application` içine eklenir.
2. SQL, dış HTTP veya dosya sistemi uygulaması
   `SosyoBel.Infrastructure` içinde yazılır.
3. Dependency injection kaydı eklenir.
4. Endpoint yalnız HTTP doğrulaması ve sonuç eşlemesi yapar.
5. Başarı, doğrulama, yetki, çakışma ve dış servis hata senaryoları test edilir.
6. Şirket şemasında olmayan tablo/kolon gerektiği varsayılmaz; önce yetkili kararı
   alınır.
