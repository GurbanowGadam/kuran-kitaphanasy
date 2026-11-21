import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'reader_fixture.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'Surah, full description and full footnote sheets inherit theme dark=$dark',
      (t) async {
        await openReader(t);
        if (dark) {
          await t.tap(find.byKey(const Key('back-library')));
          await t.pumpAndSettle();
          await setDarkTheme(t);
          await t.tap(find.byKey(const Key('book-quran')));
          await t.pumpAndSettle();
        }
        Future<void> check(String key) async {
          final context = t.element(find.byKey(Key(key)));
          expect(
            Theme.of(context).brightness,
            dark ? Brightness.dark : Brightness.light,
          );
          expect(
            t.widget<BottomSheet>(find.byType(BottomSheet)).backgroundColor,
            Theme.of(context).colorScheme.surface,
          );
        }

        await t.tap(find.byKey(const Key('surah-menu')));
        await t.pumpAndSettle();
        await check('surah-sheet');
        await t.tap(find.byTooltip('Ýap'));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('surah-info')));
        await t.pumpAndSettle();
        await check('detail-sheet');
        expect(find.text(fixture().descriptions[1]!), findsOneWidget);
        await t.tap(find.byTooltip('Ýap'));
        await t.pumpAndSettle();
        await setMode(t, 'translation');
        await t.ensureVisible(find.byKey(const Key('note-n1')));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('note-n1')));
        await t.pumpAndSettle();
        await check('detail-sheet');
        expect(find.text(fixture().footnotes['n1']!), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const Key('detail-sheet')),
            matching: find.byType(SingleChildScrollView),
          ),
          findsOneWidget,
        );
        expect(t.takeException(), isNull);
      },
    );
  }
}
