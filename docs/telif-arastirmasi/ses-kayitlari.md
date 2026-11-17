# Kuran Kitaphanasy — ses kayıtları lisans araştırması

Kontrol: 15 Kasım 2026, UTC. Yaklaşık beş dakikalık sınırlı inceleme. Proje kodu değiştirilmedi; hiçbir kişiye başvuru gönderilmedi. Bu bir hukuki görüş değil, kaynak/izin kanıtı değerlendirmesidir.

## Sonuç

Beş kârinin mevcut EveryAyah dosyaları için, Google Drive'dan yeniden dağıtma + uygulama içinden indirme + kalıcı çevrimdışı oynatma + Abu Bakr 001001 kaydını APK'ya gömme kullanımının tamamını açıkça karşılayan doğrulanmış lisans zinciri BULUNAMADI. Bu, kesin olarak yasak olduklarının tespiti değildir; izin kanıtı eksiktir. Ticari olmayan kullanımın kendiliğinden serbest olduğu da gösterilemedi.

Önemli alternatif bulgu: MP3Quran'ın kendi resmî sitesinde hem ticari kullanımı açıkça anan genel izin beyanı hem de geliştiricilerin materyal kullanmasına izin veren metin mevcut. Ancak bu beyanı EveryAyah'tan alınmış mevcut baytlara otomatik uygulamak doğru değildir: aynı ses kaydı/master olduğunun ve izin verenin ilgili kayıt haklarında yetkili olduğunun teyidi gerekiyor.

## 1. Yerel dosyalar ve uygulamanın gerçek kapsamı

/home/gadamgurban/kuran-audio-drive-test altında 75 ZIP'in tamamı Python zipfile ile açılıp lisans girdileri okundu. Her kâri altında 15 ZIP var. Her gruptaki 15 lisans metni kendi içinde aynı; beş gruptaki metin de aynı. Girdi adı: 000_license.html.

Doğrudan gömülü metin:

> Please note that use of these MP3s is only allowed if you comply with the license details:
> http://www.versebyversequran.com/site/license

Tam HTML:

```html
<html><body>Please note that use of these MP3s is only allowed if you comply with the license details:
<a href="http://www.versebyversequran.com/site/license">
http://www.versebyversequran.com/site/license</a>

</body></html>
```

Bu dosya izin koşullarının kendisi değil, koşullara bağlı kullanım bildirimi ve haricî bağlantıdır. Koşul bulunamadığı için sınırsız izin sonucu çıkarılamaz.

Yerel proje belgesi /home/gadamgurban/kuran-kitaphanasy/docs/OFFLINE_AUDIO.md satır 13–23: 5 × 15 ZIP, kamuya açık Drive kimlikleri, kaynak ZIP baytlarının korunduğu ve surelerin 1, 56, 67, 75, 93, 105–114 olduğu yazıyor. Satır 9: oynatıcı yalnızca indirilmiş yerel dosyaları kullanıyor. Bunlar mevcut belgenin ifadeleridir; bu görevde cihazda oynatma testi yeniden yapılmadı.

Drive klasörü belgede: https://drive.google.com/drive/folders/14HZQy5VwYI853RYUxQZs0aedfaM6l2wO . Bu incelemede Drive'daki bütün uzak dosyalar yeniden indirilmedi; 75 yerel ZIP incelendi. Drive hizmetinin dosya yüklemeye izin vermesi içerik için yeniden dağıtım lisansı sağlamaz.

APKgömülü varlık doğrudan doğrulandı:
- /home/gadamgurban/kuran-kitaphanasy/assets/audio/abu_bakr_fatiha_001001.mp3
- 104200 bayt
- SHA-256: b72b1275a8db14537557f668735b70a7280c1f7ec83532d159de978e8a3e7023
- Yerel Abu_Bakr_Ash-Shaatree_128kbps/001_Fatiha.zip içindeki 001001.mp3 ile bayt bayt aynı.
- Bu, kaynak kimliğini doğrular; izin veya APK'nın bu görevde yeniden açılıp incelendiğini göstermez. Gömülme proje varlığı ve AUDIO_OPENING_CORRECTION.md belgesiyle desteklenir.

## 2. Her kâri için ayrı izin değerlendirmesi

| EveryAyah kayıt seti | Yerel kanıt | Mevcut EveryAyah kaydı için açık izin | Alternatif sağlayıcının kendi kaydı |
|---|---|---|---|
| Yasser_Ad-Dussary_128kbps | 15/15 ZIP'te koşullu lisans bağlantısı | Doğrulanamadı | https://www.mp3quran.net/eng/yasser — HTTP 200, “The Holy Quran in the voice of Yasser Al-Dosari” |
| Abu_Bakr_Ash-Shaatree_128kbps | 15/15 ZIP; ayrıca APK varlığı ile 001001 eşleşiyor | Doğrulanamadı; APK içine dağıtım ayrıca açık onay gerektiriyor | https://www.mp3quran.net/eng/shatri — HTTP 200, “The Holy Quran in the voice of Shaik Abu Bakr Al Shatri” |
| Alafasy_128kbps | 15/15 ZIP'te koşullu lisans bağlantısı | Doğrulanamadı | https://www.mp3quran.net/eng/afs — HTTP 200, “The Holy Quran in the voice of Mishary Alafasi” |
| Abdurrahmaan_As-Sudais_192kbps | 15/15 ZIP'te koşullu lisans bağlantısı | Doğrulanamadı | https://www.mp3quran.net/eng/sds — HTTP 200, “The Holy Quran in the voice of Abdulrahman Alsudaes” |
| MaherAlMuaiqly128kbps | 15/15 ZIP'te koşullu lisans bağlantısı | Doğrulanamadı | https://www.mp3quran.net/eng/maher — HTTP 200, “The Holy Quran in the voice of Maher Al Meaqli” |

MP3Quran sayfaları bu sağlayıcının birincil katalog kaynaklarıdır; kârilerin kişisel resmî siteleri olarak sunulmuyor. Hepsinde “Download the complete Quran” sunulması tek başına uygulama dağıtım izni değildir. Ayrıca aynı kâri, farklı dönem/çekim/master/riwayet veya kodlama demek olabilir. Bu görevde MP3Quran seslerinin EveryAyah kayıtlarıyla akustik veya bayt düzeyinde eşitliği gösterilmedi.

## 3. EveryAyah resmî kaynakları: gerçekten alınan yanıtlar

- https://everyayah.com/ — HTTP 200. Görülen metin: “EveryAyah Quran Files”; “Contact Us” bağlantısı https://quran.zendesk.com/hc/en-us adresine gidiyor.
- https://everyayah.com/recitations_ayat.html — HTTP 200. Beş set katalogda bulunuyor; örnek görünen metin “Abu Bakr Ash-Shaatree 128kbps”, “Abdurrahmaan As-Sudais 192kbps”, “Alafasy 128kbps”, “Maher Al Muaiqly 128kbps”, “Yasser_Ad-Dussary 128kbps”. İndirme bağlantıları lisans değildir.
- https://everyayah.com/old_index.html — HTTP 200. Alıntı: “Contact us for more details.” Aynı Zendesk bağlantısını veriyor.
- http://www.versebyversequran.com/site/license — HTTPS'ye yönlendirilerek son yanıt HTTP 404; son URL https://www.versebyversequran.com/site/license . Alıntı: “404 File Not Found”.
- https://www.versebyversequran.com/site/license — HTTP 404, “404 File Not Found”.
- https://versebyversequran.com/site/license — HTTP 404, “404 File Not Found”.
- https://everyayah.com/site/license ve https://everyayah.com/license — ikisi HTTP 404. Bunlar keşfedilmiş resmî lisans bağlantıları değil, alternatif yol denemeleridir.
- https://quran.zendesk.com/hc/en-us — HTTP 403; Cloudflare “Just a moment...” / “Enable JavaScript and cookies to continue”. Bağlantının resmî ana sayfadan verildiği doğrulandı; destek içeriği okunamadı. Bu yanıt lisans şartı değildir.
- https://everyayah.com/contact.php — HTTP 404; tahminî yol, doğrulanmış iletişim yolu değildir.

Beş ayrı https://everyayah.com/data/SET/000_license.html yolu da gerçekten denendi ve hepsi HTTP 404 döndü. Bu durum ZIP içinde lisans bulunmadığı anlamına gelmez: yerelde tamamında mevcut. Denenen SET değerleri yukarıdaki tablodaki birebir beş klasör adıdır.

## 4. Arşiv: kayıt bulundu, içerik alınamadı

https://archive.org/wayback/available?url=www.versebyversequran.com/site/license — HTTP 200. JSON alıntısı:

> "status": "200", "available": true, "url": "http://web.archive.org/web/20121021062917/http://www.versebyversequran.com/site/license", "timestamp": "20121021062917"

https://web.archive.org/cdx/search/cdx?url=versebyversequran.com/site/license&output=json&filter=statuscode:200&filter=mimetype:text/html&collapse=digest — HTTP 200. İndeks 20090925025151, 20110809084252, 20110826044917, 20110928144333, 20120214083651, 20121021062917 zaman damgalı başarılı tarihsel HTML kayıtları gösterdi.

İçerik için denenen iki URL:
- https://web.archive.org/web/20121021062917id_/http://www.versebyversequran.com/site/license — HTTP 429.
- https://web.archive.org/web/20090925025151id_/http://www.versebyversequran.com:80/site/license — HTTP 429.

429 alıntısı: “Your request is being blocked because our system has flagged it as suspected abusive bot traffic”. Dolayısıyla arşivden lisans metni okunamadı. İndekste geçmişte bir sayfa bulunması, o sayfanın hangi hakları verdiğini kanıtlamaz. Ticari/ticari olmayan ayrımı, atıf koşulu, yeniden barındırma veya APK hakkı hakkında arşivden sözde alıntı üretilmedi.

## 5. MP3Quran: somut, fakat kapsamı sınırlı alternatif izin kanıtı

Resmî Türkçe yol: https://www.mp3quran.net/tr/contact-us — HTTP 200. Arayüz Türkçe, önemli hak beyanı Arapça:

> نشكركم على تواصلكم معنا ونفيدكم بأن حقوق الموقع متاحة للجميع حتى ولو كانت لإغراض تجارية

Türkçe anlamı: “Bizimle iletişime geçtiğiniz için teşekkür ederiz; sitenin haklarının ticari amaçlarla olsa bile herkese açık olduğunu bildiririz.” Bu, ticari kullanımın açıkça anıldığı gerçek kaynak beyanıdır; yalnızca kamuya açık dosya çıkarımı değildir.

https://www.mp3quran.net/tr/privacy — HTTP 200. “الحقوق” başlığından alıntı:

> جميع الحقوق متاحة للجميع و يحق لأي زائر أو مطور استخدام اي مادة أو رابط من الموقع

Türkçe anlamı: “Tüm haklar herkese açıktır; herhangi bir ziyaretçi veya geliştirici sitedeki herhangi bir materyali veya bağlantıyı kullanabilir.”

Bu iki beyan, MP3Quran'dan alınacak içerik için güçlü ve resmî sağlayıcı düzeyinde başlangıç kanıtıdır. Ancak metin tek tek her kaydın master sahibi, icracı muvafakati, EveryAyah kesitleriyle eşleşme, Drive'a yeniden yükleme ve APK'ya gömme ayrıntılarını açıklamıyor. Mevcut EveryAyah baytları için bunu lisans transferi gibi yorumlamayın. Sağlayıcıdan tam kayıt setlerini ve yeniden dağıtım biçimini yazılı teyit ettirmek en güvenli adımdır.

https://www.mp3quran.net/tr/about — HTTP 200; “Download or play Quran recitations anytime, anywhere.” Metin esasen İngilizce; Türkçe yol gerçek Türkçe içerik garantisi değil. https://www.mp3quran.net/eng/about de HTTP 200.

Tahminî https://www.mp3quran.net/eng/copyright ve /eng/contact yolları HTTP 404; gerçek iletişim yolu Türkçe sayfadan keşfedilen /tr/contact-us. Form mevcut; herhangi bir form gönderilmedi.

## 6. Hakları ayırma ve ürün için karar

1. Kur'an metninin dinî/kadim niteliği modern ses kaydını kamu malı yapmaz. İcra, kayıt/master, yapımcı/yayıncı ve ülkeye göre bağlantılı haklar ayrıca değerlendirilmeli.
2. EveryAyah sunucusundan dosya indirme yetkisi ile kayıt sahibinden yeniden üretme/dağıtma yetkisi farklıdır. Host, elindeki haklardan daha geniş hak veremez; yetki zinciri sorulmalı.
3. Google Drive'a yükleme + başkalarına uygulamadan indirtme yeni kopyalama/yeniden barındırma/dağıtım kapsamıdır; kullanıcının sonradan çevrimdışı dinlemesi bu adımı ortadan kaldırmaz.
4. APK'ya tek bir 001001 dosyası koymak da dağıtımdır. Süre kısa diye otomatik serbest değildir. Açılış/besmele yerine tekrar kullanılması açısından düzenleme, bölme ve bağlam koşulları da sorulmalı; şu anki dosya baytları değişmemiştir.
5. Ücretsiz uygulama veya reklamsız test otomatik lisans sağlamaz. Ticari olmayan izin varsa bile bunun Drive/APK dağıtımı ve geliştirici kullanımını içerdiği gösterilmeli. Bağış, reklam, abonelik/ücretli sürüm ayrıca belirtilmeli.
6. Atıf eklemek eksik iznin yerine geçmez. Lisans dosyasını ZIP'te korumak da okunamayan şartlara uyumu kendi başına kanıtlamaz.
7. Mevcut kanıtla bu beş EveryAyah setini “açık lisanslı/ücretsiz ticari dağıtıma uygun” diye etiketlemeyin. Kamusal dağıtım kararından önce izin belgesini veya hak sahibinin teyidini alın. İzin çıkmazsa MP3Quran'ın kendi kaynaklarından, kendi açık beyanının kapsamı teyit edilerek yeni ve kayıt kimliği sabitlenmiş set seçmek alternatif olabilir; bu görev kaynak değiştirmedi.

## 7. Resmî temas ve sorulacak kesin sorular

EveryAyah: ana ve eski ana sayfaların verdiği https://quran.zendesk.com/hc/en-us . 403 yüzünden destek makalesi/e-posta doğrulanamadı. Uydurma kişi/e-posta verilmedi.

MP3Quran: https://www.mp3quran.net/tr/contact-us . Her beş kârinin sayfası aynı sağlayıcının kendi katalog sayfası; bunlar kişisel resmî kâri siteleri veya master sahibi olduklarının ispatı değil. Kârilerin yetkili temsilcileri bu süre içinde bağımsız doğrulanamadı.

Yazılı onayda şu maddeler açık olmalı:
- Beş birebir set adı, örnek dosyalar/özetler ve varsa kayıt/master yılı; hangi icracı/yapımcı hakları için yetki verildiği.
- 75 ZIP'in Google Drive'da yeniden barındırılması ve uygulamadan seçmeli indirme.
- Kalıcı cihaz depolaması, sınırsız çevrimdışı tekrar oynatma; APK/AAB içinde Abu Bakr 001001'in dağıtılması.
- Ticari olmayan ve reklam/bağış/ücretli sürüm koşulları; coğrafya, platform, süre, kullanıcı sayısı sınırları.
- Kesme, normalizasyon, yeniden kodlama, ayet bazına bölme/birleştirme ve açılış kaydı olarak kullanma koşulları.
- Zorunlu atıf, lisans metnini gösterme/koruma, telif bildirimi ve varsa izin iptali/güncelleme şartı.
- Başka kurumun/üçüncü kişinin izni gerekiyorsa sahibinin ve iletişim yolunun bildirilmesi.

## 8. Araştırma kısıtları ve kanıt dosyaları

Bu oturumda web_search aracı sunulmuyor; dolayısıyla araç yokken kullanıldığı iddia edilmiyor. Güncel HTTP istekleri urllib/curl ile yapıldı. Google aramaları HTTP 200 olmasına rağmen gerçek sonuç yerine JS yönlendirme kabuğu verdi. DuckDuckGo HTTP 202 bot doğrulaması verdi. Bing HTTP 200 fakat sorguyla ilgisiz sonuçlar verdi; hiçbir ilgisiz sonuç lisans kanıtı sayılmadı. İnternet tümüyle engelli değil: EveryAyah, MP3Quran ve arşiv metaverisi gerçekten okunabildi.

Aday kişisel alan adı denemeleri: https://alafasy.me/ DNS çözümleme hatası; https://alafasy.com/ HTTP 200 ama görünür metin/bağlantı yok. Bu alan adlarının resmîliği veya hak sahibine aidiyeti doğrulanamadı; lisans/iletişim kanıtı sayılmadı. Diğer kâriler için doğrulanmış kişisel resmî bağlantı bulunamadığı, bunların hiç olmadığı anlamına gelmez.

Ham alınmış HTTP gövdeleri, istek URL'leri, son URL'ler ve durumlar (başarısızlıklar dahil):
- /tmp/quran-rights-http.json
- /tmp/quran-rights-http-2.json
- /tmp/quran-rights-http-3.json
- /tmp/quran-rights-http-4.json

Bu kayıtlar alınan yanıtların yerel kopyalarıdır; imzalı hak sahipliği belgesi değildir. Her URL'nin ayrıntılı HTTP durumu ham dosyalardadır. Yerel ZIP okuması ve MP3 eşleştirmesi gerçek çalıştırma sonucudur. Kod/proje veya Drive içeriği değiştirilmedi.
