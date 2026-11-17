# Türkmençe meal: kaynak ve yeniden kullanım hakları araştırması

## Sonuç ve sınır

Bu araştırma belirli yerel PDF'yi inceledi; yayın/yeniden dağıtım izni bulmadı. Kurumsal hazırlayan bilgisi doğrudan PDF'de doğrulandı, fakat yayınevi, gerçek kişi çevirmen, tam baskı künyesi ve hak sahipliği zinciri doğrulanamadı. Aynı dosyanın resmî çevrimiçi PDF'si bulunamadı; bu, böyle bir kaynağın bulunmadığı anlamına gelmez. Kullanıcının ikametini veya dağıtım ülkesini varsaymıyorum. Türkiye ve Romanya/AB bölümleri o hukukların uygulanacağı kullanım senaryoları içindir. Dünya çapında dağıtım ayrıca ülke bazlı değerlendirme ister. Bu not hukuki görüş veya sıfır risk garantisi değildir.

## 1. İncelenen dosya ve baskı tespiti

Dosya: /home/gadamgurban/Documents/kurany_kerim_turkmen_dilinde.pdf
Araçlar: pdfinfo; pdftotext -layout; sha256sum.

- 613 fiziksel PDF sayfası; 199980579 bayt; PDF 1.4; şifreleme yok.
- SHA-256: 3975592b810073a242879eb358c6509376d0c2db19c47f6b3fbe12ab72d40037
- Creator: Adobe InDesign CS6 (Windows); Producer: Adobe PDF Library 10.0.1.
- CreationDate: 3 Ocak 2013 15:15:45 EET; ModDate: aynı gün 15:27:39 EET. Bunlar dosya metadata tarihleri; baskı/yayın tarihi oldukları kanıtlanmış değildir.
- pdfinfo çıktısında Title/Author/ISBN yok.
- Metin çıkarımı fiziksel sayfa 1 / basılı sayfa 1'de “BISMILLÄHIR-RAHMÄNIR-RAHYM”, “SÖZBAŞY” ile başlıyor. Fiziksel sayfa 2 / basılı sayfa 2 Fatyha ile devam ediyor. Son fiziksel sayfaların metin katmanında yalnız 612 ve 613 sayfa numaraları bulunuyor; bunlardan görsel içerik yokluğu sonucu çıkarılmadı.
- İlk/son sayfaların metin katmanı ve tüm çıkarılmış metinde ISBN, copyright/© ve açık lisans/künye işaretleri araştırıldı. Ayrı bir okunabilir başlık/telif/künye sayfası veya açık yeniden kullanım izni saptanmadı. Görüntü içinde kalmış yazıların eksiksiz görsel/OCR denetimi yapılmadı; bu yüzden “dosyada kesinlikle yok” denmiyor.

### Kurumsal hazırlayan: doğrudan kanıt

Fiziksel PDF sayfa 1 / basılı sayfa 1, önsözün sonu:

> “Kurany Kerimiň türkmen diline terjimesi bolan bu kitap Hormatly Prezidentimiziň umumadamzat medeni, ruhy we ahlaky ýörelgelerini rowaçlandyrmak başlangyçlaryndan ugur alyp, Türkmenistanyň Müftüsiniň müdiriýeti tarapyndan taýýarlanyldy.”

Temkinli Türkçe karşılığı: Kur'an'ın Türkmen diline çevirisi olan bu kitabın Türkmenistan Müftülüğü müdürlüğü tarafından hazırlandığı belirtiliyor. Bu ifade kurumsal hazırlamayı destekler; kurumun tek başına tüm mali hakları taşıdığını, belirli bir yayınevi olduğunu veya uygulamaya yeniden dağıtım izni verdiğini kanıtlamaz.

Baskı tanımı için güvenli ifade: “Önsözünde Türkmenistanyň Müftüsiniň müdiriýeti tarafından hazırlandığı belirtilen, 613 sayfalık Türkmençe Kur'an çevirisi PDF'si; PDF üretim metadata tarihi Ocak 2013.” “2013 baskısı”, çevirmen adı, yayınevi ve ISBN henüz teyitsizdir.

Ham çıkarım: /tmp/quran-meal-source.txt

## 2. Resmî çevrimiçi nüsha ve izin için iletişim

Google, Bing ve DuckDuckGo üzerinden tam dosya adı ve kurumsal ibare araştırıldı. Google HTTP 200 döndürdü fakat JS doğrulama ekranıydı; DuckDuckGo HTTP 202 CAPTCHA döndürdü. Bing HTTP 200 sonuçları sorguyla ilgisizdi; kaynak kanıtı sayılmadı. Tahmini https://www.mufti.gov.tm adresi DNS hatası verdi; bu adresin gerçek resmî alan adı olduğu iddia edilmiyor. https://turkmenistan.gov.tm/en HTTP 200 ile açıldı; bu tek başına PDF veya lisans doğrulamaz.

Sonuç: Aynı 613 sayfalık nüshayı resmî yayınevi/müftülük sunucusundan doğrulayamadım; resmî müftülük telif birimi veya doğrulanmış yayınevi iletişimi bulunamadı. İnternetten indirilebilirlik ve şifreleme bulunmaması, çoğaltma/uygulamada paketleme izni değildir.

### Doğrulanmış resmî yönlendirme kanalı (hak sahibi değil)

Türkmenistan Ankara Büyükelçiliğinin resmî Dışişleri Bakanlığı sitesi:
https://turkey.tmembassy.gov.tm/en/contacts
HTTP 200; sayfada doğrudan:

> “Embassy TEL: +90 (312) 441 71 22/23”
> “E-MAIL: tmankara@yahoo.com”
> “Consulate ... E-MAIL: ankara.consular@mfa.gov.tm”
> “This site is managed by The MFA of Turkmenistan.”

Büyükelçilik telif ruhsatı veren kurum olarak sunulmamalı. Önce bu doğrulanmış kanaldan “Türkmenistanyň Müftüsiniň müdiriýeti'nin güncel resmî iletişimi ve bu kitabın yayın/hak birimi” istenebilir. Hiçbir e-posta gönderilmedi.

İzin talebine dosya özeti/hash ve önsöz sayfası eklenerek şunlar sorulmalı: tam başlık, baskı tarihi/numarası, ISBN, yayınevi, çevirmen/heyet; mali hakları kimin hangi sözleşmeyle taşıdığı; dijital metin çıkarma ve normalizasyon, çeviri/açıklamaları uygulamada kullanma, PDF/sayfa görsellerini paketleme, cihazda çevrimdışı saklama ve yeniden dağıtım, uygulama mağazaları/CDN, ticari veya ücretsiz kullanım, dünya çapı kapsam, süre, atıf ve değişiklik şartları. Yetkili imza ve hak zinciri teyidi istenmeli; sırf kurum adının yazması yeterli değil.

## 3. Birincil uluslararası temel: özgün eski metin ≠ modern çeviri/kayıt

WIPO Berne Sözleşmesi, resmî metin; HTTP 200, tam metin alındı:
https://www.wipo.int/wipolex/en/text/283698

Madde 2(3):
> “Translations, adaptations, arrangements of music and other alterations of a literary or artistic work shall be protected as original works without prejudice to the copyright in the original work.”

Madde 5(2):
> “The enjoyment and the exercise of these rights shall not be subject to any formality”

Aynı maddede koruma ve başvuru yollarının korumanın talep edildiği ülke hukukuna tabi olduğu belirtilir. ©/ISBN/lisans ibaresinin bulunmaması korumayı kendiliğinden kaldırmaz. Kur'an'ın kadim Arapça metninin tarihsel telif süresinden bağımsız olarak modern meal, açıklama, özgün editöryal katkılar ve ses kayıtları ayrıca incelenir. Devlet veya din kurumu hazırlamış olmak otomatik kamu malı sonucu doğurmaz; Berne 2(4)'teki resmî mevzuat/idari/hukuki metin alanını dini çeviriye doğrudan genellememek gerekir.

## 4. Türkiye — FSEK, uygulanması halinde

Güncel Mevzuat portalına erişim denemeleri zaman aşımına uğradı:
https://www.mevzuat.gov.tr/MevzuatMetin/1.3.5846.pdf

Başarılı birincil kaynak: WIPO Lex Türkiye mevzuat kaydı, HTTP 200:
https://www.wipo.int/wipolex/en/legislation/details/22507
Başlık: “Law No. 5846 on Intellectual and Artistic Works, amended up to Law No. 7346 dated 21/12/2021”. Kayıt “Latest Version in WIPO Lex” diyor. Bu, Türkiye'de daha sonraki değişiklik bulunmadığının bağımsız garantisi değildir.

Türkçe PDF bağlantısı bu kayıttan çözüldü; süreli imzalı URL ile HTTP 200, gerçek %PDF dosyası, 1123058 bayt olarak alındı ve pdftotext ile okundu:
https://wipolex-res.wipo.int/edocs/lexdocs/laws/tr/tr/tr183tr_1.pdf
İmzasız adrese doğrudan HTTP 200 isteği PDF yerine HTML kayıt sayfasına yönlendi; imzalı bağlantı için yukarıdaki kalıcı kayıt sayfası kullanılmalı.
Yerel gerçek PDF: /tmp/quran-research-fsek-signed.pdf
Metin: /tmp/quran-research-fsek-signed.txt
Aşağıdaki sayfalar fiziksel PDF sayfalarıdır.

- m.6, PDF s.3: “Diğer bir eserden istifade suretiyle vücuda getirilipte bu esere nispetle müstakil olmıyan ... fikir ve sanat mahsulleri işlenmedir: 1. Tercümeler;” Çeviri/şerh haklarının özgün kadim metinden ayrı değerlendirilmesi gerekir; somut koruma koşulları ayrıca incelenir.
- m.22, PDF s.7: “Bir eserin aslını veya kopyalarını, herhangi bir şekil veya yöntemle, tamamen veya kısmen, doğrudan veya dolaylı, geçici veya sürekli olarak çoğaltma hakkı münhasıran eser sahibine aittir.” PDF'den veri çıkarıp uygulamaya koymak hak analizi gerektirir.
- m.25, PDF s.8: “gerçek kişilerin seçtikleri yer ve zamanda eserine erişimini sağlamak suretiyle umuma iletimine izin vermek veya yasaklamak hakkına da sahiptir.” Çevrimiçi erişim ve indirmeye sunma ayrıca önemlidir. m.21 işleme ve m.23 yayma hakları da kullanım şekline göre incelenmeli.
- m.27, PDF s.9: “Koruma süresi eser sahibinin yaşadığı müddetçe ve ölümünden itibaren 70 yıl devam eder”. Anonim/kurumsal durumların özel kuralları var; bu PDF'de çevirmen ve hak zinciri bilinmediği için süre hesabıyla kamu malı ilan edilemez.
- m.38, PDF s.11: “kâr amacı güdülmeksizin şahsen kullanmaya mahsus çoğaltılması mümkündür. Ancak, bu çoğaltma hak sahibinin meşru menfaatlerine haklı bir sebep olmadan zarar veremez ya da eserden normal yararlanmaya aykırı olamaz.” Ücretsiz, reklamsız veya dini amaçlı herkese açık uygulama, sırf bu sebeple şahsi kullanım değildir. Uygulanabilir istisna yoksa lisans gerekir; “ticari değil” genel izin değildir.
- m.52, PDF s.21: “Mali haklara dair sözleşme ve tasarrufların yazılı olması ve konuları olan hakların ayrı ayrı gösterilmesi şarttır.” Yazılı izinde çoğaltma, yayma/umuma iletim ve gerekli işlemeler tek tek kapsanmalı.
- m.80, PDF s.29: “icracı sanatçıların, bir icra ürünü olan veya sair sesleri ilk defa tespit eden fonogram yapımcıları ... komşu hakları vardır.” Aynı sayfada icracının tespit, çoğaltma, dağıtma ve umuma iletim için izin verme/yasaklama hakları yer alır. Kadim metin serbest olsa bile mevcut okuyucu kaydı serbest sayılmaz.

Font/teknik varlıklar: Meal izni font yazılımını, gömülü font dosyasını, mushaf sayfa tasarımını, kaligrafiyi, illüstrasyonları veya üçüncü taraf veri tabanını otomatik kapsamaz. Her varlığın korunabilirliği ve somut lisansı ayrı değerlendirilmelidir. Salt kadim harf/metin ile bir font yazılımı aynı şey değildir; “bütün font şekilleri her yerde telifle korunur” şeklinde kategorik iddia yapılmamalı. Fontun yalnız görüntülenmesi, uygulamaya gömülmesi ve dosyasının yeniden dağıtılması farklı kapsamlar olabilir. Bu araştırma font adlarını/lisanslarını denetlemedi.

## 5. Romanya / AB — kayıt ve icra hakları

EUR-Lex resmî adreslerine canlı erişim denendi; tüm aşağıdaki istekler HTTP 202 ve 0 bayt döndürdü. Bu yüzden bu oturumda okunmuş metin veya doğrulanmış alıntı gibi gösterilmiyor:
https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX:32001L0029
https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX:32006L0116
https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=CELEX:32001L0029
https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=CELEX:32006L0116
https://eur-lex.europa.eu/LexUriServ/LexUriServ.do?uri=CELEX:32011L0077:EN:HTML

Başvurulacak AB çerçevesi: 2001/29/EC çoğaltma/umuma iletim ve sınırlı istisnalar; 2006/116/EC ve fonogram sürelerini değiştiren 2011/77/EU. Uygulamaya ilişkin teyit aşağıdaki başarılı WIPO Romanya metniyle sınırlandı; direktiflerden bu oturumda doğrudan alıntı yapılmadı.

Romanya WIPO Lex resmî kayıt, HTTP 200:
https://www.wipo.int/wipolex/en/legislation/details/22202
“Law No. 8 of March 14, 1996, on Copyright and Neighboring Rights (amended up to Law No. 69/2022)”. WIPO kaydı bunu son sürüm olarak sunuyor; 2022 sonrası Romanya mevzuatının bağımsız güncellik teyidi yapılamadı. Kayıt İngilizce metnin eski (2006), Fransızca metnin eski (1996) olduğunu açıkça söylüyor; bunlar güncel metin yerine kullanılmadı.

2022 Romence metin şu bağlantı HTTP 200 ile PDF yerine HTML/WIPO kayıt+tam metin olarak döndüğünde alındı ve incelendi (PDF sanılmamalı):
https://wipolex-res.wipo.int/edocs/lexdocs/laws/ro/ro/ro107ro_1.pdf
Yerel okunabilir çıkarım: /tmp/quran-research-romania.txt

Madde 106(1), doğrudan alıntı:
> “producătorul de înregistrări sonore are dreptul patrimonial exclusiv de a autoriza sau de a interzice ... a) reproducerea prin orice mijloc și sub orice formă a propriilor înregistrări sonore; b) distribuirea propriilor înregistrări sonore”

m.106(1)(g):
> “punerea la dispoziția publicului a propriilor înregistrări sonore, astfel încât să poată fi accesate, în orice loc și în orice moment ales, în mod individual, de către public”

Türkçe özeti: yapımcının ses kayıtlarını çoğaltma, dağıtma ve bireysel seçilen yer/zamanda erişime sunma bakımından ayrı hakları vardır. Ücretsiz indirmeye açma bu hakları kendiliğinden ortadan kaldırmaz. Yayın/umuma iletim için bazı hallerde bedel rejimi bulunması, indirmeli yeniden dağıtıma otomatik lisans değildir.

m.102(1)(b), icranın fonograma tespiti için belirli koşullarda:
> “drepturile încetează la 70 de ani de la prima astfel de publicare sau de la prima astfel de comunicare către public, în funcție de care dintre aceste date este prima.”

Bu, fonograma tespit edilmiş icralar için koşullu süre kuralıdır; tüm kayıtlar için “kayıttan itibaren daima 70 yıl” demek yanlıştır. Kayıt tarihi, ilk hukuka uygun yayın/iletim ve geçiş hükümleri gerekir; burada somut okuyucu kaydının süresi hesaplanmadı.

Uluslararası kayıt/performans temeli, WIPO WPPT resmî metin; HTTP 200:
https://www.wipo.int/wipolex/en/text/295578
m.7:
> “Performers shall enjoy the exclusive right of authorizing the direct or indirect reproduction of their performances fixed in phonograms, in any manner or form.”
m.11:
> “Producers of phonograms shall enjoy the exclusive right of authorizing the direct or indirect reproduction of their phonograms, in any manner or form.”

WPPT m.10 ve m.14 ayrıca erişime sunma haklarını düzenler; somut ülkenin uygulaması/istisnaları ve sözleşme zinciri ayrıca incelenir. Metnin kadimliği, modern okuyucunun icrası ile kayıt yapımcısının haklarını kaldırmaz.

## 6. Karar için pratik eşik

Bu PDF'ye dayanarak “tam meal ve açıklamaları herkesin indirebildiği uygulamada serbestçe paketleyebiliriz” sonucu çıkmaz. Doğrulanmış lisans veya yetkili hak sahibinden kapsamı açık yazılı izin bulunana kadar durum “izin doğrulanmadı” olmalı; bu bir mahkemece ihlal tespiti değildir. Alternatif, hak zinciri ve uygulamada dağıtım/çevrimdışı kullanım izni açık bir çeviri bulmak veya ayrı çeviri sipariş edip gereken hakları yazılı düzenlemektir. Ses, font ve teknik varlıklar aynı kontrol listesinden ayrı ayrı geçmelidir.

Kod veya kullanıcı projesi değiştirilmedi. Araştırmada e-posta gönderimi, hesap açma, ücretli işlem veya dağıtım yapılmadı.
