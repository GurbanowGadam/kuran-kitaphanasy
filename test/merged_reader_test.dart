import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:kuran_kitaphanasy/main.dart';

import 'reader_fixture.dart' show setMode;
import 'reader_settings_test.dart' show settings, choose, close;
import 'surah_opening_test.dart' show realData;

void main() {
  for (final vertical in [false, true]) {
    testWidgets(
      'Picker returns from continuation and header follows shared-page sections vertical=$vertical',
      (t) async {
        final data = realData();
        await t.pumpWidget(QuranApp(data: Future.value(data)));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('book-quran')));
        await t.pumpAndSettle();
        if (vertical) {
          await settings(t);
          await choose(t, 'orientation-vertical');
          await close(t);
          t
              .widget<ScrollablePositionedList>(
                find.byKey(const Key('vertical-pages')),
              )
              .itemScrollController!
              .jumpTo(index: 1);
          await t.pumpAndSettle();
        } else {
          await t.drag(
            find.byKey(const Key('quran-pages')),
            const Offset(650, 0),
          );
        }
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('surah-menu')));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('surah-2')));
        await t.pumpAndSettle();
        expect(
          t.widget<Text>(find.byKey(const Key('surah-title'))).data,
          '2. Bakara süresi',
        );
        expect(
          find.byKey(const Key('surah-opening-2')).hitTestable(),
          findsOneWidget,
        );
        await t.ensureVisible(find.byKey(const Key('surah-opening-1')));
        await t.pumpAndSettle();
        expect(
          t.widget<Text>(find.byKey(const Key('surah-title'))).data,
          '1. Fatyha süresi',
        );
        await t.ensureVisible(find.byKey(const Key('surah-opening-2')));
        await t.pumpAndSettle();
        expect(
          t.widget<Text>(find.byKey(const Key('surah-title'))).data,
          '2. Bakara süresi',
        );
      },
    );
  }
  test('Reader groups retain every exact source verse without duplication', () {
    final data = realData();
    final source =
        jsonDecode(File('assets/data/pages.json').readAsStringSync())['items']
            as List;
    final expected = [
      for (final p in source)
        for (final v in p['verses']) '${v['surah']}:${v['ayah']}',
    ];
    final actual = data.pages
        .expand((p) => p.verses)
        .map((v) => v.key)
        .toList();
    expect(data.pages.length, source.length - 1);
    expect(actual, expected);
    expect(actual.length, expected.length);
    expect(actual.toSet().length, expected.length);
    expect(data.pages.first.verses.map((v) => v.key), [
      for (var i = 1; i <= 7; i++) '1:$i',
      for (var i = 1; i <= 5; i++) '2:$i',
    ]);
    expect(data.pages[1].verses.first.key, '2:6');
    expect(data.pages.first.pdfPage, isNull);
    expect(data.startPage(2), 0);
    for (var i = 1; i < data.pages.length; i++) {
      expect(data.pages[i].verses.map((v) => v.key), [
        for (final v in source[i + 1]['verses']) '${v['surah']}:${v['ayah']}',
      ]);
      expect(data.pages[i].pdfPage, source[i + 1]['pdfPage']);
    }
  });
  for (final vertical in [false, true]) {
    for (final mode in ['both', 'arabic', 'translation']) {
      testWidgets(
        'Merged openings, picker and geometry vertical=$vertical mode=$mode',
        (t) async {
          final data = realData();
          await t.pumpWidget(QuranApp(data: Future.value(data)));
          await t.pumpAndSettle();
          await t.tap(find.byKey(const Key('book-quran')));
          await t.pumpAndSettle();
          await setMode(t, mode);
          if (vertical) {
            await settings(t);
            await choose(t, 'orientation-vertical');
            await close(t);
          }
          final surface = find.byKey(const Key('reading-surface-1'));
          for (final id in [1, 2]) {
            expect(
              find.descendant(
                of: surface,
                matching: find.byKey(Key('surah-opening-$id')),
              ),
              findsOneWidget,
            );
          }
          if (mode == 'arabic') {
            final flows = t
                .widgetList<Text>(
                  find.descendant(
                    of: surface,
                    matching: find.byWidgetPredicate(
                      (w) =>
                          w is Text &&
                          w.textDirection == TextDirection.rtl &&
                          w.textSpan != null,
                    ),
                  ),
                )
                .toList();
            expect(flows.length, 2);
            expect(
              flows.first.textSpan!.toPlainText(),
              contains(data.pages.first.verses.first.text),
            );
            expect(
              flows.last.textSpan!.toPlainText(),
              isNot(contains(data.pages.first.verses.first.text)),
            );
          }
          await t.tap(find.byKey(const Key('surah-menu')));
          await t.pumpAndSettle();
          await t.tap(find.byKey(const Key('surah-2')));
          await t.pumpAndSettle();
          expect(
            find.text('Sahypa 1 (1/${data.pages.length})'),
            findsOneWidget,
          );
          expect(
            t.widget<Text>(find.byKey(const Key('surah-title'))).data,
            contains('Bakara'),
          );
          expect(
            find.byKey(const Key('surah-opening-2')).hitTestable(),
            findsOneWidget,
          );
          await t.tap(find.byKey(const Key('surah-info')));
          await t.pumpAndSettle();
          expect(find.text(data.descriptions[2]!), findsOneWidget);
          await close(t);
          if (vertical) {
            for (final p in data.pages.where(
              (p) => find.byKey(Key('page-end-${p.id}')).evaluate().isNotEmpty,
            )) {
              expect(
                t.getBottomLeft(find.byKey(Key('page-end-${p.id}'))).dy,
                lessThan(
                  t.getTopLeft(find.byKey(Key('page-divider-${p.id}'))).dy,
                ),
              );
            }
          }
          expect(t.takeException(), isNull);
        },
      );
    }
  }
  testWidgets(
    'Alignment setting affects only Arabic-only; direction and meal stay fixed',
    (t) async {
      await t.pumpWidget(QuranApp(data: Future.value(realData())));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('book-quran')));
      await t.pumpAndSettle();
      for (final align in {
        'right': TextAlign.right,
        'center': TextAlign.center,
        'justify': TextAlign.justify,
      }.entries) {
        await settings(t);
        await choose(t, 'align-${align.key}');
        await close(t);
        for (final mode in ['both', 'translation', 'arabic']) {
          await setMode(t, mode);
          final texts = t.widgetList<Text>(
            find.descendant(
              of: find.byKey(const Key('reading-surface-1')),
              matching: find.byType(Text),
            ),
          );
          for (final text in texts.where((w) => w.textSpan != null)) {
            if (text.textDirection == TextDirection.rtl) {
              expect(
                text.textAlign,
                mode == 'arabic' ? align.value : TextAlign.right,
              );
            } else {
              expect(text.textDirection, TextDirection.ltr);
              expect(text.textAlign, TextAlign.left);
            }
          }
        }
      }
    },
  );
}
