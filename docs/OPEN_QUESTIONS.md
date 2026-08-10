# Açık Sorular

## Projeyi oluşturmadan önce gerekli

- [x] Android `applicationId` ve iOS `bundle identifier`:
  `com.catsyazilim.sosyobel`
- [x] Uygulamanın mağazalarda görünecek kesin adı: `Sosyo-Bel`
- [x] Uygulamanın kaynak koddaki paket/proje adı: `sosyo_bel`

## Şirket altyapısı

- [x] Sistemin bulut altyapısı kullanacağı belirtildi.
- [ ] Bulutta tam olarak hangi bileşenler çalışacak?
- [ ] MERNİS ve diğer kurum sunucularıyla iletişimi hangi sunucu kuracak?
- [ ] Mobil cihazlar API'ye doğrudan internetten mi, VPN üzerinden mi erişecek?
- [ ] Docker ve Docker Compose kullanımına izin veriliyor mu?
- [ ] Test ve canlı ortamlar ayrı olacak mı?
- [ ] API için alan adı ve TLS/SSL sertifikası sağlanacak mı?

## İş kuralları

- [ ] Kullanıcı rolleri ve her rolün yetkileri nelerdir?
- [x] `Görevler` seçeneği mevcut bekleyen/tamamlanmış listelerini açacak.
- [ ] Başvuru durumlarının kesin sırası ve geçiş kuralları nelerdir?
- [x] Kurula gönderilen kayıt sonradan değiştirilemeyecek.
- [ ] Taslak kayıt telefonda mı, sunucuda mı, yoksa her ikisinde mi saklanacak?
- [ ] İnternet bağlantısı yokken hangi işlemler yapılabilmelidir?

## Entegrasyonlar

- [ ] MERNİS entegrasyonunun API dokümanı, erişim yöntemi ve test ortamı var mı?
- [ ] MERNİS'ten hangi profil alanları dönecek?
- [ ] MERNİS sorgusu formdaki `Devam Et` işleminde mi çalışacak?
- [ ] MERNİS sorgusu başarısız olduğunda veya kayıt bulunamadığında ne yapılacak?
- [ ] Harita sağlayıcısı hangisi olacak?
- [ ] Bildirimler push bildirimi mi, uygulama içi bildirim mi, yoksa ikisi de mi
  olacak?
- [x] Bir başvuruya en fazla 15 hane fotoğrafı eklenebilecek.
- [ ] Fotoğrafların boyutu, sıkıştırma ve saklama kuralları nelerdir?

## Veri aktarımı

- [ ] Şirketin mevcut verileri ne zaman ve hangi formatta sağlanacak?
- [ ] Kayıtların tekilleştirilmesi için kullanılacak alanlar nelerdir?
- [ ] Hatalı ve mükerrer kayıtların nasıl ele alınacağı nedir?
- [ ] Veri aktarımı için bir yönetim ekranı gerekli midir?

## Yeni başvuru formu

- [x] `Başvuru Yap / Görevler` ekranı için ayrıca hazırlanmış tasarım yok;
  mevcut ekranların tasarım dili kullanılacak.
- [ ] Yeni başvuru formunun paylaşılan ekran görüntüsü kesin tasarım mı?
- [ ] Engel durumu seçeneklerinin şirket tarafından onaylanmış kesin listesi
  nedir? İlk geliştirmede geçici örnekler kullanılacak.
- [ ] Yardım türlerinin şirket tarafından onaylanmış kesin listesi ve yönetim
  kaynağı nedir? İlk geliştirmede geçici örnekler kullanılacak.
- [ ] T.C. kimlik numarası, doğum tarihi ve telefon için kesin doğrulama
  kuralları nelerdir?
- [ ] Talep açıklaması için karakter sınırı var mı?
- [ ] Form verisi `Devam Et` sırasında kaydedilecek mi, yoksa tüm inceleme
  tamamlanınca mı gönderilecek?

## Teslim ve yayın

- [ ] Şirketin Google Play Console hesabı var mı?
- [ ] Şirketin Apple Developer hesabı var mı?
- [ ] Minimum Android ve iOS sürümleri nelerdir?
- [ ] Şirketin KVKK, yedekleme ve veri saklama politikaları nelerdir?
