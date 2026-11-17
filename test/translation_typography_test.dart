import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'reader_fixture.dart';

void main() {
  testWidgets(
    'Both translation modes use offline Noto Serif and inline end notes',
    (t) async {
      await openReader(t);
      for (final mode in ['translation', 'both']) {
        await setMode(t, mode);
        final text = t.widget<Text>(find.byKey(const Key('translation-t1')));
        expect(text.style!.fontFamily, 'NotoSerif');
        final spans = (text.textSpan! as TextSpan).children!;
        if (mode == 'translation') {
          final number = spans.first as TextSpan;
          expect(number.text, '1. ');
          expect(number.style!.fontWeight, FontWeight.bold);
          expect(number.style!.fontSize, 22);
        }
        expect(
          spans.whereType<TextSpan>().map((s) => s.text ?? '').join(),
          contains(fixture().translations.first.text),
        );
        expect(spans.last, isA<WidgetSpan>());
        expect(find.byKey(const Key('note-n1')), findsOneWidget);
      }
    },
  );
}
