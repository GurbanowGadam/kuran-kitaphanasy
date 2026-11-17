# Offline audio — 0.0.1 FULL Quran / MP3Quran

## Current release inventory

The active assets/data/audio_catalog.json is schema2, provider mp3quran, contentVersion0.0.1. It contains570 remotely verified published packages: the same five selected reciters, all114 surahs each;6236 canonical verses per reciter,31180 canonical timing rows total. This is not the earlier15-surah demo batch.

Recording identities remain:
- mp3quran_92 / Yasser Al-Dosari, Hafs Murattal.
- mp3quran_4 / Abu Bakr Al-Shatri, Hafs Murattal.
- mp3quran_123 / Mishary Alafasi, Hafs Murattal.
- mp3quran_54 / Abdulrahman Al-Sudais, Hafs Murattal.
- mp3quran_133 / Maher Al-Muaiqly, selected Mojawwad performance; source person102, moshaf/read133. Do not silently substitute his different untimed Murattal recording.

Drive folder: https://drive.google.com/drive/folders/1Ju0a7zKN_mySZdZavuCVND-ieSSrSpK_

All570 actual Drive IDs, exact filenames, parent folders and advertised sizes were inventoried across continuation pages (114 per folder, not just the first50). Every ZIP was then downloaded in full from Drive and byte-length/SHA256 compared to the independently audited local source. Previous75 IDs and ZIP hashes are unchanged. Only after all570 passed was the separate published catalog copied into the app. Original source candidate remains pending/null-ID for reproducibility; it is not the active catalog.

Local full corpus: /home/gadamgurban/kuran-mp3quran-v0.0.1-full/packages/
Published source: /home/gadamgurban/kuran-mp3quran-v0.0.1-full/audio_catalog.published.json
Per-file full remote hash proofs: /home/gadamgurban/kuran-mp3quran-v0.0.1-full/provenance/drive-verification/

570 untouched original full-surah MP3 ZIPs total7288896192 bytes, about7.29GB. They are NOT bundled in the APK: users explicitly download whichever reciter/surah they want. Catalog/source metadata is bundled, and no Drive inventory scraping occurs during app startup.

## Download-only and local playback contract

Long-press Arabic, meal or bilingual block to open named bookmarks or Aýaty diňle; the headphones toolbar button opens the same lazy player. Existing bookmark naming/move/+ behavior remains. Choosing a reciter stops the prior recording and does not download automatically. Selecting a surah does not auto-play or stream.

Completed files live in durable app-support storage. Downloads use .part/staging, enforce expected length/SHA256, validate safe ZIP structure and original MP3 hash, then atomically publish. Cancelled/incomplete/corrupt files are not playable; controller restart verifies local persistence. Existing75 package identities were preserved, so expansion does not intentionally invalidate those completed downloads.

Native just_audio receives local file clip sources only. Original MP3s are not cut, transcoded, trimmed or reordered; clip boundaries partition at official starts and actual EOF. Original official ends remain in provenance. A nonzero introduction is generic pre-ayah audio, not automatically called Besmele, including in Fatiha/Tevbe. The documented at-most500ms FINAL end annotation overrun policy is unchanged; starts/nonfinal intervals remain strict. Ten small source-end warnings are explicit in verification-summary.json. No fabricated scaling/clamping changes raw timing data.

The compact full-width bottom player retains whole-surah measured mm:ss time/seek, previous/next ayah, reciter picker, ayah/surah repeat, close and auto-follow/highlighting. Closing returns the toolbar. It does not advertise lock-screen/background playback. Missing downloads never trigger a hidden remote-player fallback.

Large Drive archives may return an HTML confirmation page before bytes. Dart's actual transport handles the bounded trusted-HTTPS form. The publication verifier now uses drive_download.py: trusted Drive hosts, same file ID, bounded HTML/form steps, transient retries, ZIP signature/length and full hash, with at most3 concurrent temporary archives. Quota/permission/error HTML fails closed; no Google account login or key is embedded in the app.

## Verification for THIS full corpus

- Local independent source/ZIP/ffprobe/timing audit:570/570; no blocking timing errors.
- Real Drive full downloads + exact size/SHA256:570/570, including old75; no failures.
- Full Flutter regression:203 passed;12 optional tests skipped in the default run.
- Explicit full-local opt-in:11 passed, covering all570 parsed metadata packages and actual Bakara/Tevbe ZIPs for all five reciters.
- Explicit real Dart Drive transport: three passed test runs, five Fatiha + five Bakara + five Tevbe packages. They verify extraction/hash, local segment boundaries/seek/repeat and restart with a downloader that throws. These use an injected fake clip player, so they do not alone prove audible native output.
- Python:55 pipeline/inventory/download tests plus2 metadata tests passed.
- flutter analyze: No issues found.
- Debug ARM64 APK and release AAB built. Embedded catalog bytes in BOTH match the active570-package catalog exactly.

## Connected-device evidence

The full debug APK was installed with adb install -r on Samsung SM-A155M, serialR58X90JBTRP, without clearing application data. Launch returned Status:ok; no Flutter/FATAL startup error was observed.

Through the real native UI, selected Bakara and the retained default Mişari Raşid el-Afasi reciter, downloaded the120641667-byte ZIP, and waited for readiness. Native playback advanced to ayah3 with0:31 /125:39 visible. Android AudioPlaybackConfiguration for this app PID6406 reported state:started, followed by state:paused after pausing the test. The downloaded file remains on the phone. Native evidence screenshots are under artifacts/mp3quran-full-native-bakara-*.png.

This proves observed native playback/UI output state for that recording, not an independent acoustic audit of every recitation. Network settings were not disabled; no physical airplane-mode test is claimed. Offline no-fallback behavior is additionally covered by the controlled controller-restart tests above.

## Delivery and publication limits

Version0.0.1+2; debug package tm.kuran.kitaphanasy.debug. The installable APK uses the Android debug certificate. Release AAB is genuinely unsigned because owner release keys are not configured; it is not directly Play-upload-ready. Recording/source/font attribution is retained; see the rights review and source evidence, not public Drive sharing alone, for the licensing basis.

Earlier EveryAyah/demo/device logs are historical and do not prove current MP3Quran behavior. Preserved prior document: docs/history/OFFLINE_AUDIO_BEFORE_FULL.md. Earlier75-package release reports are under releases/0.0.1/history/.
