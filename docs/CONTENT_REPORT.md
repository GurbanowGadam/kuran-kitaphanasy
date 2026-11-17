# Kuran Kitaphanasy — içerik doğrulama raporu

## Kapsam ve kaynak seçimi

- İlk sürüm: çevrimdışı Kur'an + Türkmençe meal. Türkmençe sure adları PDF'den alınır; Latin harfli Arapça telaffuz listesi gösterim adı olarak kullanılmaz.
- Arapça: resmî Diyanet kamu API'sindeki `metin_grubu_id=4`, normalizasyon veya işaret silme yok. 605 ham cevap ve çözümlenmiş karşılıkları SHA-256 ile saklanır; kamu istemcisinin taşıma çözümü çevrimdışı tekrar uygulanarak doğrulanır.
- Türkmençe: `/home/gadamgurban/Documents/kurany_kerim_turkmen_dilinde.pdf`. Önsöz eserin Türkmenistanyň Müftüsiniň müdiriýeti tarafından hazırlandığını bildirir. Uygulama kaynak künyesinde bu bilgi kullanılır.
- Kaynak ve font izinlerinin tamamlandığı ürün sahibi tarafından beyan edildi. Bu beyan bağımsız hukuk/lisans denetimi yapıldığı anlamına gelmez; izin belgeleri sahibi tarafından saklanmalıdır.

## Gerçek içerik sayıları

| İçerik | Sayı |
|---|---:|
| Sure | 114 |
| Arapça ayet | 6236 |
| Kaynak mushaf sayfa grubu | 605 |
| Uygulama okuma sayfası | 604 |
| Türkmençe meal paragraf/grubu | 5905 |
| Bağlantılı açıklama notu | 203 |
| Sure giriş açıklaması | 114 |

Uygulamada ilk iki kaynak grup birleştirilir: Fatiha 1–7 ve Bakara 1–5 okuyucu sayfası 1'dir. İkinci okuyucu sayfası Bakara 6 ile başlar. Kaynak fiziksel sayfa, basılı sayfa ve okuyucu sırası birbirinin yerine yazılmaz. Kaynakta gruplanmış meal paragrafı kesilmez; sayfa sınırını geçen grup ilgili sayfalarda bütün olarak gösterilir.

## Doğrulama yöntemleri

1. Tam ayet ve meal kapsamı: her kaynak ayet sıralı, tekil ve bir meal grubuyla eşlenmiş; boş/eksik/tekrarlı ayet, çakışan grup ve bozuk not bağlantısı reddedilir.
2. Tam Arapça metin: 605 dondurulmuş resmî cevabın ham/çözümlenmiş hash ve taşıma çözümü karşılaştırması; 6236 metin birebir aynı.
3. Mushaf dağılımı: Arapça PDF'nin 605 okuma sayfasındaki ayet sonu CID numaraları resmî ayet üyelikleriyle karşılaştırıldı; 0 uyuşmazlık. Bu, PDF Arapça gliflerinin tümünün Unicode'a çözüldüğü iddiası değildir.
4. Türkmen PDF: bağımsız Poppler bounding-box çıkarımıyla dondurulmuş PyMuPDF metni 1210 sütunda karşılaştırıldı; yalnız boşluklar yok sayıldığında 0 uyuşmazlık. Eski sabit `-H 742` kontrolü 30 sütunda alttaki gövde satırlarını kesiyordu. Eksik sanılan satırların geometrisi ve metni raporda korunur; kaynak metin bu hatalı kontrolü geçmek için değiştirilmedi.
5. Metin korunumu: 114 surenin başlığı, girişi, kaynak numaraları, meal ve açıklamaları kaynağa karşı karakter bazında yeniden birleştirildi. Belgelenen boşluk/satır-sonu tire işlemleri dışında kelime, yazım veya noktalama değişikliği yoktur.
6. Onaylı demo gerileme kontrolü: ilk 76 Arapça ayet/meal, ilk 10 kaynak sayfa/not ve ilk 2 açıklama mevcut alan değerleriyle birebir korunur. Yeni konum/provenans alanları eski metni değiştirmez. Taşınabilir onaylı örnek `test/fixtures/approved_demo_content.json`.
7. Font: 6236 tam ayet koşusu, 114 Arapça sure başlığı ve süslü ayet numaraları birincil DiyanetAmasya cmap/HarfBuzz testlerinden geçer; .notdef glif yok. Noto Serif regular/bold Türkmençe metin karakterlerini kapsar. Bu testler bütün cihazlarda hareke yerleşimi veya görsel doğruluk garantisi değildir.
8. İki çevrimdışı yeniden üretim: takip edilen 21 ürün artefaktı (manifest dahil) byte düzeyinde aynı; rapor `full-content-reproducibility.json`.

## Kaynak anomalisi / son editoryal inceleme

Naziat 79:41 için PDF'de ayrı 41 etiketi basılmamıştır: `40.` paragrafından sonra `42.` gelir. Kaynak paragrafının sözcükleri değiştirilmeden 40–41 grubu olarak bağlandı. Ürün sahibi 2026-11-13 tarihinde başka kaynaklarla karşılaştırdığını ve PDF’de yalnız 41 etiketinin unutulduğunu doğruladı. Eşleme onayı `editorial-approvals.json` içinde PDF ve paragraf SHA-256 değerlerine bağlı olarak saklanır; başka kaynakların URL’leri verilmediğinden bağımsız editör doğrulaması iddia edilmez. Anomali kaydı korunur, bu özel eşlemenin bekleyen onay kapısı kaldırılmıştır. Diğer virgüllü gruplar, ara numarası basılmayan aralıklar ve ayet numarası gibi görünen alıntılar da raporda açıklanır.

## Çalıştırma

```
python3 tools/check_full_content.py
python3 test/content_full_dataset.py
python3 test/content_verification_regression.py
# fonttools + uharfbuzz kurulu venv:
python3 -m unittest discover -s test -p '*_test.py'
# Orijinal PDF + Poppler ile yeniden bağımsız çıkarım:
python3 tools/check_full_content.py --pdf-extraction
# Yeniden üretim bağımlılıkları ve orijinal PDF gerektirir:
python3 tools/verify_full_reproducibility.py
```

Eski demo araçlarını doğrudan tam veri üzerine çalıştırmayın. `tools/check_reading_data.py` artık tam ürün kontrolüne yönlendirir; eski 10 sayfalık manifest tarihsel karşılaştırma içindir.
