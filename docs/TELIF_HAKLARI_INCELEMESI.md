# Kuran Kitaphanasy — içerik ve lisans incelemesi

İnceleme: 15 Kasım 2026. İncelenen ürün: /home/gadamgurban/kuran-kitaphanasy ve mevcut debug APK. Bu teknik kaynak/lisans araştırmasıdır; avukat görüşü, kurum tasdiki, mağaza onayı veya sıfır risk garantisi değildir. Kaynak kodu, içerikler, Drive dosyaları ve uygulama davranışı değiştirilmedi; kimseye izin başvurusu gönderilmedi.

## 1. Karar özeti

Mevcut kanıtlarla uygulamanın bütün içeriklerini dünya çapında kamuya açık biçimde “sınırsız ve sorunsuz kullanılabilir” diye onaylamak mümkün değil. Özellikle mevcut EveryAyah seslerinin yeniden dağıtımı, Türkmençe meal/açıklamalar ve ayrı Shaikh Hamdullah Mushaf fontu için hak kapsamı doğrulanmalı. Bu bir ihlal kararı değildir: eksik olan, somut kullanımı karşılayan izin kanıtıdır.

README'deki “sahibi izinleri sağladığını beyan etti” kaydı bağımsız lisans belgesi değildir. Bu incelemede imzalı/kapsamı belirli izin mektupları görülmedi; sahibin proje dışında tuttuğu belgelerin bulunmadığı iddia edilmez. Varsa önce o belgeler incelenmelidir.

Ücretsiz, reklamsız, dini amaçlı veya çevrimdışı olmak; kaynak yazmak, PDF'nin şifresiz olması ve dosyanın kamuya açık sunucudan indirilmesi tek başına yeniden dağıtım izni sağlamaz. Herkese indirilebilir uygulama kişisel okuma ile aynı kullanım değildir. Özel test de kendiliğinden hak sahipliği sağlamaz.

## 2. Varlık bazlı durum

| Varlık | Somut bulgu | Yayın öncesi karar |
|---|---|---|
| Kadim Arapça Kur'an metni | Tarihsel metin ile modern veri dosyası, font, meal ve kayıt ayrı katmanlar | Kur'an'ın kendisini modern ses/çeviri/font lisansı ile karıştırma |
| Diyanet metin grubu 4 | Gerçek veri kaynağı resmi API; bu kullanımı kapsayan genel yeniden dağıtım şartları doğrulanamadı | Mevcut izin veya ilgili kurumun kapsam teyidi; veri tabanı/edition şartlarını netleştir |
| Türkmençe meal, girişler ve notlar | 613 sayfalık yerel PDF; önsöz kurumsal hazırlayanı belirtir; açık yeniden dağıtım lisansı saptanmadı | Yetkili hak sahibi ve baskı kimliği; dijital çıkarım ve mağazada/offline dağıtım için yazılı izin |
| Amasya / KuranIsaretler.ttf | Dosyaya gömülü özel lisans, ücretli veya ücretsiz yazılım parçası olarak dağıtıma açıkça izin verir | Metni koru; mevcut değiştirilmemiş font için somut olumlu kanıt var. Modifikasyon/subset/font satışı ayrı şartlar |
| ShaikhHamdullahMushaf.ttf | Ayrı telif kaydı var, nameID13/14 lisans metni yok; APK'da mevcut ve kullanılıyor | Amasya iznini otomatik uygulama; ayrıca teyit al veya lisansı açık çözüm için ayrı ürün kararı |
| Noto Serif Regular/Bold | SIL OFL 1.1; yerel belge resmî kaynakla aynı; APK'da bulunur | Lisans/telif bildirimi ve OFL koşulları korunarak kullanılabilir |
| Material Icons ve türev uygulama ikonu | Apache 2.0 belgesi resmî kaynakla aynı; depoda mevcut | APK/AAB/IPA/web son kullanıcı lisans/atıf taşımasını açıkça doğrula; depoda olması tek başına yeterli değil |
| EveryAyah — beş kâri, 75 ZIP | Tamamında koşullu haricî lisans bağlantısı var; bağlantı 404 | Bu kayıtlar için yeniden barındırma/indirtme/çevrimdışı kullanım ve APK gömme kapsamını yazılı teyit et |
| APK'daki eş-Şatri besmele kaydı | Aynı kârinin 001001.mp3 kaynak baytları; APK içinde gerçekten mevcut | Kısalığı veya ayet olması otomatik izin değil; dağıtım kapsamına ayrıca dahil et |
| Flutter ve doğrudan Dart paketleri | Yerel LICENSE'larda MIT/BSD türü izinler bulundu | Bildirimleri koru; bu kontrol bütün geçişli/native bağımlılıkların eksiksiz lisans denetimi değildir |

## 3. Sesler: mevcut kullanım ve yeni olumlu kaynak

Mevcut katalogdaki kâriler:
- Yasser_Ad-Dussary_128kbps
- Abu_Bakr_Ash-Shaatree_128kbps
- Alafasy_128kbps
- Abdurrahmaan_As-Sudais_192kbps
- MaherAlMuaiqly128kbps

Her biri için 15 yerel ZIP, toplam 75 ZIP içindeki 000_license.html okundu. Hepsi şu bağlantıya yönlendiriyor:
http://www.versebyversequran.com/site/license

Bildirim kullanımın lisans koşullarına uyulmasına bağlı olduğunu söylüyor. Bağlantının mevcut HTTP/HTTPS yanıtları 404. Wayback indeksinde tarihsel kayıtlar bulundu, fakat gövdeleri 429 engeli nedeniyle okunamadı. Şartların kaybolması, kayıtları sınırsız serbest yapmaz. Kâri, icracı ve kayıt/master/yapımcı hak zinciri kayıt özelinde belirlenmelidir.

Uygulama yalnız yerel dosyayı oynatsa da önce Drive'a yüklemek ve kullanıcıya indirtmek ayrıca kopyalama/yeniden sunma kapsamıdır. APK içindeki tek bir besmele dosyası da dağıtımdır. Aynı kişinin başka sitedeki kaydı her zaman aynı master/kayıt değildir.

### MP3Quran bulgusu

https://www.mp3quran.net/tr/contact-us — HTTP 200; resmî sağlayıcının Arapça beyanı:
> حقوق الموقع متاحة للجميع حتى ولو كانت لإغراض تجارية

Anlamı: sitenin haklarının ticari amaçlarda dahi herkese açık olduğunu bildiriyor.

https://www.mp3quran.net/tr/privacy — HTTP 200; haklar bölümü geliştirici ve ziyaretçilerin sitedeki materyal veya bağlantıları kullanabileceğini belirtiyor.

Bu, MP3Quran'ın kendi içerikleri için gerçek, olumlu bir sağlayıcı izin beyanıdır; yalnız indirilebilirlikten çıkarım değildir. Fakat mevcut EveryAyah dosyaları için kendiliğinden lisans oluşturmaz. MP3Quran'dan seçilecek kesin kayıtlar için şu kapsamı ve yetkiyi yazılı netleştirmek en izlenebilir yoldur: kendi sunucusu/Drive, yeniden kodlama veya ayetlere bölme, kalıcı offline indirme, APK/IPA içinde kayıt gömme, mağazalar, ülkeler ve ticari kullanım. Bu incelemede ses kaynağı değiştirilmedi.

EveryAyah destek bağlantısı kendi ana sayfasından https://quran.zendesk.com/hc/en-us adresine gider; içerik 403 nedeniyle okunamadı. Hayali iletişim adresi verilmedi.

## 4. Meal ve Arapça veri

Yerel PDF: /home/gadamgurban/Documents/kurany_kerim_turkmen_dilinde.pdf
SHA-256: 3975592b810073a242879eb358c6509376d0c2db19c47f6b3fbe12ab72d40037

Önsözde “Türkmenistanyň Müftüsiniň müdiriýeti tarapyndan taýýarlanyldy” ifadesi var. Bu kurumsal hazırlayan atfıdır, mali hak sahibinin kim olduğunu veya halka yeniden dağıtım iznini tek başına ispatlamaz. Çevirmen/heyet, yayınevi, baskı ve ISBN bu incelemede doğrulanamadı. 2013 dosya oluşturma tarihi baskı tarihi diye sunulamaz.

Metin katmanı ayrıca incelendi; fiziksel 1, 612 ve 613 sayfaları görsel olarak da kontrol edildi. 1 önsöz, 612 Arapça fihrist, 613 büyük ölçüde boş sayfa. Bu üç sayfada açık lisans/künye görülmedi; tüm kitabın görüntülerinde böyle bir ibare bulunmadığı iddia edilmiyor.

Arapça kadim metnin kendisini bir kurumun sahip olduğu modern edebî eser gibi tanımlamamak gerekir. Bununla birlikte Diyanet API erişimi; veri tabanı, font, özgün editoryal ekler veya sayfa görsellerine ait tüm hakların devri değildir. Bu araştırmada metin grubu 4 için genel kullanım şartları doğrulanamadı. Diyanet ağ erişimi/arama engelleri nedeniyle e-posta veya kesin ön izin şartı uydurulmadı. Kullanıcının kabul ettiği imla korunmalı; başka metin sessizce konulmamalı.

Alternatif açık kaynak: https://tanzil.net/docs/text_license . Aynen/değiştirmeden dağıtım, Tanzil atfı, tanzil.net bağlantısı ve bildirim taşıma koşulları doğrulandı. Bu, mevcut Diyanet yazımının aynı olduğu anlamına gelmez ve meal/ses/font haklarını çözmez. Kaynak değişimi ayrı onay ve doğruluk testleri ister.

## 5. Font ve ikon ayrıntıları

KuranIsaretler.ttf gerçek adı Amasya Regular, sürüm 3.009; hak kaydı Muhammet Abay. Gömülü nameID13'te:
> However, you may distribute this font as part of paid or free software.

Önceki cümleler değiştirme/çoğaltma ve embedding şartları da içerir; son cümleyi sınırsız yeniden lisanslama veya modifikasyon izni olarak okumayın. Mevcut APK'daki Amasya ve Shaikh dosyalarının kaynak TTF ile bayt bayt aynı olduğu ayrıca doğrulandı.

Shaikh Hamdullah Mushaf sürüm 1.003 (2011) ayrı dosya ve ayrı hak değerlendirmesidir. OS/2.fsType=0 teknik bayrağı tek başına lisans sözleşmesi değildir.

Noto resmî lisansı: https://raw.githubusercontent.com/notofonts/latin-greek-cyrillic/main/OFL.txt
Google Fonts aynası: https://raw.githubusercontent.com/google/fonts/main/ofl/notoserif/OFL.txt
Material Icons: https://raw.githubusercontent.com/google/material-design-icons/master/LICENSE

Yerel Noto ve Material lisans metinleri bu resmî dosyalarla eşleştirildi. Noto OFL APK'ya alınmış. MaterialIcons özel lisans belgesi repo içinde var, fakat bağımsız asset olarak APK'da yok; genel NOTICES'ın bu varlığa özgü kapsamı doğrulanamadı. Son dağıtımda açık ve izlenebilir lisans/telif kaydı tamamlanmalı; sırf bu bulgudan otomatik ihlal kararı çıkarılmıyor.

Doğrudan paketlerin yerel belgeleri kontrol edildi: archive ve just_audio MIT; Flutter, crypto, path_provider, scrollable_positioned_list ve shared_preferences BSD türü koşullu yeniden dağıtım metinleri içeriyor. Native/geçişli bağımlılıkların tamamı ve final release artifact'ı ayrıca kontrol edilmeli.

## 6. Hukuki çerçeve ve sınırlar

Modern çeviri ve kayıt, tarihsel kaynak metinden ayrı korunabilir. Berne 2(3) çeviri/işlenmeleri; WPPT 7 ve 11 icracı ve fonogram yapımcısının çoğaltma haklarını ayrı düzenler. © veya ISBN bulunmaması otomatik hak yokluğu değildir.

Birincil kaynaklar:
- Berne: https://www.wipo.int/wipolex/en/text/283698
- WPPT: https://www.wipo.int/wipolex/en/text/295578
- Türkiye FSEK WIPO kaydı: https://www.wipo.int/wipolex/en/legislation/details/22507
- Romanya WIPO kaydı: https://www.wipo.int/wipolex/en/legislation/details/22202

Türkiye uygulanıyorsa incelenen FSEK metninde m.6 çeviri, m.22 çoğaltma, m.25 umuma iletim, m.38 sınırlı şahsi kullanım, m.52 hakların ayrı gösterildiği yazılı tasarruf ve m.80 icracı/fonogram hakları önemlidir. Ücretsiz kamu uygulaması doğrudan şahsi kullanım sayılmaz. Romanya metninde de yapımcının çoğaltma/dağıtma/erişime sunma hakları ayrı ele alınır. Kullanıcının ikameti/yayın ülkesi varsayılmadı.

Güncellik sınırı: erişilebilen WIPO Türkçe derlemesi 2021, Romanya derlemesi 2022 değişikliklerini kapsadığını bildiriyor. Sonraki değişikliklerin eksiksiz teyidi yapılamadı; güncel Mevzuat/EUR-Lex erişimi başarısızdı. Bu metinler avukatın güncel ülke bazlı değerlendirmesinin yerine geçmez. Telif lisansı ile mushaf doğruluk/tasdik süreci de ayrı konulardır; mobil uygulamaya kesin bir kurul zorunluluğu bulunduğu doğrulanmadı.

## 7. Yayın öncesi kapatılacaklar

1. Mevcut yazılı izin belgelerini toplayıp hangi dosya/baskı/kayıt/font ve hakları kapsadığını kontrol et.
2. Meal ve açıklamalar için yetkili hak sahibini ve kesin baskıyı belirle; dijital metin çıkarma/normalizasyon ile offline mağaza dağıtımını açıkça kapsat.
3. Mevcut EveryAyah kayıtlarının izinlerini netleştir veya MP3Quran'ın kendi lisans beyanı kapsamı teyit edilen kayıtları için ayrı kaynak geçişi planla. İcracı/master yetkisi ve ses bölme/yeniden kodlama koşullarını sor.
4. Diyanet verisinin yeniden kullanımı ve Shaikh fontunun özel iznini teyit et; Amasya'nın mevcut gömülü izin metnini koru.
5. MaterialIcons ve tüm son ürün bağımlılıkları için lisans/atıf taşımasını final APK/AAB/IPA/web çıktısında denetle.
6. Bir rights-register tut: kaynak URL, sürüm/hash, hak sahibi/yetkili, lisans/izin belgesi, ticari kullanım, platform/ülke/süre, yeniden barındırma, offline, APK gömme, değişiklik, atıf şartı.
7. Kamusal mağaza/Drive dağıtımı öncesi hedef ülkeleri bilen fikrî mülkiyet avukatına kalan belgeleri kontrol ettir. Hiçbir belge sıfır dava/şikâyet garantisi vermez; amaç izni kanıtlanmış, yönetilebilir risktir.

### Kısa izin talebi taslağı (gönderilmedi)

“Kuran Kitaphanasy adlı uygulamamızda ekli dosya/sürüm/kayıtları kullanmak istiyoruz. Hak sahibi veya yetkili temsilci olduğunuzu ve şu haklara izin verebildiğinizi teyit eder misiniz: dijital çoğaltma, uygulama içinde gösterme/çalma, kendi sunucumuz veya Drive'dan indirmeye sunma, kalıcı çevrimdışı saklama, APK/IPA içinde paketleme ve uygulama mağazalarında dünya çapında dağıtım? Ücretsiz/reklamsız kullanım ile gelecekteki ücret/reklam/bağış senaryolarının şartlarını; gerekli format dönüşümü, ayetlere bölme veya yeniden sıralama sınırlarını; atıf, süre, bölge ve üçüncü taraf izinlerini belirtmenizi rica ederiz. Lütfen izin verilen dosyaları ve hakları yazılı olarak açıkça listeleyin.”

## 8. Kanıt ekleri

Ayrıntılı alt raporlar ve erişim engelleri docs/telif-arastirmasi/ altında:
- ses-kayitlari.md
- metin-fontlar.md
- meal-hukuki-cerceve.md

Araştırmada kullanılabilir web_search aracı bulunmadığından güncel doğrudan HTTP, resmî siteler, dosyaya gömülü lisanslar, yerel ZIP/PDF/APK analizi kullanıldı. Arama motoru doğrulamaları, Diyanet erişim hataları ve arşiv engelleri boşluk olarak korundu; engelli sayfalar okunmuş gibi sunulmadı.
