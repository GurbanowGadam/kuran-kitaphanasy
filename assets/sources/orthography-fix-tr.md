# Arapça imla regresyonu — sonuç

76 ayetin tamamı resmî Diyanet metin grubu 4 kaynağına geri döndürüldü. Sadece ilk 12 ayetlik kısmi düzeltme değildir.

## Kök neden ve tam fark

Font veya arayüz değiştirilmeden Diyanet textGroup 4 yerine AlQuran Cloud quran-uthmani kullanılmıştı. Bu iki kaynağın 76/76 ayeti kod noktası düzeyinde farklıydı. Eski arabic-verified.json ve quran.json içindeki ortak 12 ayetin tamamı yeni resmî Diyanet yanıtlarıyla birebir eşleşiyor.

Besmelede Rahman:
- Regresyon: ٱلرَّحْمَٰنِ
  U+0671 U+0644 U+0631 U+0651 U+064E U+062D U+0652 U+0645 U+064E U+0670 U+0646 U+0650
- Eski/resmî Diyanet: الرَّحْمٰنِ
  U+0627 U+0644 U+0631 U+0651 U+064E U+062D U+0652 U+0645 U+0670 U+0646 U+0650

Regresyonda başlangıçtaki elif U+0671 (wasla) idi; Diyanet'te U+0627. Mîm sonrasında regresyonda U+064E (üstün) + U+0670 (dik elif) vardı; Diyanet'te yalnız U+0670 var. Bunlar fontun uydurduğu şekiller değil, kaynak metindeki gerçek kod noktası farklarıdır.

76 ayetlik kaynak sayımları (reddedilen Uthmani → resmî Diyanet):
- U+0671: 199 → 0
- U+0670: 151 → 114
- U+064E: 1778 → 1671
- U+0656: 0 → 136
- U+06CC: 0 → 270
- U+064A: 223 → 1

Bu sayımlar bir değiştirme kuralı DEĞİLDİR. Hiçbir harf/hareke silinmedi, değiştirilmedi veya normalize edilmedi. Her metin resmî JSON'daki metin_grubu_id=4 alanından aynen alındı. Her ayetin tam eski/yeni dizgesi ve fark aralıklarının kod noktaları orthography-diff.json içindedir.

## Resmî kaynak

https://kuran.diyanet.gov.tr/api/v2/sayfa/{0..9}?font_id=173

Önceki erişim engeli bu denemede oluşmadı: halka açık API HTTP 200 verdi. Yanıtların AES-CBC taşıma zarfı, sitenin halka açık JS istemcisinin uyguladığı standart çözümle açıldı. Oturum/kimlik bilgisi kullanılmadı, güvenlik sınaması aşılmadı. Ham yanıtlar, tam çözümlenmiş JSON, kullanılan halka açık istemci ve SHA-256 manifesti assets/sources/diyanet-reading/ altında saklandı. Kontrol aracı ham yanıtları tekrar çözüp çözümlenmiş dosyalarla da karşılaştırıyor.

## Korunanlar

Sayfalar, mealler, açıklamalar, dipnotlar ve sure adları SHA-256 düzeyinde değişmedi. lib/ arayüz kodu, fontlar ve pubspec değiştirilmedi. Sayfa 0–9 resmî API üyeliği mevcut PDF sayfa üyeliğiyle aynı. PDF'nin özel CID gliflerinin tamamı Unicode'a çevrilmiş gibi bir iddia yoktur.

## Doğrulama

- Düzeltmeden önce eski 12 ayetin eşitlik testi ve textGroup=4 testi başarısız: orthography-red.log.
- Düzeltmeden sonra Python unittest: 7 test geçti; eski font/meal doğrulamaları da geçti.
- Tam kaynak kontrolü --require-complete geçti: 76 tam resmî metin, ham/çözümlenmiş kaynak hash'leri, 10 sayfa, 20 meal sütunu, 114+114 isim, 2 açıklama, 10 dipnot.
- DiyanetAmasya birincil fontta 57 kaynak kod noktası eksiksiz.
- HarfBuzz: 743 farklı güncel kelime ve 76 numaralı ayet .notdef olmadan şekillendi. Eski kaynak U+06CC bağlanma testi de geçti.
- Flutter: 15 test geçti; flutter analyze sorun bulmadı.
- flutter build web ve flutter build apk --debug başarılı.
- Hem web hem APK içindeki verses.json geri yüklenen dosyayla bayt düzeyinde aynı.

verses.json SHA-256: bb864f4844f55217003a4df312be8246c4ae07f3dca773bdb8f587cb09baddc3
APK SHA-256: 98c7c3a983aa4834ecedc4418b52823ee9dd5ca8481307cf88407f076381f856

## Sınırlar

Telefon kurulumu yapılmadı; ana ajan yapacak. Yeni tarayıcı/telefon görsel incelemesi yapılmadı; cmap/HarfBuzz testleri görsel kabulün yerine geçmez. Web derlemesinde mevcut CupertinoIcons font bildirimi uyarısı çıktı; derleme başarılı. Dinî içerik için insan incelemesi ve yeniden dağıtım hakları ayrıca değerlendirilmelidir.
