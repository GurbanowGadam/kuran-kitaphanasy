# Play Console'a yükleme rehberi — 1.0.0+3

Sahip için adım adım yol. Sıra önemlidir. Hesap türü: **kişisel** → üretime çıkmadan
önce kapalı test zorunluluğu var (adım 7).

Teknik durum (2026-11-18, yerel derleme ile doğrulandı):

| Kontrol | Sonuç |
|---|---|
| applicationId / sürüm | `tm.kuran.kitaphanasy`, versionName 1.0.0, versionCode 3 |
| targetSdk / minSdk | 36 / 24 (Play'in 2026 hedef API şartını karşılar) |
| 16 KB sayfa hizalaması | Tüm `.so` dosyaları ≥ 16 KB hizalı |
| İzinler (birleşik manifest) | `INTERNET`, `ACCESS_NETWORK_STATE` (ExoPlayer/media3), androidx iç izni; reklam kimliği (AD_ID) yok |
| Yedekleme / düz HTTP | `allowBackup=false`, `usesCleartextTraffic=false` |
| Hata ayıklama sembolleri, R8 eşlemesi | AAB içinde (Console uyarısı çıkmaz) |
| AAB boyutu | ~60 MB (cihaza inen boyut daha küçüktür; sesler dahil değil) |

## 1. Upload anahtarını oluşturun (bir kez)

Bu anahtar **kaybolursa veya şifresi unutulursa** güncelleme yüklemek için Google
desteğiyle anahtar sıfırlama gerekir. Şifreyi kendiniz seçin, kimseyle paylaşmayın.

```sh
mkdir -p ~/keys
keytool -genkeypair -v \
  -keystore ~/keys/kuran-kitaphanasy-upload.jks \
  -alias upload -keyalg RSA -keysize 4096 -validity 10000 \
  -dname "CN=Kuran Kitaphanasy"
chmod 600 ~/keys/kuran-kitaphanasy-upload.jks
```

Sonra `android/key.properties` dosyasını oluşturun (Git dışıdır, commit edilmez):

```properties
storeFile=/home/gadamgurban/keys/kuran-kitaphanasy-upload.jks
storePassword=SECTIGINIZ_SIFRE
keyAlias=upload
keyPassword=SECTIGINIZ_SIFRE
```

**Yedek:** `.jks` dosyasını ve şifreyi bilgisayar dışında iki güvenli yerde saklayın
(ör. şifreli USB + şifre yöneticisi).

## 2. İmzalı AAB üretin ve doğrulayın

```sh
cd ~/kuran-kitaphanasy
python3 tools/release/release_readiness.py --require-signing
flutter build appbundle --release
jarsigner -verify build/app/outputs/bundle/release/app-release.aab   # "jar verified." görmelisiniz
keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab | grep SHA256
```

Yüklenecek dosya: `build/app/outputs/bundle/release/app-release.aab`.

## 3. Gizlilik politikasını yayınlayın (GitHub Pages)

1. Commit'leri GitHub'a push edin.
2. GitHub → repo → **Settings → Pages → Build and deployment → Source: GitHub Actions**.
3. **Actions** sekmesinde "Publish privacy site" iş akışı yeşil olunca adres açılır:
   `https://gurbanowgadam.github.io/kuran-kitaphanasy/privacy.html`
4. Adresi tarayıcıda açıp kontrol edin. Bu adres uygulamanın "Hakkında" penceresinde de yazılı.

Yalnız `site/` klasörü yayınlanır; `docs/` içindeki iç belgeler web sitesine çıkmaz.

## 4. Uygulamayı oluşturun

Play Console → **Uygulama oluştur**:

- Uygulama adı: `Kuran Kitaphanasy`
- Varsayılan dil: listede **Türkmençe** varsa o; yoksa **Türkçe – tr-TR**.
- Uygulama veya oyun: **Uygulama** · Ücretsiz veya ücretli: **Ücretsiz**
- Beyanlar: geliştirici program politikaları ve ABD ihracat yasaları kutularını işaretleyin.

## 5. Uygulama içeriği formları (Policy → App content)

| Form | Cevap |
|---|---|
| Gizlilik politikası | `https://gurbanowgadam.github.io/kuran-kitaphanasy/privacy.html` |
| Uygulama erişimi | **Tüm işlevler özel erişim olmadan kullanılabilir** (giriş yok) |
| Reklamlar | **Hayır**, reklam içermiyor |
| İçerik derecelendirmesi | E-posta: `kurankitaphanasy@gmail.com`; kategori: **Referans, Haber veya Eğitim**. Şiddet, cinsellik, küfür, uyuşturucu, kumar: hepsi **Hayır**. Kullanıcılar birbiriyle etkileşir/içerik paylaşır mı: **Hayır**. Konum paylaşımı: **Hayır**. Dijital satın alma: **Hayır**. |
| Hedef kitle ve içerik | Yaş grupları: **13–15, 16–17, 18 ve üzeri**. 13 yaş altını seçmek Aileler politikasının ek şartlarını getirir; uygulama çocuklara özel tasarlanmadı. "Çocuklara hitap ediyor mu" sorusu çıkarsa: **Hayır**. |
| Veri güvenliği | Aşağıdaki bölüm |
| Haber uygulaması | **Hayır** |
| Sağlık uygulaması | **Hayır** |
| Finansal özellikler | **Hiçbiri** |
| Devlet uygulaması | **Hayır** |
| Reklam kimliği | **Hayır**, kullanmıyor (manifestte AD_ID izni yok) |

### Veri güvenliği — önerilen cevaplar

- "Uygulamanız gerekli kullanıcı verisi türlerinden herhangi birini toplar veya paylaşır mı?" → **Hayır**.
- Gerekçe: Uygulama hiçbir kullanıcı verisini (ad, e-posta, konum, kimlik, uygulama
  etkinliği vb.) cihaz dışına göndermez; yer imleri ve ayarlar cihazda kalır. Tek ağ isteği,
  kullanıcının başlattığı herkese açık bir ses dosyasının Google Drive'dan indirilmesidir.
  İstekte kullanıcı verisi yoktur; IP adresi her internet bağlantısının teknik parçasıdır ve
  geliştiriciye ulaşmaz. Bu durum gizlilik politikasında açıkça anlatılır.
- Hesap oluşturma: **Uygulama hesap oluşturmayı desteklemiyor** → hesap silme URL'si gerekmez.

Bu beyan sizin sorumluluğunuzdadır. İleride analitik, çökme raporu (ör. Firebase
Crashlytics), hesap veya başka bir SDK eklenirse beyan güncellenmelidir.

## 6. Mağaza girişi (Grow → Store presence → Main store listing)

| Alan | Değer / dosya |
|---|---|
| Uygulama adı, kısa ve tam açıklama | `STORE_LISTING_TK.md` (Türkmençe) veya `STORE_LISTING_TR.md` (Türkçe) |
| Uygulama simgesi 512×512 | `docs/play-store/assets/play-icon-512.png` |
| Öne çıkan görsel 1024×500 | `docs/play-store/assets/feature-graphic-1024x500.png` |
| Telefon ekran görüntüleri | En az 2, önerilen 4–8 (aşağıya bakın) |
| Kategori | **Kitaplar ve Referans** (Books & Reference) |
| E-posta | `kurankitaphanasy@gmail.com` |
| Web sitesi (isteğe bağlı) | `https://gurbanowgadam.github.io/kuran-kitaphanasy/` |

**Ekran görüntüleri** — gerçek telefonda, iç test sürümünden çekin (Güç + Ses kısma).
Önerilen sıra: (1) Kitaphana, (2) Arapça + Türkmençe okuma, (3) yalnız Türkmençe,
(4) sure listesi, (5) ses paneli çalarken vurgulu ayet, (6) koyu tema, (7) yer imleri.
Telefonu USB ile bağlarsanız ben `adb` ile çekip hazırlayabilirim.

## 7. Test kanalları ve üretime geçiş

1. **İç test (Internal testing):** yeni sürüm oluştur → AAB yükle → sürüm notu
   (`RELEASE_NOTES_TK.md` / `STORE_LISTING_TR.md`) → kendinizi test kullanıcısı ekleyin →
   Play'den kurup uçak modunda okuma, ses indirme/dinleme deneyin. Play App Signing'i
   ilk yüklemede kabul edin (Google uygulama imza anahtarını saklar, siz upload anahtarını).
2. **Kapalı test (Closed testing) — kişisel hesap için zorunlu:** en az **12 test
   kullanıcısı**, **14 gün kesintisiz** katılımda kalmalı. Test kullanıcılarını e-posta
   listesi veya Google Grubu ile ekleyin; katılım bağlantısını gönderin, kurmalarını isteyin.
3. 14 gün dolunca **Dashboard → Apply for production** formunu doldurun (test süreci ve
   geri bildirimler hakkında sorular). Onaydan sonra üretim sürümü oluşturup incelemeye
   gönderin. İnceleme genellikle birkaç gün sürer.

Her yeni yüklemede `pubspec.yaml` içindeki `+N` (versionCode) bir artırılmalıdır.

## 8. Yüklemeden sonra

- Pre-launch raporu (Kalite → Pre-launch report) çökme/erişilebilirlik bulgularını kontrol edin.
- Android Vitals'ta çökme/ANR'yi izleyin.
- Bulgularla bana dönün; düzeltip yeni sürüm hazırlarım.
