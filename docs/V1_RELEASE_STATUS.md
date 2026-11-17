# Kuran Kitaphanasy 1.0.0 — uygulanan ilk ürün sürümü

## Ürün sınırı

İlk sürümde yalnız Kur'an, Arapça metin ve Türkmençe meal bulunur. Hesap, reklam, analitik, backend ve ses oynatıcı yoktur. Gelecekteki kitap ve ses özellikleri için çalışmayan menüler eklenmedi. Türkmençe sure isimleri esas alınır. Ürün sahibi demo arayüzünü ve kaynak izinlerini onaylamıştır.

Onaylı demo `/home/gadamgurban/kurany-kerim-demo` içinde değişmeden tutulur. Ürün `/home/gadamgurban/kuran-kitaphanasy` içinde gelişir. Baştan yeniden yazım yerine test korumalı mimari ayrıştırma uygulanmıştır.

## İlk sürümün işlevleri

- 114 sure, 6236 ayet, 5905 kaynak meal grubu, 203 bağlantılı açıklama, 114 sure girişi.
- 605 kaynak mushaf grubu; ilk ikisinin onaylı birleşimiyle 604 okuyucu sayfası. İlk sayfa Fatiha ve Bakara 1–5, ikinci sayfa Bakara 6'dan başlar.
- Arapça, Türkmençe, birlikte okuma; tam Arapça sure başlıkları, kaynak besmele kuralları.
- Kaynak meal grupları korunur; sayfa sınırında metin yeniden yazılmaz veya keyfî bölünmez.
- Kaynak DiyanetAmasya Arapça fontu, yerel Noto Serif meal fontu; çevrimdışı kullanım.
- Yatay sayfalama ve tembel dikey kesintisiz akış; görünür sayfa/sure takibi; tam kitapta son sureye erişim.
- Kitap bazlı açık/koyu tema, bağımsız font boyutları ve canlı besmele örnekleri.
- Arapça-only hizalama: ortada, sağda, iki yana; varsayılan iki yana. İki dilde Arapça sağa/Türkmençe sola sabit.
- Dikey sayfa bitiminde numara, altında ince çizgi.
- Altta tam ekran/ayarlar/sureler solda, ana sayfa en sağda.
- Tam ekranda uygulama/sistem çubuklarını gizleme, üç saniyelik Türkmençe ipucu, çift dokunma/geri ile çıkış.
- Sürümlü yerel okuma kaydı: sayfa, mod, tema, fontlar, hizalama, akış ve sınırlı sayfa içi offset önbelleği; kitap ve kütüphane teması ayrı kayıtlar. Fullscreen kalıcı değildir.
- Kaynak künyesi, yerel gizlilik açıklaması, Noto Serif açık font lisansına erişim.
- Uygulama adı Kuran Kitaphanasy; onaylı `auto_stories_outlined` simgesinden üretilmiş Android/iOS/web ikonları.

## Bakım / genişleme

`lib/app`, `lib/library/{domain,data,presentation}`, `lib/reader/{domain,data,presentation,settings}` sınırları oluşturuldu. Veri deposu ve tercih deposu enjekte edilebilir. Ham kaynak edinme ve deterministik içerik üretimi runtime kodundan ayrıdır. Gerçek kitap kataloğu, kitap kimliği, içerik sürümü ve yetenekleri tanımlar.

Bu, diğer kitap türlerinin veya sesin şimdiden uygulandığı iddiası değildir. Yeni kitap için sürümlü bir içerik/repository adaptörü, uygun okuyucu ve testler eklenir. Ses için ayrı oynatma/indirme/konum eşleme servisi gerekir; Kur'an metinleri ve okuma tercihleriyle karıştırılmamalıdır. Ayrıntılar `ARCHITECTURE.md`.

## Doğrulananlar

- 91 Flutter testi geçti; `flutter analyze` temiz.
- 9 font/ortografi regresyon testi geçti; tüm 6236 ayet koşusunda eksik glif bulunmadı.
- 9 tam içerik testi ve 4 bağımsız doğrulama regresyon testi geçti.
- 605 resmî ham cevabın hash ve tekrar çözüm kontrolü başarılı; kaynak metinleri birebir korundu.
- 1210 Türkmen PDF sütunu bağımsız çıkarımla karşılaştırıldı; 0 uyuşmazlık. Eski kontrolün 30 kesilmiş sütunu açıkça belgelendi.
- Android debug APK ve release AAB gerçek Flutter/Gradle derlemesinden üretildi.
- Samsung SM_A155M üzerinde ayrı ürün paketi `tm.kuran.kitaphanasy.debug` kuruldu/açıldı. Demo kurulumu değiştirilmedi.
- Gerçek süreç durdurma/yeniden başlatma: kayıtlı ikinci sayfa `Sahypa 2 (2/604)` geri geldi; SharedPreferences kaydı da okundu.
- Cihaz ekran görüntüsünde ikinci sayfa ve ikon/header düzeni incelendi. Bu tüm ayetlerin/cihazların görsel onayı değildir.
- Release birleşik manifestinde INTERNET izni yok, Android backup kapalı. Debug geliştirme paketi INTERNET izni içerir.
- 32 native/web PNG boyutu, gerçek Material glyph ve platform kimlik dosyaları hazırlık kontrolünden geçti.
- Release AAB imzasız: imza girdisi yok. Bu beklenen durumdur; sessiz debug-signing kullanılmaz.

## Yayından önce sahibiyle tamamlanacak kapılar

1. **Kaynak eşleme incelemesi:** Naziat 79:41 etiketi PDF'de yok; 40 numaralı değiştirilmemiş paragraf 40–41 grubuna eşlenmiştir. Ürün sahibi 2026-11-13 tarihinde başka kaynaklarla karşılaştırarak eşlemeyi onayladı. Onay PDF/paragraf hash’leriyle kaydedildi; bu özel kaynak kapısı kapanmıştır. `CONTENT_REPORT.md` ve `assets/sources/full-translation-anomalies.json`.
2. **Son kullanıcı kabulü:** demo kabulü tam kitabın her sayfasının görsel/dilsel kabulü değildir. Özellikle uzun/gruplu mealler, son sureler, farklı harekeler, büyük fontlar ve erişilebilirlik üzerinde son tur yapılmalıdır.
3. **Android mağaza imzası:** sahibi upload keystore/sertifikasını güvenle tanımlamalı; imzalı release yeniden üretilip sertifikası kontrol edilmelidir. Şu anki AAB Google Play'e gönderilmeye hazır değildir.
4. **iOS:** proje/simge/bundle ID hazır; Linux ortamında Xcode, iOS derleme, archive, imza veya cihaz testi yapılmadı. macOS + Apple developer hesabı gerekir.
5. **Mağaza başvurusu:** gizlilik URL'si ve iletişim bilgisi, mağaza açıklaması/görselleri, veri güvenliği beyanı, owner izin belgeleri ve mağaza hesabı tamamlanmalıdır. Hiçbir mağazaya yükleme/yayın yapılmadı.
6. CI dosyası oluşturuldu fakat GitHub üzerinde çalıştırıldığı iddia edilmez; remote/repository bağlantısı ve secrets sahibi tarafından sağlanmalıdır.

## Dosyalar

- Test APK: `build/app/outputs/flutter-apk/app-debug.apk`
- İmzasız release AAB: `build/app/outputs/bundle/release/app-release.aab`
- Yerel sabit kopyalar: `releases/1.0.0/`
- İmza adımları: `NATIVE_RELEASE.md`
- Yayın listesi: `RELEASE_CHECKLIST.md`
- Gizlilik: `PRIVACY.md`
