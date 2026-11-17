import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuran_kitaphanasy/main.dart';
import 'package:kuran_kitaphanasy/reader_data.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets('Surah fixed chrome is darker and stays pinned dark=$dark', (
      t,
    ) async {
      final data = (await t.runAsync(() => ReaderData.load()))!;
      await t.pumpWidget(QuranApp(data: Future.value(data)));
      await t.pumpAndSettle();
      if (dark) {
        await t.tap(find.byTooltip('Garaňky görnüş'));
        await t.pumpAndSettle();
      }
      await t.tap(find.byKey(const Key('book-quran')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('surah-menu')));
      await t.pumpAndSettle();
      final header = find.byKey(const Key('surah-sheet-header'));
      final background = t.widget<Container>(header).color!;
      final surface = Theme.of(t.element(header)).colorScheme.surface;
      expect(
        background.computeLuminance(),
        lessThan(surface.computeLuminance()),
      );
      final before = t.getTopLeft(header);
      final search = find.byKey(const Key('surah-name-search'));
      final searchBefore = t.getTopLeft(search);
      await t.drag(find.byType(ListView).last, const Offset(0, -450));
      await t.pumpAndSettle();
      expect(t.getTopLeft(header), before);
      expect(t.getTopLeft(search), searchBefore);
      await t.tap(find.byTooltip('Ýap'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('surah-sheet')), findsNothing);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets(
    'Name search handles Türkmen letters, ignores metadata and clears',
    (t) async {
      t.view.physicalSize = const Size(320, 740);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final data = (await t.runAsync(() => ReaderData.load()))!;
      await t.pumpWidget(QuranApp(data: Future.value(data)));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('book-quran')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('surah-menu')));
      await t.pumpAndSettle();
      final search = find.byKey(const Key('surah-name-search'));
      for (final query in ['ÄLI', 'ali', '  Äli-Ymran  ']) {
        await t.enterText(search, query);
        await t.pumpAndSettle();
        expect(find.byKey(const Key('surah-3')), findsOneWidget);
        expect(find.byKey(const Key('surah-1')), findsNothing);
        expect(find.byKey(const Key('surah-2')), findsNothing);
      }
      for (final query in ['Medine', '286', 'zzzzzz']) {
        await t.enterText(search, query);
        await t.pumpAndSettle();
        expect(find.text('Süre tapylmady.'), findsOneWidget);
        expect(find.byType(ListTile), findsNothing);
      }
      await t.tap(find.byTooltip('Arassala'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('surah-1')), findsOneWidget);
      await t.enterText(search, 'bakara');
      await t.pumpAndSettle();
      t.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(t.view.resetViewInsets);
      await t.pumpAndSettle();
      final row = find.byKey(const Key('surah-2'));
      expect(t.getBottomRight(row).dy, lessThanOrEqualTo(460));
      await t.tap(row);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('surah-sheet')), findsNothing);
      expect(find.text('2. Bakara süresi'), findsOneWidget);
      t.view.resetViewInsets();
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('surah-menu')));
      await t.pumpAndSettle();
      expect(t.widget<TextField>(search).controller!.text, isEmpty);
      expect(t.takeException(), isNull);
    },
  );
}
