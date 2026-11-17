import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'reader_fixture.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets('Fixed bars contrast with paper and retain swipe dark=$dark', (
      t,
    ) async {
      await openReader(t);
      if (dark) {
        await t.tap(find.byKey(const Key('back-library')));
        await t.pumpAndSettle();
        await t.tap(find.byTooltip('Garaňky görnüş'));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('book-quran')));
        await t.pumpAndSettle();
      }
      final bar = t.widget<AppBar>(find.byType(AppBar));
      final theme = Theme.of(t.element(find.byType(AppBar)));
      expect(bar.backgroundColor, isNotNull);
      expect(bar.backgroundColor, isNot(theme.scaffoldBackgroundColor));
      expect(bar.shape, isA<Border>());
      final bottom = t.widget<DecoratedBox>(
        find.byKey(const Key('reader-bottom-chrome')),
      );
      final decoration = bottom.decoration as BoxDecoration;
      expect(decoration.color, bar.backgroundColor);
      expect(decoration.border, isNotNull);
      expect(decoration.boxShadow, isNotEmpty);
      await t.drag(find.byKey(const Key('quran-pages')), const Offset(650, 0));
      await t.pumpAndSettle();
      expect(find.text('Sahypa 2 (2/9)'), findsOneWidget);
      expect(find.byKey(const Key('surah-menu')), findsOneWidget);
      expect(find.byKey(const Key('back-library')), findsOneWidget);
    });
  }
}
