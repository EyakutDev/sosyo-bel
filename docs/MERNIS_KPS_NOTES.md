# MERNİS / KPS Entegrasyonu Teknik Notu

> Araştırma tarihi: 29 Temmuz 2026
> Bu not, NVİ'nin kamuya açık resmî sayfalarına dayanır. Gerçek servisler ve dönen alanlar, belediyenin NVİ ile yaptığı veri paylaşımı anlaşması ve kendisine verilen yetkiler görülmeden kesinleştirilemez.

## MERNİS ile KPS aynı şey değildir

- **MERNİS**, nüfus kayıtlarının merkezî ve elektronik olarak tutulduğu kaynak sistemdir.
- **KPS (Kimlik Paylaşımı Sistemi)**, MERNİS'te tutulan nüfus kayıtları ile yerleşim yeri bilgilerinin mevzuat ve kurum yetkileri çerçevesinde paylaşılmasını sağlayan kurumsal erişim katmanıdır.

## MERNİS kapsamındaki nüfus kayıt alanları

NVİ'nin KVKK metninde aktardığı 5490 sayılı Kanun'un 7. maddesine göre aile kütüklerinde özetle şu bilgiler bulunur:

- T.C. kimlik numarası
- Nüfusa kayıtlı olunan il, ilçe, köy/mahalle ile cilt, aile ve birey sıra numaraları
- Ad, soyad, cinsiyet; anne ve baba bilgileri; ilgili önceki soyadı bilgileri
- Doğum yeri, doğum tarihi ve kütüğe kayıt tarihi
- Evlenme, boşanma, soybağı, ölüm, vatandaşlık ve kayıt düzeltmesi gibi kişisel durum olayları
- Din ve medeni hâl
- Yerleşim yeri adresi
- Fotoğraf, biyometrik veri, velayet ve vesayet bilgileri

Bu liste, kayıt sisteminde bulunabilecek alanları açıklar; belediyenin KPS üzerinden bunların tamamına erişebileceği anlamına gelmez.

## KPS'nin sunduğu temel sorgular

NVİ'nin açıklamasında KPS üzerinden temel olarak şunların sunulduğu belirtilir:

- T.C. kimlik numarasına karşılık kişi bilgisi sorgulama
- Kişi bilgilerine karşılık T.C. kimlik numarası sorgulama
- Nüfusa kayıtlı olunan yer bilgilerine karşılık kimlik bilgisi sorgulama
- Nüfus kayıt örneği sorgulama
- Adres bilgisi sorgulama

Hangi sorguların kullanılabileceği ve her sorguda hangi alanların görülebileceği, NVİ ile kurum arasındaki ikili anlaşmanın/veri paylaşımı taahhütnamesinin yetkilendirme kapsamına bağlıdır. Bu nedenle projede hiçbir alan için şimdiden **“kesin döner”** kabulü yapılmamalıdır.

## Erişim ve ağ gereksinimleri

- KPS, herkese açık bir veri API'si değildir; belediye adına kurumsal başvuru, onay ve yetkilendirme gerekir.
- Yetkiler kurumun idari kullanıcısı tarafından yönetilir; servis ayrıntıları yetkili KPS başvuru portalında görülür.
- NVİ'nin SSS sayfasına göre KPSv2, kurumun başvuruda bildirdiği **statik IP adresi** dışından yanıt vermez. Bulut ortamındaki kurum backend'i bu nedenle kayıtlı, sabit bir çıkış IP'si üzerinden erişebilmelidir.
- KPS işlemleri geri izlenebilir şekilde loglanır. Uygulama tarafında da erişim amacı, kullanıcı, zaman ve işlem sonucuna ilişkin denetim kaydı tasarlanmalıdır.

## Kamu doğrulama ekranı ile KPS farkı

NVİ'nin kamuya açık T.C. Kimlik No Doğrulama hizmeti, kullanıcının girdiği kimlik numarası, ad-soyad ve doğum bilgileri gibi değerlerin kayıtla uyuşup uyuşmadığını **doğrulamak** içindir. Bu hizmeti bir vatandaşın profil bilgilerini getirip formu otomatik dolduran KPS sorgusu gibi değerlendirmemeliyiz.

NVİ'nin güncel duyurusuna göre eski kamu web sayfası doğrulama servislerinin entegrasyon erişimi 30 Eylül 2025'e kadar uzatıldıktan sonra kapatılmış, tarayıcıdaki doğrulama ekranları ise açık bırakılmıştır. Bu nedenle proje, internetteki eski `KPSPublic` örneklerini kullanılabilir bir kurumsal API kabul ederek tasarlanmamalıdır.

KPS ise yetkilendirilmiş kurumların, anlaşmalarındaki kapsam dâhilinde nüfus ve adres verilerine erişmesini sağlayan kurumsal sistemdir.

## Sosyo-Bel profil alanlarının ön değerlendirmesi

| Profil alanı | Ön değerlendirme |
| --- | --- |
| T.C. kimlik numarası | MERNİS nüfus kaydı kapsamındadır; ilgili KPS hizmetinde erişim yetkisi ayrıca doğrulanmalıdır. |
| Ad-soyad | Nüfus kaydı kapsamındadır; dönen alan anlaşmaya bağlıdır. |
| Doğum tarihi | Nüfus kaydı kapsamındadır; dönen alan anlaşmaya bağlıdır. |
| Medeni hâl | Nüfus kaydı kapsamındadır; dönen alan anlaşmaya bağlıdır. |
| Yerleşim yeri adresi | Nüfus/adres sistemi ve KPS sorguları kapsamında olabilir; kurumun adres sorgusu yetkisi doğrulanmalıdır. |
| Telefon numarası | Aile kütüğü alanları arasında sayılmıyor; başvuruda kullanıcıdan veya belediyenin başka sisteminden alınmalıdır. |
| Engel durumu | Aile kütüğü alanları arasında sayılmıyor; KPS'den geleceği varsayılmamalıdır. Ayrıca hassas veri olarak ayrı hukuki ve güvenlik değerlendirmesi gerekir. |
| Çocuk sayısı | Doğrudan bir aile kütüğü alanı olarak sayılmıyor. Yetkili nüfus kayıt/aile ilişkisi verilerinden türetilebilmesi mümkün olsa bile servis ve yetki görülmeden varsayılmamalıdır. |
| Çalışma durumu | Aile kütüğü alanları arasında sayılmıyor; başka bir kaynak veya kullanıcı beyanı gerekir. |
| Eğitim durumu | Aile kütüğü alanları arasında sayılmıyor; başka bir kaynak veya kullanıcı beyanı gerekir. |

## Uygulama mimarisi için sonuç

Mobil uygulama **doğrudan KPS'ye bağlanmamalıdır**. Önerilen sınır:

```text
Sosyo-Bel mobil uygulaması
        ↓ HTTPS
Kurumun/Cats Yazılım'ın yetkili backend'i
        ↓ kayıtlı statik IP + kurumsal KPS yetkileri
NVİ KPS
```

KPS kullanıcı bilgileri, sertifikaları veya diğer sırlar mobil uygulamaya gömülmemeli; sadece backend'de tutulmalıdır. Backend ayrıca alan bazlı yetki kontrolü, veri minimizasyonu, denetim kaydı ve hata yönetiminden sorumlu olmalıdır.

Uygulamayı gerçek KPS alanlarına bağlamadan önce belediyeden şu belgeler/bilgiler alınmalıdır:

1. KPS/KRM başvuru ve protokol durumu
2. Yetkili servislerin adları ve erişilebilen cevap alanları
3. Kuruma sağlanan güncel teknik servis dokümanı ve varsa test ortamı
4. Kayıtlı statik IP ve backend'in çalışacağı ağ/bulut topolojisi
5. Kimlik bilgisi, sertifika ve teknik kullanıcıların kurum içindeki sahibi
6. KVKK, erişim logu ve veri saklama politikaları

## Resmî kaynaklar

- [NVİ — Kimlik Paylaşımı Sistemi (KPS)](https://www.nvi.gov.tr/kps)
- [NVİ İstanbul — Kimlik Paylaşım Sistemi ve temel sorgular](https://nvi.gov.tr/istanbul/kimlik-paylasim-sistemi)
- [NVİ — KVKK Aydınlatma Metni ve aile kütüğü alanları](https://www.nvi.gov.tr/kvkk-aydinlatma-metni)
- [NVİ — Bilgi İşlem ve Sistemler SSS](https://www.nvi.gov.tr/sss-bilgi-islem-ve-sistemler)
- [NVİ — Kamuya açık çevrimiçi doğrulamalar](https://tckimlik.nvi.gov.tr/Home?v=1.0.24)
