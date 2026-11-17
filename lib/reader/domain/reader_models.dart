class VerseRef {
  const VerseRef(this.surah, this.ayah);
  final int surah, ayah;
  String get key => '$surah:$ayah';
}

class QuranVerse extends VerseRef {
  const QuranVerse(super.surah, super.ayah, this.text);
  final String text;
}

class QuranPage {
  const QuranPage(this.id, this.printedPage, this.verses, this.pdfPage);
  final int id;
  final int? printedPage, pdfPage;
  final List<QuranVerse> verses;
}

class TranslationBlock {
  TranslationBlock(Map<String, dynamic> row)
    : id = row['id'] as String,
      surah = row['surah'] as int,
      fromAyah = row['fromAyah'] as int,
      toAyah = row['toAyah'] as int,
      text = row['text'] as String,
      footnoteIds = List.unmodifiable(
        List<String>.from(row['footnoteIds'] as List),
      );
  final String id, text;
  final int surah, fromAyah, toAyah;
  final List<String> footnoteIds;
  String get range => fromAyah == toAyah ? '$fromAyah' : '$fromAyah–$toAyah';
  bool contains(VerseRef v) =>
      v.surah == surah && v.ayah >= fromAyah && v.ayah <= toAyah;
}
