# Kaynak ürün ikonu — gerçek Flutter Material glifi

Onaylı şekil kütüphane başlığındaki `Icons.auto_stories_outlined` glifidir;
yerine rastgele kitap illüstrasyonu/Flutter logosu kullanılmaz. Flutter 3.47.7'nin
`icons.dart` dosyasından `0xeeaf` MaterialIcons codepoint'i bulunur; SDK'nın gerçek
`MaterialIcons-Regular.otf` dosyasından Bézier outline çıkarılır. Font/girdi hash'leri
`glyph-provenance.json` içinde kayıtlıdır. Şekle yalnız eş oranlı ölçek, merkezleme
ve font koordinatını ekrana çeviren y ekseni dönüşü uygulanır; geometri çizilmez.

`auto_stories_outlined.path` orijinal outline'ın taşınabilir vektör kaynağıdır;
`app-icon.svg` aynı beyaz glifi #18685f arka planda gösterir.
`app-icon-foreground.svg` şeffaf zeminli aynı şekildir. 108 birim kanvasta 56 birim
maksimum genişlik/yükseklik adaptive/maskable güvenli dairenin içinde kalır.
Ürün zemin/boşluk tasarımı glyph'in kendisini değiştirmez.

## Tekrar üretme

```sh
python3 -m venv .venv-branding
.venv-branding/bin/pip install -r tool/branding-requirements.txt
# Linux'ta libcairo2 sistem kütüphanesi gerekir; Python bağımlılığı değildir.
# Taahhüt edilmiş orijinal outline'dan, Flutter/uygulama derlemesi olmadan:
.venv-branding/bin/python tool/generate_branding.py
python3 tool/release_readiness.py
# Yalnız bilinçli SDK/glif güncellemesinde, outline/provenance diff'ini inceleyerek:
.venv-branding/bin/python tool/generate_branding.py --flutter-root /absolute/path/to/flutter
```

Çıktılar:
- Android legacy mipmap launcher: mdpi 48, hdpi 72, xhdpi 96, xxhdpi 144, xxxhdpi 192 px.
- Aynı yoğunluklarda şeffaf foreground mipmap: 108, 162, 216, 324, 432 px.
- Android drawable foreground gerçek vektördür; v26 adaptive ve v33 monochrome/
  themed icon XML'leri onu kullanır. PNG foreground'lar aynı şeklin raster karşılığıdır.
- iOS AppIcon Contents.json'daki tüm slotlar: 20–1024 px; marketing 1024 dahil,
  alfa kanalı olmayan RGB PNG. iOS kendi maskesini uygular; önceden köşe kırpılmaz.
- Web normal/maskable 192/512 ve favicon 32; ürün kaynağı 1024 ve Play store icon 512.
- `generated-icons.json`: her üretilmiş PNG'nin beklenen kare boyutu.

`tool/release_readiness.py` PNG IHDR boyutlarını, iOS RGB/alfa durumunu, catalog
referanslarını ve Android/SVG vektörünün aynı orijinal path kullandığını doğrular.
Aynı bağımlılık/native Cairo sürümüyle yeniden üretim byte düzeyinde kararlıdır;
farklı rasterizer sürümünde antialiasing byte'ları değişebilir, glif outline'ı korunur.
Gerçek launcher maskeleri/küçük boyut okunurluğu için ayrıca cihaz görsel testi gerekir.

Material icons: Google Material Design Icons, Apache License 2.0;
`MaterialIcons-LICENSE.txt`, kaynak https://github.com/google/material-design-icons .
Bu bildirim metin/meal/Diyanet fontları için lisans oluşturmaz.
