import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'reader_fixture.dart';

void main() {
  testWidgets(
    'Physical pages swipe right to advance; vertical scrolling stays on page and bounds hold',
    (t) async {
      await openReader(t);
      expect(find.text('Sahypa 1 (1/9)'), findsOneWidget);
      final view = t.widget<PageView>(find.byKey(const Key('quran-pages')));
      expect(view.reverse, isTrue);
      expect(find.byKey(const Key('previous-page')), findsNothing);
      expect(find.byKey(const Key('next-page')), findsNothing);
      expect(find.byKey(const Key('source-page')), findsNothing);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byKey(const Key('page-counter')),
        ),
        findsOneWidget,
      );
      expect(
        t.getTopLeft(find.byKey(const Key('page-counter'))).dx,
        equals(t.getTopLeft(find.byKey(const Key('surah-title'))).dx),
      );
      await t.drag(
        find.byKey(const Key('page-scroll-1')),
        const Offset(0, -450),
      );
      await t.pumpAndSettle();
      expect(find.text('Sahypa 1 (1/9)'), findsOneWidget);
      await t.drag(find.byKey(const Key('quran-pages')), const Offset(650, 0));
      await t.pumpAndSettle();
      expect(find.text('Sahypa 2 (2/9)'), findsOneWidget);
      for (var i = 2; i < 9; i++) {
        await t.drag(
          find.byKey(const Key('quran-pages')),
          const Offset(650, 0),
        );
        await t.pumpAndSettle();
      }
      expect(find.text('Sahypa 9 (9/9)'), findsOneWidget);
      expect(find.byKey(const Key('next-page')), findsNothing);
      await t.drag(find.byKey(const Key('quran-pages')), const Offset(650, 0));
      await t.pumpAndSettle();
      expect(find.text('Sahypa 9 (9/9)'), findsOneWidget);
    },
  );
  testWidgets('Available surahs jump to physical starts only', (t) async {
    await openReader(t);
    await t.tap(find.byKey(const Key('surah-menu')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('surah-112')), findsNothing);
    await t.tap(find.byKey(const Key('surah-2')));
    await t.pumpAndSettle();
    expect(find.text('Sahypa 1 (1/9)'), findsOneWidget);
    await t.tap(find.byKey(const Key('surah-menu')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('surah-1')));
    await t.pumpAndSettle();
    expect(find.text('Sahypa 1 (1/9)'), findsOneWidget);
  });
}
