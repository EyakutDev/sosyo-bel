# Erişim kontrolü ve hesap yönetimi

## Rol modeli

- `SISTEM_YONETICISI`: Cats sistem rolüdür ve yalnız ASP.NET Identity rol
  tablosunda tutulur. Belediye üyeliği yoktur.
- `BELEDIYE_YONETICISI`: `sosyobel.KullaniciBelediyeleri.RolKodu` üzerinde,
  belirli bir belediyeye bağlıdır.
- `PERSONEL`: aynı şekilde belirli belediye üyeliğine bağlıdır.
- `KILITLI_BASVURU_DUZENLE`: rol değil, geri alınabilir ve belediye kapsamlı
  özel yetkidir (`sosyobel.KullaniciYetkileri`).

Belediye rolleri global Identity rolü olarak verilmez. Böylece bir belediyedeki
rol başka bir belediyeye taşınamaz. Veritabanı gelecekte çoklu üyeliği
destekler; mevcut servis akışı yeni kullanıcıyı yalnız tek üyelikle oluşturur.

## Token ve anlık doğrulama

Belediye kullanıcısının access token'ında şu claim'ler birlikte bulunur:

- `municipality_id`
- `municipality_code`
- `municipality_membership_id`
- üyelikten gelen tek belediye rolü

Sistem yöneticisi token'ında belediye claim'i bulunmaz. Refresh sırasında rol
ve üyelik yeniden okunur. Ayrıca yetkili endpoint politikaları her istekte
kullanıcı, belediye, üyelik ve rolün hâlâ aktif olduğunu veritabanından kontrol
eder; bu nedenle kapatılan hesabın henüz süresi dolmamış access token'ı da
belediye işlemlerinde kullanılamaz.

`KILITLI_BASVURU_DUZENLE` JWT'ye gömülmez. Kritik işlem anında güncel yetki
kaydı okunur.

## Yönetim endpoint'leri

| Yetki | Endpoint | İşlem |
|---|---|---|
| Sistem yöneticisi | `POST /api/v1/system/municipalities` | Belediye ve ilk belediye yöneticisi |
| Sistem yöneticisi | `PUT /api/v1/system/municipalities/{code}/personnel/{userId}/permissions/locked-application-edit` | Özel yetki ver/iptal et |
| Belediye yöneticisi | `POST /api/v1/municipality/personnel/` | Kendi belediyesinde personel oluştur |
| Belediye yöneticisi | `POST /api/v1/municipality/personnel/{userId}/reset-password` | Personel şifresini sıfırla |
| Belediye yöneticisi | `POST /api/v1/municipality/personnel/{userId}/deactivate` | Personeli kapat |
| Personel | `GET /api/v1/tasks/assigned` | Yalnız kendi üyeliğine atanmış görevler |

Mutasyon endpoint'lerinde 8-100 karakterlik tek bir `Idempotency-Key` header'ı
zorunludur. Aynı aktör/endpoint/anahtar tekrarında işlem ikinci kez uygulanmaz;
aynı anahtar farklı güvenli payload ile kullanılırsa `409` döner. Parola,
idempotency hashine veya sonuç JSON'una yazılmaz.

## Audit görünürlüğü

- Sistem yöneticisi: `GET /api/v1/system/audit` (tüm belediyeler; isteğe bağlı
  `municipalityCode` filtresi)
- Belediye yöneticisi: `GET /api/v1/municipality/audit` (yalnız kendi belediyesi)
- Personel: `GET /api/v1/audit/mine` (yalnız kendi ürettiği olaylar)

Audit kaydı aktör, hedef kullanıcı, UTC zaman, gerekçe, cihaz, IP ve correlation
kimliği taşır. Parola/token taşımaz. `TR_IslemGecmisleri_AppendOnly` triggerı
mevcut audit satırlarının güncellenmesini ve silinmesini engeller.

## Kurulum ve doğrulama

İlk sistem yöneticisi için [BOOTSTRAP.md](BOOTSTRAP.md) izlenir. Migration sırası
`000` → `001` → `002` → `003` → `004` şeklindedir.

Yerel geçici veritabanında doğrulama:

```powershell
./backend/scripts/validate-schema.ps1 -SqlServer 'localhost\MSSQLSERVER01'
./backend/scripts/validate-administration-flow.ps1 -SqlServer 'localhost\MSSQLSERVER01'
```

İki betik de yalnız kendilerinin oluşturduğu geçici veritabanını kullanır ve
`finally` bloğunda kaldırır.
