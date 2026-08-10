# İlk sistem yöneticisi kurulumu

İlk Cats sistem yöneticisi HTTP üzerinden oluşturulmaz. Yalnız dağıtım veya
kurulum yetkisine sahip kişinin çalıştırdığı `SosyoBel.Bootstrap` aracı kullanılır.

Gerekli ortam değişkenleri:

- `ConnectionStrings__SosyoBel`
- `SOSYOBEL_BOOTSTRAP_EMAIL`
- `SOSYOBEL_BOOTSTRAP_FIRST_NAME`
- `SOSYOBEL_BOOTSTRAP_LAST_NAME`
- `SOSYOBEL_BOOTSTRAP_PASSWORD` (isteğe bağlı; interaktif çalışmada gizli sorulur)

Çalıştırma:

```powershell
dotnet run --project backend/src/SosyoBel.Bootstrap/SosyoBel.Bootstrap.csproj
```

Üretimde değerler Bitbucket Pipelines/dağıtım platformunun secret deposundan
enjekte edilmelidir. Gerçek parola `.env`, `appsettings*.json`, komut satırı
argümanı veya repository içine yazılmamalıdır.

Araç fail-closed çalışır:

- Sistemde yönetici yoksa ilk hesabı oluşturur.
- Aynı aktif yönetici zaten varsa hiçbir alanı ve parolayı değiştirmeden başarılı döner.
- Başka, pasif veya tutarsız bir sistem yöneticisi varsa yeni hesap/rol üretmez.
- Mevcut sıradan bir kullanıcıyı otomatik olarak sistem yöneticisine yükseltmez.
