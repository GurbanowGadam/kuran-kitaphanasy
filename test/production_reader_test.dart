import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuran_kitaphanasy/main.dart';
import 'package:kuran_kitaphanasy/reader_data.dart';
import 'package:kuran_kitaphanasy/reader/settings/reader_preferences.dart';

import 'reader_fixture.dart';

void main() {
  testWidgets(
    'vertical reader builds a bounded window rather than the full book',
    (t) async {
      final docs = fixtureDocuments();
      for (var p = 11; p <= 200; p++) {
        (docs['pages']['items'] as List).add({
          'id': p,
          'printedPage': p - 1,
          'verses': [
            {'surah': 2, 'ayah': p - 1},
          ],
        });
        (docs['verses']['items'] as List).add({
          'surah': 2,
          'ayah': p - 1,
          'text': 'TEST',
        });
        (docs['translations']['items'] as List).add({
          'id': 't$p',
          'surah': 2,
          'fromAyah': p - 1,
          'toAyah': p - 1,
          'text': 'TEST',
          'footnoteIds': [],
        });
      }
      await t.pumpWidget(
        QuranApp(data: Future.value(ReaderData.fromDocuments(docs))),
      );
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('book-quran')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('reader-settings')));
      await t.pumpAndSettle();
      await t.ensureVisible(find.byKey(const Key('orientation-vertical')));
      await t.tap(find.byKey(const Key('orientation-vertical')));
      await t.pumpAndSettle();
      expect(
        find
            .byWidgetPredicate(
              (w) =>
                  w.key is ValueKey<String> &&
                  (w.key! as ValueKey<String>).value.startsWith(
                    'reading-surface-',
                  ),
              skipOffstage: false,
            )
            .evaluate()
            .length,
        lessThan(6),
      );
      await t.tap(find.byTooltip('Ýap').last);
      await t.pumpAndSettle();
    },
  );
  testWidgets(
    'reader restarts with last page, typography and mode, but not fullscreen',
    (t) async {
      final store = MemoryReaderStore();
      await store.write(
        'quran',
        ReaderPreferences(
          page: 7,
          mode: 'translation',
          dark: true,
          arabicSize: 46,
          translationSize: 30,
          alignment: 'right',
        ).toJson(),
      );
      await t.pumpWidget(QuranApp(data: Future.value(fixture()), store: store));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('book-quran')));
      await t.pumpAndSettle();
      expect(find.text('Sahypa 8 (8/9)'), findsOneWidget);
      expect(
        t.widget<Text>(find.byKey(const Key('translation-t9'))).style!.fontSize,
        30,
      );
      expect(find.byKey(const Key('reader-fullscreen')), findsOneWidget);
      await t.tap(find.byKey(const Key('reader-fullscreen')));
      await t.pump();
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
      await t.pumpWidget(QuranApp(data: Future.value(fixture()), store: store));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('book-quran')));
      await t.pumpAndSettle();
      expect(find.text('Sahypa 8 (8/9)'), findsOneWidget);
      expect(find.byKey(const Key('reader-fullscreen')), findsOneWidget);
    },
  );
}
