# Kuran Kitaphanasy — Arapça metin ve font hakları araştırması

Araştırma tarihi: 15 Kasım 2026. Kapsam: `/home/gadamgurban/kuran-kitaphanasy`; uygulama koduna müdahale edilmedi. Bu teknik kaynak/lisans incelemesidir, hukukî görüş veya Diyanet onayı değildir.

## Kısa sonuç

- **Önemli yeni kanıt:** `KuranIsaretler.ttf` dosyasının gerçek adı **Amasya Regular 3.009**. Gömülü nameID 13, fontun ücretli/ücretsiz yazılım içinde dağıtımına açıkça izin veriyor. Dolayısıyla bu font için “hiç lisans yok / kesin yasak” demek yanlış olur. Bu, Diyanet'in bütün varlıklarını kapsayan genel lisans değil, Muhammet Abay adına font dosyasında bulunan özel izin metnidir.
- `ShaikhHamdullahMushaf.ttf` ayrı bir fonttur; telif sahibi yine Muhammet Abay, ancak bu dosyada lisans açıklaması/URL'si yok. Birinci fontun izni buna kendiliğinden uygulanamaz. Uygulama bunu `DiyanetMarkers` olarak gerçekten paketler/kullanır.
- Diyanet `metin_grubu_id=4` için çevrimdışı paketleme/mağaza yeniden dağıtımını açıkça kapsayan genel kamu lisansı **bu araştırmada doğrulanamadı**. Kamuya açık API, yeniden dağıtım izni değildir. “Lisans yoktur” veya “mutlaka yasaktır” sonucu da çıkarılamaz.
- Noto Serif OFL belgesi ve MaterialIcons Apache belgesi resmî kaynaklarla byte düzeyinde eşleşti. Noto lisansı APK içinde var; MaterialIcons özel lisans dosyası APK'ya asset olarak eklenmemiş. Genel NOTICES içinde Apache bulunması tek başına MaterialIcons'a özgü kapsamı kanıtlamıyor.

## 1. Yerel uygulama bağlamı ve kanıt zinciri

Okunanlar: README.md (özellikle 77–96), pubspec.yaml, lib/main.dart, lib/library/presentation/library_page.dart, okuyucu font referansları, docs/V1_RELEASE_STATUS.md, docs/RELEASE_CHECKLIST.md, assets/branding/README.md, glyph-provenance.json, tools/capture_diyanet_reading.py ve font raporları.

README 92–96: “Sahibi, kaynakları doğruladığını ve gerekli yayın/yeniden dağıtım izinlerini sağladığını beyan etmiştir.” Hemen ardından bunun bağımsız hukukî onay/lisans olmadığı yazıyor. Bu beyan, burada görülmüş bir izin mektubu sayılmaz. Release checklist izin belgelerinin saklanmasını ayrıca ister.

Resmî metin kökü: https://kuran.diyanet.gov.tr/
Yerel yakalama aracında gerçek uç nokta örneği: https://kuran.diyanet.gov.tr/api/v2/sayfa/0?font_id=173
Araç `metin_grubu_id == 4` seçer. README 114 sure/6236 ayet ve dondurulmuş yanıt/hash zincirini tarif eder. Bu çalışmada tüm Kur'an veri bütünlüğü yeniden test edilmedi; hak incelemesi için kaynak sözleşmesi okundu.

`pubspec.yaml`: DiyanetAmasya → assets/fonts/KuranIsaretler.ttf; DiyanetMarkers → assets/fonts/ShaikhHamdullahMushaf.ttf. Sonuncusu yalnız “eski bir dosya” diye lisans kapsamından çıkarılamaz: reader_content.dart işaretlerde DiyanetMarkers kullanır ve APK FontManifest her ikisini içerir.

## 2. Gerçek font name tabloları

Sistemde mevcut fontTools ile doğrudan TTF/OTF açıldı; kurulum yapılmadı. Aşağıdaki kayıtlar dosya adından tahmin değil, name tablosu çıktısıdır. Tekrarlanan platform kayıtları tekilleştirilmiştir.

### assets/fonts/KuranIsaretler.ttf

- ID 0: `Copyright (c) 2009-2026 by Muhammet Abay. All rights reserved.`
- ID 1: `Amasya`
- ID 2: `Regular`
- ID 4: `Amasya Regular`
- ID 5: `Version 3.009`
- ID 6: `Amasya-Regular`
- ID 8 ve 9: `Muhammet Abay`
- ID 13 tam metin:

> This font is the property of Muhammet Abay. You may not reproduce or modify it without the express written permission of Muhammet Abay. You are allowed to use this font to display and print content. You may only (i) embed this font in content as permitted by the embedding restrictions included with the font; and (ii) distribute this font free of charge. However, you may distribute this font as part of paid or free software.

- ID 14 lisans URL'si bulunmadı.
- OS/2.fsType = 0.

Yorum: Son cümle yazılım içinde ücretli/ücretsiz dağıtıma somut izin kanıtıdır. İlk cümlenin çoğaltma/değiştirme kısıtlamasıyla birlikte bütün olarak korunmalı; değiştirme, format dönüştürme/subset oluşturma ve fontun tek başına satılması için sınırsız izin diye okunmamalı. Teknik embedding bayrağının 0 olması bu metni destekler ama tek başına hukukî lisans değildir. Resmî hak sahibinden gerekiyorsa uygulama/mağaza/web/subset kapsamını yazılı netleştirmek ihtiyatlıdır.

### assets/fonts/ShaikhHamdullahMushaf.ttf

- ID 0: `Copyright (c) 2011 by Muhammet Abay. All rights reserved.`
- ID 1 ve 4: `Shaikh Hamdullah Mushaf`
- ID 2: `Regular`
- ID 5: `Version 1.003 2011`
- ID 6: `ShaikhHamdullahMushaf`
- ID 8 ve 9: `Muhammet Abay`
- ID 13/14: bulunmadı.
- OS/2.fsType = 0.

Sonuç: Teknik gömme izni bayrağı var, fakat genel yeniden dağıtım sözleşmesi dosyada yok. Amasya izin metninin bu eski/başka fontu kapsadığı varsayılamaz. Sahibin mevcut yazılı izni kontrol edilmeli veya font özelinde izin istenmeli.

### assets/fonts/NotoSerif-Regular.ttf / NotoSerif-Bold.ttf

- ID 0: `Copyright 2022 The Noto Project Authors (https://github.com/notofonts/latin-greek-cyrillic)`
- ID 1: `Noto Serif`; ID 2: `Regular` / `Bold`
- ID 4: `Noto Serif Regular` / `Noto Serif Bold`
- ID 5: `Version 2.015`
- ID 6: `NotoSerif-Regular` / `NotoSerif-Bold`
- ID 8: `Monotype Imaging Inc.`; ID 9: `Monotype Design Team`
- ID 11: `http://www.google.com/get/noto/`
- ID 13: `This Font Software is licensed under the SIL Open Font License, Version 1.1. This license is available with a FAQ at: https://openfontlicense.org`
- ID 14: `https://openfontlicense.org`
- OS/2.fsType = 0.

### APK içindeki MaterialIcons-Regular.otf

- ID 0: `Copyright 2019 Google LLC. All Rights Reserved.`
- ID 1: `Material Icons`; ID 4: `MaterialIcons-Regular`.
- ID 13/14 bulunmadı. Bu nedenle upstream lisansı ayrı doğrulandı.
- SHA-256: `d9865b671a09d683d13a863089d8825e0f61a37696ce5d7d448bc8023aa62453`.
- Bu hash assets/branding/glyph-provenance.json ile eşleşir. Ürün ikonu `Icons.auto_stories_outlined`, U+EEAF; font outline'ından türetilmiş. Apache yalnız uygulama içi font için değil dağıtılan türev ikon varlığı için de dikkate alınmalı.

## 3. Resmî çevrimiçi kaynaklar / erişim durumu

Aşağıdaki durumlar gerçek ağ denemelerine dayanır; erişim hatası yokluk kanıtı değildir.

1. https://raw.githubusercontent.com/notofonts/latin-greek-cyrillic/main/OFL.txt — HTTP 200, 4396 byte. Yerel `assets/fonts/NotoSerif-OFL.txt` ile byte düzeyinde aynı.
2. https://raw.githubusercontent.com/google/fonts/main/ofl/notoserif/OFL.txt — HTTP 200, 4396 byte; resmî Google Fonts aynasından da alındı.
3. https://raw.githubusercontent.com/google/material-design-icons/master/LICENSE — HTTP 200, 11357 byte. Yerel `assets/branding/MaterialIcons-LICENSE.txt` ile byte düzeyinde aynı; Apache License Version 2.0, January 2004.
4. https://tanzil.net/docs/text_license — HTTP 200; koşullar aşağıda.
5. https://kuran.diyanet.gov.tr/ — bağlantı karşı uçça sıfırlandı (`Connection reset by peer`). Güncel genel kullanım şartları alınamadı.
6. https://yayin.diyanet.gov.tr/ — bağlantı karşı uçça sıfırlandı. İzin/iletişim sayfası alınamadı.
7. Google resmî-domain aramaları: `site:diyanet.gov.tr yayınlar izin alıntı telif` ve `site:diyanet.gov.tr "font" "lisans"`; HTTP 200 yanıtları arama sonuçları değil yönlendirme kabuğuydu. Browser ile arama CAPTCHA/olağandışı trafik engeline düştü; içerik kanıtı kabul edilmedi.
8. Alternatif arama/resmî iletişim/mushaf sayfası sorgusu araç tarafından kullanıcı onayı reddiyle engellendi; aynı işlemi başka yolla tekrar denemedim. Bu nedenle güncel resmî iletişim adresi ve şartlardan kesin alıntı sağlanamadı.

### Diyanet izinleri ve iletişim için doğrulanmamış kalanlar

Bu oturumda resmî Diyanet metin lisansı, “yalnız kaynak göstermek yeterlidir” hükmü veya “her durumda önceden onay şarttır” hükmü doğrulanmadı. Böyle bir hüküm varmış gibi alıntı yapılmamalı. API erişiminden CC/OFL benzeri izin çıkarılamaz. Klasik Kur'an metninin statüsü, modern dijital veri seti, tipografi/font yazılımı, düzenleme ve meal haklarıyla aynı değildir.

İzin yazışması için kurumun resmî yayın portalı https://yayin.diyanet.gov.tr/ ve Diyanet'in resmî ana alanı https://www.diyanet.gov.tr/ üzerinden Dini Yayınlar Genel Müdürlüğü/yayın hakları birimine yönlendirme istenmesi önerilir; bu bir iletişim rotası önerisidir, doğrulanmış e-posta/telefon değildir. **Güncel resmî e-posta/telefon teyit edilemedi; tahminî adres verilmemiştir.** Fontta adı geçen hak sahibi Muhammet Abay'dır; Diyanet'in bu hak sahibinden hangi yetkiye sahip olduğu ayrıca sorulmalıdır.

Talepte uygulama kimliği, metin grubu 4, font dosya adları/gerçek adları/sürümleri/hash'leri, tam metin-fontun APK/IPA/web içinde çevrimdışı dağıtımı, ücretsiz/ücretli kullanım, mağaza/bölgeler, veri biçimi dönüşümü, font altkümeleme ve istenen atıf metni açıkça belirtilmeli. Mevcut sahibin izin belgesi varsa önce onun kapsamı incelenmeli; yeniden başvuru gerektiği varsayılmamalı.

**Telif izni ≠ mushaf doğrulama/inceleme onayı.** Lisans metni/font dağıtma hakkı, metnin dinî doğruluğunu veya basım/elektronik yayına dair bir kurul tasdikini vermez. Tersine metin doğrulaması/tasdik de font yazılımının telif lisansı değildir. Mushafları inceleme/kıraat konusunda yetkili kurumsal birimden uygulama tipinin hangi inceleme sürecine tabi olduğu ayrıca sorulmalı. Bu oturumda güncel mevzuat/başvuru sayfası doğrulanamadığından mobil uygulama için kesin zorunluluk veya muafiyet iddiası yoktur.

## 4. OFL ve Apache koşulları; gerçek APK bildirimi

OFL resmî/yerel ortak metin:

> The fonts, including any derivative works, can be bundled, embedded, redistributed and/or sold with any software ...

OFL; fontu tek başına satmama, telif/lisansı birlikte sağlama, türevler için reserved font name kurallarına uyma ve font türevlerini OFL altında tutma gibi koşullar içerir. Uygulamanın tüm kodunu OFL yapmaz.

İncelenen somut APK: `build/app/outputs/flutter-apk/app-debug.apk` (release/AAB incelemesi değildir).

- `assets/flutter_assets/assets/fonts/NotoSerif-OFL.txt` mevcut ve depodaki/resmî belgenin byte aynısı.
- lib/main.dart bunu `LicenseRegistry.addLicense` ile `Noto Serif` adı altında çalışma anında ekler. Bu nedenle derleme anında oluşturulmuş NOTICES.Z içinde Noto olmaması otomatik uyumsuzluk değildir.
- APK içindeki NOTICES.Z gzip biçiminde açıldı; düz metin `/tmp/quran-apk-notices.txt` olarak çıkarıldı. İlk zlib denemesi biçim hatası verdi; gzip ile başarıyla çözüldü.
- NOTICES.Z içinde `Noto Serif`, `SIL OPEN FONT LICENSE`, `Amasya`, `Diyanet`, `Shaikh`, `Material Icons`, `MaterialIcons`, `material-design-icons` bulunmadı. Genel `Apache License` ve çeşitli Google telifleri bulunur; bunlar başka bağımlılıklara da aittir, MaterialIcons kapsamı varsayılamaz.
- `assets/branding/MaterialIcons-LICENSE.txt` pubspec assets listesinde değil; APK'da adına uyan bağımsız MaterialIcons lisans belgesi bulunmadı. Depoda mevcut olması son kullanıcı dağıtımında bulunduğu anlamına gelmez.
- Apache 2.0 bölüm 4, lisans kopyasının alıcıya verilmesini; değiştirilen dosyalarda değişiklik notlarını; uygulanabilir telif/atıfların korunmasını ve upstream NOTICE varsa ona uygun taşımayı gerektirir. Ayrı NOTICE dosyası her projede zorunluymuş gibi okunmamalı. Mevcut genel NOTICES'ın tam MaterialIcons uyumluluğunu sağladığı **kanıtlanmadı**; bir özel MaterialIcons lisans/atıf kaydını paketleyip lisans ekranına dahil etmek daha izlenebilir bir kapatma adımıdır.
- Amasya gömülü name lisansı TTF ile birlikte zaten taşınır; bunun kullanıcıya okunabilir kaynak/lisans açıklamasında ayrıca sunulması izlenebilirliği artırır. Shaikh için ek izin kanıtı hâlâ gerekir. Uygulamanın mevcut kaynak ekranında Noto lisansı belirtilirken Amasya'nın özel izin metni ve Shaikh'in ayrı durumu açıklanmıyor.

Kontrol hash'leri:
- NotoSerif-OFL.txt SHA-256 `cee9892f9f0cc8fe882c9e9537ee6a89621d86ee7ceaf70b02e2b2b1c25c061a`.
- MaterialIcons-LICENSE.txt SHA-256 `58d1e17ffe5109a7ae296caafcadfdbe6a7d176f0bc4ab01e12a689b0499d8bd`.

## 5. Tanzil: yalnız koşullu alternatif

Resmî sayfa https://tanzil.net/docs/text_license kendisini `Creative Commons Attribution 3.0` olarak etiketler ve ayrıca açık kullanım şartlarını yazar:

> Permission is granted to copy and distribute verbatim copies of this text, but CHANGING IT IS NOT ALLOWED.

> This Quran text can be used in any website or application, provided that its source (Tanzil Project) is clearly indicated, and a link is made to tanzil.net to enable users to keep track of changes.

> This copyright notice shall be included in all verbatim copies of the text, and shall be reproduced appropriately in all files derived from or containing substantial portion of this text.

Başlık: `Tanzil Quran Text`; telif `Copyright (C) 2007-2021 Tanzil Project`. Lisans etiketi tek başına alınıp sayfanın “değiştirmeyin”, atıf, bağlantı ve bildirimi taşıma koşulları atlanmamalı. Metin lisansı font/meal/ses için otomatik izin değildir.

Bu uygulamanın mevcut kabul sözleşmesi Diyanet metin grubu 4/Amasya ortografisidir. Tanzil metni, generic Uthmani veya farklı işaret dizisi aynı veri sayılmaz. Tanzil ancak sahibin açık kabulü, somut metin varyantının belirlenmesi, tüm Unicode/ayet-besmele-sayfa/işaret sözleşmesi ve font şekillendirme testlerinin yeniden onayı ile alternatif olabilir. **Sessiz değiştirme, işaret silme veya Diyanet yazımına benzetmek için Tanzil metnini değiştirme önerilmez.** Bu çalışmada hiçbir kaynak/font değiştirilmedi.

## Öncelikli takip

1. Mevcut owner izin belgelerinde Diyanet veri paketinin ve özellikle Shaikh Hamdullah Mushaf'ın kapsamını teyit edin.
2. Amasya nameID 13'ü aynen koruyun; dağıtım izni bulunduğu bulgusunu kaydedin, bunu OFL veya Diyanet genel lisansı diye adlandırmayın.
3. Diyanet resmî kullanım/atıf/ön onay ve güncel resmî iletişim bilgisi erişim engeli nedeniyle açık kalan araştırma kalemidir; doğrulanmış belge olmadan kesin hüküm vermeyin.
4. MaterialIcons'a özgü lisans/atıf taşımasını son kullanıcı APK/AAB/IPA/web çıktısında açıkça doğrulayın; Noto'nun mevcut çalışma-anı lisans kaydını koruyun.
5. Telif iznini mushaf doğruluğu/kurul incelemesiyle karıştırmayın. Bu rapor mağaza veya kurum onayı vermez.
