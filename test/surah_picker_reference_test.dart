import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuran_kitaphanasy/main.dart';
import 'package:kuran_kitaphanasy/reader_data.dart';
import 'package:kuran_kitaphanasy/reader/presentation/surah_picker_list.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'Reference surah rows use Türkmen source metadata and real pages at 320px dark=$dark',
      (t) async {
        t.view.physicalSize = const Size(320, 740);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final data = (await t.runAsync(() => ReaderData.load()))!;
        await t.pumpWidget(QuranApp(data: Future.value(data)));
        await t.pumpAndSettle();
        if (dark) {
          await t.tap(find.byTooltip('Garaňky görnüş'));
          await t.pumpAndSettle();
        }
        await t.ensureVisible(find.byKey(const Key('book-quran')));
        await t.tap(find.byKey(const Key('book-quran')));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('surah-menu')));
        await t.pumpAndSettle();
        for (final id in [1, 2, 3]) {
          final row = find.byKey(Key('surah-$id'));
          await t.ensureVisible(row);
          await t.pumpAndSettle();
          expect(
            find.descendant(
              of: row,
              matching: find.text('$id. ${data.names[id]} süresi'),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: row,
              matching: find.text(data.openingMetadata[id]!),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: row,
              matching: find.text(
                'sah. ${(data.startPage(id) + 1).toString().padLeft(3, '0')}',
              ),
            ),
            findsOneWidget,
          );
          final icon = find.byKey(Key('surah-origin-$id'));
          final badge = find.byKey(Key('surah-page-$id'));
          expect(t.getCenter(icon).dx, lessThan(t.getCenter(badge).dx));
          expect(t.widget<ListTile>(row).selected, id == 1);
        }
        final sheet = find.byKey(const Key('surah-sheet'));
        expect(
          Theme.of(t.element(sheet)).brightness,
          dark ? Brightness.dark : Brightness.light,
        );
        expect(
          find.descendant(of: sheet, matching: find.byType(TextField)),
          findsOneWidget,
        );
        expect(find.text('Cüzler'), findsNothing);
        expect(find.text('Metin Ara'), findsNothing);
        await t.tap(find.byKey(const Key('surah-3')));
        await t.pumpAndSettle();
        expect(find.byKey(const Key('surah-sheet')), findsNothing);
        expect(
          find.text(
            'Sahypa ${data.startPage(3) + 1} (${data.startPage(3) + 1}/${data.pages.length})',
          ),
          findsOneWidget,
        );
        expect(t.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'Surah list remains readable at large text and reaches last surah',
    (t) async {
      final data = (await t.runAsync(() => ReaderData.load()))!;
      int? picked;
      await t.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 600),
              textScaler: TextScaler.linear(1.6),
            ),
            child: Scaffold(
              body: SizedBox(
                width: 320,
                child: SurahPickerList(
                  data: data,
                  selectedSurah: 1,
                  onSelected: (id) => picked = id,
                ),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.byKey(const Key('surah-114')),
        500,
        maxScrolls: 250,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await t.pumpAndSettle();
      await t.ensureVisible(find.byKey(const Key('surah-114')));
      await t.pumpAndSettle();
      expect(find.text('114. ${data.names[114]} süresi'), findsOneWidget);
      await t.tap(find.byKey(const Key('surah-114')));
      expect(picked, 114);
      expect(t.takeException(), isNull);
    },
  );
}
