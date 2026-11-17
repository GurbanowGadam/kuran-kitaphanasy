import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuran_kitaphanasy/main.dart';
import 'package:kuran_kitaphanasy/reader/settings/reader_preferences.dart';

import 'surah_opening_test.dart' show realData;
import 'reader_fixture.dart' show fixture;
import 'reader_settings_test.dart' show settings, choose, close;

Future<void> open(
  WidgetTester t,
  ReaderStore store, {
  bool real = false,
}) async {
  await t.pumpWidget(
    QuranApp(data: Future.value(real ? realData() : fixture()), store: store),
  );
  await t.pumpAndSettle();
  await t.tap(find.byKey(const Key('book-quran')));
  await t.pumpAndSettle();
}

double verticalOffset(WidgetTester t, int index) {
  final viewport = t.getTopLeft(find.byKey(const Key('vertical-pages'))).dy;
  final content = t
      .getTopLeft(find.byKey(Key('reading-surface-${index + 1}')))
      .dy;
  return viewport - content + 16;
}

void main() {
  for (final vertical in [false, true]) {
    testWidgets(
      'Full book picker reaches final surah and returns to shared Baqara start vertical=$vertical',
      (t) async {
        final store = MemoryReaderStore();
        await store.write(
          'quran',
          ReaderPreferences(vertical: vertical, mode: 'translation').toJson(),
        );
        await open(t, store, real: true);
        final data = realData();
        await t.tap(find.byKey(const Key('surah-menu')));
        await t.pumpAndSettle();
        await t.scrollUntilVisible(
          find.byKey(const Key('surah-114')),
          400,
          scrollable: find
              .descendant(
                of: find.descendant(
                  of: find.byKey(const Key('surah-sheet')),
                  matching: find.byType(ListView),
                ),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await t.tap(find.byKey(const Key('surah-114')));
        await t.pumpAndSettle();
        expect(
          t.widget<Text>(find.byKey(const Key('surah-title'))).data,
          '114. ${data.names[114]} süresi',
        );
        expect(
          find.byKey(const Key('surah-opening-114')).hitTestable(),
          findsOneWidget,
        );
        expect(
          find.text(
            'Sahypa ${data.startPage(114) + 1} (${data.startPage(114) + 1}/${data.pages.length})',
          ),
          findsOneWidget,
        );
        await t.tap(find.byKey(const Key('surah-menu')));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('surah-2')));
        await t.pumpAndSettle();
        expect(
          find.byKey(const Key('surah-opening-2')).hitTestable(),
          findsOneWidget,
        );
        expect(
          t.widget<Text>(find.byKey(const Key('surah-title'))).data,
          '2. Bakara süresi',
        );
        expect(find.text('Sahypa 1 (1/${data.pages.length})'), findsOneWidget);
        expect(t.takeException(), isNull);
      },
    );

    testWidgets(
      'Pixel offset survives real reader teardown and restart vertical=$vertical',
      (t) async {
        final store = MemoryReaderStore();
        await store.write(
          'quran',
          ReaderPreferences(
            page: 2,
            vertical: vertical,
            offsets: {3: 170},
          ).toJson(),
        );
        await open(t, store);
        double offset() => vertical
            ? verticalOffset(t, 2)
            : t
                  .widget<ListView>(find.byKey(const Key('page-scroll-3')))
                  .controller!
                  .offset;
        expect(offset(), closeTo(170, 1));
        await t.drag(
          find.byKey(Key(vertical ? 'vertical-pages' : 'page-scroll-3')),
          const Offset(0, -130),
        );
        await t.pumpAndSettle();
        final saved = offset();
        expect(saved, greaterThan(200));
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 1));
        await open(t, store);
        expect(offset(), closeTo(saved, 1));
        expect(find.byKey(const Key('reader-fullscreen')), findsOneWidget);
      },
    );
  }
  testWidgets('Changing reading flow preserves the current page pixel offset', (
    t,
  ) async {
    final store = MemoryReaderStore();
    await store.write(
      'quran',
      ReaderPreferences(page: 2, offsets: {3: 170}).toJson(),
    );
    await open(t, store);
    await settings(t);
    await choose(t, 'orientation-vertical');
    await close(t);
    expect(verticalOffset(t, 2), closeTo(170, 1));
    await settings(t);
    await choose(t, 'orientation-horizontal');
    await close(t);
    expect(
      t
          .widget<ListView>(find.byKey(const Key('page-scroll-3')))
          .controller!
          .offset,
      closeTo(170, 1),
    );
  });
  testWidgets(
    'Library theme survives application restart independently of book theme',
    (t) async {
      final store = MemoryReaderStore();
      await open(t, store);
      await t.tap(find.byKey(const Key('back-library')));
      await t.pumpAndSettle();
      await t.tap(find.byIcon(Icons.dark_mode_outlined));
      await t.pumpAndSettle();
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
      await t.pumpWidget(QuranApp(data: Future.value(fixture()), store: store));
      await t.pumpAndSettle();
      expect(find.byIcon(Icons.light_mode_outlined), findsOneWidget);
    },
  );
}
