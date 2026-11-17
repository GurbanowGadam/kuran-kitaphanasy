import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuran_kitaphanasy/main.dart';

import 'reader_fixture.dart';

void main() {
  testWidgets('Library does not display demo scope descriptions', (t) async {
    await t.pumpWidget(QuranApp(data: Future.value(fixture())));
    await t.pumpAndSettle();
    expect(find.text('9 sahypa · synag nusgasy'), findsNothing);
    expect(
      find.text('Fatyha bilen başlanýan ilkinji 10 mushaf sahypasy'),
      findsNothing,
    );
    expect(find.byKey(const Key('book-quran')), findsOneWidget);
  });
  for (final mode in ['both', 'translation']) {
    testWidgets(
      'Inline note fits body line height and opens full note in $mode',
      (t) async {
        t.view.physicalSize = const Size(320, 740);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        await openReader(t);
        await setMode(t, mode);
        final note = find.byKey(const Key('note-n1'));
        await t.ensureVisible(note);
        await t.pumpAndSettle();
        final body = t.widget<Text>(find.byKey(const Key('translation-t1')));
        final span = (body.textSpan! as TextSpan).children!
            .whereType<WidgetSpan>()
            .single;
        expect(
          t.getSize(note).height,
          lessThanOrEqualTo(body.style!.fontSize! * body.style!.height! + .1),
        );
        expect(span.alignment, PlaceholderAlignment.baseline);
        expect(span.baseline, TextBaseline.alphabetic);
        await t.tap(note);
        await t.pumpAndSettle();
        expect(find.text(fixture().footnotes['n1']!), findsOneWidget);
        expect(t.takeException(), isNull);
      },
    );
  }
}
