# Karar Kaydı

Bu dosyada yalnızca açıkça onaylanmış kararlar tutulur.

## D-001 — Mobil teknoloji

- Durum: Onaylandı
- Karar: Mobil uygulama Flutter ile geliştirilecek.
- Gerekçe: Android ve iOS için ortak kod tabanı kullanılacak.

## D-002 — Tasarım kaynağı

- Durum: Onaylandı
- Karar: Figma tasarımı görsel referans olacak; onay alınmadan tasarım
  değiştirilmeyecek.
- Figma dosya anahtarı: `2hsOH3A060pG5EGZIAjrjY`

## D-003 — Sistem kapsamı

- Durum: Onaylandı
- Karar: Mobil uygulamaya ek olarak gerekli backend, API ve veri saklama
  bileşenleri de geliştirilecek.

## D-004 — Mevcut verilerin aktarımı

- Durum: Onaylandı
- Karar: Şirketin sağlayacağı veri türü ve formatı geldiğinde incelenecek ve
  sisteme uygun bir aktarım yöntemi geliştirilecek.

## D-005 — Varsayım yapılmaması

- Durum: Onaylandı
- Karar: Belirsiz konularda uygulama kararı alınmayacak; soru sorulup cevap
  kaydedilecek.

## D-006 — Uygulama kimliği

- Durum: Onaylandı
- Görünen uygulama adı: `Sosyo-Bel`
- Flutter proje adı: `sosyo_bel`
- Android application ID: `com.catsyazilim.sosyobel`
- iOS bundle identifier: `com.catsyazilim.sosyobel`

## D-007 — Kod açıklama standardı

- Durum: Onaylandı
- Karar: İlk kez kodu inceleyen geliştiricinin yapıyı anlayabilmesi için
  sınıflar, karmaşık iş akışları, entegrasyon sınırları ve karar gerekçeleri
  açıklanacak.
- Karar: Kodu tekrar eden gereksiz yorumlar yerine, neden ve bağlam anlatan
  yorumlar kullanılacak.
## D-008 — Kullanıcı hesaplarının kaynağı

- Durum: Onaylandı
- Karar: Mobil uygulama kullanıcıları belediye tarafından sağlanacak.
- Karar: Şu an için halka açık kullanıcı kayıt ekranı geliştirilmeyecek.

## D-009 — Giriş sonrası işlem seçimi

- Durum: Onaylandı
- Karar: Kullanıcı giriş yaptıktan sonra `Başvuru Yap` ve `Görevler`
  seçeneklerini içeren bir ekran gösterilecek.

## D-010 — Yeni başvuru başlangıç akışı

- Durum: Onaylandı
- Karar: `Başvuru Yap` seçeneği ilk başvuru formunu açacak.
- Karar: Formdaki `Devam Et` işlemi kullanıcıyı mevcut vatandaş profili ve
  inceleme akışına ilerletecek.

## D-011 — Vatandaş bilgilerinin kaynağı

- Durum: Onaylandı
- Karar: Vatandaş profil bilgilerinin sağlanmasında mevcut MERNİS
  entegrasyonu kullanılacak.
- Not: Entegrasyondan dönecek kesin alanlar ve teknik bağlantı yöntemi
  netleşmeden veri modeli uygulanmayacak.

## D-012 — Hazır API durumu

- Durum: Onaylandı
- Karar: Uygulama için kullanılabilecek hazır bir API bulunmuyor; gerekli API
  proje kapsamında geliştirilecek.
## D-013 — Görevler seçeneğinin hedefi

- Durum: Onaylandı
- Karar: Giriş sonrası işlem seçimindeki `Görevler` seçeneği mevcut bekleyen ve
  tamamlanmış başvuru listelerini içeren ana ekranı açacak.

## D-014 — Yeni ekranların tasarım dili

- Durum: Onaylandı
- Karar: `Başvuru Yap / Görevler` ekranı için ayrıca hazırlanmış bir tasarım
  bulunmuyor.
- Karar: Yeni ekran, mevcut Figma ekranlarının renk, tipografi, boşluk ve
  bileşen dili korunarak tasarlanacak; farklı bir görsel dil oluşturulmayacak.

## D-015 — Geçici form seçenekleri

- Durum: Onaylandı
- Karar: Engel durumu seçenekleri şirket API/veritabanı kaynağından gelecek.
  Kaynak paylaşılana kadar mevcut örnekler yalnızca arayüz geliştirmesinde
  kullanılacak.
- Karar: Yardım türü seçenekleri şirketin kesin listesi gelene kadar örnek
  verilerle geliştirilecek.
## D-016 — Aile Bilgileri adımı

- Durum: Onaylandı
- Karar: Vatandaş Profili ekranındaki `Devam Et`, Figma `2015:24213` Aile
  Bilgileri ekranını açacak.
- Karar: Aile üyesi satırları, Figma `2020:24542` durumundaki gibi açılıp
  kapanabilecek.
- Karar: Figma'daki kayıtlar başlangıç tasarım örneği olarak kalacak; ayrıntısı
  bulunmayan yakınların bilgileri saha personeli tarafından tamamlanabilecek.
- Karar: Genel `Bilgi Güncelle` düğmesi manuel aile yönetimini, kişi bazlı
  düğme ise seçilen kişinin güncelleme formunu açacak.
- Karar: Değişiklikler tek bir aile modeliyle üst akışa aktarılacak ve kalıcı
  API geldiğinde ekran yeniden yazılmadan repository katmanına bağlanabilecek.
## D-017 — Hane Durumu adımı

- Durum: Kısmen onaylandı
- Karar: Hane soruları MERNİS/KPS verisi değildir; belediye saha görevlisi
  gözlemine göre uygulamada elle dolduracak.
- Karar: Figma `2021:24845` Sorular ve `2024:25104` Fotoğraflar durumları aynı
  ekran akışı içinde geliştirilecek.
- Karar: Fotoğraflar Figma'daki kamera eylemiyle çekilecek ve bir hane için en
  fazla 15 fotoğraf eklenebilecek.
- Geçici karar: Figma'da bulunmayan açılır seçenekler tek bir fixture dosyasında
  örnek veri olarak tutulacak; şirket listeleri geldiğinde değiştirilecek.
- Açık konu: Alanların zorunlulukları, kesin seçenek listeleri ve
  `Save to directory of beneficiary` seçeneğinin sunucu davranışı şirket
  tarafından netleştirilecek.

## D-018 — Aktivite geri dönüş davranışı

- Durum: Onaylandı
- Karar: Aktivite ekranlarının üst başlık oku, tasarımla uyumlu bir uyarıdan
  sonra kullanıcıyı ilk `Yeni Başvuru` formuna döndürecek.
- Karar: Bu dönüş başvuruyu kapatmayacak; form, hane cevapları, fotoğraflar ve
  tamamla notu mevcut başvuru oturumu içinde korunacak.
- Karar: Alt `Geri Dön` düğmeleri uyarı göstermeden bir önceki adıma dönecek.
  Hane ekranında sıra `Fotoğraflar → Sorular → Aile Bilgileri` olacak.
- Karar: Veri kaybı uyarısı yalnızca kullanıcı başvurudan tamamen çıkacağı
  zaman gösterilecek.

## D-019 — Manuel aile bilgileri ve fotoğraf sınırı

- Durum: Onaylandı
- Karar: Bakanlık API'si hane üyelerini sağlamadığı için yakınların sınırlı
  bilgileri saha personeli tarafından manuel olarak eklenecek ve
  güncellenebilecek.
- Karar: Genel kalemli `Bilgi Güncelle` eylemi aile yönetim ekranını, kişi
  içindeki `Bilgi Güncelle` eylemi doğrudan seçilen kişinin formunu açacak.
- Karar: Silme işlemi onaylanmadığı için bu aşamada sunulmayacak.
- Karar: Bir hane için fotoğraf üst sınırı 15 olacak.
- Karar: Yakınlık standart bir açılır listeden seçilecek; listede bulunmayan
  değerler yalnızca `Diğer` seçildikten sonra aynı alan içinde elle
  yazılabilecek.
- Karar: Çalışma durumu yalnızca `Çalışıyor`, `Çalışmıyor` veya `Emekli`;
  yaşam durumu yalnızca `Sağ` veya `Ölü` olarak seçilebilecek.
- Karar: Eğitim durumu ortak ve anlaşılır seçeneklerden oluşan açılır listeden
  seçilecek.
- Karar: Yeni yakın formundaki seçenek listeleri ilgili giriş alanıyla birebir
  aynı genişlikte, yuvarlatılmış ve form akışı içinde açılacak; liste açılınca
  sonraki alanlar aşağı kayacak ve menünün altında kalmayacak.
- Karar: Doğum tarihi alanı yalnızca rakam girişini kabul ederek yazım
  sırasında otomatik `GG/AA/YYYY` biçimine dönüşecek.

## D-020 — Şirket veritabanıyla uyumluluk

- Durum: Onaylandı
- Karar: Cats Yazılım tarafından paylaşılan `sosyaldb.ipynb` şeması uyumluluk
  çalışmasının başlangıç şeması olarak kullanılacak.
- Karar: Mevcut `dbo` tabloları silinmeyecek, yeniden adlandırılmayacak veya
  onaysız biçimde değiştirilmeyecek; backend mevcut tablolara uyarlanacak.
- Karar: Mobil akışın şirkette karşılığı bulunmayan verileri ayrı `sosyobel`
  tamamlayıcı tablolarında tutulacak.
- Karar: Paylaşılan notebook ile gerçek hedef veritabanının aynı olduğu
  varsayılmayacak; migration öncesinde salt-okunur şema kontrolü yapılacak.
- Karar: Temiz yerel kurulum için hazırlanmış `000`–`005` migration zinciri
  şirketin mevcut veritabanına uygulanmayacak.

## D-021 — Mevcut kullanıcılar için güvenli geçiş

- Durum: Yetkili doğrulaması bekleyen geçici teknik karar
- Karar: `dbo.AspNetUsers` satırı bulunup
  `sosyobel.KullaniciUygulamaBilgileri` satırı bulunmayan hesap otomatik aktif
  kabul edilmeyecek.
- Karar: Mevcut şirket kullanıcılarına canlı ortamda otomatik profil kaydı
  açılmayacak; kurumun onayladığı kullanıcı ve rol listesi geldikten sonra ayrı,
  denetlenebilir bir geçiş betiği hazırlanacak.
- Karar: Gerçek `dbo.AspNetRoles` değerleri doğrulanana kadar canlı veriye rol
  ekleme, yeniden adlandırma veya dönüştürme işlemi uygulanmayacak.
