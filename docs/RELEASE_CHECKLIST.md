# Yayın kontrol listesi — Kuran Kitaphanasy 1.0.0+1

Durum: native/yayın hazırlığı. İşaretlenmemiş her madde owner veya entegrasyon
sorumlusunun gerçek kanıtıyla tamamlanır. Bu dosya yayın ya da mağaza onayı değildir.

## Sahiplik ve içerik

- [ ] Sahip/yayıncı hesabı ve kalıcı ürün kimliği `tm.kuran.kitaphanasy` doğrulandı.
- [ ] Owner'ın “kaynaklar doğrulandı, izinler tamam” beyanını destekleyen belgeler
      güvenli yerde saklandı; Arapça metin, meal, fontlar ve mobil/web/mağaza/bölge
      dağıtım kapsamı incelendi. Kamuya erişim lisans sayılmadı.
- [ ] `tools/check_full_content.py` başarılı; hash raporları ve 114 sure/6.236 ayet/
      605 kaynak sayfa kapsamı sürüm artefaktıyla eşleşiyor. Meal blokları ve notlar
      kaynağa sadık; eski demo/kısmi üretici veri setinin üzerine çalıştırılmadı.
- [ ] Yetkin insan kaynak karşılaştırması, hareke/durak/ayet işaretleri ve Türkmençe
      meal incelemesi yapıldı. Teknik testler dinî/editoryal onay diye sunulmadı.
- [ ] Font ve MaterialIcons lisans/bildirimleri dağıtımda korundu.

## Entegrasyon ve cihaz

- [ ] `flutter pub get`, `python3 tool/release_readiness.py`, `flutter analyze`,
      `flutter test`, `python3 tools/check_full_content.py` gerçek çıktıları kaydedildi.
- [ ] Pubspec `version: 1.0.0+1`; native derlemenin sürüm adı/kodu 1.0.0/1 olarak okundu.
- [ ] `flutter build apk --debug`; kurulum yalnız entegrasyon onayından sonra yapıldı.
      Debug ID `.debug`, demo ID farklı ve release ID sabit; paketler birbirini silmedi.
- [ ] Gerçek cihazda başlatma, kitap açma, sure geçişi, son sayfa, meal/notlar,
      kaydırma yönleri, yön değişimi, font büyütme, tercihler/yeniden açılış incelendi.
- [ ] Dar ekran, açık/koyu mod, Arapça birleştirme/hareke/kırpılma ve büyük yazı
      kontrol edildi; ekran görüntüleri o gerçek sürümden alındı.
- [ ] Uçak modunda ilk native başlatma, okuma ve soğuk yeniden açılış çalıştı.
- [ ] Launcher maskeleri ve Android 13 temalı ikon ile iOS küçük/büyük ikonlar
      gerçek cihazda orijinal `auto_stories_outlined` şekline göre onaylandı.
- [ ] Android 12 exported launcher, Android 15/16 edge-to-edge/geri hareketleri,
      minimum Android sürümü ve büyük ekran davranışı test edildi.
- [ ] Final release native kütüphaneleri 16 KB page-size/emulator kontrolünden geçti;
      kullanılan Flutter/SDK/plugin sürümleri mağazanın o günkü koşullarına uygun.

## Android imzalama ve Google Play (owner)

- [ ] Owner gerçek upload keystore ve alias'ı sağladı; anahtar/sır üretilmedi veya
      uydurulmadı. Şifreli yedek ve kurtarma/erişim sorumlusu belirlendi.
- [ ] `android/key.properties` veya dört belgelenmiş ortam değişkeni sağlandı;
      dosyalar Git dışında, sırlar günlüklerde yok.
- [ ] `python3 tool/release_readiness.py --require-signing` başarılı.
- [ ] `flutter build appbundle --release` gerçek imzalı AAB üretti. İmzasız
      varsayılan AAB veya debug APK mağazaya hazır diye işaretlenmedi.
- [ ] `jarsigner -verify -verbose -certs .../app-release.aab` gerçekten “jar verified”;
      sertifika owner'ın beklenen upload fingerprint'i, debug sertifikası değil.
- [ ] Final birleşik manifest/izinler bundletool/Android Studio ile incelendi:
      INTERNET ve gereksiz hassas izin yok, backup/transfer kuralları doğru.
- [ ] Play App Signing kaydı ve upload-key/app-signing-key farkı owner tarafından
      kaydedildi; paket adı tekrar kullanılamama riski anlaşıldı.
- [ ] Play internal testing yüklemesi owner tarafından yapıldı; Play-generated split
      APK gerçek cihazda test edildi, pre-launch raporu ve crash/ANR incelendi.
- [ ] Güncel target API/device/form-factor şartları Play Console'da doğrulandı.

## iOS — yalnız macOS/Xcode ve owner hesabı ile

- [ ] Desteklenen Xcode/macOS, Apple SDK ve Flutter bağımlılıkları kuruldu;
      `flutter doctor -v`, `flutter pub get`, CocoaPods/SPM çözümü başarılı.
- [ ] `ios/Runner.xcworkspace` açıldı; Team ID ve distribution/provisioning owner'a
      ait, Runner bundle ID üç configuration'da `tm.kuran.kitaphanasy`.
- [ ] `flutter build ios --release --no-codesign` gerçek macOS derleme kontrolü geçti;
      Linux statik plist kontrolü iOS derlemesi diye sayılmadı.
- [ ] `flutter build ipa --release` veya Xcode Archive/Validate imzalı çıktı üretti;
      1024 RGB ikon, display name, sürüm ve `tk/ar/en` içerik/UI dil iddiaları incelendi.
- [ ] Plugin required-reason API/PrivacyInfo.xcprivacy bildirimi final archive'da
      mevcut; App Store Connect privacy/export compliance mevcut offline kapsamla uyumlu.
- [ ] iOS OS backup davranışı (yerel tercihler dahil olabilir) ve veri silme açıklaması
      incelendi; Android yedekleme kuralı iOS için aynen iddia edilmedi.
- [ ] Fiziksel iPhone/iPad ve TestFlight testi, font/not/soğuk açılış/airplane mode
      kontrolü geçti. TestFlight ve App Store yüklemesi owner tarafından ayrıca yapıldı.

## Mağaza materyali ve gizlilik (iki mağaza)

- [ ] İsim, kısa/uzun açıklama, kategori, yaş/içerik derecelendirmesi ve ülkeler owner
      tarafından seçildi. Dinî doğruluk veya kurum ortaklığı hakkında asılsız iddia yok.
- [ ] Gizlilik politikası gerçek kalıcı HTTPS URL'de yayımlandı; gerçek support iletişim
      ve gerekiyorsa marketing URL'si eklendi. Depo içi taslak tek başına URL değildir.
- [ ] Data Safety/App Privacy formu final binary/plugin davranışıyla eşleşiyor:
      offline/hesapsız/analitiksiz mevcut kapsam için toplama/paylaşma yok beyanı owner
      tarafından doğrulandı; izin, ağ veya telemetri eklentisi değişirse form güncellendi.
- [ ] Yerel tercihler, uygulama silinmesi, OS backup ve web hosting logları ayrı ele alındı.
- [ ] Gerçek cihaz ekran görüntüleri, Android feature graphic, store icon ve Apple
      ekran boyutları platformun güncel kurallarına uygun hazırlandı.
- [ ] Erişilebilirlik, support/sorun bildirme yolu, sürüm notu ve red gerekçelerine
      cevap sorumlusu belirlendi; staging/internal test sonrasında owner release onayı aldı.
- [ ] Yayın, inceleme sonucu ve kullanıcılara dağıtım yalnız gerçek mağaza kanıtıyla
      ayrıca kaydedildi. Bu hazırlık bunların hiçbirini tamamlanmış saymaz.
