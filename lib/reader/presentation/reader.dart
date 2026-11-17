import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../data/reader_data.dart';
import '../../audio/quran_audio_controller.dart';
import 'surah_opening.dart';
import 'surah_picker_list.dart';
import '../settings/reader_preferences.dart';
import 'page_scroll.dart';
import 'reader_paging.dart';
import 'sajdah_marker.dart';
part '../settings/reader_settings_sheet.dart';
part 'reader_content.dart';
part 'reader_bookmarks.dart';
part 'reader_audio.dart';

class Reader extends StatefulWidget {
  const Reader({
    super.key,
    required this.goHome,
    this.data,
    this.active = true,
    this.bookId = 'quran',
    this.store,
    this.audioController,
  });
  final String bookId;
  final ReaderStore? store;
  final QuranAudioController? audioController;
  final bool active;
  final VoidCallback goHome;
  final Future<ReaderData>? data;
  @override
  State<Reader> createState() => _ReaderState();
}

class _ReaderState extends State<Reader> with WidgetsBindingObserver {
  QuranAudioController? audio;
  bool audioVisible = false, audioOpening = false;
  int audioOpenGeneration = 0, audioTargetSurah = 1, audioTargetAyah = 1;
  Future<void>? audioInitialization, audioClosing;
  String? audioUiError;
  String? spokenRef;
  bool wasAudioPlaying = false;
  int audioFollowGeneration = 0;
  bool audioFollowing = false, audioUserScrolling = false;
  final audioPageIndex = <String, int>{};
  final audioBlockRef = <String, String>{};
  final audioVerseLength = <String, int>{};

  Color? spokenBackground(String ref) => spokenRef == ref
      ? Color.alphaBlend(
          Colors.black.withValues(
            alpha: readerTheme.brightness == Brightness.dark ? .48 : .16,
          ),
          readerTheme.scaffoldBackgroundColor,
        )
      : null;

  void audioChanged() {
    if (!mounted) return;
    final playing = audioVisible && widget.active && audio?.isPlaying == true;
    final ref = playing
        ? (audio!.isOpening ? null : '${audio!.surah}:${audio!.ayah}')
        : spokenRef;
    final follow = playing && (ref != spokenRef || !wasAudioPlaying);
    if (!playing && wasAudioPlaying) audioFollowGeneration++;
    // The panel listens independently; clock/download samples do not change
    // scripture or its geometry. Preserve follow on playback transitions.
    if (ref == spokenRef && playing == wasAudioPlaying) return;
    setState(() {
      if (playing) spokenRef = ref;
      wasAudioPlaying = playing;
    });
    if (follow) queueAudioFollow();
  }

  void queueAudioFollow() {
    final generation = ++audioFollowGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && generation == audioFollowGeneration) {
        unawaited(followSpokenVerse(generation));
      }
    });
  }

  bool validAudioFollow(int generation) =>
      mounted &&
      widget.active &&
      audioVisible &&
      audio?.isPlaying == true &&
      generation == audioFollowGeneration;

  bool audioScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      audioUserScrolling = true;
      audioFollowGeneration++;
    }
    if (notification is ScrollEndNotification && audioUserScrolling) {
      audioUserScrolling = false;
      if (audioVisible && audio?.isPlaying == true) queueAudioFollow();
    }
    return false;
  }

  Future<void> followSpokenVerse(int generation) async {
    final ref = spokenRef;
    final index = audioPageIndex[ref];
    if (ref == null ||
        index == null ||
        !validAudioFollow(generation) ||
        audioUserScrolling) {
      return;
    }
    final data = await source;
    if (!validAudioFollow(generation)) return;
    audioFollowing = true;
    try {
      // Mount an unbuilt source page without changing the user's reading mode.
      if (vertical) {
        final visible = itemPositions.itemPositions.value.any(
          (p) =>
              p.index == index &&
              p.itemTrailingEdge > 0 &&
              p.itemLeadingEdge < 1,
        );
        if (!visible && itemScroll.isAttached) itemScroll.jumpTo(index: index);
      } else if (selected != index && pages.hasClients) {
        await pages.animateToPage(
          index,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      }
      await WidgetsBinding.instance.endOfFrame;
      if (!validAudioFollow(generation)) return;
      final page = data.pages[index];
      final arabic = mode == 'translation' ? null : arabicTargets[ref];
      final ctx =
          arabic?.key.currentContext ??
          bookmarkTargets['${page.id}:${audioBlockRef[ref]}']?.currentContext;
      if (ctx == null || !ctx.mounted) return;
      final render = ctx.findRenderObject();
      if (render is! RenderBox || !render.hasSize) return;
      Rect rect = Offset.zero & render.size;
      if (render is RenderParagraph && arabic != null) {
        final boxes = render.getBoxesForSelection(
          TextSelection(
            baseOffset: arabic.offset,
            extentOffset: arabic.offset + (audioVerseLength[ref] ?? 1),
          ),
        );
        if (boxes.isEmpty) return;
        rect = boxes
            .map((b) => b.toRect())
            .reduce((a, b) => a.expandToInclude(b));
      }
      final scrollable = Scrollable.maybeOf(ctx);
      if (scrollable != null && !scrollable.mounted) return;
      final viewport = (vertical
          ? viewportKey.currentContext?.findRenderObject()
          : scrollable?.context.findRenderObject());
      if (viewport is! RenderBox || !viewport.hasSize) return;
      final top = render.localToGlobal(rect.topLeft).dy;
      final bottom = render.localToGlobal(rect.bottomRight).dy;
      final safeTop = viewport.localToGlobal(Offset.zero).dy + 12;
      final safeBottom =
          viewport.localToGlobal(Offset(0, viewport.size.height)).dy - 12;
      if (top >= safeTop && bottom <= safeBottom) return;
      // Tall source-grouped meals cannot fit: reveal their unchanged beginning.
      final delta = top < safeTop || rect.height > safeBottom - safeTop
          ? top - safeTop
          : bottom - safeBottom;
      if (delta.abs() < 1 || !validAudioFollow(generation)) return;
      if (vertical) {
        await scrollOffset.animateScroll(
          offset: delta,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        );
      } else if (scrollable != null) {
        final position = scrollable.position;
        await position.animateTo(
          (position.pixels + delta).clamp(
            position.minScrollExtent,
            position.maxScrollExtent,
          ),
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        );
      }
    } finally {
      if (mounted) audioFollowing = false;
    }
  }

  void setStateAudioOpening(bool opening) {
    setState(() => audioOpening = opening);
  }

  void setStateAudio(bool visible) {
    if (mounted) {
      setState(() {
        audioVisible = visible;
        audioUiError = null;
        if (!visible) {
          spokenRef = null;
          wasAudioPlaying = false;
          audioFollowGeneration++;
        }
      });
    }
  }

  late final ReaderStore store =
      widget.store ??
      (widget.data != null
          ? MemoryReaderStore()
          : SharedPreferencesReaderStore());
  late final PreferenceWriter writer = PreferenceWriter(store, widget.bookId);
  late final Future<ReaderData> source = restore();
  bool ready = false;
  final bookmarks = <_Bookmark>[];
  _Bookmark? bookmarkFeedback;
  final bookmarkTargets = <String, GlobalKey>{};
  final arabicTargets = <String, _ArabicTarget>{};
  final arabicKeys = <String, GlobalKey>{};
  late final bookmarkWriter = PreferenceWriter(
    store,
    '${widget.bookId}.bookmarks',
  );
  final offsets = <int, double>{};
  bool backgrounded = false;
  int scrollGeneration = 0;
  final itemScroll = ItemScrollController();
  final itemPositions = ItemPositionsListener.create();
  final scrollOffset = ScrollOffsetController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    itemPositions.itemPositions.addListener(trackVisiblePage);
  }

  Future<ReaderData> restore() async {
    final data = await (widget.data ?? ReaderData.load());
    if (!mounted) return data;
    for (var i = 0; i < data.pages.length; i++) {
      final page = data.pages[i];
      for (final block in data.blocksFor(page)) {
        final verses = page.verses.where(block.contains).toList();
        for (final verse in verses) {
          audioPageIndex[verse.key] = i;
          audioBlockRef[verse.key] = verses.first.key;
          audioVerseLength[verse.key] = _arabicVerseLength(verse);
        }
      }
    }
    await restoreBookmarks(data);
    if (!mounted) return data;
    final state = ReaderPreferences.restore(
      await store.read(widget.bookId),
      data.pages.length,
    );
    if (!mounted) return data;
    selected = state.page;
    mode = state.mode;
    vertical = state.vertical;
    bookDark = state.dark;
    arabicSize = state.arabicSize;
    translationSize = state.translationSize;
    alignment = TextAlign.values.firstWhere((a) => a.name == state.alignment);
    offsets.addAll(state.offsets);
    pages.dispose();
    pages = ReaderPageController(initialPage: selected);
    ready = true;
    return data;
  }

  void persist() {
    if (!ready) return;
    writer.schedule(
      ReaderPreferences(
        page: selected,
        mode: mode,
        vertical: vertical,
        dark: bookDark,
        arabicSize: arabicSize,
        translationSize: translationSize,
        alignment: alignment.name,
        offsets: offsets,
      ).toJson(),
    );
  }

  void setBookmarkFeedback(_Bookmark? target) {
    setState(() => bookmarkFeedback = target);
  }

  void changeState(VoidCallback change) {
    setState(change);
    persist();
  }

  void rememberOffset(int id, double value) {
    offsets.remove(id);
    offsets[id] = value;
    while (offsets.length > ReaderPreferences.offsetLimit) {
      offsets.remove(offsets.keys.first);
    }
    persist();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      backgrounded = true;
    } else if (state == AppLifecycleState.resumed && backgrounded) {
      backgrounded = false;
      if (ready) {
        final currentOffset = offsets[selected + 1] ?? 0.0;
        setState(() {
          offsets.clear();
          offsets[selected + 1] = currentOffset;
          scrollGeneration++;
        });
      }
    }
    if (state != AppLifecycleState.resumed) {
      if (audio != null) unawaited(audioAction(audio!.pause));
      persist();
      unawaited(writer.flush());
    }
  }

  PageController pages = ReaderPageController();

  final viewportKey = GlobalKey();

  final sectionKeys = <String, GlobalKey>{};
  final activeSurahNotifier = ValueNotifier<int?>(null);
  int? get activeSurah => activeSurahNotifier.value;
  set activeSurah(int? value) => activeSurahNotifier.value = value;
  bool vertical = false;
  bool fullscreen = false, showFullscreenHint = false;
  Timer? fullscreenHintTimer;

  void setFullscreen(bool value) {
    fullscreenHintTimer?.cancel();
    changeState(() {
      fullscreen = value;
      showFullscreenHint = value;
    });
    unawaited(
      SystemChrome.setEnabledSystemUIMode(
        value ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
      ),
    );
    if (value) {
      fullscreenHintTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) changeState(() => showFullscreenHint = false);
      });
    }
  }

  @override
  void didUpdateWidget(covariant Reader oldWidget) {
    super.didUpdateWidget(oldWidget);
    // IndexedStack retains this reader when returning to the library.
    if (!widget.active) {
      closeAudio();
      if (fullscreen) setFullscreen(false);
      persist();
      unawaited(writer.flush());
    }
  }

  bool? bookDark;
  double arabicSize = 34, translationSize = 20;
  TextAlign alignment = TextAlign.justify;

  ThemeData? cachedReaderTheme, cachedInheritedTheme;
  bool? cachedBookDark;

  ThemeData get readerTheme {
    final inherited = Theme.of(context);
    if (bookDark == null) return inherited;
    if (cachedReaderTheme != null &&
        identical(cachedInheritedTheme, inherited) &&
        cachedBookDark == bookDark) {
      return cachedReaderTheme!;
    }
    cachedInheritedTheme = inherited;
    cachedBookDark = bookDark;
    final dark = bookDark!;
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xff18685f),
      brightness: dark ? Brightness.dark : Brightness.light,
      surface: dark ? const Color(0xff142320) : const Color(0xfffaf7ef),
    );
    return cachedReaderTheme = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  void trackActiveSurah() {
    if (!mounted) return;
    for (final entry in sectionKeys.entries) {
      if (!entry.key.startsWith('${selected + 1}:')) continue;
      final section = entry.value.currentContext;
      if (section == null) continue;
      final box = section.findRenderObject() as RenderBox?;
      final viewport =
          (vertical
                  ? viewportKey.currentContext?.findRenderObject()
                  : Scrollable.maybeOf(section)?.context.findRenderObject())
              as RenderBox?;
      if (box == null || viewport == null || !box.hasSize) continue;
      final top = viewport.localToGlobal(Offset.zero).dy + 20;
      final y = box.localToGlobal(Offset.zero).dy;
      if (y + box.size.height > top) {
        final id = int.parse(entry.key.split(':').last);
        if (activeSurah != id) activeSurah = id;
        return;
      }
    }
  }

  void trackVisiblePage() {
    if (!vertical || !mounted) return;
    final visible =
        itemPositions.itemPositions.value
            .where((p) => p.itemTrailingEdge > 0 && p.itemLeadingEdge < 1)
            .toList()
          ..sort((a, b) => a.index.compareTo(b.index));
    if (visible.isEmpty) return;
    final first = visible.first;
    if (selected != first.index) {
      changeState(() {
        selected = first.index;
        activeSurah = null;
      });
    }
    final box = viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null) {
      rememberOffset(
        selected + 1,
        (-first.itemLeadingEdge * box.size.height).clamp(0, double.infinity),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => trackActiveSurah());
  }

  void changeOrientation(bool value) {
    if (vertical == value) return;
    final target = selected;
    changeState(() {
      vertical = value;
      if (!value) {
        pages.dispose();
        pages = ReaderPageController(initialPage: target);
      }
    });
  }

  int selected = 0;
  String mode = 'both';
  @override
  void dispose() {
    audioOpenGeneration++;
    audio?.removeListener(audioChanged);
    if (audio != null) {
      if (widget.audioController == null) {
        audio!.dispose();
      } else {
        unawaited(audio!.close());
      }
    }
    fullscreenHintTimer?.cancel();
    if (fullscreen) {
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    }
    pages.dispose();
    WidgetsBinding.instance.removeObserver(this);
    itemPositions.itemPositions.removeListener(trackVisiblePage);
    activeSurahNotifier.dispose();
    persist();
    writer.dispose();
    bookmarkWriter.dispose();
    super.dispose();
  }

  void go(int index) {
    if (vertical) {
      if (itemScroll.isAttached) itemScroll.jumpTo(index: index);
      changeState(() {
        selected = index;
        activeSurah = null;
      });
    } else if (pages.hasClients) {
      pages.jumpToPage(index);
    }
  }

  void sheet(
    String title,
    Widget body, {
    required String key,
    bool fitContent = false,
  }) {
    final theme = readerTheme;
    final isSurahSheet = key == 'surah-sheet';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: theme.colorScheme.surface,
      builder: (ctx) {
        final keyboard = isSurahSheet
            ? MediaQuery.viewInsetsOf(ctx).bottom
            : 0.0;
        return Theme(
          data: theme,
          child: DefaultTextStyle.merge(
            style: theme.textTheme.bodyMedium!.copyWith(
              color: theme.colorScheme.onSurface,
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(bottom: keyboard),
                child: Container(
                  key: Key(key),
                  constraints: BoxConstraints(
                    maxHeight: (MediaQuery.sizeOf(ctx).height - keyboard) * .72,
                  ),
                  height: fitContent
                      ? null
                      : (MediaQuery.sizeOf(ctx).height - keyboard) * .72,
                  child: Column(
                    mainAxisSize: fitContent
                        ? MainAxisSize.min
                        : MainAxisSize.max,
                    children: [
                      Container(
                        key: isSurahSheet
                            ? const Key('surah-sheet-header')
                            : null,
                        color: isSurahSheet
                            ? surahNavigationBackground(theme)
                            : null,
                        padding: isSurahSheet
                            ? const EdgeInsets.fromLTRB(16, 4, 6, 0)
                            : const EdgeInsets.fromLTRB(20, 8, 8, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: isSurahSheet
                                    ? theme.textTheme.titleMedium?.copyWith(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      )
                                    : theme.textTheme.titleLarge,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Ýap',
                              onPressed: () => Navigator.pop(ctx),
                              icon: Icon(
                                Icons.close,
                                size: isSurahSheet ? 20 : 24,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Flexible(
                        fit: fitContent ? FlexFit.loose : FlexFit.tight,
                        child: body,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void detail(String title, String text, {bool footnote = false}) => sheet(
    title,
    SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Text(
        // Presentation-only: preserve every stored source character unchanged.
        footnote ? text.replaceFirst(RegExp(r'^\s*Düşündiriş:\s*'), '') : text,
        style: const TextStyle(
          fontFamily: 'NotoSerif',
          fontSize: 18,
          height: 1.7,
        ),
      ),
    ),
    key: 'detail-sheet',
    fitContent: footnote,
  );
  void surahs(ReaderData data) => sheet(
    'Süreler',
    SurahPickerList(
      data: data,
      selectedSurah: activeSurah ?? data.pages[selected].verses.first.surah,
      onSelected: (id) {
        Navigator.pop(context);
        final target = data.startPage(id);
        go(target);
        changeState(() => activeSurah = id);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final section =
              sectionKeys['${data.pages[target].id}:$id']?.currentContext;
          if (section != null) Scrollable.ensureVisible(section);
        });
      },
    ),
    key: 'surah-sheet',
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !widget.active,
    onPopInvokedWithResult: (didPop, result) {
      if (didPop || !widget.active) return;
      if (fullscreen) {
        setFullscreen(false);
      } else {
        unawaited(returnToLibrary());
      }
    },
    child: Theme(
      data: readerTheme,
      child: Builder(
        builder: (context) => FutureBuilder<ReaderData>(
          future: source,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Scaffold(
                body: SafeArea(
                  child: Center(
                    child: snapshot.hasError
                        ? const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Maglumat ýüklenmedi. Kitabyň tassyklanan maglumatlary elýeterli däl. Çaklama tekst görkezilmeýär.',
                              key: Key('data-error'),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : const CircularProgressIndicator(),
                  ),
                ),
                bottomNavigationBar: SafeArea(
                  child: Align(
                    heightFactor: 1,
                    alignment: Alignment.centerRight,
                    child: homeButton(),
                  ),
                ),
              );
            }
            final data = snapshot.data!, page = data.pages[selected];

            final dark = Theme.of(context).brightness == Brightness.dark;
            final chromeColor = dark
                ? const Color(0xFF293632)
                : const Color(0xFFEDE5D7);
            final separatorColor = dark
                ? const Color(0xFF52635B)
                : const Color(0xFFD0C3AD);
            final chromeShadow = Colors.black.withValues(
              alpha: dark ? 0.20 : 0.08,
            );
            const labels = {
              'both': 'Arapça + Türkmençe',
              'arabic': 'Arapça',
              'translation': 'Türkmençe',
            };
            return Scaffold(
              appBar: fullscreen
                  ? null
                  : AppBar(
                      backgroundColor: chromeColor,
                      surfaceTintColor: Colors.transparent,
                      elevation: 2,
                      scrolledUnderElevation: 2,
                      shadowColor: chromeShadow,
                      shape: Border(
                        bottom: BorderSide(color: separatorColor, width: 0.8),
                      ),
                      titleSpacing: 12,
                      toolbarHeight: 76,
                      title: ValueListenableBuilder<int?>(
                        valueListenable: activeSurahNotifier,
                        builder: (context, active, _) {
                          final surah = active ?? page.verses.first.surah;
                          return Row(
                            children: [
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            '$surah. ${data.names[surah]} süresi',
                                            key: const Key('surah-title'),
                                            textAlign: TextAlign.left,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          key: const Key('surah-info'),
                                          tooltip: 'Süre barada maglumat',
                                          onPressed: () => detail(
                                            data.names[surah]!,
                                            data.descriptions[surah]!,
                                          ),
                                          icon: const Icon(
                                            Icons.info_outline,
                                            size: 20,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      'Sahypa ${selected + 1} (${selected + 1}/${data.pages.length})',
                                      key: const Key('page-counter'),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              PopupMenuButton<String>(
                                key: const Key('mode-dropdown'),
                                tooltip: labels[mode],
                                initialValue: mode,
                                onSelected: (value) =>
                                    changeState(() => mode = value),
                                itemBuilder: (_) => [
                                  for (final e in labels.entries)
                                    PopupMenuItem(
                                      key: Key('mode-${e.key}'),
                                      value: e.key,
                                      child: Text(e.value),
                                    ),
                                ],
                                child: SizedBox(
                                  width: 140,
                                  height: 72,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          labels[mode]!,
                                          maxLines: 2,
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ),
                                      const Icon(Icons.arrow_drop_down),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
              // A stable subtree preserves each scrollable across chrome changes.
              body: NotificationListener<ScrollNotification>(
                onNotification: audioScrollNotification,
                child: GestureDetector(
                  key: const Key('reader-gestures'),
                  behavior: HitTestBehavior.translucent,
                  onDoubleTap: fullscreen ? () => setFullscreen(false) : null,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Column(
                        children: [
                          Expanded(
                            child: vertical
                                ? SizedBox(
                                    key: viewportKey,
                                    child: LayoutBuilder(
                                      builder: (context, constraints) =>
                                          ScrollablePositionedList.builder(
                                            key: const Key('vertical-pages'),
                                            itemScrollController: itemScroll,
                                            itemPositionsListener:
                                                itemPositions,
                                            scrollOffsetController:
                                                scrollOffset,
                                            initialScrollIndex: selected,
                                            initialAlignment:
                                                -(offsets[selected + 1] ?? 0) /
                                                constraints.maxHeight,
                                            itemCount: data.pages.length,
                                            minCacheExtent: 0,
                                            itemBuilder: (_, i) => Center(
                                              child: ConstrainedBox(
                                                constraints:
                                                    const BoxConstraints(
                                                      maxWidth: 900,
                                                    ),
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.fromLTRB(
                                                        20,
                                                        16,
                                                        20,
                                                        0,
                                                      ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .stretch,
                                                    children: [
                                                      pageContent(
                                                        data.pages[i],
                                                        data,
                                                      ),
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                              bottom: 16,
                                                            ),
                                                        child: Text(
                                                          'Sahypa ${i + 1}',
                                                          key: Key(
                                                            'page-end-${data.pages[i].id}',
                                                          ),
                                                          textAlign:
                                                              TextAlign.center,
                                                          style:
                                                              Theme.of(context)
                                                                  .textTheme
                                                                  .labelMedium,
                                                        ),
                                                      ),
                                                      Divider(
                                                        key: Key(
                                                          'page-divider-${data.pages[i].id}',
                                                        ),
                                                        thickness: .8,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                    ),
                                  )
                                : PageView.builder(
                                    key: const Key('quran-pages'),
                                    controller: pages,
                                    // Türkmen-only follows ordinary LTR books;
                                    // Arabic-containing modes retain RTL paging.
                                    reverse: mode != 'translation',
                                    scrollDirection: Axis.horizontal,
                                    itemCount: data.pages.length,
                                    onPageChanged: (i) => changeState(() {
                                      selected = i;
                                      activeSurah = null;
                                    }),
                                    itemBuilder: (_, i) =>
                                        pageBody(data.pages[i], data),
                                  ),
                          ),
                        ],
                      ),
                      if (showFullscreenHint)
                        Positioned(
                          left: 20,
                          right: 20,
                          bottom: 24,
                          child: IgnorePointer(
                            child: SafeArea(
                              child: Material(
                                color: chromeColor,
                                borderRadius: BorderRadius.circular(8),
                                elevation: 2,
                                child: const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Text(
                                    'Doly ekrandan çykmak üçin ekrana iki gezek basyň.',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              bottomNavigationBar: fullscreen
                  ? null
                  : DecoratedBox(
                      key: const Key('reader-bottom-chrome'),
                      decoration: BoxDecoration(
                        color: audioVisible && audio != null
                            ? readerTheme.colorScheme.surfaceContainer
                            : chromeColor,
                        border: Border(
                          top: BorderSide(color: separatorColor, width: 0.8),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: chromeShadow,
                            blurRadius: 8,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: SafeArea(
                        top: false,
                        child: Padding(
                          padding: audioVisible && audio != null
                              ? EdgeInsets.zero
                              : const EdgeInsets.symmetric(horizontal: 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (audioVisible && audio != null)
                                ListenableBuilder(
                                  listenable: audio!,
                                  builder: (_, _) => audioPanel(data),
                                )
                              else
                                Row(
                                  children: [
                                    IconButton(
                                      key: const Key('reader-fullscreen'),
                                      tooltip: 'Doly ekran',
                                      onPressed: () => setFullscreen(true),
                                      icon: const Icon(Icons.fullscreen),
                                    ),
                                    IconButton(
                                      key: const Key('reader-settings'),
                                      tooltip: 'Sazlamalar',
                                      onPressed: () => settings(data),
                                      icon: const Icon(Icons.settings_outlined),
                                    ),
                                    IconButton(
                                      key: const Key('surah-menu'),
                                      tooltip: 'Süreler',
                                      onPressed: () => surahs(data),
                                      icon: const Icon(Icons.list_alt_outlined),
                                    ),
                                    IconButton(
                                      key: const Key('bookmarks-menu'),
                                      tooltip: 'Bellikler',
                                      onPressed: () => showBookmarks(data),
                                      icon: const Icon(
                                        Icons.bookmarks_outlined,
                                      ),
                                    ),
                                    IconButton(
                                      key: const Key('audio-menu'),
                                      tooltip: 'Ses diňle',
                                      onPressed: () {
                                        final surah =
                                            activeSurah ??
                                            page.verses.first.surah;
                                        final verse = page.verses.firstWhere(
                                          (v) => v.surah == surah,
                                          orElse: () => page.verses.first,
                                        );
                                        unawaited(
                                          openAudio(verse.surah, verse.ayah),
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.headphones_outlined,
                                      ),
                                    ),
                                    const Spacer(),
                                    homeButton(),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
            );
          },
        ),
      ),
    ),
  );
  Future<void> returnToLibrary() async {
    closeAudio();
    persist();
    await writer.flush();
    if (mounted && widget.active) widget.goHome();
  }

  Widget homeButton() => IconButton(
    key: const Key('back-library'),
    tooltip: 'Kitaphana dolan',
    onPressed: returnToLibrary,
    icon: const Icon(Icons.home_outlined),
  );
}
