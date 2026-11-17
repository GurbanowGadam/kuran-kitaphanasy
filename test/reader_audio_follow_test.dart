import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuran_kitaphanasy/reader/presentation/reader.dart';
import 'package:kuran_kitaphanasy/reader/settings/reader_preferences.dart';

import 'reader_audio_test.dart' show FakeAudio;
import 'reader_fixture.dart';

import 'package:kuran_kitaphanasy/reader/data/reader_data.dart';

class OpeningAudio extends FakeAudio {
  OpeningAudio() {
    opening = true;
  }
  @override
  bool get isBasmala => opening;
}

ReaderData groupedFixture() {
  final docs = fixtureDocuments();
  final pages = docs['pages']['items'] as List;
  final tail = [for (final p in pages.skip(2)) ...(p['verses'] as List)];
  pages.removeRange(2, pages.length);
  pages.add({'id': 3, 'printedPage': 2, 'verses': tail});
  for (final verse in docs['verses']['items']) {
    if (verse['surah'] == 2 && verse['ayah'] >= 2) {
      verse['text'] = List.filled(45, 'بِسْمِ اللّٰهِ').join(' ');
    }
  }
  final blocks = docs['translations']['items'] as List;
  blocks.removeRange(2, blocks.length);
  blocks.add({
    'id': 'group',
    'surah': 2,
    'fromAyah': 2,
    'toAyah': 9,
    'text': 'TEST ONLY unchanged grouped prose.',
    'footnoteIds': [],
    'pdfPage': 3,
  });
  return ReaderData.fromDocuments(docs);
}

List<TextSpan> painted(InlineSpan span) => [
  if (span is TextSpan && span.style?.backgroundColor != null) span,
  if (span is TextSpan)
    for (final child in span.children ?? <InlineSpan>[]) ...painted(child),
];
List<TextSpan> highlights(WidgetTester t) => t
    .widgetList<Text>(find.byType(Text))
    .expand((w) => w.textSpan == null ? <TextSpan>[] : painted(w.textSpan!))
    .toList();
Future<void> start(
  WidgetTester t,
  FakeAudio a, {
  bool vertical = false,
  String mode = 'arabic',
  ReaderData? data,
  Brightness brightness = Brightness.light,
}) async {
  final store = MemoryReaderStore();
  await store.write('quran', {
    'version': 1,
    'mode': mode,
    'vertical': vertical,
  });
  await t.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Reader(
        data: Future.value(data ?? fixture()),
        store: store,
        audioController: a,
        goHome: () {},
      ),
    ),
  );
  await t.pumpAndSettle();
  await setMode(t, mode);
  await t.tap(find.byKey(const Key('audio-menu')));
  await t.pumpAndSettle();
  a.playing = true;
  a.notifyListeners();
  await t.pumpAndSettle();
}

void main() {
  testWidgets('audio panel background reaches both screen edges', (t) async {
    final a = FakeAudio()..local = true;
    await start(t, a);
    final panel = t.getRect(find.byKey(const Key('audio-panel')));
    final screen = t.getRect(find.byType(Scaffold).first);
    expect(panel.left, screen.left);
    expect(panel.right, screen.right);
  });
  testWidgets('spoken marker and Arabic share full line-height bands', (
    t,
  ) async {
    final a = FakeAudio()..local = true;
    await start(t, a);
    final band = find.byKey(const Key('spoken-highlight-1:1'));
    expect(band, findsOneWidget);
    final dynamic painter = t.widget<CustomPaint>(band).painter!;
    final rectangles = painter.rectangles as List<Rect>;
    expect(rectangles, isNotEmpty);
    final text = t.widget<Text>(find.byKey(const Key('arabic-flow-1')));
    final plain = text.textSpan!.toPlainText(includeSemanticsLabels: false);
    final markerStart = plain.indexOf('﴿');
    final render = t.renderObject<RenderParagraph>(
      find.descendant(
        of: find.byKey(const Key('arabic-flow-1')),
        matching: find.byType(RichText),
      ),
    );
    final marker = render
        .getBoxesForSelection(
          TextSelection(
            baseOffset: markerStart,
            extentOffset: plain.indexOf('﴾') + 1,
          ),
        )
        .first
        .toRect();
    final markerBand = rectangles.firstWhere((r) => r.contains(marker.center));
    expect(markerBand.height, greaterThan(marker.height));
    final maximum = rectangles
        .map((r) => r.height)
        .reduce((a, b) => a > b ? a : b);
    expect(markerBand.height, closeTo(maximum, .5));
    expect(text.style!.fontSize, greaterThan(22));
  });
  for (final brightness in Brightness.values) {
    testWidgets('spoken background darkens the surface in $brightness', (
      t,
    ) async {
      final a = FakeAudio()..local = true;
      await start(t, a, brightness: brightness);
      final active = highlights(t).first.style!.backgroundColor!;
      final surface = Theme.of(
        t.element(find.byKey(const Key('arabic-flow-1'))),
      ).scaffoldBackgroundColor;
      expect(active.computeLuminance(), lessThan(surface.computeLuminance()));
    });
  }
  testWidgets('generic full recording intro suppresses spoken ayah', (t) async {
    final a = FakeAudio()
      ..local = true
      ..opening = true;
    await start(t, a);
    expect(highlights(t), isEmpty);
    a.opening = false;
    a.notifyListeners();
    await t.pumpAndSettle();
    expect(highlights(t), hasLength(2));
  });
  testWidgets('separate opening basmala is not mislabeled as spoken ayah', (
    t,
  ) async {
    final a = OpeningAudio()..local = true;
    await start(t, a);
    expect(highlights(t), isEmpty);
    a.opening = false;
    a.notifyListeners();
    await t.pumpAndSettle();
    expect(highlights(t), hasLength(2));
  });
  for (final vertical in [false, true]) {
    testWidgets(
      'exact later ayah reveal and one shaped paragraph in ${vertical ? 'vertical' : 'horizontal'} grouped bilingual',
      (t) async {
        final data = groupedFixture();
        final a = FakeAudio()..local = true;
        await start(t, a, vertical: vertical, mode: 'both', data: data);
        a.targetSurah = 2;
        a.targetAyah = 2;
        a.notifyListeners();
        await t.pumpAndSettle();
        final finder = find.byKey(const Key('arabic-group'));
        final original = t
            .widget<Text>(finder)
            .textSpan!
            .toPlainText(includeSemanticsLabels: false);
        a.targetAyah = 9;
        a.notifyListeners();
        await t.pumpAndSettle();
        final text = t.widget<Text>(finder);
        expect(
          text.textSpan!.toPlainText(includeSemanticsLabels: false),
          original,
        );
        final spans = painted(text.textSpan!);
        expect(
          spans.length,
          2,
          reason: 'exact Arabic verse plus its native marker only',
        );
        expect(spans.last.text, contains('٩'));
        expect(spans.last.text, isNot(contains('٢')));
        final render = t.renderObject<RenderParagraph>(
          find.descendant(of: finder, matching: find.byType(RichText)),
        );
        final offset = original.lastIndexOf(data.pages.last.verses.last.text);
        final box = render
            .getBoxesForSelection(
              TextSelection(
                baseOffset: offset,
                extentOffset: offset + data.pages.last.verses.last.text.length,
              ),
            )
            .first;
        final y = render.localToGlobal(Offset(box.left, box.top)).dy;
        expect(y, greaterThanOrEqualTo(76));
        expect(
          y,
          lessThan(t.getTopLeft(find.byKey(const Key('audio-panel'))).dy),
        );
        expect(
          find.text('TEST ONLY unchanged grouped prose.', findRichText: true),
          findsOneWidget,
        );
      },
    );
  }
  testWidgets(
    'only spoken Arabic and marker darken, previous clears, close restores toolbar',
    (t) async {
      final a = FakeAudio()..local = true;
      await start(t, a);
      expect(highlights(t), isNotEmpty);
      expect(
        highlights(t)
            .map((s) => s.toPlainText(includeSemanticsLabels: false))
            .join(),
        contains('بِسْمِ اللّٰهِ'),
      );
      expect(find.byKey(const Key('reader-settings')), findsNothing);
      a.targetSurah = 2;
      a.targetAyah = 1;
      a.notifyListeners();
      await t.pumpAndSettle();
      final rich = t.widget<Text>(find.byKey(const Key('arabic-flow-1')));
      expect(
        rich.textSpan!.toPlainText(includeSemanticsLabels: false),
        contains('﴿١﴾'),
      );
      await t.tap(find.byKey(const Key('audio-close')));
      await t.pumpAndSettle();
      expect(highlights(t), isEmpty);
      expect(find.byKey(const Key('reader-settings')), findsOneWidget);
    },
  );
  for (final vertical in [false, true]) {
    testWidgets(
      'lazy later page follows in ${vertical ? 'vertical' : 'horizontal'} flow; paused never follows',
      (t) async {
        final a = FakeAudio()..local = true;
        await start(t, a, vertical: vertical);
        a.playing = false;
        a.targetSurah = 2;
        a.targetAyah = 9;
        a.notifyListeners();
        await t.pumpAndSettle();
        expect(find.byKey(const Key('arabic-flow-9')), findsNothing);
        a.playing = true;
        a.notifyListeners();
        await t.pumpAndSettle();
        expect(find.byKey(const Key('arabic-flow-9')), findsOneWidget);
        final render = t.renderObject<RenderParagraph>(
          find.descendant(
            of: find.byKey(const Key('arabic-flow-9')),
            matching: find.byType(RichText),
          ),
        );
        expect(
          render.localToGlobal(Offset.zero).dy,
          lessThan(t.view.physicalSize.height),
        );
        final before = render.localToGlobal(Offset.zero);
        a.elapsed = const Duration(seconds: 3);
        a.notifyListeners();
        await t.pumpAndSettle();
        expect(render.localToGlobal(Offset.zero), before);
      },
    );
  }
}
