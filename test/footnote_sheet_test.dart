import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuran_kitaphanasy/main.dart';
import 'package:kuran_kitaphanasy/reader_data.dart';

import 'reader_fixture.dart';

Future<ReaderData> openNote(
  WidgetTester t,
  String text, {
  bool dark = false,
}) async {
  t.view.physicalSize = const Size(320, 640);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  final docs = fixtureDocuments();
  docs['footnotes']['items'][0]['text'] = text;
  docs['translations']['items'][0]['text'] = 'TEST ONLY paragraph.';
  final data = ReaderData.fromDocuments(docs);
  await t.pumpWidget(QuranApp(data: Future.value(data)));
  await t.pumpAndSettle();
  if (dark) {
    await setDarkTheme(t);
  }
  await t.ensureVisible(find.text('Okap başla'));
  await t.pumpAndSettle();
  await t.tap(find.text('Okap başla'));
  await t.pumpAndSettle();
  await setMode(t, 'translation');
  await t.ensureVisible(find.byKey(const Key('note-n1')));
  await t.pumpAndSettle();
  await t.tap(find.byKey(const Key('note-n1')));
  await t.pumpAndSettle();
  return data;
}

Finder get sheet => find.byKey(const Key('detail-sheet'));
Finder get noteScroll =>
    find.descendant(of: sheet, matching: find.byType(Scrollable));

void main() {
  testWidgets(
    'footnote removes only its leading redundant label without changing source',
    (t) async {
      const raw = 'Düşündiriş: TEST ONLY. Düşündiriş: keep this inside.';
      final data = await openNote(t, raw);
      expect(
        find.descendant(of: sheet, matching: find.text('Düşündiriş')),
        findsOneWidget,
      );
      expect(
        find.text('TEST ONLY. Düşündiriş: keep this inside.'),
        findsOneWidget,
      );
      expect(find.text(raw), findsNothing);
      expect(data.footnotes['n1'], raw);
      await t.tap(find.byTooltip('Ýap'));
      await t.pumpAndSettle();
      expect(sheet, findsNothing);
    },
  );

  for (final dark in [false, true]) {
    testWidgets(
      'short footnote wraps its content instead of reserving maximum height dark=$dark',
      (t) async {
        await openNote(t, 'TEST ONLY short note.', dark: dark);
        expect(t.getSize(sheet).height, lessThan(250));
        expect(
          t.state<ScrollableState>(noteScroll).position.maxScrollExtent,
          0,
        );
        expect(find.text('TEST ONLY short note.'), findsOneWidget);
        expect(
          Theme.of(t.element(sheet)).brightness,
          dark ? Brightness.dark : Brightness.light,
        );
        expect(t.takeException(), isNull);
      },
    );

    for (final scale in [1.0, 1.8]) {
      testWidgets(
        'long footnote caps at former 72 percent height and scrolls dark=$dark scale=$scale',
        (t) async {
          t.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
          final body =
              '${List.filled(120, 'TEST ONLY long explanatory text.').join(' ')} END OF NOTE';
          await openNote(t, body, dark: dark);
          expect(t.getSize(sheet).height, closeTo(640 * .72, 1));
          final state = t.state<ScrollableState>(noteScroll);
          expect(state.position.maxScrollExtent, greaterThan(0));
          await t.drag(noteScroll, const Offset(0, -300));
          await t.pumpAndSettle();
          expect(state.position.pixels, greaterThan(0));
          state.position.jumpTo(state.position.maxScrollExtent);
          await t.pump();
          expect(state.position.extentAfter, 0);
          expect(find.text(body), findsOneWidget);
          expect(find.byTooltip('Ýap').hitTestable(), findsOneWidget);
          expect(t.takeException(), isNull);
        },
      );
    }
  }
}
