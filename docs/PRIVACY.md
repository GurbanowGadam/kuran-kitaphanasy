# Gizlilik — owner incelemesi/yayın URL'si için taslak

Kuran Kitaphanasy metin ve fontları uygulama içinde bulunduran çevrimdışı bir
okuyucudur. Mevcut ürün kapsamı hesap, reklam, analitik, izleme, uygulama sunucusu
veya çalışma sırasında içerik indirmesi içermez. Uygulama okuma tercihlerini ve
okuma durumunu cihazdaki yerel depoda tutabilir; bunlar geliştiriciye gönderilmez.
Uygulamayı kaldırmak yerel veriyi silebilir; işletim sistemi/tarayıcı yedekleme ve
saklama davranışı platforma bağlıdır.

Android release internet izni istemez; yedekleme devre dışı ve Android 12+ bulut/
cihaz aktarım dışlama kuralları bulunur. Üretici davranışı ayrıca doğrulanır.
iOS'ta yerel tercihler sistem yedeğine dahil olabilir; Android kuralının iOS için
geçerli olduğu iddia edilmez. Web sürümünde sunucu ilk yükleme için gereklidir ve
hosting hizmeti IP/erişim günlükleri tutabilir; owner seçtiği hosting'in politikasını
ayrıca açıklamalıdır. Offline PWA önbelleğinin her tarayıcıda kalıcılığı garanti edilmez.

Uygulama kişisel veri toplayan bir backend sunmadığından geliştirici tarafında
hesap/veri silme işlemi yoktur. Yerel veriler uygulama ayarlarından/işletim sisteminin
uygulama verisi yönetiminden temizlenebilir; iOS'ta uygulamayı silip yeniden kurmak
ve gerekiyorsa OS yedeğini yönetmek gerekebilir.

Bu belge hukukî onay değildir. Owner yayın öncesinde gerçek yayıncı adını, destek
iletişimini, yürürlük tarihini ve kalıcı HTTPS politika URL'sini eklemeli, final plugin/
release davranışını doğrulamalı ve Google Play Data Safety/App Store App Privacy
formlarını buna göre doldurmalıdır. Yeni ağ/analitik/reklam/hesap özelliği bu metnin
ve mağaza beyanlarının yeniden incelenmesini gerektirir.
