# Proje Özeti

## Amaç

Sosyo-Bel, belediye saha ekiplerinin kendilerine atanan sosyal yardım
başvurularını görüntüleyebilmesini, hane ziyaretinde gerekli bilgileri
toplayabilmesini ve inceleme sonucunu ilgili değerlendirme sürecine
iletebilmesini sağlayacaktır.

## Kesinleşmiş kapsam

- Mobil uygulama Flutter ile geliştirilecektir.
- Uygulama Android ve iOS platformlarında çalışacaktır.
- Figma tasarımı görsel kaynak kabul edilecek ve onay alınmadan
  değiştirilmeyecektir.
- Mobil uygulamanın ihtiyaç duyduğu backend, API ve veri saklama bileşenleri
  proje kapsamında geliştirilecektir.
- Hazır bir uygulama API'si bulunmamaktadır.
- Mobil uygulamayı kullanacak personel hesapları belediye tarafından
  sağlanacaktır; halka açık kullanıcı kaydı akışı planlanmamaktadır.
- Şirketin sağlayacağı mevcut veriler, sağlandıkları format incelendikten sonra
  sisteme aktarılabilecektir.
- Vatandaş profil bilgilerinin MERNİS entegrasyonundan getirilmesi
  planlanmaktadır. Getirilecek alanlar ve teknik entegrasyon sözleşmesi henüz
  kesinleşmemiştir.
- Sistem şirket devrine uygun olarak kaynak kodu, yapılandırması ve teknik
  belgeleriyle teslim edilecektir.
- Belirsiz tasarım, iş kuralı veya teknik kararlar varsayılmayacak; uygulamadan
  önce kullanıcıdan ya da şirket yetkilisinden onay alınacaktır.

## Doğrulanan ana akış

1. Personel girişi
2. `Başvuru Yap` ve `Görevler` seçeneklerini gösteren işlem seçimi ekranı
3. `Başvuru Yap` seçildiğinde ilk başvuru formu
4. Formda `Devam Et` seçildiğinde vatandaş profili ve mevcut inceleme akışı
5. Bekleyen ve tamamlanmış başvurular
6. Bildirimler
7. Vatandaş profili ve konum
8. Aile bilgileri
9. Hane durumu soruları
10. Hane fotoğrafları
11. Taslak kaydetme veya kurula gönderme

## Yeni başvuru formu için verilen alanlar

- Kişi bilgileri:
  - T.C. Kimlik Numarası (zorunlu)
  - Doğum Tarihi (zorunlu)
  - Engel Durumu (zorunlu)
- Talep bilgileri:
  - Telefon Numarası (zorunlu)
  - Talep Edilen Yardım Türü (zorunlu)
  - Talep Açıklaması

Formun kesin doğrulamaları, seçim listeleri ve MERNİS sorgusunun hangi aşamada
çalışacağı henüz netleşmemiştir.

## Henüz kapsamı kesinleşmeyen bileşenler

- Yönetim panelinin ekranları ve yetkileri
- Bulutta çalışacak sunucu bileşenleri ve diğer sunucularla iletişim mimarisi
- Backend teknoloji seçimi
- Veritabanı ve dosya depolama çözümü
- Çevrimdışı çalışma gereksinimi
- Harita ve bildirim sağlayıcıları
- Veri içe aktarma arayüzünün kesin davranışı
