# Kullanıcının onayladığı okuyucu kuralları

- Sure adları iki ayrı kaynakta tutulur: Arapça okunuşun Latin aktarımı ve kullanıcının Türkmençe meal PDF'sindeki adlar. Nihai ad listesi kullanıcıyla görüşüldükten sonra seçilecektir; şimdilik PDF adları kullanılır. Başlığın sonundaki parantezli ad/anlam gösterim adından çıkarılır; açıklama ve orijinal başlık korunur.
- Sure giriş açıklamaları ayrı dataset olur. Sure adının yanında açıklama düğmesiyle açılır.
- Ayet açıklamaları ayrı dataset olur ve ilgili ayet/range'e bağlanır. Meal sonunda dokunulabilir dipnot bağlantısı bulunur; açıklama ayrıntılı, kaydırılabilir pencerede okunur. Kaynak metin yeniden yazılmaz veya özetlenmez.
- Ayetlerin sayfalara dağılımı Türkiye Diyanet mushaf baskısına göre doğrulanır; ekran yüksekliğine göre yeni sayfa sınırı üretilmez. Sayfa içeriği dikey kayar; mushaf sayfaları yatay kaydırmayla değişir. Arapça ve Arapça+meal aynı ayet sınırlarını kullanır.
- İlk deneme Fatiha'dan başlayan ilk on mushaf okuma sayfasıdır; PDF fiziksel sayfası ile Diyanet basılı sayfa numarası farklı kavramlardır ve kaynak sınırları doğrulanmadan eşit varsayılmaz.
- Kaynakta birleşik meal grupları varsa keyfî ayetlere bölünmez.

## Mevcut uygulama durumu

Bu dosya hedef kuralları kaydeder, tamamlandıklarını iddia etmez. assets/sources/reading-data-manifest.json kaynak hazırlığının doğrulanmış durumunu içerir. Resmî Diyanet sınırları ve eksik Arapça veri elde edilmeden on sayfalık sürüm hazır kabul edilmez.
