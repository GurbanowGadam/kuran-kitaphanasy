# Native sürüm ve imzalama — 1.0.0+3 hedefi

Bu belge sahibinin uygulayacağı prosedürdür; bu doküman çalışmasında derleme, test, imza veya mağaza yüklemesi yapılmış olduğunu göstermez. Yerel hazırlık, imzalı dağıtım ve mağaza onayı ayrı kapılardır.

## Kimlik ve sürüm

Android namespace/applicationId: `tm.kuran.kitaphanasy`; debug: `tm.kuran.kitaphanasy.debug`. iOS Runner kimliği: `tm.kuran.kitaphanasy` (son archive ayrıca doğrulanır). Hedef `1.0.0+3`: Android versionName `1.0.0`, versionCode `3`; iOS build `3`. Pubspec/nihai artefakt sürümünü kontrol edin; dokümandaki hedef tek başına sürümü değiştirmez. Play'de kod 3 daha önce kullanıldıysa yeni, kullanılmamış ve uygun artan kod seçilmelidir.

Android `compileSdk`, `targetSdk`, `minSdk` ve NDK Flutter SDK'dan gelir; Java/JVM hedefi 17'dir. Gerçek araç zincirini `flutter doctor -v` ile, son manifest değerlerini paket üzerinden okuyun. Güncel Play hedef API ve 16 KB sayfa boyutu koşullarını Console'da kontrol edin; bir SDK sürümünden otomatik mağaza uyumu çıkarmayın.

Release kaynak manifestinde INTERNET vardır: isteğe bağlı Google Drive ses indirmeleri için gereklidir. `usesCleartextTraffic=false`, `allowBackup=false`, `fullBackupContent=false` ve Android 12+ data extraction dışlamaları tanımlıdır. Son birleşik manifesti Android Studio/bundletool veya APK için `apkanalyzer manifest permissions` ile inceleyin; eklentiler farklı izinler ekleyebilir. Gizlilik açıklamasında eski “internet izni yok” ifadesini kullanmayın.

## Gerçek Gradle imzalama girdileri

`android/app/build.gradle.kts` şu eşlemeleri kullanır:

| android/key.properties alanı | Öncelikli ortam değişkeni |
| --- | --- |
| storeFile | ANDROID_KEYSTORE_PATH |
| storePassword | ANDROID_KEYSTORE_PASSWORD |
| keyAlias | ANDROID_KEY_ALIAS |
| keyPassword | ANDROID_KEY_PASSWORD |

Boş olmayan ortam değeri ilgili properties alanını geçersiz kılar. `storeFile` mutlak yol veya `android/` dizinine göre yoldur. Dört değer de sağlanmalı; kısmi yapılandırma veya bulunmayan keystore hata verir. Dördü de yoksa release signingConfig null'dır: AAB üretilebilmesi imzalandığı anlamına gelmez. Debug anahtarına sessiz geri dönüş yoktur.

Sahibi mevcut doğru upload keystore'unu ve alias'ını güvenli şekilde sağlamalıdır. Bu görev anahtar üretmez. `android/key.properties.example` yalnız şablondur; gerçek yerel dosya ve keystore Git dışında tutulur. Parolaları komut geçmişine, ekran görüntüsüne, rapora veya depoya yazmayın. Güvenli yedek/erişim sorumlusunu ve upload key ile Play app-signing key farkını kaydedin.

## Sahibi tarafından uygulanacak sıra

Repo kökünde, gerçek imza girdileri güvenli biçimde sağlandıktan sonra:

```sh
flutter pub get
python3 tools/release/release_readiness.py --require-signing
flutter analyze
flutter test
python3 tools/check_full_content.py
flutter build appbundle --release --build-name=1.0.0 --build-number=3
jarsigner -verify -verbose -certs build/app/outputs/bundle/release/app-release.aab
keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab
```

Bunlar çalıştırma talimatıdır, başarılı sonuç kaydı değildir. Hazırlık kontrolü sertifika geçerliliğini veya yayın hakkını kanıtlamaz. `jarsigner` çıktısını inceleyin: gerçekten imzalı/doğrulanmış olmalı; yalnız çıkış koduna güvenmeyin. Sertifikanın SHA-256 parmak izini sahibinin beklenen upload sertifikasıyla karşılaştırın; debug sertifikasını kabul etmeyin. Self-signed upload sertifikası uyarısını da otomatik olarak debug sertifikası saymayın. APK için `apksigner verify --print-certs` kullanın.

Beklenen çıktı: `build/app/outputs/bundle/release/app-release.aab`. Eski aynı adlı dosyayı yeni sonuç diye kullanmayın; sürüm, paket, katalog, hash ve sertifikayı final çıktıdan kaydedin. Anahtarlar, yerel raporlar ve build artefaktları Git'e eklenmez.

Sahibi ayrıca Play App Signing kaydını, internal testing yüklemesini, Play kaynaklı split APK kurulumunu, pre-launch raporunu ve gerçek cihaz kabulünü tamamlar. AAB üretmek yükleme veya onay değildir. Haricî CI çalıştırılması ve secret kurulumu da bu dokümanla yapılmış sayılmaz.

## iOS sınırı

iOS için macOS/Xcode ve sahibine ait Apple hesabı, Team/provisioning gerekir. `flutter build ios --release --no-codesign` yalnız derleme kontrolüdür; `flutter build ipa --release`/Xcode Archive, imza ve TestFlight ayrı işlemlerdir. Linux statik kontrolü iOS testi değildir. Son archive'ın privacy manifestleri/required-reason API beyanları, yerel veri yedeği ve ağ/şifreleme beyanları Google üzerinden ses indirme kapsamıyla yeniden incelenmelidir; eski tamamen offline varsayımı kullanılmamalıdır.
