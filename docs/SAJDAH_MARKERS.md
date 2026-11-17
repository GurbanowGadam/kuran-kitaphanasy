# Secde işaretleri

## Kaynak ve işaretleme politikası

Uygulama, Diyanet Kur’an portalının olağan herkese açık işaretçi verisindeki
`tip == "Secde"` kayıtlarını kullanır:
https://kuran.diyanet.gov.tr/api/v2/isaretciler
Okuyucu: https://kuran.diyanet.gov.tr/kuran

Ham yanıt ve çözülmüş JSON `assets/sources/diyanet-reading/isaretciler-*.json`
altında dondurulmuştur. `tools/build_sajdah_markers.py` mevcut halka açık
istemci çözümleyicisiyle ham/çözülmüş eşleşmesini ve kaynak sayfa üyeliğini
kontrol ederek `assets/data/sajdah_markers.json` üretir. Dosyalar tam içerik
manifestinin SHA-256 kapsamındadır; yeniden üretim ağ erişimi gerektirmez.

Bu, bütün mezhepler için tek bir secde hükmü iddiası değildir. Diyanet portalının
**işaretleme konumları** aynen korunur. Bazı konumlar birkaç ayetten oluşan
pasajın başındadır: 16:49, 17:107, 27:25 ve 41:37 gibi. Bu referanslar başka
listelerdeki son-ayet numaralarına sessizce çevrilmez; kelimelerden secde
sınıflandırması türetilmez. Mevcut kaynağın işaretlemediği 22:77 eklenmemiştir.

| Sure | Kaynak işaretleme konumu |
|---|---|
| Agraf | 7:206 |
| Ragd | 13:15 |
| Nahl | 16:49 |
| Isra | 17:107 |
| Merýem | 19:58 |
| Haj | 22:18 |
| Furkan | 25:60 |
| Neml | 27:25 |
| Sežde | 32:15 |
| Sad | 38:24 |
| Fussylet | 41:37 |
| Nejm | 53:62 |
| Inşikak | 84:21 |
| Alak | 96:19 |

## Görünüm

`ornek8.jpeg` esinlenmesi: küçük bilgi simgesi ve `(Sežde aýaty)` yazısı,
sağda ayrı bir satırda; koyu temada yumuşak şeftali, açık temada okunaklı
kahverengi. Kart, iletişim kutusu veya ayet metnine yerleştirilmiş yeni bir
Unicode karakter yoktur.

- Arapça ve iki dilli görünümde işaret, kaynakta belirtilen ayetin hemen üstünde.
- Olağan Arapça pasajlar kesintisiz kalır; yalnız işaret yerinde yeni metin akışı
  açılır. Font, harekeler, ayet sonu işaretleri ve seçili hizalama korunur.
- Türkmençe görünümde ilgili meal paragrafının üstünde sure:ayet referansı da
  gösterilir. PDF'nin çok ayetli meal paragrafları parçalanmaz veya yeniden yazılmaz.
- Ekran okuyucularına sure:ayet + Sežde aýaty etiketi sunulur.
- Arapça, meal ve mevcut dokuz kaynak veri dosyasının içerikleri değişmedi.

## Doğrulama

- 91 Flutter testi; 320px ve iki temada üç okuma modu dahil.
- `flutter analyze` temiz.
- Ham/çözülmüş kayıt, 14 konum, kaynak sayfa üyeliği ve manifest testleri.
- Tam metin doğrulaması: 605 Diyanet yanıtı, 6236 ayet, 114 surelik meal karakter korunumu.
- Samsung Galaxy A15'e güncel APK kuruldu; Alak 19 iki dilli görünümü gerçek
  ekran görüntüsünde kontrol edildi: `artifacts/product-sajdah-alak-device.png`.

```sh
python3 tools/build_sajdah_markers.py
python3 test/sajdah_source_test.py
python3 tools/check_full_content.py
flutter test --no-pub
flutter analyze
```
