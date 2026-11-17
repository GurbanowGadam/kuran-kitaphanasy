# Native kimlik ve imzalama

Ürün: Kuran Kitaphanasy. Android namespace/applicationId ve iOS Runner bundle ID:
`tm.kuran.kitaphanasy`. Android debug: `tm.kuran.kitaphanasy.debug`.
`pubspec.yaml` sürümü native kabuklarda Flutter build name/number olarak kullanılır;
1.0.0+1 Android versionName=1.0.0/versionCode=1 ve iOS 1.0.0/build 1 hedefidir.
Sürüm dosyasını platform kabuklarında ayrıca sabitlemeyin.

## Android

Android 12 launcher activity `android:exported="true"` olarak belirtilmiştir.
`compileSdk`, `targetSdk`, `minSdk`, NDK Flutter SDK varsayımlarından gelir.
Yerel Flutter 3.47.7 `compileSdk=36`, `targetSdk=36`, `minSdk=24` bildirir;
bunlar kullanılan SDK'nın değerleridir, gelecekteki mağaza şartına otomatik uyum
iddiası değildir. Android 15/16 edge-to-edge, sistem çubukları, geri hareketi ve
16 KB sayfa boyutu/native kütüphane uyumluluğu gerçek release üzerinde denetlenir.
JDK 17 kullanılır. SDK pinleri/CI değişirse bu kontrolleri tekrarlayın.

Release kaynak manifestinde INTERNET yoktur. Debug/profile geliştirme bağlantısı
izinleri ayrı manifestlerdedir. Birleşik release manifestini `apkanalyzer manifest
permissions` veya Android Studio ile ayrıca inceleyin; eklenti izin ekleyebilir.
`allowBackup=false`, `fullBackupContent=false`, Android 12+ data extraction
exclusion kuralları yerel tercihlerin Android yedeğine/aktarımına girmesini sınırlar.

### Sahibe ait release anahtarı

Bu çalışma anahtar üretmez ve sır oluşturmaz. Sahibi güvenli biçimde upload anahtarı
sağlamalı, sertifika parmak izini ve keystore'un şifreli çevrimdışı yedeğini saklamalıdır.
Google Play App Signing ile upload key ve app signing key farkını kaydedin.

1. `android/key.properties.example` dosyasını `android/key.properties` olarak kopyalayın.
2. Örnek değerleri sahibi tarafından sağlanan gerçek bilgilerle yerelde değiştirin.
   storeFile mutlak yol veya `android/` dizinine göre yoldur. Java properties
   sözdizimi kullanılır; Linux/macOS yolları tercih edilir.
3. Alternatif: ortam değişkenleri her alan için properties değerini geçersiz kılar:
   `ANDROID_KEYSTORE_PATH`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`,
   `ANDROID_KEY_PASSWORD`. Parolaları terminal geçmişine, loga veya depoya yazmayın.
4. `python3 tool/release_readiness.py --require-signing`
5. `flutter build appbundle --release`
6. `jarsigner -verify -verbose -certs build/app/outputs/bundle/release/app-release.aab`
   çıktısında gerçekten imzalı ve doğrulanmış olduğunu kontrol edin. Beklenen owner
   sertifikasıyla karşılaştırın; self-signed upload certificate uyarısı tek başına
   debug anahtarı demek değildir. APK için `apksigner verify --print-certs` kullanılır.

Dört alan da yoksa `flutter build appbundle --release` imzasız AAB üretir; bu mağazaya
hazır değildir. Bazı release APK görevleri imza yokken başarısız olabilir; debug'a
gerileme yapılmaz. Eksik kısmi yapılandırma veya bulunmayan keystore derlemeyi keser.
Statik hazırlık aracı bir sertifika geçerlilik testi değildir. `.gitignore` keystore,
key.properties, p12 ve provision dosyalarını dışlar; bu tek başına sır sızıntısı
koruması değildir. Yanlışlıkla paylaşılan anahtar/parolayı sahibin prosedürüyle döndürün.

Debug test APK'sı: `flutter build apk --debug`. Kurulum entegrasyon sorumlusunca
onaydan sonra yapılır; bu hazırlık çalışması cihaza kurulum yapmaz.

### GitHub Actions

`.github/workflows/flutter.yml` Flutter 3.47.7 / Java 17 kullanır. Push/PR kalite
kontrolleri ve debug APK; manuel `signed_release=true` seçimi ayrı imzalı AAB job'ı
başlatır. Owner GitHub `production` ortamını korumalı ve şu sırları sağlamalıdır:
`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`,
`ANDROID_KEY_PASSWORD`. Base64 şifreleme değildir. Keystore geçici runner dizinine
çözülür, izinleri sınırlandırılır ve adım sonunda kaldırılır. Eksik sırda job durur.
AAB artifact'ı yalnız owner incelemesi içindir, yükleme/yayın yoktur. Reponun gerçekten
GitHub'a bağlanması, Actions policy ve action pinlerinin owner incelemesi ayrı iştir.

## iOS (macOS gerekir)

Eksik iOS kabuğu, yerel Flutter 3.47.7 ile geçici dizinde
`flutter create --platforms=ios --org tm.kuran --project-name kitaphanasy --no-pub <temp>`
çalıştırılıp yalnız `ios/` kopyalanarak üretildi. Ana `lib`, `pubspec` ve testler bu
komutla yeniden oluşturulmadı. Runner Debug/Profile/Release bundle ID doğru; test
bundle ID `tm.kuran.kitaphanasy.RunnerTests`. Team ID/sahte provision eklenmedi.

Info.plist ürün adını, Flutter sürüm değişkenlerini ve `tk`, `ar`, `en` dil bildirimini
içerir: Türkmençe geliştirme dili, Arapça kitap içeriği, İngilizce sistem fallback.
Bu bildirim tüm UI'nin üç dilde çevrildiği iddiası değildir. App Store dil alanlarını
gerçekte sunulan UI ve içerik ile karşılaştırın. Uygulamada özel şifreleme yoktur;
`ITSAppUsesNonExemptEncryption=false` mevcut offline kapsam içindir, yeni ağ/kripto
özelliğinde yeniden incelenmelidir.

macOS'ta `flutter doctor -v`, `flutter pub get`, gerekli CocoaPods/SPM bağımlılık
çözümü ve `open ios/Runner.xcworkspace` ile başlayın. Runner hedefinde sahibi Team,
bundle ID, entitlements ve signing/provisioning ayarlar. `flutter build ios --release
--no-codesign` derleme kontrolü, daha sonra sahibi imzalı `flutter build ipa --release`
veya Xcode Archive yapar. Plugin privacy manifestlerini ve birleşik archive içindeki
required-reason API bildirimlerini inceleyin (özellikle yerel tercihler eklentisi).
Linux'ta Xcode/iOS derlemesi, archive, simulator veya cihaz doğrulaması yapılmadı.
