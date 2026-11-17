# Offline audio — 0.0.1 MP3Quran preparation

## Current state (0.0.1)

The active catalog is MP3Quran schema 2, content version 0.0.1: five reciters, fifteen surahs each, 75 original full-surah MP3 ZIPs prepared for manual Google Drive upload. It contains no EveryAyah Drive IDs or bundled EveryAyah opening recording. New recordings use official recording-matched verse timestamps and local clipped native queues; original audio bytes remain unchanged. A generic recorded prelude is not automatically labeled Besmele. See `MP3QURAN_PIPELINE.md` for exact format, source provenance and bounded final-end annotation policy.

All 75 packages now have `publicationStatus: published`, unique real Drive IDs and `remoteVerified: true`. The folder is https://drive.google.com/drive/folders/1Ju0a7zKN_mySZdZavuCVND-ieSSrSpK_ . Every remote ZIP was fully downloaded and matched against the prepared length/SHA256 before the published catalog was integrated. The application's actual Dart Drive downloader also verified Fatiha for all five reciters; an injected clip-player boundary exercised timing, seeking/repeats and offline controller restart without network fallback. This is not native audible/device acceptance: no ADB device was connected. The source candidate remains deliberately pending and is not the active production catalog. Prepared local ZIPs remain at `/home/gadamgurban/kuran-mp3quran-v0.0.1/packages/`.

## Historical implementation and verification (EveryAyah private test, superseded)

The sections below describe the previous source and its prior device tests, NOT current MP3Quran validation. Their Drive IDs, source archives, opening overrides, durations and native-device results must not be reused as evidence for the new recordings.


## User-facing flow

Long-press an Arabic verse, meal or bilingual block → targeted haptic/highlight → verse action sheet. Only real actions are shown: Bellikler (existing named-bookmark chooser) and Aýaty diňle. The latter opens a persistent bottom player. The headphones button immediately right of the bottom bookmarks button opens the same player using the current page/surah's first verse.

The player provides five reciters, whole-surah download/cancel, previous/next verse, play/pause, seek and elapsed/duration, ayah/surah repeat, local deletion and close. Choosing a reciter stops the previous recording and never downloads automatically. Opening the player does not auto-play. Unsupported chapters are explicitly unavailable.

Only downloaded local files are played. There is no streaming option, URL audio source or silent EveryAyah fallback. The user must explicitly download a complete selected reciter/surah package first. Current transfer cancellation restarts the ZIP on a later attempt; it is not byte-range resumability. Returning to the library closes the player, and app inactivity pauses it; this implementation does not advertise background/lock-screen playback.

## Available content

`assets/data/audio_catalog.json` includes actual public Google Drive file IDs for five reciters × fifteen surahs (75 packages):

- Yasser_Ad-Dussary_128kbps
- Abu_Bakr_Ash-Shaatree_128kbps
- Alafasy_128kbps
- Abdurrahmaan_As-Sudais_192kbps
- MaherAlMuaiqly128kbps

Surahs: 1, 56, 67, 75, 93, 105–114. Original source ZIP bytes were preserved in the user's Drive upload. The catalog freezes archive byte lengths/SHA256 and each MP3 SHA256 from the locally verified source packages. It is bundled, not scraped from Drive during app startup. If a Drive file is deleted/reuploaded under a new ID or its bytes change, regenerate/reverify the catalog; do not bypass integrity checks.

Folder: https://drive.google.com/drive/folders/14HZQy5VwYI853RYUxQZs0aedfaM6l2wO

## Architecture and safety

- `lib/audio/quran_audio_controller.dart`: injectable catalog, app-support directory, downloader and local player; constructor is plugin-free and reader initializes audio lazily.
- `lib/reader/presentation/reader_audio.dart`: reader-scoped player UI and controller lifecycle.
- `lib/reader/presentation/reader_bookmarks.dart`: shared long-press action sheet retains existing chooser/move/+ workflow.
- `just_audio` receives only local file sources. A verified whole-surah `setAudioSources` playlist is preloaded with lazy preparation disabled; automatic ayah changes happen natively without per-verse Dart hash/load work. Source MP3 bytes, natural pauses and verse order are not trimmed, mixed or transcoded.
- Native playback events publish matching index/position/duration snapshots; stale queue generations are ignored. Whole-surah equal-width ayah progress interpolates observed samples for 160 ms, without extrapolating a clock; paused state and intentional backwards seek/repeat reset directly.
- `path_provider` application support directory stores `quran_audio/<reciter>/<surah>/*.mp3`, not an evictable cache.
- Download goes to a `.part`, validates exact length and archive SHA256, checks ZIP safety, MP3 hashes and complete verse coverage, extracts to `.staging` then publishes the completed directory.
- Partial/cancelled/invalid packages are not playable. A fresh controller validates persistent local files. A missing/corrupt selected MP3 invalidates readiness rather than using the network.
- The downloader follows standard HTTPS redirects, supports a bounded Drive confirmation form, and reports quota/permission/HTML failures. No Google credentials, private keys or user login are embedded.
- Source `000_license.html` is allowed as bounded root metadata but never rendered or played. Verified SSS000 opening recordings precede ayah 1 for surahs other than 1 and 9, without inventing an ayah 0. During this segment `isBasmala` is true and the panel says Besmele; native queue indices map back to canonical ayah numbers. A new `selectVerse(surah, 1)` is an intentional surah start, while previous/next navigate canonical ayahs. Surah repeat includes the opening; ayah repeat never loops the opening instead of the ayah.

## Verification performed

- Full Flutter suite: 116 passed, 1 opt-in network test skipped.
- `flutter analyze`: no issues.
- Explicit `flutter test test/audio_service_live_test.dart --dart-define=AUDIO_LIVE=true`: passed; actual Drive Afasi Fatiha GET downloaded 798099 bytes, verified all seven MP3 hashes, and a fresh controller recognized persisted files.
- Debug arm64 APK built, installed with `adb install -r`, and launched (`Status: ok`) on connected Samsung SM-A155M, preserving debug-variant app data.
- Physical UI: actual long-press action menu, persistent player and toolbar placement inspected in screenshots under `artifacts/audio-device-*.png`. Device received real Drive downloads. Existing stored user reading/bookmark state was not cleared.
- Physical offline playback: Wi-Fi and mobile-data settings temporarily set to 0, native AudioPlaybackConfiguration for this app reported `state:started`, and screenshot showed pause/elapsed time. Both settings restored to their original enabled state in a finally block.
- After native app process restart, local package readiness remained, and with both network settings disabled the restarted process (PID 27916) produced a started native AudioTrack. Sound was not independently heard by the agent; native output state and UI were observed.
- All 75 public Drive filenames/IDs were mapped; only sample packages were actually downloaded through Drive during validation, not every Drive package. Full source archives had previously passed coverage/CRC/MD5 checks. No blanket perceptual-audio-quality or every-recording besmele approval is claimed.

## Transition smoothing verification

The later compact-player layout is retained: reciter picker left of play, only the right surah-repeat control, no delete icon, and equal-width ayah progress for the whole surah (not an invented total-time estimate).

For the transition fix, independently reran `flutter analyze` (clean), full Flutter tests (126 passed, 1 opt-in live test skipped), built arm64 debug APK, installed -r and launched successfully. Device screenshots show natural Fatiha 2/7 → 3/7 advancement; Android reported the same started AudioTrack/player/session at the two samples. The recording is `artifacts/audio-smooth-device.mp4`; screenshots are `artifacts/audio-smooth-transition1.png` and `artifacts/audio-smooth-transition2.png`.

Tests reproduce no-new-load/hash work on natural native transitions, atomic new-ayah snapshots, stale-event rejection, native repeats/EOF and paused navigation, progress tween midpoint/boundaries, real backwards reset and drag/paused behavior. No acoustic before/after millisecond measurement was performed, so no numerical audible-gap reduction is claimed. Original recording silence remains untouched.

## Overlay player and spoken-verse following

The latest player covers/replaces the reader's bottom toolbar while open; closing it restores those controls. It no longer adds its height above a second icon row. Visible transport icons are 20px (play 22px), with six 48px hit targets. Real current-file position/duration mm:ss labels flank the equal-width whole-surah ayah scrubber; these clocks are not total-surah time. The panel is tested at 320px, both themes, 2× text.

Only the current Arabic verse and its native number are darkened inside the existing shaped paragraph. The darkened color derives from the actual book background, tested to have lower luminance in both themes. Bilingual grouped Arabic still selects only the precise ayah; translation-only preserves and shades the source group rather than inventing per-verse meal splits. A separate opening is not mislabeled/highlighted as ayah 1.

Follow uses cached verse/page and source-group anchors, mounts lazy pages, then checks exact paragraph-selection geometry. Already visible verses do not recenter; playback position ticks do not repeatedly scroll. Both horizontal pages and continuous vertical flow have regression coverage; user drag completion re-enables following, and generation checks guard stale work.

Final independent validation: `flutter analyze` clean; 146 tests passed, one opt-in live download test skipped; APK built/installed -r and launched. Connected-device evidence shows Wakyga Besmele (0:00–0:02 / 0:03) → ayah 1, exact dark highlights at ayahs 2/5/16, and automatic page 533 ayah 16 → page 534 ayah 17. See `artifacts/audio-player-v2-follow.mp4` and `artifacts/audio-player-v2-{verse,follow,verse16,page-crossing}.png`. The native player was active in Android diagnostics; the agent did not independently hear or audit the recordings.

## Full-width player, measured surah time and uniform selection bands

Latest correction supersedes per-ayah clocks and equal-width ayah scrubbing. The panel background fills the full bottom chrome width (no external 8px side padding); safe-area surrounding chrome uses the same panel color. Transport hit targets retain their prior dimensions.

`tools/measure_audio_timings.py` independently verifies all 75 original ZIP byte lengths/archive hashes and each MP3 hash before measuring 1233 exact MP3 byte streams with ffprobe. It adds only `durationsMs` metadata to catalog packages, preserving original IDs, hashes and source archives. Whole-surah prefixes include SSS000 only where played (not Fatiha/Tawba). Controller API: `hasSurahTiming`, `surahPosition`, `surahDuration`, `seekSurah(Duration)`. Clocks and weighted slider share this measured timeline, keeping the total stable across ayahs. Scrubs map to native queue index/local position, commit once, preserve pause/play, and reuse prepared queues. Missing metadata shows --:-- and disables the timeline rather than estimating durations.

Arabic selection retains original glyph/marker sizes, but an underlay uses `RenderParagraph.getBoxesForSelection(boxHeightStyle: BoxHeightStyle.max)` for full line-height dark bands including the smaller number glyph. No canonical text is rewritten or split. Prior span backgrounds share the same opaque color and are backed by this uniform-height underlay.

Final independent checks: analyze clean, 158 tests passed (one opt-in network test skipped), APK built and installed -r. On the connected phone Fatiha advanced from ayah 1 at 0:01/0:46 to ayah 3 at 0:12/0:46. Pixel samples at the physical left/right edges and center of five panel rows matched RGB(26,33,32), proving no side gap. Selection pixel regions on consecutive lines measured 191/190 physical pixels (rounding), while unit geometry verifies marker-band height equals the body band without changing 22px marker typography. Screenshots: `artifacts/audio-surah-total-{early,later}.png`.

## Rights and release scope

This is a private test, not a cleared Google Play release. Source recording redistribution permission remains unresolved: the original archive license notice points to a URL that returned 404. Neither public Drive sharing nor private testing establishes a license. Preserve provenance/credits and obtain the necessary recording permissions before public distribution.

Existing approved Quran/meal/font assets and demo directory were not replaced for this feature. Downloaded reciter preference is currently reset to Afasi after process restart; audio files themselves persist. Google Drive quotas and sharing settings can still block new downloads, but cannot affect already complete local playback.
