import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuran_kitaphanasy/main.dart';
import 'package:kuran_kitaphanasy/reader_data.dart';
import 'package:kuran_kitaphanasy/reader/settings/reader_preferences.dart';

void main() {
  test('Sajdah positions match the 14 frozen Diyanet markers exactly', () {
    final docs = {
      for (final name in ReaderData.datasets)
        name: jsonDecode(File('assets/data/$name.json').readAsStringSync()),
    };
    final data = ReaderData.fromDocuments(docs);
    expect(data.sajdahMarkers, {
      '7:206',
      '13:15',
      '16:49',
      '17:107',
      '19:58',
      '22:18',
      '25:60',
      '27:25',
      '32:15',
      '38:24',
      '41:37',
      '53:62',
      '84:21',
      '96:19',
    });
    final source = jsonDecode(
      File('assets/sources/diyanet-reading/isaretciler-decoded.json')
          .readAsStringSync(),
    );
    expect(data.sajdahMarkers, {
      for (final r in source['data'])
        if (r['tip'] == 'Secde') '${r['sure_id']}:${r['ayet_no']}',
    });
    docs['sajdah_markers']['items'][0]['ayah'] = 999;
    expect(() => ReaderData.fromDocuments(docs), throwsFormatException);
  });
  for (final dark in [false, true]) {
    for (final mode in ['arabic', 'both', 'translation']) {
      testWidgets(
        'Alak 19 sajdah annotation is visible without altering grouped text mode=$mode dark=$dark',
        (t) async {
          t.view.physicalSize = const Size(320, 740);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          final data = (await t.runAsync(() => ReaderData.load()))!;
          final page = data.pages.indexWhere(
            (p) => p.verses.any((v) => v.key == '96:19'),
          );
          final store = MemoryReaderStore();
          await store.write(
            'quran',
            ReaderPreferences(page: page, mode: mode, dark: dark).toJson(),
          );
          await t.pumpWidget(QuranApp(data: Future.value(data), store: store));
          await t.pumpAndSettle();
          await t.tap(find.byKey(const Key('book-quran')));
          await t.pumpAndSettle();
          final marker = find.byKey(const Key('sajdah-96:19'));
          expect(marker, findsOneWidget);
          await t.ensureVisible(marker);
          await t.pumpAndSettle();
          expect(marker.hitTestable(), findsOneWidget);
          expect(
            find.descendant(of: marker, matching: find.text('(Sežde aýaty)')),
            findsOneWidget,
          );
          expect(
            find.descendant(of: marker, matching: find.byIcon(Icons.info)),
            findsOneWidget,
          );
          if (mode != 'translation') {
            // Stable verse-specific keys identify the separate Arabic run after the marker.
            final runs = find.byWidgetPredicate(
              (w) =>
                  w is Text &&
                  w.key is ValueKey<String> &&
                  (w.key as ValueKey<String>).value.endsWith('-sajdah-96:19'),
            );
            expect(runs, findsOneWidget);
            expect(t.getTopLeft(marker).dy, lessThan(t.getTopLeft(runs).dy));
          } else {
            final block = data.translations.firstWhere(
              (b) => b.surah == 96 && b.toAyah == 19,
            );
            final text = t.widget<Text>(
              find.byKey(Key('translation-${block.id}')),
            );
            expect(text.textSpan!.toPlainText(), contains(block.text));
            expect(
              find.descendant(of: marker, matching: find.text('96:19')),
              findsOneWidget,
            );
          }
          expect(t.takeException(), isNull);
        },
      );
    }
  }
}
