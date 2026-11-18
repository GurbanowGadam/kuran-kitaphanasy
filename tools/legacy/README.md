# Eski / tek seferlik araçlar — ÇALIŞTIRMAYIN

Bu betikler demo ve kimlik geçişi dönemine aittir; yalnız tarihsel kanıt ve
yeniden üretilebilirlik için saklanır.

- `build_data.py` — 3 sureli demo `assets/quran.json` dosyasını üretir (tam veri paketi değil).
- `extract_translation.py` — demo test fikstürü `test/translation_expected.json`'ı üretir.
- `configure_native_identity.py` — `tm.demo.kurany_kerim_demo` → `tm.kuran.kitaphanasy`
  tek seferlik geçişi; tamamlandı, tekrar çalıştırmak native dosyaları değiştirir.

Tam içerik üretimi ve denetimi için `tools/build_full_content.py` ve
`tools/check_full_content.py` kullanılır.
