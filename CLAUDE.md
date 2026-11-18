@AGENTS.md

# Kuran Kitaphanasy — Claude çalışma kuralları

Sahip: Gurbanov Gadam (Türkçe yazışır). Uygulama arayüzü **Türkmençe**. Sahiple
Türkçe konuş; kullanıcıya görünen her metin Türkmençe olmalı (hata mesajları dahil).

## Ürün özeti

Flutter (3.47.7 / Dart 3.13.5) çevrimdışı Kur'an okuyucu: 114 sure, 6236 ayet,
604 okuyucu sayfası (605 kaynak grubu; ilk iki grup birleşik), Arapça (Diyanet
textGroup 4) + Türkmençe meal (sahibin PDF'i), notlar, secde işaretleri, yer imleri.
Ses: MP3Quran kaynaklı tam-sure kayıtları, Google Drive'dan kullanıcı isteğiyle
indirilir, SHA-256 ile doğrulanır, yerelde ayet zamanlamalarıyla çalınır.
Kitaphana'da Hadis kitapları yalnızca "ýakynda" yer tutucusudur.

## Mimari harita

- `lib/main.dart` → `lib/app/app.dart` (tema, Library↔Reader `IndexedStack`, ilk kare erteleme)
- `lib/library/{domain,data,presentation}` — kitap kataloğu, `BookRepository`
- `lib/reader/data/reader_data.dart` — 10 JSON dataset'i yükler, **fail-closed** doğrular, indeksler
- `lib/reader/presentation/reader.dart` + `part` dosyaları (`reader_content`, `reader_bookmarks`,
  `reader_audio`, `../settings/reader_settings_sheet`) — tek büyük `_ReaderState`
- `lib/reader/settings/reader_preferences.dart` — sürümlü tercih şeması, `PreferenceWriter` (debounce)
- `lib/audio/quran_audio_controller.dart` — katalog, indirme, ZIP, doğrulama, oynatma (çok büyük)
- Kök `lib/library.dart`, `lib/reader_data.dart`, `lib/surah_opening.dart` yalnız uyumluluk export'ları
- `tools/` içerik edinme/doğrulama (Python), `tool/` ürün kimliği/ikon/yayın denetimi
- `assets/data/` çalışma verisi, `assets/sources/` dondurulmuş kaynak kanıtları + hash'ler

## Değişmez kurallar (kırma)

1. **Kutsal metin dokunulmazdır.** `assets/data/{verses,translations,footnotes,surah_*}.json`
   ve `assets/sources/` elle düzenlenmez, normalize edilmez, yeniden çevrilmez, meal
   grupları bölünmez. Değişiklik yalnızca `tools/` üreticileriyle ve sahibin açık
   onayıyla yapılır; ardından `python3 tools/check_full_content.py` geçmelidir.
2. **Fail-closed.** Eksik/bozuk veri tahmini içerikle doldurulmaz; Türkmençe hata +
   "Täzeden synanyş" gösterilir. Ses dosyası hash'i tutmuyorsa çalınmaz.
3. Gizlilik: hesap, analitik, reklam, uzaktan font yok. Yeni ağ isteği/SDK/izin
   eklemek `docs/PRIVACY.md`, uygulama içi gizlilik metni ve `tool/release_readiness.py`
   güncellemesi gerektirir — sahibe sor.
4. `~/kurany-kerim-demo` salt okunur referanstır.
5. Push yok, mağaza yüklemesi yok, imza anahtarı üretme/okuma yok.

## İş akışı

- Önce test (davranışı kilitleyen başarısız test → düzeltme). Widget testleri `Key(...)`
  ile bulur; mevcut key'leri yeniden adlandırma.
- Her değişiklikten sonra (ilgili olanlar):
  ```sh
  flutter analyze
  flutter test                      # ~1 dk; tek dosya: flutter test test/x_test.dart
  python3 tool/release_readiness.py # android/ios/web/pubspec kimliği değişince
  python3 tools/check_full_content.py # assets/ veya tools/ değişince
  python3 -m unittest discover -s test -p 'test_*.py'
  ```
- Sonra yalnızca kendi değiştirdiğim dosyalarla yerel commit (`git add <dosyalar>`,
  asla `git add -A`). Başkasının commit edilmemiş işini sessizce commit'leme.
- `reports/`, `artifacts/`, `releases/`, `build/`, `.hermes/` git dışıdır; oraya
  kanıt koyabilirim ama commit'lemem.
- Belgeler: yeni olgu → ilgili `docs/*.md`. Eski sürüme ait belgeyi silmek yerine
  "TARİHSEL" diye işaretle. README'yi gerçek davranışla uyumlu tut.

## Bilinen teknik borç (öncelik sırası; ayrıntı: docs/ENGINEERING_REVIEW.md)

1. Ses denetleyicisi İngilizce hata metinlerini doğrudan kullanıcıya gösteriyor.
2. ZIP indirme tamamen belleğe okunuyor (`readAsBytes` + `entry.content`) → düşük RAM riski.
3. `quran_audio_controller.dart` 1470 satır; artık kullanılmayan `ayah-files-v1` /
   `openingOverride` eski yolu duruyor.
4. Google Drive'ın HTML onay sayfasını kazıyarak indirme kırılgan (kota/format değişimi).
5. CI Python birim testlerinin çoğunu çalıştırmıyor.
6. `mode`/`alignment` string; enum değil. `_ReaderState` çok büyük.
