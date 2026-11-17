import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'package:kuran_kitaphanasy/main.dart';

import 'surah_opening_test.dart' show realData;
import 'reader_fixture.dart';

Future<void> settings(WidgetTester t) async {
  await t.tap(find.byKey(const Key('reader-settings')));
  await t.pumpAndSettle();
}

Future<void> choose(WidgetTester t, String key) async {
  await t.ensureVisible(find.byKey(Key(key)));
  await t.pumpAndSettle();
  await t.tap(find.byKey(Key(key)));
  await t.pumpAndSettle();
}

Future<void> close(WidgetTester t) async {
  await t.tap(find.byTooltip('Ýap'));
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'Real noninitial notes, all vertical page ends, modes and session state',
    (t) async {
      final data = realData();
      await t.pumpWidget(QuranApp(data: Future.value(data)));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('book-quran')));
      await t.pumpAndSettle();
      await settings(t);
      await choose(t, 'theme-dark');
      await choose(t, 'orientation-vertical');
      await close(t);
      for (final page in data.pages.where(
        (p) => find.byKey(Key('page-divider-${p.id}')).evaluate().isNotEmpty,
      )) {
        expect(find.byKey(Key('page-divider-${page.id}')), findsOneWidget);
        expect(
          t
              .widget<Divider>(find.byKey(Key('page-divider-${page.id}')))
              .thickness,
          .8,
        );
        expect(find.byKey(Key('page-end-${page.id}')), findsOneWidget);
      }
      for (final mode in ['arabic', 'translation', 'both']) {
        await setMode(t, mode);
        for (final id in [1, 2]) {
          expect(find.text('سُورَةُ ${data.arabicTitles[id]}'), findsOneWidget);
        }
      }
      final pageIndex = data.pages.indexWhere(
        (p) => p.verses.any((v) => v.surah == 2 && v.ayah == 37),
      );
      t
          .widget<ScrollablePositionedList>(
            find.byKey(const Key('vertical-pages')),
          )
          .itemScrollController!
          .jumpTo(index: pageIndex);
      await t.pumpAndSettle();
      expect(
        find.text(
          'Sahypa ${pageIndex + 1} (${pageIndex + 1}/${data.pages.length})',
        ),
        findsOneWidget,
      );
      final note = find.byKey(const Key('note-2:37-37:note-1'));
      await t.ensureVisible(note);
      await t.pumpAndSettle();
      await t.tap(note);
      await t.pumpAndSettle();
      expect(
        find.text(
          data.footnotes['2:37-37:note-1']!.substring('Düşündiriş: '.length),
        ),
        findsOneWidget,
      );
      expect(
        Theme.of(t.element(find.byKey(const Key('detail-sheet')))).brightness,
        Brightness.dark,
      );
      await close(t);
      final counter = t
          .widget<Text>(find.byKey(const Key('page-counter')))
          .data;
      final scroll = t
          .widget<ScrollablePositionedList>(
            find.byKey(const Key('vertical-pages')),
          )
          .itemPositionsNotifier!;
      final offset = scroll.itemPositions.value.first.itemLeadingEdge;
      await t.tap(find.byKey(const Key('back-library')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('book-quran')));
      await t.pumpAndSettle();
      expect(scroll.itemPositions.value.first.itemLeadingEdge, offset);
      expect(
        t.widget<Text>(find.byKey(const Key('page-counter'))).data,
        counter,
      );
      await t.tap(find.byKey(const Key('surah-menu')));
      await t.pumpAndSettle();
      expect(
        Theme.of(t.element(find.byKey(const Key('surah-sheet')))).brightness,
        Brightness.dark,
      );
      await t.tap(find.byKey(const Key('surah-2')));
      await t.pumpAndSettle();
      expect(find.text('Sahypa 1 (1/${data.pages.length})'), findsOneWidget);
      await settings(t);
      for (var i = 0; i < 20; i++) {
        await choose(t, 'arabic-decrease');
        await choose(t, 'translation-decrease');
      }
      await choose(t, 'theme-light');
      await close(t);
      expect(
        t.widget<Text>(find.byKey(const Key('arabic-2:1-1'))).style!.fontSize,
        24,
      );
      expect(
        t
            .widget<Text>(find.byKey(const Key('translation-2:1-1')))
            .style!
            .fontSize,
        14,
      );
      await t.tap(find.byKey(const Key('surah-info')));
      await t.pumpAndSettle();
      expect(
        Theme.of(t.element(find.byKey(const Key('detail-sheet')))).brightness,
        Brightness.light,
      );
      await close(t);
    },
  );
  testWidgets(
    'Book settings apply independent fonts, literal alignment and scoped theme',
    (t) async {
      await openReader(t);
      expect(
        t.getCenter(find.byKey(const Key('reader-settings'))).dx,
        lessThan(t.getCenter(find.byKey(const Key('surah-menu'))).dx),
      );
      await settings(t);
      await choose(t, 'arabic-increase');
      await choose(t, 'translation-increase');
      await choose(t, 'align-right');
      await choose(t, 'theme-dark');
      expect(
        Theme.of(t.element(find.byKey(const Key('settings-sheet')))).brightness,
        Brightness.dark,
      );
      await close(t);
      var a = t.widget<Text>(find.byKey(const Key('arabic-t1')));
      expect(a.style!.fontSize, 36);
      expect(a.textAlign, TextAlign.right);
      expect(a.textDirection, TextDirection.rtl);
      expect(
        t.widget<Text>(find.byKey(const Key('translation-t1'))).style!.fontSize,
        22,
      );
      await setMode(t, 'arabic');
      expect(
        t.widget<Text>(find.byKey(const Key('arabic-flow-1'))).textAlign,
        TextAlign.right,
      );
      for (final align in ['center', 'justify']) {
        await settings(t);
        await choose(t, 'align-$align');
        await close(t);
        expect(
          t.widget<Text>(find.byKey(const Key('arabic-flow-1'))).textAlign,
          align == 'center' ? TextAlign.center : TextAlign.justify,
        );
      }
      await t.tap(find.byKey(const Key('surah-info')));
      await t.pumpAndSettle();
      expect(
        Theme.of(t.element(find.byKey(const Key('detail-sheet')))).brightness,
        Brightness.dark,
      );
      await close(t);
      await t.tap(find.byKey(const Key('back-library')));
      await t.pumpAndSettle();
      expect(
        Theme.of(t.element(find.byKey(const Key('book-quran')))).brightness,
        Brightness.light,
      );
      await t.tap(find.byKey(const Key('book-quran')));
      await t.pumpAndSettle();
      expect(
        t.widget<Text>(find.byKey(const Key('arabic-flow-1'))).style!.fontSize,
        36,
      );
      expect(
        Theme.of(t.element(find.byKey(const Key('page-counter')))).brightness,
        Brightness.dark,
      );
    },
  );
  testWidgets(
    'Continuous vertical pages track visible page and preserve switching position',
    (t) async {
      await openReader(t);
      await t.drag(find.byKey(const Key('quran-pages')), const Offset(650, 0));
      await t.pumpAndSettle();
      await settings(t);
      await choose(t, 'orientation-vertical');
      await close(t);
      expect(find.text('Sahypa 2 (2/9)'), findsOneWidget);
      expect(find.byKey(const Key('vertical-pages')), findsOneWidget);
      expect(find.byKey(const Key('page-divider-2')), findsOneWidget);
      expect(find.byKey(const Key('page-end-2')), findsOneWidget);
      t
          .widget<ScrollablePositionedList>(
            find.byKey(const Key('vertical-pages')),
          )
          .itemScrollController!
          .jumpTo(index: 2);
      await t.pumpAndSettle();
      expect(find.text('Sahypa 3 (3/9)'), findsOneWidget);
      await settings(t);
      await choose(t, 'orientation-horizontal');
      await close(t);
      expect(find.text('Sahypa 3 (3/9)'), findsOneWidget);
      await t.drag(find.byKey(const Key('quran-pages')), const Offset(650, 0));
      await t.pumpAndSettle();
      expect(find.text('Sahypa 4 (4/9)'), findsOneWidget);
    },
  );
  for (final dark in [false, true]) {
    testWidgets('320px enlarged settings are bounded and usable dark=$dark', (
      t,
    ) async {
      t.view.physicalSize = const Size(320, 740);
      t.view.devicePixelRatio = 1;
      t.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(
        MaterialApp(
          home: Reader(data: Future.value(fixture()), goHome: () {}),
        ),
      );
      await t.pumpAndSettle();
      await settings(t);
      await choose(t, dark ? 'theme-dark' : 'theme-light');
      for (var i = 0; i < 20; i++) {
        await choose(t, 'arabic-increase');
        await choose(t, 'translation-increase');
      }
      await close(t);
      expect(
        t.widget<Text>(find.byKey(const Key('arabic-t1'))).style!.fontSize,
        48,
      );
      expect(
        t.widget<Text>(find.byKey(const Key('translation-t1'))).style!.fontSize,
        32,
      );
      await settings(t);
      await choose(t, 'orientation-vertical');
      await close(t);

      await settings(t);
      await choose(t, 'settings-reset');
      await close(t);
      expect(
        t.widget<Text>(find.byKey(const Key('arabic-t1'))).style!.fontSize,
        34,
      );
      expect(
        t.widget<Text>(find.byKey(const Key('translation-t1'))).style!.fontSize,
        20,
      );
    });
  }
}
