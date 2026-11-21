import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuran_kitaphanasy/main.dart';
import 'package:kuran_kitaphanasy/reader_data.dart';

import 'reader_fixture.dart';

ReaderData sourceData() => ReaderData.fromDocuments({
  for (final name in ReaderData.datasets)
    name: jsonDecode(File('assets/data/$name.json').readAsStringSync()),
});

void main() {
  test('Opening metadata matches all 114 archived Diyanet records', () {
    final source =
        jsonDecode(
              File('assets/sources/diyanet-reading/surahs-decoded.json')
                  .readAsStringSync(),
            )['data']
            as List;
    final metadata = jsonDecode(
      File('assets/data/surah_metadata.json').readAsStringSync(),
    );
    expect(metadata['items'], hasLength(114));
    for (final row in source) {
      final item = (metadata['items'] as List).singleWhere(
        (r) => r['surah'] == row['id'],
      );
      expect(item['verseCount'], row['ayet_sayisi']);
      expect(
        item['place'],
        {'mekki': 'Mekge', 'medeni': 'Medine'}[row['inis_yeri']],
      );
    }
  });

  for (final dark in [false, true]) {
    for (final mode in ['both', 'arabic', 'translation']) {
      testWidgets('Exact source labels wrap at 320px $mode dark=$dark', (
        t,
      ) async {
        t.view.physicalSize = const Size(320, 850);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final data = sourceData();
        await t.pumpWidget(QuranApp(data: Future.value(data)));
        await t.pumpAndSettle();
        if (dark) {
          await setDarkTheme(t);
        }
        await t.tap(find.byKey(const Key('book-quran')));
        await t.pumpAndSettle();
        await setMode(t, mode);
        expect(find.text('1. Fatyha süresi'), findsOneWidget);
        expect(find.text('Fatyha Süresi • Mekge • 7 aýat'), findsOneWidget);
        expect(find.text('Sahypa 1 (1/${data.pages.length})'), findsOneWidget);
        await t.tap(find.byKey(const Key('surah-menu')));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('surah-2')));
        await t.pumpAndSettle();
        expect(find.text('2. Bakara süresi'), findsOneWidget);
        final banner = find.text('Bakara Süresi • Medine • 286 aýat');
        expect(banner, findsOneWidget);
        final paragraph = t.renderObject<RenderParagraph>(banner);
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(paragraph.size.height, greaterThan(24));
        expect(find.byKey(const Key('opening-arabic-title-2')), findsOneWidget);
        await t.drag(
          find.byKey(const Key('quran-pages')),
          Offset(mode == 'translation' ? -240 : 240, 0),
        );
        await t.pumpAndSettle();
        expect(find.text('Sahypa 2 (2/${data.pages.length})'), findsOneWidget);
        expect(find.text('3 / 10'), findsNothing);
        expect(t.takeException(), isNull);
      });
    }
  }

  testWidgets('Long top title remains constrained beside mode control', (
    t,
  ) async {
    t.view.physicalSize = const Size(320, 850);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final docs = fixtureDocuments();
    docs['surah_names_pdf']['items'][0]['name'] =
        'TEST ONLY very long chapter name';
    await t.pumpWidget(
      QuranApp(data: Future.value(ReaderData.fromDocuments(docs))),
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('book-quran')));
    await t.pumpAndSettle();
    final title = find.byKey(const Key('surah-title'));
    expect(
      t.widget<Text>(title).data,
      '1. TEST ONLY very long chapter name süresi',
    );
    expect(
      t.getRect(title).right,
      lessThan(t.getRect(find.byKey(const Key('mode-dropdown'))).left),
    );
    expect(t.takeException(), isNull);
  });
}
