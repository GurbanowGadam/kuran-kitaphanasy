# Kuran Kitaphanasy runtime architecture

## Product boundary

V1 is an offline-first Flutter application with one real catalog entry: Quran (Hadith cards are explicit coming-soon placeholders). No account, backend, analytics or runtime scripture download exists. The only network use is a user-initiated audio download. The approved Arabic/Türkmen reader surface is retained. Source capture/build tools and archived captures are build-time evidence, not runtime services.

## Modules

- `lib/main.dart`: entry point and compatibility exports for existing integrations/tests.
- `lib/app/app.dart`: application theme, injectable repository/store, library-to-reader navigation. An `IndexedStack` retains the current reader during same-session library visits; its `active` flag terminates fullscreen when hidden.
- `lib/library/domain/book.dart`: immutable catalog descriptor.
- `lib/library/data/book_repository.dart`: repository contract and bundled Quran implementation. Applications/tests may inject another repository; only actual available entries are rendered.
- `lib/library/presentation/library_page.dart`: library cover, open action and library theme control.
- `lib/reader/domain/reader_models.dart`: immutable verse references, Arabic records, translation groups and edition pages.
- `lib/reader/data/reader_data.dart`: bundled JSON loading, fail-closed validation and indexed content snapshot.
- `lib/reader/presentation/reader.dart`: reader route/state, chrome, fullscreen, source-page/surah navigation and lazy reading flows.
- `lib/reader/presentation/reader_content.dart`: part library containing unchanged source text presentation, opening sections and compact baseline-aligned inline note links.
- `lib/reader/presentation/page_scroll.dart`: disposable page-owned horizontal scroll controller.
- `lib/reader/presentation/surah_opening.dart`: source-backed Arabic headings, opening formulas and metadata.
- `lib/reader/settings/reader_preferences.dart`: versioned state decoding, storage adapters and ordered debounced writer.
- `lib/reader/settings/reader_settings_sheet.dart`: part library containing book-scoped settings and live font previews.
- `lib/audio/audio_catalog.dart`: MP3Quran full-surah package model, metadata/timing validation, isolate catalog decode. Only `full-surah-timed-v1` is accepted.
- `lib/audio/audio_download.dart`: streamed Drive download, incremental SHA-256, file-backed ZIP inflate into a staging directory, atomic rename. Memory is bounded by I/O buffers.
- `lib/audio/audio_playback.dart`: `AudioPlayback` interface (gapless clip queue) and the `just_audio` implementation.
- `lib/audio/audio_failure.dart`: `AudioFailure` enum with the only user-visible (Türkmen) audio messages; technical causes stay in `errorDetail`.
- `lib/audio/quran_audio_controller.dart`: selection, download state, clip queue and seek orchestration with generation counters against stale async work. Storage key `quran_audio/mp3quran-0.0.1/<reciter>/<surah>/` is stable across versions.
- Top-level `reader_data.dart`, `library.dart` and `surah_opening.dart` are compatibility exports; they do not duplicate implementations.

## Content invariants

The runtime consumes ten asset datasets: pages, verses, translations, PDF names, pronunciation metadata, Diyanet Arabic titles, surah metadata, introductions, footnotes and source-backed sajdah annotations. Sajdah annotations preserve the official Diyanet passage-marker positions independently of scripture strings; see `SAJDAH_MARKERS.md`. Missing required metadata fails loading; the UI shows an explicit error instead of guessed scripture or headings.

`sourcePages` preserves all 605 physical groups. `pages` combines only the first two groups into one opening page: Fatiha 1–7 and Baqara 1–5. There are consequently 604 reader pages. Reader page two begins at Baqara 6. The merged page deliberately has no single physical/PDF page label. Page numbering in reader chrome is reader ordinal, not a fabricated PDF mapping.

The loader verifies ordering, duplicate/missing references, metadata/title/introduction coverage, nonempty records, translation coverage and note linkage. Complete-edition assets must cover all declared 114-surah verse counts. Domain records and exposed collections are immutable. Original grouped translations remain whole at source boundaries; scripture strings are not normalized or rewritten by the renderer. Corpus/archival hash checks and independent font/source verification are separate pipeline gates.

Indexes are constructed once: verse-to-translation coverage, page-to-ordered-translation groups and surah-to-first-reader-page. Rendering does not repeatedly scan every translation for every page. Shared-page surah selection scrolls to the matching section and updates header/info; tracking visible sections changes the header without changing edition page membership.

## Full-book rendering and resource lifetime

Horizontal reading uses a lazy RTL `PageView.builder`. Each built page owns its vertical `ListView` controller and releases it on disposal. A bounded cache stores numbers, not hundreds of live page widgets/controllers.

Continuous vertical reading uses `ScrollablePositionedList.builder` with indexed jumps, visible-item tracking and no full-book eager column. Far-off surahs can be selected without first mounting or measuring every intervening page. The first visible page drives the header and persisted current page. Per-page positions are pixel offsets computed from item leading edge and actual viewport height. A `LayoutBuilder` converts the saved pixel offset back into initial list alignment on reconstruction, preserving position after application teardown/restart. The cache retains at most 24 offsets; it is not an unlimited reading-history database. Changing font size, mode or viewport can change text layout, so pixel offsets are not semantic verse anchors.

Both flows retain a stable gesture/stack subtree through fullscreen changes. Fullscreen uses immersive-sticky system UI, hides reader chrome, displays a noninteractive three-second hint and exits on double tap/back. It is never persisted. Deactivation/disposal restores edge-to-edge system UI and cancels the timer.

## Local persistence

`ReaderStore` is injectable. Production uses `SharedPreferencesReaderStore`; isolated tests use `MemoryReaderStore`. SharedPreferences keys are namespaced as `kuran_kitaphanasy.reader.<bookId>`. Each book stores schema version 1, last reader-page index, mode, reading flow, optional book-theme override, Arabic/Türkmen font sizes, Arabic-only alignment and bounded per-page offsets. `_library` is a reserved application-state entry storing its own version and theme independently of book overrides.

Restore rejects unsupported versions, invalid page indices/modes/alignments, nonfinite/out-of-range sizes and corrupt/oversized offset values. Malformed SharedPreferences JSON falls back safely. The writer debounces gesture updates by 350 ms, serializes writes, and flushes reader state when leaving the reader, on lifecycle transitions and on disposal. Library theme changes flush immediately. Write errors are retained by `PreferenceWriter.lastError`; there is currently no user-facing storage failure indicator or crash-recovery transaction guarantee. Fullscreen and transient sheets are excluded.

## Verification and acceptance boundaries

Dart regression suites retain exact source/group assertions, fixture navigation boundaries, narrow 320 px labels in all three modes/both themes, typography/inline-note geometry, book-scoped settings previews, modal themes, fullscreen timers/gestures/back and lazy build-window checks. Production navigation tests additionally open the actual full corpus, select surah 114 in both flows, return to Baqara on the shared opening page, and verify title/counter/visible opening. Restart tests destroy/recreate the application, checking page-internal pixel offsets in both flows and library theme persistence.

Run `flutter test --reporter expanded` and `flutter analyze` from the repository root. Widget tests are not phone visual approval, native process-kill durability, performance profiling on low-memory devices, independent text proofreading, or store readiness. Release signing, platform identity/version, device installation/visual QA and iOS/macOS builds remain separate owner/platform workstreams.
