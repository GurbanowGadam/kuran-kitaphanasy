# Hasaplar (kullanıcı takipleri) ve alt menü

2026-11-22'de eklendi. Uygulama artık alt menüyle üç sekmeye ayrılır:
**Kitaphana · Hasaplar · Sazlamalar**. Okuyucu açıkken alt menü görünmez
(tam ekran okuma korunur). Başka sekmedeyken sistem "geri" tuşu önce Kitaphana'ya döner.

## Takip türleri (`lib/trackers/domain/tracker.dart`)

| Tür (`kind`) | Türkmençe | Davranış | Hazır şablon |
| --- | --- | --- | --- |
| `counter` | Sanagyç | Her basışta `step` kadar artar; isteğe bağlı tur hedefi; "Nola gaýtar" | Tesbih (33) |
| `progress` | Maksada çenli | Hedefe kadar ilerler, hedefte durur | Kitap okamak (300 sahypa), Hatym (604 sahypa) |
| `debt` | Bergi | Birden çok satır; her satır kalan sayıdan geri sayar, başlangıç toplamı `target` | Kaza namazlary (Ertir, Öýle, Ikindi, Agşam, Ýassy, Witr) |
| `habit` | Gündelik endik | Günde bir kez işaretlenir, ardışık gün serisi; son 7 gün düzeltilebilir | Gündelik endik |

"Öz hasabyň" ile kullanıcı türü kendisi seçer. Oluşturulduktan sonra tür değişmez; ad,
birim, hedef, adım ve satırlar düzenlenebilir. Kaza şablonunda "Ýyl (365 gün) + Gün"
yardımcı alanı her satıra aynı sayıyı yazar (yaklaşık hesap; satırlar elle düzeltilebilir).

`days` haritası gün başına olumlu etkinliği tutar (okunan sayfa, kaza edilen namaz,
tesbih sayısı, alışkanlık için 1). "Bu gün" ve seri buradan hesaplanır. Düzeltmeler
(yza al / aýyr) hem değeri hem o günün kaydını geri alır.

## Depolama ve fail-closed

- Anahtar: SharedPreferences `kuran_kitaphanasy.trackers`, JSON zarfı
  `{"format": "kuran-kitaphanasy-hasaplar", "version": 1, "trackers": [...]}`.
  **Anahtar ve `format` değişmemeli**; şema değişirse `version` artırılıp göç yazılır.
- `decodeTrackers` katıdır: bilinmeyen tür, aralık dışı sayı, hedefi aşan değer,
  tekrarlanan kimlik, geçersiz gün anahtarı → `FormatException`.
- Okuma hatasında `TrackerBook` salt okunur kalır: kayıt **üzerine yazılmaz**,
  Türkmençe hata + "Täzeden synanyş" gösterilir. (Okuyucu tercih deposu hatayı
  "kayıt yok" diye yuttuğu için ayrı `TrackerStore` kullanılır.)
- Hızlı dokunuşlar (tesbih) sıralı, birleştirilmiş tam-liste yazımlarıyla kaydedilir.
- Hasaplar sekmesi ilk açılana kadar depolama okunmaz (başlangıç beklemez);
  Sazlamalar'daki yedekleme gerekirse yüklemeyi kendisi başlatır.

## Yedekleme (Sazlamalar)

"Hasaplary göçür" JSON'u sistem panosuna kopyalar; "Hasaplary dikelt" yapıştırılan
metni aynı katı çözücüyle doğrular, onay sonrası tüm listeyi değiştirir. Geçersiz
metin hiçbir şeyi değiştirmez. Dosya paylaşımı/seçici bilinçli olarak yok: yeni
eklenti (share_plus/file_picker) gizlilik kuralı gereği sahibin onayını gerektirir.

## Sazlamalar sekmesi

Garaňky görnüş (eski kütüphane tema düğmesinin yeni yeri, aynı `_library` tercihi),
Ýüklenen sesler (diskte bulunan tam-sure kayıtları, boyut, silme; silinen kayıt
çalıyorsa önce durdurulur; çalmadan önce SHA-256 doğrulaması her zamanki gibi sürer),
Hasaplary göçür/dikelt ve "Çeşmeler we programma barada" (`source-about`).
Okuyucu ile Sazlamalar aynı `QuranAudioController` örneğini paylaşır.

## Bildirim

Hatırlatma bildirimi yok (sahip kararı, 2026-11-22): izin + eklenti + gizlilik
güncellemesi gerektirdiği için ayrı adım olarak bekliyor.
