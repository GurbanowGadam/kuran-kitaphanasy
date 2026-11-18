# Sahibine teslim — Google Play / 1.0.0+3 hazırlığı

## Şu anki durum

Yerel mağaza metinleri ve yayın prosedürü hazırlandı; sahip onayı gerektiren taslaklardır. İmzalı AAB, Play yüklemesi, mağaza incelemesi ve yayın birbirinden ayrıdır; burada hiçbiri tamamlandı diye işaretlenmez. Bu doküman görevi uygulama testlerini/derlemesini çalıştırmadı. Önceki sürümlerin test kayıtları yeni sürümün kanıtı değildir.

Ürün kapsamı: 114 sure, çevrimdışı Arapça/Türkmençe okuma; MP3Quran kaynaklı Google Drive indirmeleri sonrası yerel ses; adlandırılmış yer imleri ve tema/font ayarları. Hadisler yalnız açık yakında yer tutucularıdır. Seslerin tümü APK içinde değildir; ilk indirme internet gerektirir. Hak kapsamındaki eski açık maddeler kapatılmış sayılmadı; kapsamlı yeni lisans araştırması yapılmadı.

## Teslim edilen metinler

- `STORE_LISTING_TK.md`: Türkmençe başlık, kısa ve tam açıklama.
- `RELEASE_NOTES_TK.md`: gelecek 1.0.0+3 için Türkmençe sürüm notu.
- `DATA_SAFETY.md`: Türkçe, kanıt/karar gerektiren veri güvenliği rehberi.
- `../PRIVACY.md`: Google/IP ve yerel veri kapsamına göre düzeltilmiş, henüz yayımlanamaz gizlilik taslağı.
- `../NATIVE_RELEASE.md`: gerçek Gradle değişkenleri ile sahibin imzalama prosedürü.
- `../RELEASE_CHECKLIST.md`: teknik, hak/gizlilik ve mağaza kapıları.

## Yayını engelleyen sahip kararları

1. Gerçek yasal yayıncı, doğrulanmış destek/gizlilik e-postası, yürürlük tarihi ve herkese açık HTTPS politika URL'si BEKLİYOR. Bunlar uydurulmadı; depo dosyası URL yerine geçmez.
2. Üçüncü taraf Google işlemesi ve final SDK/ağ davranışına dayalı Data Safety kararı BEKLİYOR. Hesapsız olmak “hiç veri toplanmaz” demek değildir.
3. Mevcut hak araştırmasının açık kapsamları ve sahibinin izin belgeleri; nihai yayın/ülke kapsamı BEKLİYOR.
4. Gerçek upload anahtarı, sertifika kontrolü, final imzalı paket ve sürüm kodunun kullanılabilirliği BEKLİYOR. Bu görev anahtar üretmez.
5. Final cihaz kabulü, internal testing ve mağaza materyali onayı BEKLİYOR. Geçmiş başarılar yeni test olarak sunulmaz.

## Kalan görsel ve Console materyalleri

Bu görev ekran görüntüsü veya grafik üretmedi. Sahibi son imzalı/test sürümünü temel alarak şunları hazırlamalı:

- Gerçek okuyucu (Arapça/Türkmençe), sure listesi, named bookmark, tema/font ve ses indirme/oynatma ekran görüntüleri. Hadis yer tutucusu görüntülenirse hazır içerik izlenimi verilmemeli.
- Google Play mağaza ikonu ve feature graphic; telefon ve hedeflenen diğer form faktörleri için gerekli ekran görüntüleri. Güncel sayı/boyut/format sınırlarını Console'dan doğrulayın; launcher ikonu tek başına bütün mağaza materyali değildir.
- Doğrulanmış destek iletişimi, yayımlanmış gizlilik URL'si, yayıncı bilgisi; gerekli/isteğe bağlı web alanlarını gerçek sahiplikle doldurma.
- Kategori, hedef kitle/yaş, içerik derecelendirmesi, reklam/app access cevapları, ülkeler ve hesabın test/yayın koşulları.
- Türkmençe dil redaksiyonu; Console'un desteklediği dil/yerelleştirme yolu. Yanlış dil etiketiyle yayın yapmayın.

Son sıra: eksik sahip bilgileri ve hak/gizlilik kararları → gerçek test ve imzalı paket → internal test/cihaz kabulü → materyal/form onayı → sahibi tarafından incelemeye gönderim. Yayın ve mağaza kabulü ancak gerçek Console sonucu ile kaydedilir.
