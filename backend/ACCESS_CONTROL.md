# Erişim kontrolü ve hesap yönetimi

## Rol modeli

Mobil API şirketin mevcut ASP.NET Identity tablolarını kullanır. Kullanıcı ve rol
kayıtları `dbo.AspNetUsers`, `dbo.AspNetRoles` ve `dbo.AspNetUserRoles`
tablolarından okunur; mobil API ikinci bir kullanıcı veya belediye üyeliği
oluşturmaz.

Mobil erişim verebilen mevcut rol adları:

- `Admin`
- `Kurul`
- `Personel`

Bu roller yeniden adlandırılmaz. Admin ve Kurul hesapları da mobil saha
işlemlerinde Personel hesabıyla aynı temel erişime sahip olabilir.

## API sınırı

Kullanıcı, rol, parola ve belediye yönetimi şirketin web panelinin
sorumluluğundadır. Bu nedenle aşağıdaki eski yönetim yüzeyleri mobil API'ye map
edilmez ve Swagger'da gösterilmez:

- sistem/belediye oluşturma,
- personel oluşturma, pasifleştirme veya parola sıfırlama,
- belediye üyeliğine bağlı yetki yönetimi,
- eski çoklu belediye audit endpointleri.

Mobil API yalnız oturum, başvuru, KPS, görev, iş listesi ve form referans
sözleşmelerini dışarı açar.

## Token ve oturum

Başarılı login sonucunda JWT access token ile tek kullanımlık refresh token
döndürülür. Access token kullanıcı kimliği, kullanıcı adı, isteğe bağlı e-posta,
görünen ad ve mevcut Identity rollerini taşır. Belediye kodu veya belediye
üyeliği login isteğinin parçası değildir.

Refresh tokenın kendisi veritabanına açık metin olarak yazılmaz. Hash ve oturum
metadata bilgileri şirketin mevcut `dbo.AspNetUserTokens` tablosunda tutulur.
Logout refresh tokenı iptal eder; yeniden kullanım tespit edilirse oturum
güvenlik nedeniyle kapatılır.

## HTTP davranışı

- Login, refresh ve logout anonim çağrı kabul eder.
- Diğer mobil endpointler geçerli Bearer access token ister.
- Token yoksa veya geçersizse `401` döner.
- Hesapta mobil erişim veren rol yoksa `403` döner.
- Swagger'daki Authorize alanına yalnız token yapıştırılır; Bearer önekini
  Swagger ekler.
