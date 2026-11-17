part of 'reader.dart';

// Native marker text is shared by rendering and UTF-16 selection indexing.
// Keep NBSP/RLM and the trailing paragraph separator exactly as rendered.
String _arabicMarker(int ayah) =>
    '\u00a0\u200f﴿${ayah.toString().split('').map((d) => '٠١٢٣٤٥٦٧٨٩'[int.parse(d)]).join()}﴾\u200f';
int _arabicVerseLength(QuranVerse verse) =>
    verse.text.length + _arabicMarker(verse.ayah).length + 1;

extension _ReaderContent on _ReaderState {
  TextSpan arabic(Iterable<QuranVerse> verses) => TextSpan(
    children: [
      for (final v in verses) ...[
        TextSpan(
          text: v.text,
          style: TextStyle(backgroundColor: spokenBackground(v.key)),
        ),
        TextSpan(
          text: _arabicMarker(v.ayah),
          semanticsLabel: '${v.ayah}-nji aýat',
          style: TextStyle(
            fontFamily: 'DiyanetMarkers',
            fontSize: 22,
            color: readerTheme.colorScheme.primary,
            backgroundColor: spokenBackground(v.key),
          ),
        ),
        const TextSpan(text: ' '),
      ],
    ],
  );
  Widget arabicText(
    Iterable<QuranVerse> source,
    String key, {
    bool continuous = false,
  }) {
    final verses = source.toList();
    final paragraphKey = arabicKeys.putIfAbsent(key, GlobalKey.new);
    final spans = <InlineSpan>[];
    var offset = 0;
    for (final verse in verses) {
      arabicTargets[verse.key] = _ArabicTarget(paragraphKey, offset);
      final span = arabic([verse]);
      spans.add(span);
      offset += _arabicVerseLength(verse);
      if (continuous && marked([verse])) {
        spans.add(WidgetSpan(child: bookmarkIcon(verse.key)));
        offset++;
      }
    }
    final text = KeyedSubtree(
      key: paragraphKey,
      child: Text.rich(
        TextSpan(children: spans),
        key: Key(key),
        textDirection: TextDirection.rtl,
        textAlign: continuous ? alignment : TextAlign.right,
        style: TextStyle(
          fontFamily: 'DiyanetAmasya',
          fontSize: arabicSize,
          height: 2,
        ),
      ),
    );
    final activeIndex = verses.indexWhere((v) => v.key == spokenRef);
    final Widget paintedText = CustomPaint(
      key: activeIndex >= 0 ? Key('spoken-highlight-$spokenRef') : null,
      painter: activeIndex < 0
          ? null
          : _SpokenVerseBackground(spokenBackground(spokenRef!)!, () {
              final render = paragraphKey.currentContext?.findRenderObject();
              if (render is! RenderParagraph || !render.hasSize) return [];
              final start = arabicTargets[verses[activeIndex].key]!.offset;
              final end = start + _arabicVerseLength(verses[activeIndex]) - 1;
              return render
                  .getBoxesForSelection(
                    TextSelection(baseOffset: start, extentOffset: end),
                    boxHeightStyle: ui.BoxHeightStyle.max,
                  )
                  .map((box) => box.toRect())
                  .toList();
            }),
      child: text,
    );
    if (!continuous) return paintedText;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPressStart: (details) async {
        final render = paragraphKey.currentContext?.findRenderObject();
        if (render is! RenderParagraph) return;
        final position = render
            .getPositionForOffset(render.globalToLocal(details.globalPosition))
            .offset;
        final verse = verses.lastWhere(
          (v) => arabicTargets[v.key]!.offset <= position,
          orElse: () => verses.first,
        );
        final data = await this.source;
        if (!mounted) return;
        final page = data.pages.firstWhere(
          (p) => p.verses.any((v) => v.key == verse.key),
        );
        await chooseBookmark(
          _Bookmark('', page.id, verse.surah, verse.ayah, 'arabic'),
        );
      },
      child: bookmarkFeedbackSurface(
        paintedText,
        verses.any((v) => v.key == bookmarkFeedback?.ref)
            ? bookmarkFeedback?.ref
            : null,
        rectangles: () {
          final render = paragraphKey.currentContext?.findRenderObject();
          final index = verses.indexWhere(
            (v) => v.key == bookmarkFeedback?.ref,
          );
          if (render is! RenderParagraph || index < 0) return [];
          final start = arabicTargets[verses[index].key]!.offset;
          final end = index + 1 < verses.length
              ? arabicTargets[verses[index + 1].key]!.offset
              : offset;
          return render
              .getBoxesForSelection(
                TextSelection(baseOffset: start, extentOffset: end),
              )
              .map((box) => box.toRect())
              .toList();
        },
      ),
    );
  }

  /// Keep ordinary verses continuous. Split only at source-backed annotations,
  /// so the label precedes the precise Arabic verse, even in grouped meal blocks.
  Widget annotatedArabic(
    Iterable<QuranVerse> source,
    String key,
    ReaderData data, {
    bool continuous = false,
  }) {
    final verses = source.toList();
    if (!verses.any((v) => data.sajdahMarkers.contains(v.key))) {
      return arabicText(verses, key, continuous: continuous);
    }
    final children = <Widget>[];
    var run = <QuranVerse>[];
    var runKey = key;
    void flush() {
      if (run.isNotEmpty) {
        children.add(arabicText(run, runKey, continuous: continuous));
        run = [];
      }
    }

    for (final verse in verses) {
      if (data.sajdahMarkers.contains(verse.key)) {
        flush();
        children.add(
          SajdahMarker(key: Key('sajdah-${verse.key}'), reference: verse.key),
        );
        runKey = '$key-sajdah-${verse.key}';
      }
      run.add(verse);
    }
    flush();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget translation(TranslationBlock block, ReaderData data) => Text.rich(
    TextSpan(
      children: [
        if (mode == 'translation')
          TextSpan(
            text: '${block.range}. ',
            style: TextStyle(
              fontSize: translationSize + 2,
              fontWeight: FontWeight.bold,
            ),
          ),
        TextSpan(text: block.text),
        for (final id in block.footnoteIds)
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: TextButton(
              key: Key('note-$id'),
              onPressed: () =>
                  detail('Düşündiriş', data.footnotes[id]!, footnote: true),
              style: TextButton.styleFrom(
                foregroundColor: readerTheme.brightness == Brightness.dark
                    ? const Color(0xffffb46e)
                    : const Color(0xffa74300),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.standard,
                textStyle: TextStyle(
                  fontFamily: 'NotoSerif',
                  fontSize: translationSize,
                  fontWeight: FontWeight.w400,
                  height: 1.7,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('Düşündiriş'),
            ),
          ),
      ],
    ),
    key: Key('translation-${block.id}'),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.left,
    style: TextStyle(
      fontFamily: 'NotoSerif',
      fontSize: translationSize,
      fontWeight: FontWeight.w400,
      height: 1.7,
      backgroundColor:
          mode == 'translation' &&
              spokenRef != null &&
              spokenRef!.split(':').first == '${block.surah}' &&
              int.parse(spokenRef!.split(':').last) >= block.fromAyah &&
              int.parse(spokenRef!.split(':').last) <= block.toAyah
          ? spokenBackground(spokenRef!)
          : null,
    ),
  );
  Widget pageBody(QuranPage page, ReaderData data) =>
      NotificationListener<ScrollNotification>(
        onNotification: (_) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => trackActiveSurah(),
          );
          return false;
        },
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ReaderPageScroll(
              key: ValueKey('page-state-${page.id}'),
              generation: scrollGeneration,
              pageId: page.id,
              initialOffset: offsets[page.id] ?? 0,
              onOffset: (value) => rememberOffset(page.id, value),
              child: pageContent(page, data),
            ),
          ),
        ),
      );
  Widget pageContent(QuranPage page, ReaderData data) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        sectionKeys.removeWhere((_, key) => key.currentContext == null);
        bookmarkTargets.removeWhere((_, key) => key.currentContext == null);
        arabicKeys.removeWhere((_, key) => key.currentContext == null);
        arabicTargets.removeWhere(
          (_, target) => target.key.currentContext == null,
        );
        // A restored nonzero offset need not emit a ScrollNotification. Derive
        // the visible section after first layout too, before opening audio.
        trackActiveSurah();
      }
    });
    return Column(
      key: Key('reading-surface-${page.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final surah in page.verses.map((v) => v.surah).toSet())
          Column(
            key: sectionKeys.putIfAbsent('${page.id}:$surah', GlobalKey.new),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (page.verses.any((v) => v.surah == surah && v.ayah == 1))
                SurahOpening(
                  start: page.verses.firstWhere((v) => v.surah == surah),
                  data: data,
                  showArabic: mode != 'translation',
                ),
              if (mode == 'arabic')
                annotatedArabic(
                  page.verses.where((v) => v.surah == surah),
                  surah == page.verses.first.surah
                      ? 'arabic-flow-${page.id}'
                      : 'arabic-flow-${page.id}-$surah',
                  data,
                  continuous: true,
                )
              else
                for (final b
                    in data.blocksFor(page).where((b) => b.surah == surah))
                  bookmarkBlock(
                    page,
                    b,
                    Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (mode == 'both') ...[
                            annotatedArabic(
                              page.verses.where(b.contains),
                              'arabic-${b.id}',
                              data,
                            ),
                            Text(
                              '${b.range}. AÝAT',
                              style: TextStyle(
                                fontSize: 11,
                                color: readerTheme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                          if (mode == 'translation')
                            for (var a = b.fromAyah; a <= b.toAyah; a++)
                              if (data.sajdahMarkers.contains('${b.surah}:$a'))
                                SajdahMarker(
                                  key: Key('sajdah-${b.surah}:$a'),
                                  reference: '${b.surah}:$a',
                                  showReference: true,
                                ),
                          translation(b, data),
                        ],
                      ),
                    ),
                  ),
            ],
          ),
      ],
    );
  }
}

/// Paint the selection using the paragraph's full line metrics rather than
/// each font run's glyph height: the smaller marker retains its typography,
/// while its dark band matches the Arabic body on the same line.
class _SpokenVerseBackground extends CustomPainter {
  const _SpokenVerseBackground(this.color, this.bounds);
  final Color color;
  final List<Rect> Function() bounds;
  List<Rect> get rectangles => bounds();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (final rect in rectangles) {
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(_SpokenVerseBackground oldDelegate) =>
      color != oldDelegate.color || bounds != oldDelegate.bounds;
}
