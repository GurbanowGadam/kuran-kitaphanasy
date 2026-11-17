import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'reader_fixture.dart';

void main() {
  testWidgets(
    'Arabic page is exact continuous justified RTL with native markers; both unboxed',
    (t) async {
      await openReader(t);
      await setMode(t, 'arabic');
      final text = t.widget<Text>(find.byKey(const Key('arabic-flow-1')));
      expect(text.textDirection, TextDirection.rtl);
      expect(text.textAlign, TextAlign.justify);
      expect(text.style!.fontFamily, 'DiyanetAmasya');
      final spans = (text.textSpan! as TextSpan).children!;
      expect(spans.whereType<WidgetSpan>(), isEmpty);
      expect(
        text.textSpan!.toPlainText(includeSemanticsLabels: false),
        'بِسْمِ اللّٰهِ\u00a0\u200f﴿١﴾\u200f ',
      );
      for (final mode in ['both', 'translation']) {
        await setMode(t, mode);
        expect(
          find.descendant(
            of: find.byKey(const Key('reading-surface-1')),
            matching: find.byType(Card),
          ),
          findsNothing,
        );
        if (mode == 'both') {
          expect(
            t.getTopLeft(find.byKey(const Key('arabic-t1'))).dy,
            lessThan(t.getTopLeft(find.byKey(const Key('translation-t1'))).dy),
          );
        }
      }
    },
  );
}
