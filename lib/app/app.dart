import 'package:flutter/material.dart';

import 'startup_page.dart';
import '../library.dart';
import '../reader_data.dart';
import '../reader/presentation/reader.dart';
import '../library/data/book_repository.dart';
import '../reader/settings/reader_preferences.dart';
import '../audio/quran_audio_controller.dart';
import '../settings/settings_page.dart';
import '../trackers/data/tracker_book.dart';
import '../trackers/presentation/trackers_page.dart';

class QuranApp extends StatefulWidget {
  const QuranApp({
    super.key,
    this.data,
    this.repository,
    this.store,
    this.trackerStore,
    this.audioController,
    this.onStartupReady,
  });

  /// Called after the first library or recoverable error frame is laid out.
  /// Only the production entry point defers engine submission, not widget tests.
  final VoidCallback? onStartupReady;
  final Future<ReaderData>? data;
  final BookRepository? repository;
  final ReaderStore? store;
  final TrackerStore? trackerStore;
  final QuranAudioController? audioController;
  @override
  State<QuranApp> createState() => _QuranAppState();
}

class _QuranAppState extends State<QuranApp> {
  bool dark = false, reading = false;
  late final BookRepository repository =
      widget.repository ?? BundledBookRepository();
  late final ReaderStore store =
      widget.store ??
      (widget.data != null
          ? MemoryReaderStore()
          : SharedPreferencesReaderStore());
  LibraryBook? selectedBook;

  /// Bottom navigation: 0 Kitaphana, 1 Hasaplar, 2 Sazlamalar.
  int tab = 0;

  /// Hasaplar storage is read only once its tab is first opened, so startup
  /// and the library never wait for it.
  bool trackersOpened = false;
  late final TrackerBook trackers = TrackerBook(
    store:
        widget.trackerStore ??
        (widget.data != null
            ? MemoryTrackerStore()
            : SharedPreferencesTrackerStore()),
  );

  /// One player for the reader and Sazlamalar, so deleting a recording there
  /// stops it here. Created lazily; its constructor never touches plugins.
  QuranAudioController? ownedAudio;
  QuranAudioController get audio =>
      widget.audioController ?? (ownedAudio ??= QuranAudioController());
  late final PreferenceWriter libraryWriter = PreferenceWriter(
    store,
    '_library',
  );

  bool initializing = true;
  bool initializationFailed = false;
  bool startupNotified = false;
  final loadedBooks = <String, Future<ReaderData>>{};

  Future<ReaderData> loadBook(String id) => loadedBooks.putIfAbsent(id, () {
    final future =
        widget.data ?? Future<ReaderData>.sync(() => repository.load(id));
    // Observe preload failures immediately, even when no reader is mounted.
    // Keep the original failed future for the actionable book error screen.
    future.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return future;
  });

  @override
  void initState() {
    super.initState();
    widget.data?.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    // Start after layout, which also runs while the native first frame is
    // deferred. Never await a submitted/rasterized frame: that would deadlock.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) initialize();
    });
  }

  Future<void> initialize() async {
    setState(() {
      initializing = true;
      initializationFailed = false;
    });
    try {
      final saved = await store.read('_library');
      if (!mounted) return;
      setState(() {
        if (saved?['version'] == 1 && saved?['dark'] is bool) {
          dark = saved!['dark'] as bool;
        }
        initializing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        initializing = false;
        initializationFailed = true;
      });
    }
    // The state change schedules the library/error layout. Release only at its
    // end, never while the pending page is still the current render tree.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!startupNotified) {
        startupNotified = true;
        widget.onStartupReady?.call();
      }
      // Warm validated data only after the themed library has laid out.
      if (!initializationFailed && repository.books.isNotEmpty) {
        loadBook(repository.books.first.id);
      }
    });
  }

  void setTheme(bool value) {
    setState(() => dark = value);
    libraryWriter.schedule({'version': 1, 'dark': dark});
    libraryWriter.flush();
  }

  @override
  void dispose() {
    libraryWriter.dispose();
    trackers.dispose();
    ownedAudio?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xff18685f),
      brightness: dark ? Brightness.dark : Brightness.light,
      surface: dark ? const Color(0xff142320) : const Color(0xfffaf7ef),
    );
    return MaterialApp(
      title: 'Kuran Kitaphanasy',
      debugShowCheckedModeBanner: false,
      // Restored preferences must apply on the first library frame, not fade
      // through the temporary launch palette.
      themeAnimationDuration: Duration.zero,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: scheme.surface,
        appBarTheme: AppBarTheme(
          backgroundColor: scheme.surface,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      home: initializing || initializationFailed
          ? StartupPage(failed: initializationFailed, retry: initialize)
          : IndexedStack(
              index: reading ? 1 : 0,
              children: [
                PopScope(
                  canPop: tab == 0,
                  onPopInvokedWithResult: (didPop, result) {
                    if (!didPop && tab != 0) setState(() => tab = 0);
                  },
                  child: Scaffold(
                    body: IndexedStack(
                      index: tab,
                      children: [
                        LibraryPage(
                          dark: dark,
                          books: repository.books,
                          openBook: (book) => setState(() {
                            selectedBook = book;
                            reading = true;
                          }),
                        ),
                        trackersOpened
                            ? TrackersPage(book: trackers)
                            : const SizedBox.shrink(),
                        SettingsPage(
                          dark: dark,
                          setDark: setTheme,
                          trackers: trackers,
                          audio: () => audio,
                          surahNames: () async =>
                              (await loadBook(repository.books.first.id)).names,
                        ),
                      ],
                    ),
                    bottomNavigationBar: NavigationBar(
                      key: const Key('main-navigation'),
                      selectedIndex: tab,
                      onDestinationSelected: (i) => setState(() {
                        tab = i;
                        if (i == 1) trackersOpened = true;
                      }),
                      destinations: const [
                        NavigationDestination(
                          key: Key('tab-library'),
                          icon: Icon(Icons.auto_stories_outlined),
                          selectedIcon: Icon(Icons.auto_stories),
                          label: 'Kitaphana',
                        ),
                        NavigationDestination(
                          key: Key('tab-trackers'),
                          icon: Icon(Icons.checklist_outlined),
                          selectedIcon: Icon(Icons.checklist),
                          label: 'Hasaplar',
                        ),
                        NavigationDestination(
                          key: Key('tab-settings'),
                          icon: Icon(Icons.settings_outlined),
                          selectedIcon: Icon(Icons.settings),
                          label: 'Sazlamalar',
                        ),
                      ],
                    ),
                  ),
                ),
                if (selectedBook != null)
                  FutureBuilder<ReaderData>(
                    // A different book must not inherit the previous snapshot.
                    key: ValueKey(selectedBook!.id),
                    future: loadBook(selectedBook!.id),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        return Reader(
                          key: ValueKey(selectedBook!.id),
                          bookId: selectedBook!.id,
                          store: store,
                          audioController: audio,
                          data: loadBook(selectedBook!.id),
                          active: reading,
                          goHome: () => setState(() => reading = false),
                        );
                      }
                      // FutureBuilder retains the previous error while a retry waits.
                      final failed =
                          snapshot.connectionState == ConnectionState.done &&
                          snapshot.hasError;
                      final media = MediaQuery.of(context);
                      return PopScope(
                        canPop: !reading,
                        onPopInvokedWithResult: (didPop, result) {
                          if (!didPop && reading) {
                            setState(() => reading = false);
                          }
                        },
                        child: Scaffold(
                          key: Key(
                            failed ? 'reader-load-error' : 'reader-loading',
                          ),
                          body: SafeArea(
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (failed) ...[
                                    const Padding(
                                      padding: EdgeInsets.all(24),
                                      child: Text(
                                        'Maglumat ýüklenmedi. Çaklama tekst görkezilmeýär.',
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    FilledButton(
                                      key: const Key('reader-load-retry'),
                                      onPressed: () => setState(() {
                                        loadedBooks.remove(selectedBook!.id);
                                      }),
                                      child: const Text('Täzeden synanyş'),
                                    ),
                                  ] else
                                    SizedBox(
                                      width: 112,
                                      child: LinearProgressIndicator(
                                        value:
                                            media.disableAnimations ||
                                                media.accessibleNavigation
                                            ? 0
                                            : null,
                                      ),
                                    ),
                                  TextButton(
                                    key: const Key('reader-load-home'),
                                    onPressed: () =>
                                        setState(() => reading = false),
                                    child: const Text('Kitaphana'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
    );
  }
}
