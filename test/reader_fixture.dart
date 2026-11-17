import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuran_kitaphanasy/main.dart';
import 'package:kuran_kitaphanasy/reader_data.dart';

// Explicit synthetic UI fixture, NEVER bundled or presented as scripture.
Map<String, dynamic> fixtureDocuments() => {
  'pages': {
    'items': [
      for (var p = 1; p <= 10; p++)
        {
          'id': p,
          'printedPage': p - 1,
          'verses': [
            {'surah': p == 1 ? 1 : 2, 'ayah': p == 1 ? 1 : p - 1},
          ],
        },
    ],
  },
  'verses': {
    'items': [
      for (var p = 1; p <= 10; p++)
        {
          'surah': p == 1 ? 1 : 2,
          'ayah': p == 1 ? 1 : p - 1,
          'text': 'بِسْمِ اللّٰهِ',
        },
    ],
  },
  'translations': {
    'items': [
      for (var p = 1; p <= 10; p++)
        {
          'id': 't$p',
          'surah': p == 1 ? 1 : 2,
          'fromAyah': p == 1 ? 1 : p - 1,
          'toAyah': p == 1 ? 1 : p - 1,
          'text': List.filled(35, 'TEST ONLY Türkmençe tekst.').join(' '),
          'footnoteIds': p == 1 ? ['n1'] : [],
          'pdfPage': p,
        },
    ],
  },
  'footnotes': {
    'items': [
      {
        'id': 'n1',
        'surah': 1,
        'fromAyah': 1,
        'toAyah': 1,
        'text':
            'TEST ONLY full note. ${List.filled(90, 'Düşündiriş doly tekst.').join(' ')}',
        'pdfPage': 2,
      },
    ],
  },
  'surah_names_pdf': {
    'items': [
      {'surah': 1, 'name': 'Fatyha'},
      {'surah': 2, 'name': 'Bakara'},
      {'surah': 112, 'name': 'Yhlas'},
    ],
  },
  'surah_names_arabic': {
    'items': [
      {'surah': 1, 'name': 'El-Fätiha'},
      {'surah': 2, 'name': 'El-Bakara'},
    ],
  },
  'surah_titles_diyanet': {
    'items': [
      {'surah': 1, 'name': 'TEST ONLY title 1'},
      {'surah': 2, 'name': 'TEST ONLY title 2'},
    ],
  },
  'surah_metadata': {
    'items': [
      {'surah': 1, 'place': 'Mekge', 'verseCount': 7},
      {'surah': 2, 'place': 'Medine', 'verseCount': 286},
    ],
  },
  'surah_descriptions': {
    'items': [
      for (var s = 1; s <= 2; s++)
        {
          'surah': s,
          'text':
              'TEST ONLY description $s. ${List.filled(60, 'Doly maglumat.').join(' ')}',
          'pdfPage': s,
        },
    ],
  },
};
ReaderData fixture() => ReaderData.fromDocuments(fixtureDocuments());
Future<void> openReader(WidgetTester tester) async {
  await tester.pumpWidget(QuranApp(data: Future.value(fixture())));
  await tester.pumpAndSettle();
  if (tester.getCenter(find.byKey(const Key('book-quran'))).dy >=
      tester.view.physicalSize.height / tester.view.devicePixelRatio) {
    await tester.ensureVisible(find.byKey(const Key('book-quran')));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.byKey(const Key('book-quran')));
  await tester.pumpAndSettle();
}

Future<void> setMode(WidgetTester tester, String mode) async {
  await tester.tap(find.byKey(const Key('mode-dropdown')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key('mode-$mode')));
  await tester.pumpAndSettle();
}
