# Kuran Kitaphanasy 1.0.0

İlk ürün sürümü: tam çevrimdışı Kur'an ve Türkmençe meal.

## Eklenen / üretime taşınan
- Tam 114 sure ve 6236 ayet; onaylı Türkmençe isimler, meal grupları, açıklamalar.
- İlk iki kaynak grubunun birleşimiyle 604 okuyucu sayfası.
- Uygulama/kitap kataloğu/okuyucu/veri/ayar katmanları ayrıldı.
- Tam kitap için tembel dikey okuma ve sınırlı konum önbelleği.
- Kitap bazlı kalıcı okuma durumu ve ayrı kalıcı kütüphane teması.
- Onaylı demo tasarımı, dipnot satır aralığı, font örnekleri ve tam ekran davranışı korundu.
- Kuran Kitaphanasy adı, onaylı kitap simgesi, Android ve iOS kimlikleri.
- Yerel kaynak/font lisans bilgisi ve gizlilik açıklaması.
- Deterministik tam içerik üretimi, kaynak/karakter korunumu ve font testleri.
- CI tanımı, owner kontrollü release imzalama, yayın kontrol belgeleri.

## Secde işaretleri
- Resmî Diyanet işaretçi kaynağına bağlı 14 secde konumu, ham/çözülmüş kaynak ve SHA-256 doğrulamasıyla eklendi.
- Ayetin hemen üstünde sağa hizalı küçük bilgi simgesi ve `(Sežde aýaty)` etiketi; üç okuma modu ve iki tema desteklenir. Gruplu meal ve kanonik metinler değişmedi.
- Kaynak politikası ve konum listesi: `docs/SAJDAH_MARKERS.md`.

## Son düzenleme
- Sure seçicisinde başlık/kapatma ve arama bölgesi, temaya uygun daha koyu sabit bant ve alt ayırıcıyla ayrıldı.
- Yalnız Türkmençe sure adlarında anlık arama, sade harf eşleme, temizleme ve boş sonuç durumu eklendi; ayet/meal metni veya metaveri aranmaz. Klavye açıkken liste ve kapatma kontrolü görünür kalır.

## Önceki düzenleme
- Sure listesi: Mekge/Medine simgeleri, numaralı Türkmençe ad, yer/ayet bilgisi ve gerçek başlangıç sayfası rozeti. Cüz veya arama alanı eklenmedi; açık/koyu tema, 320px ve büyütülmüş yazı testleri mevcut.

## Yayın durumu
Android test APK'sı üretildi ve cihazda çalıştırıldı. Release AAB üretildi ama sahibin imza anahtarı olmadığı için imzasızdır. iOS native proje hazır; macOS/Xcode derlemesi ve Apple signing yapılmadı. Mağazaya yükleme/yayın yapılmadı. Naziat 79:40–41 kaynak etiket eşlemesi ürün sahibi tarafından başka kaynaklarla karşılaştırılarak onaylandı; kayıt PDF/paragraf hash’lerine bağlıdır.

Ayrıntılı rapor: docs/V1_RELEASE_STATUS.md.
