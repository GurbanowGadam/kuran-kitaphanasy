# Google Play yayın kontrol listesi — hedef 1.0.0+3

Durum: yerel doküman/mağaza metni hazırlığı. Aşağıdaki kutular gerçek kanıtla sahibi tarafından kapatılır. Bu çalışma test çalıştırma, imzalı AAB doğrulama, yükleme veya mağaza onayı beyanı değildir. Önceki test kayıtları kendi sürümlerine aittir.

## Ürün ve açık hak kapsamı

- [ ] Kalıcı paket `tm.kuran.kitaphanasy`, yasal yayıncı ve Play hesabı sahibi doğrulandı.
- [ ] Hedef sürüm 1.0.0+3 pubspec ve final AAB'de doğrulandı; Play'de kod 3 kullanılabilir.
- [ ] 114 sure, Arapça/Türkmençe çevrimdışı okuma, adlandırılmış yer imleri, tema/yazı ayarları gerçek son uygulamada doğrulandı.
- [ ] Sesler MP3Quran kaynaklı, Google Drive üzerinden kullanıcı isteğiyle önce indirme/sonra yerel oynatma olarak anlatıldı. İnternetsiz ilk ses indirme, streaming, arka plan/kilit ekranı oynatma vaadi verilmedi.
- [ ] Hadis kartları yalnız “ýakynda”/yakında yer tutucusu olarak gösterildi; mevcut okunabilir hadis koleksiyonu veya kesin yayın tarihi vaat edilmedi.
- [ ] `TELIF_HAKLARI_INCELEMESI.md` ve ses kaynak kayıtları incelendi. Eski EveryAyah bulguları güncel MP3Quran dosyalarıyla karıştırılmadı; MP3Quran'ın olumlu sağlayıcı beyanı tüm hakların sınırsız teyidi sayılmadı.
- [ ] Arapça veri, Türkmençe meal/giriş/notlar, ayrı Shaikh Hamdullah fontu, kesin ses kayıtları ve uygulamada gömülü ses için sahibinin izin kanıtları/kapsamı değerlendirildi. Drive yeniden barındırma, offline dağıtım, mağaza/ülke kapsamı açıkta bırakılmadı. Kamuya erişim ve önceki owner beyanı tek başına lisans sayılmadı.
- [ ] Noto Serif, Material Icons, diğer font ve bağımlılık bildirimleri final pakette korundu. Yetkin insan içerik incelemesi teknik testlerden ayrı tamamlandı.

## Yerel kalite ve gerçek cihaz (henüz bu belgede onaylanmış değil)

- [ ] `flutter pub get`, `python3 tool/release_readiness.py`, `flutter analyze`, `flutter test`, `python3 tools/check_full_content.py` son kaynak üzerinde çalıştırıldı; gerçek sonuçlar güvenli yerel raporda kaydedildi.
- [ ] Son artefaktın içerik/katalog hash ve sürüm bilgileri kaynaklarla eşleştirildi. Tarihsel `V1_RELEASE_STATUS.md` güncel kanıt sayılmadı.
- [ ] İlk başlatma ve soğuk yeniden açılış uçak modunda: tüm surelere erişim, son sayfa, Arapça/meal/notlar, kaydırma ve kayıtlı konum kontrol edildi.
- [ ] Yer imi adı ekleme/düzenleme/silme ve yeniden açılış; açık/koyu tema, büyük yazı, dar/büyük ekran, Arapça birleşme/hareke/kırpılma kontrol edildi.
- [ ] Ses: kâri/sure seçimi kendiliğinden indirmiyor; kullanıcı indirmesi, ilerleme, iptal, yetersiz alan, bozuk dosya, bağlantı kesilmesi ve Drive kota/izin hatası denendi.
- [ ] Tamamlanmış sesle gerçek uçak modu ve süreç yeniden başlatma sonrası dinleme; ayet geçişi, tekrar, arama, silme ve tekrar indirme denendi. Bir kaydın denemesi tüm kayıtların akustik onayı sayılmadı.
- [ ] Minimum Android, Android 15/16 sistem çubukları/geri hareketi, erişilebilirlik ve 16 KB native uyumluluk final release üzerinde incelendi.

## Gizlilik ve mağaza materyali — bloklayıcı sahip işleri

- [ ] `PRIVACY.md` içindeki gerçek yayıncı, destek/gizlilik e-postası, yürürlük tarihi ve HTTPS URL dolduruldu; kullanıcı dilinde son metin gözden geçirildi.
- [ ] Politika sahibi tarafından herkese açık, giriş gerektirmeyen kalıcı URL'de yayımlandı ve uygulama içinden/Play alanından erişimi doğrulandı. Yerel Markdown dosyası yayın URL'si değildir.
- [ ] Uygulama içi gizlilik metni Google isteklerini, IP/teknik bilgileri ve yerel tercihler/sesleri açıklıyor; eski “ağ yok” beyanı kalmadı.
- [ ] `play-store/DATA_SAFETY.md` doğrultusunda final SDK/ağ davranışı ve Google'ın üçüncü taraf işlemesi incelendi. “Veri toplanmaz/paylaşılmaz” otomatik işaretlenmedi; gerekçeli Console cevapları sahibi tarafından onaylandı.
- [ ] `play-store/STORE_LISTING_TK.md` Türkmençe metni dil ve gerçek özellik kapsamı açısından onaylandı; Console dil seçenekleri ve güncel karakter sınırları kontrol edildi.
- [ ] Gerçek son sürümden ekran görüntüleri, mağaza ikonu ve feature graphic hazırlandı; `play-store/OWNER_HANDOFF.md` materyal listesi tamamlandı. Bu görev görsel üretmedi.
- [ ] Kategori, hedef kitle, içerik derecelendirme anketi, reklam beyanı, app access, dağıtım ülkeleri ve varsa hesaba özgü test şartları gerçek ürün/Console üzerinden dolduruldu.

## İmza, yükleme ve onay — ayrı kapılar

- [ ] Sahibi gerçek upload keystore/alias sağladı; sırlar Git ve günlük dışında; yedek/kurtarma sorumlusu belli.
- [ ] `NATIVE_RELEASE.md` içindeki gerçek dört Gradle girdisiyle `--require-signing` ve release AAB derlemesi tamamlandı.
- [ ] `jarsigner` doğrulaması ve beklenen upload sertifikası parmak izi eşleşti; imzasız AAB veya debug APK mağazaya hazır diye sunulmadı.
- [ ] Final birleşik manifestte beklenen INTERNET izni, cleartext/yedek/aktarım kuralları ve ek izinler incelendi; güncel hedef API gereksinimleri doğrulandı.
- [ ] Sahibi internal testing'e yükledi; Play ürettiği split APK gerçek cihazda test edildi, pre-launch/crash/ANR bulguları değerlendirildi.
- [ ] Son kullanıcı kabulü, hak/gizlilik kararları ve mağaza materyalleri için sahibi açık yayın onayı verdi.
- [ ] İncelemeye gönderim, mağaza onayı ve kullanıcıya dağıtım durumları yalnız gerçek Console kanıtıyla ayrı kaydedildi. Yerel hazırlık bunların hiçbiri değildir.

## Diğer platform

- [ ] iOS planlanıyorsa macOS/Xcode derleme, imza, gerçek cihaz/TestFlight, App Privacy ve backup davranışı ayrıca doğrulandı. Android hazırlığı App Store hazırlığı sayılmadı.
