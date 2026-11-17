# Kuran Kitaphanasy

Türkmençe Kur'an okuma kütüphanesi. Flutter uygulaması; Arapça kaynak metin,
Türkmençe meal, sure girişleri, açıklama notları ve fontlar paket içinde bulunur.
Ürün kimliği `tm.kuran.kitaphanasy`, ilk sürüm hedefi `1.0.0+1`'dir.
Bu depo yayın hazırlığıdır; mağaza onayı, yükleme veya yayımlanma iddiası değildir.

## Kullanım

Kitaphana'dan kitabı açın; Arapça, Türkmençe veya birlikte görünümü seçin.
Sure listesi, okuma sayfaları, açıklama notları ve okuyucu tercihleri cihazda çalışır.
Tam veri paketinin kapsamı: 114 sure, 6.236 Arapça ayet, 605 kaynak okuma sayfası;
meal kaynak blokları gerektiğinde birden çok ayeti kapsar, bloklar yeniden çevrilmez
veya keyfî bölünmez. Kapsam ve metin korunumu için `tools/check_full_content.py`
ve `assets/sources/full-content-manifest.json` esas alınır.

## Geliştirme ve denetim

Flutter 3.47.7 stable / Dart 3.13.5, Android JDK 17. SDK sürümünü değiştirirken
CI ve native eklenti uyumluluğunu birlikte denetleyin.

```sh
flutter pub get
python3 tool/release_readiness.py
python3 tools/check_full_content.py
flutter analyze
flutter test
flutter build apk --debug
flutter run
# Web fontları/CDN bağımlılığı olmadan yerel derleme:
flutter build web --no-web-resources-cdn
```

`check_full_content.py` çevrimdışı dondurulmuş kaynakları kullanır: Python standart
kütüphanesi ve sistem `openssl` yeterlidir. `--pdf-extraction` ayrı ve isteğe bağlı
bir denetimdir; sahibin orijinal PDF'sini ve Poppler `pdftotext` ister, CI bunu
çalıştırmaz. Font/şekillendirme ve veri yeniden üretim araçlarının ayrı bağımlılıkları
vardır (`fonttools`, `uharfbuzz`, gerektiğinde `pymupdf`); salt denetim için eski/kısmi
üreticileri tam veri paketinin üzerine çalıştırmayın.

Debug Android paketi `tm.kuran.kitaphanasy.debug`'dır; eski demo ve gerçek release
kurulumunun üstüne yazmaz. Release imza bilgisi yoksa AAB imzasızdır, debug anahtarı
ile gizlice imzalanmaz. Telefon kurulumu ve görsel onay ayrı bir entegrasyon adımıdır.

## Mimari

- [Giriş noktası](lib/main.dart) ve [uygulama kabuğu](lib/app/app.dart).
- [Kitap alan modeli](lib/library/domain/book.dart),
  [repository](lib/library/data/book_repository.dart),
  [kütüphane sunumu](lib/library/presentation/library_page.dart).
- [Okuyucu veri katmanı](lib/reader/data/reader_data.dart),
  [okuyucu sunumu](lib/reader/presentation/reader.dart),
  [sure açılışı](lib/reader/presentation/surah_opening.dart),
  [yerel tercihler](lib/reader/settings/reader_preferences.dart).
- `assets/data/`: uygulama verileri; `assets/fonts/`: çevrimdışı fontlar;
  `assets/sources/`: dondurulmuş yanıtlar, kaynak hash'leri ve kontrol raporları.
- `tools/`: içerik edinme/doğrulama araçları; `tool/`: ürün kimliği/ikon/yayın araçları.
- `android/`, `ios/`, `web/`: aynı ürünün native/web kabukları.

## Gizlilik ve çevrimdışı çalışma

Okuma için hesap, backend, analitik, reklam, uzaktan font veya içerik indirmesi
gerekmez. Yerel okuma tercihleri/son konum cihazda tutulur; uygulamayı silmek bu
yerel veriyi kaldırabilir. Android release ana manifestinde INTERNET izni yoktur;
debug/profile manifestlerinin Flutter geliştirme bağlantısı için INTERNET içermesi
release ağ erişimi iddiası değildir. Nihai birleşik APK/AAB izinleri yine kontrol edilir.
Android uygulama yedekleme kapalıdır; Android 12+ bulut/cihaz aktarım kuralları yerel
veri alanlarını dışlar. OEM davranışı ayrıca cihazda doğrulanmalıdır.
iOS yedekleme davranışı Android ile aynı varsayılmaz; cihazdaki yerel tercihler OS
yedeğine dahil olabilir, yayın öncesi gizlilik açıklaması buna göre incelenir.

Web ilk yüklemesi bir sunucu gerektirir; sunucunun erişim günlükleri kendi gizlilik
kapsamıdır. Offline PWA önbelleği/tüm tarayıcılarda kurulum garantisi verilmez.
Ayrıntılar: [gizlilik taslağı](docs/PRIVACY.md). Mağaza için sahibi tarafından erişilebilir
bir gizlilik URL'si yayımlanmalıdır; bu belge tek başına mağaza başvurusunu tamamlamaz.

## Kaynaklar ve izinler

- Arapça okuma: Diyanet'in halka açık Kur'an istemcisi/API'si,
  `https://kuran.diyanet.gov.tr/`; metin grubu 4. Ham/çözümlenmiş yanıtlar ve SHA-256
  kayıtları `assets/sources/diyanet-reading/` içinde korunur.
- Türkmençe meal, sure girişleri ve notlar: sahibin sağladığı
  `kurany_kerim_turkmen_dilinde.pdf`; çıkarım ve kaynak izleri
  `assets/sources/full-content-manifest.json` ve ilgili PDF denetim raporlarındadır.
- Arapça font: Diyanet `KuranIsaretler.ttf`/Amasya tabanlı paket fontları; içerik/font
  kapsam raporları `assets/sources/` içinde. Metin/font kapsam denetimi insanî/dinî
  doğruluk onayı yerine geçmez.
- Noto Serif: Google Fonts, SIL OFL 1.1; paket lisansı `assets/fonts/NotoSerif-OFL.txt`.
- Ürün ikonu: Flutter MaterialIcons `Icons.auto_stories_outlined` gerçek glifi;
  Apache 2.0 bildirimi `assets/branding/MaterialIcons-LICENSE.txt`.

Sahibi, kaynakları doğruladığını ve gerekli yayın/yeniden dağıtım izinlerini
sağladığını beyan etmiştir. Bu beyan bağımsız hukukî onay veya burada uydurulmuş bir
lisans değildir. İzin belgeleri ve kapsamı (metin, meal, font, mobil/web dağıtım,
mağazalar, bölgeler) sahibi tarafından saklanır ve yayın öncesinde kontrol edilir.
Kaynağa erişilebilirlik tek başına yeniden dağıtım izni sayılmaz.

## İkon ve yayın

[İkonun tekrar üretilmesi](assets/branding/README.md),
[imzalama ve native hazırlık](docs/NATIVE_RELEASE.md),
[yayın kontrol listesi](docs/RELEASE_CHECKLIST.md).

GitHub CI analiz, Flutter testleri, dondurulmuş içerik denetimi ve debug APK üretir.
İmzalı AAB yalnız manuel istek ve sahibin `production` ortam sırlarıyla üretilir;
akış hiçbir mağazaya yükleme yapmaz. iOS kabuğu Flutter ile üretildi, fakat Linux'ta
iOS derlemesi/cihaz testi yapılamaz: macOS/Xcode ve gerçek cihaz kontrolü gerekir.
