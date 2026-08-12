# Sosyo-Bel V2 Veritabanı Tasarımı

> **Önemli:** Bu belgedeki `000`–`005` migration zinciri boş yerel geliştirme
> veritabanı içindir. Cats Yazılım tarafından paylaşılan mevcut `dbo` şemasına
> uygulanmayacaktır. Şirket şemasını koruyan güncel yaklaşım ve çakışma analizi
> için `docs/DATABASE_COMPATIBILITY.md` belgesine bakın.

## Durum

Veritabanı şemasının kaynak kontrolündeki tek doğruluk kaynağı `database/`
altındaki migration, seed ve check dosyalarıdır. Kişisel keşif notebook'ları
kurulum kaynağı değildir ve repoya alınmaz. Yeni model ayrı `sosyobel` şeması
altında hazırlanmıştır; mevcut `dbo` tablolarını kontrolsüz biçimde değiştirmez.

Migration ve doğrulama zinciri yerel SQL Server üzerinde çalıştırılmış, API yaşam
döngüsü de yerel uçtan uca test edilmiştir. Dosyalar henüz şirketin test veya canlı
veritabanına uygulanmamıştır; bu işlem kurum bağlantı bilgileri ve onayıyla yapılır.

## Neden ayrı `sosyobel` şeması kullanıldı?

Paylaşılan şemanın canlı veri içerip içermediği ve başka bir uygulama tarafından
kullanılıp kullanılmadığı bilinmiyor. Eski `dbo` tablolarını doğrudan değiştirmek
veri kaybı veya mevcut sistemi bozma riski taşır.

Yeni şema şu yararları sağlar:

- Eski taslak ve olası eski veriler korunur.
- API'nin kullanacağı tablolar açıkça ayrılır.
- Eski veriler daha sonra doğrulama ve dönüştürme kurallarıyla aktarılabilir.
- Migration geri alınmasa bile eski tablolar etkilenmez.
- Şirket devrinde eski yapı ile yeni yapı arasındaki sınır anlaşılır kalır.

## Dosyalar ve uygulanma sırası

1. `database/migrations/` altındaki numaralı dosyalar sırayla çalıştırılır.
2. Üretimde yalnız `database/seed/001_confirmed_reference_data.sql` içindeki
   onaylı ortak referans verileri uygulanır.
3. `database/checks/` altındaki aynı sırayı izleyen doğrulamalar çalıştırılır.
4. `002_development_form_options.sql` ve
   `003_development_household_options.sql` yalnız yerel geliştirme/test içindir;
   şirketin kesin referans verisi yerine üretimde kullanılmaz.

Bu eski bağımsız zincir yalnız `backend/scripts/validate-schema.ps1` içindeki
izole şema doğrulamasında korunur. Güncel yerel kurulum
`backend/scripts/initialize-local-development.ps1` ile şirketin veri içermeyen
`dbo` snapshot'ını ve `database/compatibility/` zincirini kullanır. Güncel
kurulum yaklaşımı için `docs/DATABASE_COMPATIBILITY.md` esas alınır.

## Eski şemaya göre yapılan temel revizyonlar

### 1. Belediye ayrımı

Eski `SistemAyarlari`, tek belediye bilgisi taşıyan genel bir tabloydu. V2'de:

- `Belediyeler` belediye adı, kodu ve logo anahtarını tutar.
- `KullaniciBelediyeleri` Identity kullanıcısını yetkili olduğu belediyeye bağlar.
- Vatandaş ve başvuru kayıtları `BelediyeId` taşır.

Bu yapı tek belediyelik kurulumda bir satırla çalışır; birden fazla belediye aynı
backend'i kullanırsa kayıtların birbirine karışmasını engellemek için de temel
oluşturur. API, belediye kimliğini istek gövdesinden değil oturumdan belirlemelidir.

### 2. Kararlı seçenek kodları

Eski lookup tablolarında yalnızca gösterilen ad bulunuyordu. V2'de her seçeneğin:

- Değişmeyen `Kod` değeri
- Kullanıcıya gösterilen `Ad` değeri
- Gösterim sırası
- Aktiflik durumu

bulunur. Mobil uygulama `Çalışıyor` gibi değiştirilebilir etiketi değil,
`CALISIYOR` gibi kararlı kodu API'ye gönderir.

### 3. Vatandaş tekilleştirme ve veri tipleri

- T.C. kimlik numarası belediye bazında benzersizdir.
- T.C. kimlik numarası için 11 rakam kontrolü vardır.
- Doğum tarihi metin yerine `date` tipindedir.
- Telefon API'de normalize edilmiş uluslararası biçimde tutulabilecek uzunluktadır.
- Engel oranı 0–100 aralığıyla sınırlandırılmıştır.
- `nvarchar(max)` yalnız gerçekten uzun JSON/audit verilerinde kullanılmıştır.

Ekrandaki `03/11/2002` ve `(534)-551-2872` biçimleri yalnız sunum biçimidir. API
veritabanına tarih ve telefonun normalize edilmiş değerini yazacaktır.

### 4. Başvuru anlık kopyası

`Basvurular`, başvuru sırasında görülen vatandaş bilgilerini ayrıca saklar. Daha
sonra vatandaş profili değişse bile geçmiş başvurunun adı, adresi ve diğer
bilgileri değişmez.

`BasvuruAileFertleri` de aynı nedenle `AileFertleri` tablosunun başvuru anındaki
anlık kopyasıdır.

### 5. Manuel aile bilgileri

Eski aile tablolarına aşağıdaki eksik alanlar eklenmiştir:

- `YakinlikDigerAciklama`
- `YasamDurumuId` (`Sağ` veya `Ölü`)
- `EngelAciklamasi`
- Oluşturan/güncelleyen personel
- UTC zamanları ve `rowversion`

Yaş için 0–130 aralığı uygulanır. Uygulama şu anda doğum tarihi değil yaş aldığı
için V2 de mevcut ekran sözleşmesine göre `Yas` saklar.

### 6. Hane soru ve cevapları

Eski şemada uygulamadaki hane sorularını saklayacak tablo yoktu. V2'de:

- `HaneSorulari`
- `HaneSoruSecenekleri`
- `BasvuruHaneCevaplari`

tabloları eklenmiştir. Sorular ve seçenekler kodla güncelleme yapmadan yönetilebilir.
Bir başvuru aynı soruya yalnız bir cevap verebilir.

Mevcut beş sorunun seçenekleri geçici olduğu için üretim seed dosyasına
eklenmemiştir. Şirket kesin listeyi doğruladığında veri olarak eklenecektir.

### 7. Fotoğraflar

Eski `Basvurular.HaneFotografYolu` tek fotoğraf taşıyabiliyor, eski
`HaneFotograflari` ise fotoğrafı başvuru yerine vatandaşa bağlıyordu.

V2 `BasvuruFotograflari` tablosu:

- Fotoğrafı doğrudan başvuruya bağlar.
- Dosyanın kendisini değil object storage anahtarını saklar.
- MIME türü, boyut ve SHA-256 özeti tutar.
- Zararlı yazılım taraması ve EXIF temizleme durumunu tutar.
- Silme işlemini kullanıcı ve zaman bilgisiyle izler.
- Aktif fotoğraf sıra numarasını 1–15 ile sınırlar.

Sıra numarası hem 1–15 aralığında hem başvuru içinde benzersiz olduğu için bir
başvuruda en fazla 15 aktif fotoğraf veritabanı seviyesinde de garanti edilir.

### 8. Kurul ve değiştirilemezlik

Eski `KurulIslemleri`, yalnız `VatandasId` taşıyordu. V2 kurul işlemini
`BasvuruId` ile bağlar. Böylece aynı vatandaşın farklı başvurularının kararları
karışmaz.

`BasvuruDurumGecmisi`, her durum değişikliğinin önceki/yeni durumunu, personeli ve
zamanını saklar. `Basvurular.RowVersion`, eş zamanlı iki güncellemenin birbirini
sessizce ezmesini engellemek için kullanılır.

Kurula gönderilmiş kaydın güncellenmesini reddetme kuralı API'de uygulanır.
Taslak oluşturma, saha verisi/fotoğraf kaydı ve `KURUL_BEKLIYOR` geçişi güncel
`RowVersion` ile sıralanır. Kesinleşmemiş sonraki kurul kararları için kısıtlayıcı
bir trigger eklenmemiştir.

### 9. Görevler

Eski `SahaAktiviteleri` vatandaş üzerinden ilerliyordu. V2 `SahaGorevleri`, görevi
başvuruya ve atanan Identity kullanıcısına bağlar. Bu yapı bekleyen/tamamlanmış
görev listesini doğru personel için sorgulamayı sağlar.

Görev durumlarının kesin kodları henüz onaylanmadığı için seed edilmemiştir.

### 10. Veri aktarımı

CSV ve ileride sağlanabilecek diğer formatlar için:

- `VeriAktarimIslemleri`
- `VeriAktarimSatirHatalari`

tabloları eklenmiştir. Toplam, başarılı ve hatalı satır sayıları ile maskelenmiş
hata bilgileri kaydedilebilir. İçe aktarma doğrudan tablolara kontrolsüz INSERT
yapmayacak; API/worker doğrulamasından geçecektir.

### 11. Kimlik doğrulama

Temiz yerel kurulum zincirindeki `000` migration'ı Identity tablolarını oluşturur.
Şirket uyumluluk yaklaşımında bu migration çalıştırılmaz ve mevcut
`dbo.AspNetUsers` tablosu korunur. `YenilemeTokenlari`, mobil oturumlar için
refresh tokenın açık değerini değil SHA-256 özetini tutar.

## Flutter alanlarının V2 karşılıkları

| Flutter alanı | V2 karşılığı |
|---|---|
| T.C. kimlik numarası | `Basvurular.BasvuranTcKimlikNo` ve vatandaş kaydı |
| Doğum tarihi | `Basvurular.BasvuranDogumTarihi` (`date`) |
| Telefon | `Basvurular.BasvuranTelefon` |
| Engel durumu | `EngelDurumu`, `EngelOrani`, `EngelTuruId` |
| Yardım türü | `YardimTuruId` |
| Talep açıklaması | `TalepAciklamasi` |
| Profil bilgileri | `Vatandaslar` ve başvuru anlık kopyası |
| Manuel yakınlar | `AileFertleri` ve `BasvuruAileFertleri` |
| Beş hane cevabı | `BasvuruHaneCevaplari` |
| En fazla 15 fotoğraf | `BasvuruFotograflari` |
| Tamamla ekranı notu | `SahaIncelemeNotu` |
| Taslak/kurul/tamamlandı | `BasvuruDurumuId` ve durum geçmişi |

## Bilinçli olarak açık bırakılan konular

Aşağıdaki kararlar doğrulanmadan varsayılmamıştır:

- Paylaşılan eski şemanın canlı veya yalnız taslak olması
- SQL Server'ın kesin sürümü
- Tek veritabanında çok belediye mi, belediye başına ayrı veritabanı mı kullanılacağı
- Yardım ve engel türlerinin kesin kayıtları
- Hane soru seçeneklerinin kesin kayıtları ve zorunlulukları
- Kurulun reddetme/iptal/tamamlama geçişlerinin kesin sırası
- Fotoğraf boyutu, formatı, saklama süresi ve object storage ürünü
- `Save to directory of beneficiary` seçeneğinin sunucu davranışı
- Görev durumlarının kesin listesi
- Çevrimdışı taslak ve senkronizasyon davranışı
- Eski `PublicToken` alanının amaçlanan kullanımı

Bu kararlar geldikten sonra yeni migration ve seed dosyaları eklenmelidir; daha
önce çalıştırılmış migration dosyaları geriye dönük değiştirilmemelidir.
