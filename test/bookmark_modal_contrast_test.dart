import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuran_kitaphanasy/reader/presentation/reader.dart';
import 'package:kuran_kitaphanasy/reader/settings/reader_preferences.dart';

import 'reader_fixture.dart';

void main() {
  for (final bookDark in [false, true]) {
    testWidgets(
      'empty bookmarks follow book foreground across opposite route theme: $bookDark',
      (t) async {
        final store = MemoryReaderStore();
        await store.write('quran', {'version': 1, 'dark': bookDark});
        await t.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              brightness: bookDark ? Brightness.light : Brightness.dark,
            ),
            home: Reader(
              data: Future.value(fixture()),
              store: store,
              goHome: () {},
            ),
          ),
        );
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('bookmarks-menu')));
        await t.pumpAndSettle();
        final empty = find.text(
          'Entek bellik ýok.\nBellik goşmak üçin aýaty basyp saklaň.',
        );
        expect(empty, findsOneWidget);
        final theme = Theme.of(t.element(empty));
        expect(theme.brightness, bookDark ? Brightness.dark : Brightness.light);
        final paragraph = t.renderObject<RenderParagraph>(
          find.descendant(of: empty, matching: find.byType(RichText)),
        );
        final foreground = paragraph.text.style!.color!;
        expect(foreground, theme.colorScheme.onSurface);
        final light = foreground.computeLuminance();
        final background = theme.colorScheme.surface.computeLuminance();
        expect(
          (math.max(light, background) + .05) /
              (math.min(light, background) + .05),
          greaterThanOrEqualTo(4.5),
        );
        await t.tap(find.byTooltip('Ýap'));
        await t.pumpAndSettle();
        expect(empty, findsNothing);
      },
    );
  }
}
