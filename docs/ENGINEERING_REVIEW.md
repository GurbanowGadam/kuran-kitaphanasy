# Mühendislik değerlendirmesi — 2026-11-18

Codex/Hermes ile geliştirilen kod tabanının devralma incelemesi. Bundan sonraki
çalışmanın öncelik listesidir; tamamlanan maddeler işaretlenerek güncellenir.

## Genel tablo

| Alan | Değerlendirme |
|---|---|
| Veri bütünlüğü | **Çok iyi.** `ReaderData.fromDocuments` sıra, çakışma, kapsam, not bağlantısı ve secde kaynağını doğrular; başarısızlıkta tahmini metin gösterilmez. Kaynaklar SHA-256 ile dondurulmuş. |
| Test | **Güçlü.** 323 Flutter testi geçiyor (12 atlanmış), `flutter analyze` temiz + Python içerik/font/ortografi testleri. Testler bazen davranış yerine uygulama ayrıntısına (sabit metin, sürüm dizesi) bağlı. |
| Mimari | **Orta.** Katman klasörleri doğru; fakat iki "tanrı nesnesi" var: `_ReaderState` (~2.500 satır, `part` + extension) ve `QuranAudioController` (1.470 satır). Durum yönetimi yok, string tabanlı modlar. |
| Ses | **Doğru ama riskli.** Hash doğrulama, iptal, nesil sayaçları özenli. Bellek kullanımı, Drive bağımlılığı ve İngilizce hata metinleri sorunlu. |
| Güvenlik/gizlilik | **İyi.** Cleartext kapalı, yedekleme kapalı, ZIP girişleri beyaz listeli, boyut sınırları, imza fail-closed. |
| Belgeler | **Fazla ve dağınık.** Kökte 4 ayrı md + 11 docs; README güncel davranışla çelişiyor (INTERNET izni). |
| CI | **İyi temel.** Ancak Python birim testlerinin çoğu CI'da koşmuyor. |

## Bulgular ve öneriler (öncelik sırası)

### P1 — Kullanıcıya İngilizce hata metni — ✅ ÇÖZÜLDÜ (2026-11-18)
`QuranAudioController._error` (`'Download failed: $e'`, `'Playback failed: $e'`,
`'Audio initialization failed'`, `'Invalid verse'` …) ses panelinde doğrudan
gösteriliyor; ham exception metni de ekleniyor. Türkmençe arayüz kuralını ihlal eder.
**Öneri:** Denetleyici `AudioError` enum'u yayınlasın; panel bunu Türkmençe metne
çevirsin; teknik ayrıntı yalnız `debugPrint`'e gitsin.

### P1 — İndirmede bellek tepe noktası — ✅ ÇÖZÜLDÜ (2026-11-18, akışlı kurulum)
`_download` tüm `.part` dosyasını `readAsBytes()` ile belleğe alıp `ZipDecoder`
ile çözüyor, sonra `entry.content` ile ikinci kopya oluşuyor. Uzun surelerde
(ör. Bakara, onlarca MB) düşük RAM'li cihazlarda OOM riski.
**Öneri:** `InputFileStream` + `ZipDecoder().decodeStream` ve dosyaya akışla yazma;
hash'i yazarken hesapla. Mümkünse ZIP'i tamamen kaldırıp tek MP3 + hash indir.

### P2 — Google Drive bağımlılığı
HTML onay formunu regex ile kazımak; kota, Google arayüz değişikliği veya virüs
taraması uyarısıyla kırılabilir. 570 paket herkese açık Drive'da.
**Öneri:** Sabit HTTPS dosya barındırma (GitHub Releases, Cloudflare R2 vb.).
Hak/izin kapsamı sahibin kararıdır.

### P2 — Ses denetleyicisinin bölünmesi ve eski kod — ✅ ÇÖZÜLDÜ (2026-11-18)
Katalogdaki 570 paketin tamamı `full-surah-timed-v1`; `ayah-files-v1`,
`openingOverride`, `_advance`, `_loadedPath` yolu yalnız eski testler için duruyor.
**Öneri:** `AudioCatalog` (model+doğrulama), `AudioDownloader` (indirme+depolama),
`AudioPlayerService` (kuyruk/oynatma) olarak ayır; eski yolu testleriyle birlikte kaldır.

### P2 — Okuyucu durumu
`_ReaderState` tema, kalıcılık, sayfalama, yer imleri, ses takibi ve sheet'leri tek
sınıfta tutuyor. `mode`/`alignment` string. **Öneri:** `ReadingMode` enum'u,
yer imleri ve ses-takibi için ayrı `ChangeNotifier`'lar; adım adım, testler yeşilken.

### P3 — CI kapsamı
CI yalnız `content_editorial_review.py` çalıştırıyor. `test/test_*.py`,
`tools/tests/`, font/ortografi testleri koşmuyor. **Öneri:** bağımlılığı olmayanları
CI'a ekle; `fonttools`/`uharfbuzz` gerektirenleri ayrı iş olarak.

### P3 — Depo düzeni — ✅ ÇÖZÜLDÜ (2026-11-18: `tools/release`, `tools/legacy`, belgeler `docs/`)
- `tool/` ve `tools/` iki ayrı klasör — kafa karıştırıcı.
- Kökteki `OKUYUCU_KURALLARI.md`, `AUDIO_OPENING_CORRECTION.md`, `SURE_ADLARI.txt`
  `docs/` altına taşınmalı; `AUDIO_OPENING_CORRECTION.md` artık eski (Abu Bakr
  ayah-files kataloğu kalmadı).
- `kurany_kerim_demo.iml` artığı (git dışı).
- README "release manifestinde INTERNET yok" diyor; ses indirme için artık var.

### P3 — Lint
`analysis_options.yaml` yalnız varsayılan `flutter_lints`. `prefer_final_locals`,
`unawaited_futures`, `avoid_dynamic_calls` gibi kuralların kademeli eklenmesi faydalı.

## Güçlü yönler (korunmalı)

- Fail-closed içerik yükleme ve isolate'te (`compute`) çözme.
- Enjekte edilebilir `BookRepository`, `ReaderStore`, ses fabrikaları → test edilebilirlik.
- Ses tarafında nesil sayaçlarıyla yarış durumu koruması, atomik `staging → rename`.
- İlk kare erteleme ile native açılış kitabından kesintisiz geçiş.
- Kaynak kanıtlarının hash'lenmiş arşivi ve yeniden üretilebilirlik araçları.
- İmzasız release'in debug anahtarıyla gizlice imzalanmaması.

## Açık iş (devralındığı anda)

Hermes'in "Play hazırlığı" (`.hermes/plans/2026-11-17_223344-play-preparation.md`)
commit edilmemiş halde: sürüm `1.0.0+3`, uygulama içi gizlilik metni, `release_readiness.py`
INTERNET kuralı, `docs/play-store/`. Sahip bilgileri (yayıncı, e-posta, gizlilik URL'si,
upload anahtarı) beklemede.
