# Google Play Data Safety — sahibin karar çalışma notu

Hedef: Android 1.0.0+3. Bu hazır doldurulmuş form, hukukî görüş veya “veri toplanmaz” garantisi değildir. Güncel Play tanımları ve final uygulama davranışı üzerinden sahibi karar vermelidir. Bu görev Console'a erişmedi ve üçüncü tarafların günlüklerini denetlemedi.

## Koddan gözlenen veri akışı

| Akış | Gözlem | Form için kalan karar |
| --- | --- | --- |
| Okuma konumu, tema/font, yer imi adları | Yerel tercihler; uygulama kodunda geliştiriciye yükleme yolu yok | Sadece cihazda işleme ile cihaz dışı toplama ayrımını güncel tanımlara göre yapın; final SDK ve backup kapsamını doğrulayın |
| İndirilmiş ses ve zamanlama/doğrulama dosyaları | Uygulamaya ait kalıcı yerel depo, yerelden oynatma | İndirme sırasında oluşan ağ verisini sesin yerel saklanmasından ayrı değerlendirin |
| Google Drive ses isteği | Kullanıcı başlatır; Google IP, istenen dosya kimliği, istek zamanı ve HTTP teknik bilgilerini alabilir | Google'ın rolü, amaçları, saklaması ve bağımsız kullanımı araştırılmadan “toplama/paylaşma yok” seçmeyin |
| Hesap/reklam/analitik | İncelenen uygulama kapsamı bunları sunmuyor | Final geçişli/native SDK'lar ve son paket için tekrar doğrulayın; kodda görünmemek üçüncü taraf davranışı hakkında garanti değildir |
| Destek iletişimi | Gerçek adres ve operasyon henüz bekliyor | Sahibin e-posta/yardım kanalına kullanıcıların göndereceği veriler ve applicable form kapsamı ayrıca değerlendirilmeli |

## Yanıt vermeden önce

1. Son APK/AAB'nin izin/SDK listesini ve gerçek ağ trafiğini inceleyin: ilk açılış, yalnız okuma, ses seçimi, açıkça başlatılan indirme, iptal, yeniden açılış, yerel oynatma. Drive yönlendirmelerini de kaydedin; teknik doğrulama raporuna kullanıcı sırlarını koymayın.
2. Google'ın hizmet şartları/gizlilik politikasında bu barındırma kullanımını değerlendirin. IP/teknik günlükler için saklama, güvenlik/istismar önleme, bağımsız amaçlar ve olası aktarım kapsamını belgeleyin. Google'ın yalnız yayıncı adına hizmet sağlayıcı olduğu varsayımını kanıtsız kullanmayın.
3. Console'un o günkü veri türlerine göre IP/teknik tanımlayıcıları ve istenen dosyanın kullanım bilgisi niteliğini değerlendirin. IP'den yaklaşık konum türetilmesi biliniyor mu? İsteklerden uygulama etkileşimi çıkarılıyor mu? Kanıt yoksa kesin “var/yok” işaretlemek yerine belirsizliği çözün. Dini içerik seçiminin hassas bağlamını da göz ardı etmeyin; sadece dosya isteğinden profil oluşturulduğu iddia edilmez.
4. Her ilgili tür için toplanma, paylaşılma, amaç, isteğe bağlı/zorunlu, geçici işleme ve silme cevaplarını ayrı gerekçelendirin. Kullanıcının indirme düğmesine basması bütün veriyi otomatik olarak beyan dışı veya paylaşım istisnası yapmaz. Google'ın saklama süresi bilinmeden “yalnız geçici işleme” seçmeyin.
5. HTTPS indirme yolu aktarım şifrelemesine ilişkin olumlu teknik bulgudur; tüm SDK/uç noktalar için doğrulamadan genel güvenlik beyanı vermeyin. Yerel dosya silme, Google günlüklerinin silinmesini sağlamaz; henüz doğrulanmamış uzaktan silme hizmeti vaat etmeyin.
6. Uygulama hesabı bulunmaması ile yerel veri silmeyi ayırın. Güncel Console hesap silme sorularına gerçek işlev üzerinden cevap verin; hayali hesap silme URL'si oluşturmayın.
7. Gizlilik politikası, uygulama içi metin, store listing ve Data Safety cevaplarını aynı final paket için eşleştirin. Sahibinin kararını ve kanıt tarihini kayıt altına alın; ağ/SDK değiştiğinde yenileyin.

Başvuru referansları (bu görevde güncellikleri çevrimiçi doğrulanmadı):
- https://support.google.com/googleplay/android-developer/answer/10787469
- https://policies.google.com/privacy

## Açık durum

Nihai “toplanır/paylaşılır” cevapları BEKLİYOR. Üçüncü taraf davranışı, gerçek yasal yayıncı, destek iletişimi ve herkese açık politika URL'si netleşmeden bu not üretim beyanı olarak kopyalanmamalıdır. Nihai kontrol: `../RELEASE_CHECKLIST.md`.
