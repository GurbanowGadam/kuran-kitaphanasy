import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuran_kitaphanasy/main.dart';
import 'package:kuran_kitaphanasy/reader_data.dart';

import 'package:kuran_kitaphanasy/surah_opening.dart';

import 'reader_fixture.dart' show setMode;

ReaderData realData() => ReaderData.fromDocuments({
  for (final name in ReaderData.datasets)
    name: jsonDecode(File('assets/data/$name.json').readAsStringSync()),
});

void main() {
  testWidgets('Future Tawba opening never adds basmala', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SurahOpening(
            start: const QuranVerse(9, 1, 'TEST ONLY'),
            data: realData(),
            showArabic: true,
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('surah-opening-9')), findsOneWidget);
    expect(find.byKey(const Key('opening-basmala-9')), findsNothing);
  });
  for (final dark in [false, true]) {
    testWidgets('Opening respects theme and scales at 320px dark=$dark', (
      t,
    ) async {
      t.view.physicalSize = const Size(320, 850);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final data = realData();
      await t.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            brightness: dark ? Brightness.dark : Brightness.light,
          ),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: SurahOpening(
                start: data.pages.first.verses.firstWhere((v) => v.surah == 2),
                data: data,
                showArabic: true,
              ),
            ),
          ),
        ),
      );
      final title = t.widget<Text>(
        find.byKey(const Key('opening-arabic-title-2')),
      );
      expect(title.data, 'سُورَةُ ${data.arabicTitles[2]}');
      expect(title.style!.fontFamily, 'DiyanetAmasya');
      final basmala = t.widget<Text>(
        find.byKey(const Key('opening-basmala-2')),
      );
      expect(
        basmala.style!.color,
        dark ? const Color(0xffffb46e) : const Color(0xff934515),
      );
      expect(t.takeException(), isNull);
    });
  }
  for (final mode in ['arabic', 'both', 'translation']) {
    testWidgets('Source opening, basmala and continuation in $mode at 320px', (
      t,
    ) async {
      t.view.physicalSize = const Size(320, 850);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final data = realData();
      await t.pumpWidget(QuranApp(data: Future.value(data)));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('book-quran')));
      await t.pumpAndSettle();
      await setMode(t, mode);
      expect(find.byKey(const Key('surah-opening-1')), findsOneWidget);
      expect(find.text('سُورَةُ ${data.arabicTitles[1]}'), findsOneWidget);
      expect(find.byKey(const Key('opening-basmala-1')), findsNothing);
      expect(find.byKey(const Key('surah-opening-2')), findsOneWidget);
      final title = t.widget<Text>(
        find.byKey(const Key('opening-arabic-title-2')),
      );
      expect(title.data, 'سُورَةُ ${data.arabicTitles[2]}');
      expect(title.textDirection, TextDirection.rtl);
      expect(title.style!.fontFamily, 'DiyanetAmasya');
      final basmala = find.byKey(const Key('opening-basmala-2'));
      if (mode == 'translation') {
        expect(basmala, findsNothing);
      } else {
        expect(basmala, findsOneWidget);
        final text = t.widget<Text>(basmala);
        expect(text.data, data.pages.first.verses.first.text);
        expect(text.style!.fontFamily, 'DiyanetAmasya');
      }
      expect(t.takeException(), isNull);
      await t.drag(
        find.byKey(const Key('quran-pages')),
        Offset(mode == 'translation' ? -240 : 240, 0),
      );
      await t.pumpAndSettle();
      expect(find.byKey(const Key('surah-opening-2')), findsNothing);
      expect(basmala, findsNothing);
      expect(t.takeException(), isNull);
    });
  }
}
