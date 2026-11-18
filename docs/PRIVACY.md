# Gizlilik politikası taslağı — Android / 1.0.0+3 hedefi

DURUM: Kullanıcıya yayımlanan metin `site/privacy.html` dosyasıdır (Türkmençe + Türkçe) ve GitHub Pages ile yayınlanır. Bu belge onun ayrıntılı iç gerekçesidir; ikisi birlikte güncellenir.

- Uygulama: Kuran Kitaphanasy (`tm.kuran.kitaphanasy`).
- Yayıncı: Kuran Kitaphanasy (sahibi tarafından 2026-11-18'de belirlendi).
- Destek ve gizlilik iletişimi: kurankitaphanasy@gmail.com.
- Herkese açık politika URL'si: https://gurbanowgadam.github.io/kuran-kitaphanasy/privacy.html (Pages etkinleştirildikten sonra).
- Yürürlük tarihi: 18.11.2026.

## Uygulama ve cihazda tutulan bilgiler

Kur'an'ın 114 suresi, Arapça metin ve Türkmençe meal uygulama içinde bulunur; okuma için internet gerekmez. Mevcut kodda kullanıcı hesabı, reklam, geliştirici analitiği veya geliştiriciye okuma kaydı gönderen bir backend bulunmaz. Bu, üçüncü tarafların hiçbir veri işlemediği anlamına gelmez.

Okuma konumu, görünüm/tema, yazı boyutları ve diğer okuma tercihleri, kullanıcının adlandırdığı yer imleri cihazdaki yerel uygulama depolamasında tutulur. İndirilen sesler ve bunların doğrulama/ayet zamanlama dosyaları uygulamaya ait kalıcı yerel depoda saklanır. Bunlar uygulama tarafından geliştiriciye yüklenmez; hesaplar veya cihazlar arasında uygulama kaynaklı senkronizasyon sunulmaz.

## İsteğe bağlı ses indirmeleri ve Google

Ses kaynağı MP3Quran'dır; mevcut uygulamanın indirme sunucusu Google Drive'dır. Kullanıcı bir kâri/sure için indirme başlattığında uygulama Google'a HTTPS isteği gönderir. Google Drive ve indirme altyapısı (örneğin drive.google.com ve drive.usercontent.google.com) bağlantının IP adresini, istenen dosya kimliğini ve bağlantıya ait zaman/HTTP teknik bilgilerini alabilir ve kendi hizmet politikaları kapsamında işleyebilir. İstenen dosya seçilen kâri ve sureyle ilişkilidir. Bu trafik için “hiç veri cihaz dışına çıkmaz” denemez.

Uygulama Google hesabıyla giriş istemez; kullanıcıdan Google şifresi veya Drive yetkisi istemez. Mevcut indirme kodu yer imi adlarını ve okuma tercihlerini isteğe eklemez. Ses indirilmeden uzaktan akışla çalınmaz; doğrulanıp tamamlanan dosya yerelden oynatılır. İndirilmiş kayıtlar çevrimdışı dinlenebilir. İndirme internet ve cihaz alanı gerektirir; operatör ücreti ve Drive kota/erişim kısıtları uygulanabilir.

Google'ın bu isteklere ilişkin saklama süresi, bağımsız kullanım amaçları, aktarım ülkeleri ve olası IP türetimleri bu depo incelemesiyle doğrulanmış değildir. Sahibinin son politika ve Data Safety beyanından önce bunları değerlendirmesi gerekir. Google'ın politika referansı: https://policies.google.com/privacy . Bu bağlantı uygulamanın kendi gizlilik politikası URL'sinin yerine geçmez. MP3Quran kaynak atfı, uygulamanın her dinlemede MP3Quran sunucusuna bağlandığı anlamına gelmez.

## Saklama, silme ve yedekleme

Yerel tercihler ve yer imleri değiştirilene/silinene veya uygulama verileri temizlenene kadar, tamamlanmış sesler silinene kadar cihazda kalır; otomatik süreli silme taahhüdü yoktur. Tüm yerel veriler Android sistem ayarlarındaki uygulama depolaması/verileri temizleme yoluyla kaldırılabilir; kaldırma işlemi de normalde uygulamaya ait yerel verileri siler. Google'ın olası sunucu günlükleri cihaz verilerini temizlemekle silinmez.

Son birleşik release manifestinde `INTERNET` ve ExoPlayer/media3'ün eklediği olağan `ACCESS_NETWORK_STATE` izni bulunur; allowBackup=false ve yedek/aktarım dışlama kuralları tanımlıdır. Nihai paket ve üretici davranışı ayrıca doğrulanmalıdır; mutlak yedeklenmeme garantisi verilmez. iOS ve web davranışı bu Android taslağından otomatik çıkarılamaz: iOS sistem yedekleri, web sunucusu erişim günlükleri ve tarayıcı depolaması ayrıca açıklanmalıdır.

## Talepler ve değişiklikler

Uygulama hesabı bulunmadığı için bir uygulama hesabı silme süreci yoktur. Yerel veri silme yukarıda açıklanmıştır. Gizlilik talepleri için gerçek iletişim alanı yayın öncesinde doldurulmalıdır. Destek e-postasına kullanıcı tarafından gönderilecek bilgiler için saklama/erişim sürecini yayıncı ayrıca belirlemelidir; henüz kurulmuş bir destek süreci varmış gibi sunulmaz.

Ağ, SDK, reklam, hesap veya içerik dağıtım yöntemi değiştiğinde bu metin ve mağaza beyanları yeniden değerlendirilir. Son APK/AAB ağ davranışı ile uygulama içi gizlilik açıklaması aynı kapsamı anlatmalıdır. Data Safety karar notları: `play-store/DATA_SAFETY.md`.
