part of 'reader.dart';

class _Bookmark {
  const _Bookmark(this.name, this.page, this.surah, this.ayah, this.mode);
  final String name, mode;
  final int page, surah, ayah;
  String get ref => '$surah:$ayah';
  String get id => '$page:$ref:$mode:$name';
  Map<String, dynamic> toJson() => {
    'name': name,
    'page': page,
    'surah': surah,
    'ayah': ayah,
    'mode': mode,
  };
}

extension _ReaderBookmarks on _ReaderState {
  Future<void> restoreBookmarks(ReaderData data) async {
    final raw = await store.read('${widget.bookId}.bookmarks');
    if (raw?['version'] != 1 || raw?['items'] is! List) return;
    for (final row in raw!['items'] as List) {
      if (row is! Map ||
          row['name'] is! String ||
          (row['name'] as String).trim().isEmpty ||
          (row['name'] as String).length > 100 ||
          row['page'] is! int ||
          row['surah'] is! int ||
          row['ayah'] is! int ||
          !['both', 'translation', 'arabic'].contains(row['mode'])) {
        continue;
      }
      final b = _Bookmark(
        row['name'],
        row['page'],
        row['surah'],
        row['ayah'],
        row['mode'],
      );
      if (data.pages.any(
            (p) => p.id == b.page && p.verses.any((v) => v.key == b.ref),
          ) &&
          !bookmarks.any((v) => v.id == b.id)) {
        bookmarks.add(b);
      }
    }
  }

  Future<void> saveBookmarks() async {
    bookmarkWriter.schedule({
      'version': 1,
      'items': bookmarks.map((b) => b.toJson()).toList(),
    });
    await bookmarkWriter.flush();
    if (mounted && bookmarkWriter.lastError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bellik saklanmady. Gaýtadan synanyşyň.')),
      );
    }
  }

  Future<void> chooseBookmark(_Bookmark target) async {
    unawaited(HapticFeedback.mediumImpact());
    setBookmarkFeedback(target);
    final data = await source;
    if (!mounted) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: readerTheme.colorScheme.surface,
      builder: (ctx) => Theme(
        data: readerTheme,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              key: const Key('verse-actions'),
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${data.names[target.surah]} · ${target.surah}:${target.ayah}',
                  style: readerTheme.textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        key: const Key('verse-bookmarks'),
                        onPressed: () => Navigator.pop(ctx, 'bookmark'),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bookmark_outline, size: 30),
                            SizedBox(height: 8),
                            Text('Bellikler'),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextButton(
                        key: const Key('verse-listen'),
                        onPressed: () => Navigator.pop(ctx, 'audio'),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.play_circle_outline, size: 30),
                            SizedBox(height: 8),
                            Text('Aýaty diňle'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'audio') {
      await openAudio(target.surah, target.ayah, autoplay: true);
      return;
    }
    if (action != 'bookmark') return;
    await bookmarkChooser(target);
  }

  Future<void> bookmarkChooser(_Bookmark target) async {
    final selected = await showModalBottomSheet<Object>(
      context: context,
      backgroundColor: readerTheme.colorScheme.surface,
      builder: (ctx) => Theme(
        data: readerTheme,
        child: SafeArea(
          child: Column(
            key: const Key('bookmark-chooser'),
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Bellik saýla'),
                trailing: IconButton(
                  key: const Key('bookmark-add'),
                  tooltip: 'Bellik goş',
                  icon: const Icon(Icons.add),
                  onPressed: () => Navigator.pop(ctx, true),
                ),
              ),
              if (bookmarks.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Täze bellik goşmak üçin + basyň.'),
                ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final b in bookmarks)
                      ListTile(
                        title: Text(b.name),
                        subtitle: Text(
                          '${b.surah}:${b.ayah} · Sahypa ${b.page}',
                        ),
                        onTap: () => Navigator.pop(ctx, b),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (selected == true) {
      await editBookmark(target);
    } else if (selected is _Bookmark) {
      final index = bookmarks.indexOf(selected);
      if (index < 0) return;
      changeState(
        () => bookmarks[index] = _Bookmark(
          selected.name,
          target.page,
          target.surah,
          target.ayah,
          target.mode,
        ),
      );
      await saveBookmarks();
    }
  }

  Widget bookmarkFeedbackSurface(
    Widget child,
    String? ref, {
    List<Rect> Function()? rectangles,
  }) => Stack(
    children: [
      child,
      if (ref != null)
        Positioned.fill(
          child: IgnorePointer(
            child: TweenAnimationBuilder<double>(
              key: Key('bookmark-feedback-$ref'),
              tween: Tween(begin: 1, end: 0),
              duration: const Duration(milliseconds: 850),
              onEnd: () {
                if (mounted && bookmarkFeedback?.ref == ref) {
                  setBookmarkFeedback(null);
                }
              },
              builder: (_, value, _) => CustomPaint(
                painter: _BookmarkHighlightPainter(
                  readerTheme.colorScheme.primary.withValues(
                    alpha: .32 * value,
                  ),
                  rectangles,
                ),
              ),
            ),
          ),
        ),
    ],
  );

  Future<void> editBookmark(_Bookmark target) async {
    final index = bookmarks.indexOf(target);
    final existing = index < 0 ? null : bookmarks[index];
    final controller = TextEditingController(text: existing?.name ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => Theme(
        data: readerTheme,
        child: AlertDialog(
          title: Text(existing == null ? 'Bellik goş' : 'Adyny üýtget'),
          content: TextField(
            key: const Key('bookmark-name'),
            controller: controller,
            autofocus: true,
            maxLength: 100,
            decoration: const InputDecoration(labelText: 'Belligiň ady'),
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) Navigator.pop(ctx, value.trim());
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Ýatyr'),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  Navigator.pop(ctx, controller.text.trim());
                }
              },
              child: const Text('Ýatda sakla'),
            ),
          ],
        ),
      ),
    );
    // Dialog route teardown may still reference the controller during its exit animation.
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (name == null || !mounted) return;
    changeState(() {
      final b = _Bookmark(
        name,
        target.page,
        target.surah,
        target.ayah,
        target.mode,
      );
      if (index < 0) {
        bookmarks.add(b);
      } else {
        bookmarks[index] = b;
      }
    });
    await saveBookmarks();
  }

  bool marked(Iterable<QuranVerse> verses) =>
      verses.any((v) => bookmarks.any((b) => b.ref == v.key));
  Widget bookmarkIcon(String ref) => Icon(
    Icons.bookmark,
    key: Key('bookmark-icon-$ref'),
    size: 14,
    color: readerTheme.colorScheme.primary,
    semanticLabel: 'Bellik',
  );

  Widget bookmarkBlock(QuranPage page, TranslationBlock block, Widget child) {
    // A grouped meal may continue across source pages. Anchor this occurrence
    // to its first actual verse without splitting or rewriting the meal.
    final first = page.verses.firstWhere(block.contains);
    final ref = first.key;
    final key = bookmarkTargets.putIfAbsent('${page.id}:$ref', GlobalKey.new);
    return GestureDetector(
      key: key,
      behavior: HitTestBehavior.translucent,
      onLongPress: () =>
          chooseBookmark(_Bookmark('', page.id, first.surah, first.ayah, mode)),
      child: bookmarkFeedbackSurface(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (marked(page.verses.where(block.contains)))
              Align(alignment: Alignment.centerRight, child: bookmarkIcon(ref)),
            child,
          ],
        ),
        bookmarkFeedback?.page == page.id && bookmarkFeedback?.ref == ref
            ? ref
            : null,
      ),
    );
  }

  void showBookmarks(ReaderData data) => sheet(
    'Bellikler',
    StatefulBuilder(
      builder: (ctx, update) => bookmarks.isEmpty
          ? const Center(
              child: Text(
                'Entek bellik ýok.\nBellik goşmak üçin aýaty basyp saklaň.',
                textAlign: TextAlign.center,
              ),
            )
          : ListView(
              children: [
                for (final b in List<_Bookmark>.of(bookmarks))
                  ListTile(
                    key: Key('saved-bookmark-${b.id}'),
                    title: Text(b.name),
                    subtitle: Text(
                      '${data.names[b.surah]} · ${b.ayah}-nji aýat · Sahypa ${b.page}',
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      jumpToBookmark(b, data);
                    },
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Adyny üýtget',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () async {
                            await editBookmark(b);
                            if (ctx.mounted) update(() {});
                          },
                        ),
                        IconButton(
                          tooltip: 'Poz',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            final remove = await showDialog<bool>(
                              context: ctx,
                              builder: (c) => Theme(
                                data: readerTheme,
                                child: AlertDialog(
                                  title: const Text('Belligi pozmalymy?'),
                                  content: Text(b.name),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(c, false),
                                      child: const Text('Ýatyr'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(c, true),
                                      child: const Text('Poz'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                            if (remove == true && mounted) {
                              changeState(
                                () =>
                                    bookmarks.removeWhere((v) => v.id == b.id),
                              );
                              await saveBookmarks();
                              if (ctx.mounted) update(() {});
                            }
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    ),
    key: 'bookmarks-sheet',
  );

  Future<void> jumpToBookmark(_Bookmark b, ReaderData data) async {
    changeState(() => mode = b.mode);
    go(data.pages.indexWhere((p) => p.id == b.page));
    // Lazy page navigation first mounts the destination, then exact content can be revealed.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    if (b.mode != 'arabic') {
      final target = bookmarkTargets['${b.page}:${b.ref}']?.currentContext;
      if (target != null && target.mounted) {
        // Align the beginning, not a percentage of a potentially very tall
        // grouped translation (which would put its first lines off-screen).
        await Scrollable.ensureVisible(target, alignment: 0);
      }
    } else {
      final entry = arabicTargets[b.ref];
      final ctx = entry?.key.currentContext;
      if (ctx == null || !ctx.mounted) return;
      final rich = ctx.findRenderObject();
      if (rich is! RenderParagraph) return;
      final boxes = rich.getBoxesForSelection(
        TextSelection(
          baseOffset: entry!.offset,
          extentOffset: entry.offset + 1,
        ),
      );
      if (boxes.isEmpty) return;
      final rect = boxes.first.toRect();
      final scrollable = Scrollable.maybeOf(ctx);
      if (scrollable != null) {
        final viewport = RenderAbstractViewport.of(rich);
        final offset = viewport.getOffsetToReveal(rich, .05, rect: rect).offset;
        scrollable.position.jumpTo(
          offset.clamp(
            scrollable.position.minScrollExtent,
            scrollable.position.maxScrollExtent,
          ),
        );
      }
    }
  }
}

class _BookmarkHighlightPainter extends CustomPainter {
  const _BookmarkHighlightPainter(this.color, this.rectangles);
  final Color color;
  final List<Rect> Function()? rectangles;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (final rect in rectangles?.call() ?? [Offset.zero & size]) {
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(_BookmarkHighlightPainter oldDelegate) =>
      color != oldDelegate.color || rectangles != oldDelegate.rectangles;
}

class _ArabicTarget {
  const _ArabicTarget(this.key, this.offset);
  final GlobalKey key;
  final int offset;
}
