import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'reader_fixture.dart';

void main() {
  testWidgets('Home restores mode, physical page and each page scroll', (
    t,
  ) async {
    await openReader(t);
    await setMode(t, 'translation');
    final first = t
        .widget<ListView>(find.byKey(const Key('page-scroll-1')))
        .controller!;
    await t.drag(find.byKey(const Key('page-scroll-1')), const Offset(0, -300));
    await t.pumpAndSettle();
    final saved = first.offset;
    expect(saved, greaterThan(0));
    await t.drag(find.byKey(const Key('quran-pages')), const Offset(-650, 0));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('back-library')));
    await t.pumpAndSettle();
    expect(find.text('9 sahypa · synag nusgasy'), findsNothing);
    expect(find.byKey(const Key('book-quran')), findsOneWidget);
    await t.tap(find.byKey(const Key('book-quran')));
    await t.pumpAndSettle();
    expect(find.text('Sahypa 2 (2/9)'), findsOneWidget);
    expect(find.byTooltip('Türkmençe'), findsOneWidget);
    await t.drag(find.byKey(const Key('quran-pages')), const Offset(650.0, 0));
    await t.pumpAndSettle();
    expect(
      t
          .widget<ListView>(find.byKey(const Key('page-scroll-1')))
          .controller!
          .offset,
      saved,
    );
  });
}
