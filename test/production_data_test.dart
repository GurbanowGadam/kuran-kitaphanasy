import 'package:flutter_test/flutter_test.dart';
import 'package:kuran_kitaphanasy/reader_data.dart';

import 'reader_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('full edition has ordered 114 surahs and 6236 unique verses', () async {
    final data = await ReaderData.load();
    expect(data.sourcePages.length, 605);
    expect(data.pages.length, 604);
    expect(data.availableSurahs, List.generate(114, (i) => i + 1));
    final verses = data.pages.expand((p) => p.verses).toList();
    expect(verses.length, 6236);
    expect(verses.map((v) => v.key).toSet().length, 6236);
    expect(verses.last.key, '114:6');
    expect(data.startPage(114), data.pages.length - 1);
    expect(data.pages.first.verses.last.key, '2:5');
  });
  for (final corruption in [
    'orphan verse',
    'duplicate translation',
    'duplicate note',
    'missing title',
    'duplicate name',
    'verse order',
  ]) {
    test('fails closed: $corruption', () {
      final docs = fixtureDocuments();
      final verses = docs['verses']['items'] as List;
      switch (corruption) {
        case 'orphan verse':
          verses.add({'surah': 2, 'ayah': 10, 'text': 'test'});
        case 'duplicate translation':
          (docs['translations']['items'] as List).add(
            docs['translations']['items'][0],
          );
        case 'duplicate note':
          (docs['footnotes']['items'] as List).add(
            docs['footnotes']['items'][0],
          );
        case 'missing title':
          (docs['surah_titles_diyanet']['items'] as List).removeLast();
        case 'duplicate name':
          (docs['surah_names_pdf']['items'] as List).add(
            docs['surah_names_pdf']['items'][0],
          );
        case 'verse order':
          final rows = docs['pages']['items'] as List;
          final tmp = rows[3]['verses'];
          rows[3]['verses'] = rows[4]['verses'];
          rows[4]['verses'] = tmp;
      }
      expect(() => ReaderData.fromDocuments(docs), throwsFormatException);
    });
  }
}
