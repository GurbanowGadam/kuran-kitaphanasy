import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/reader_models.dart';
export '../domain/reader_models.dart';

/// Immutable, fail-closed content snapshot. Work is linear in source coverage.
class ReaderData {
  ReaderData._(
    this.pages,
    this.sourcePages,
    this.translations,
    this.names,
    this.arabicNames,
    this.arabicTitles,
    this.openingMetadata,
    this.descriptions,
    this.footnotes,
    this.sources,
    this.sajdahMarkers,
  ) {
    final byVerse = <String, TranslationBlock>{};
    for (final b in translations) {
      for (var a = b.fromAyah; a <= b.toAyah; a++) {
        byVerse['${b.surah}:$a'] = b;
      }
    }
    for (var i = 0; i < pages.length; i++) {
      final blocks = <TranslationBlock>{};
      for (final v in pages[i].verses) {
        _starts.putIfAbsent(v.surah, () => i);
        blocks.add(byVerse[v.key]!);
      }
      _blocks[pages[i].id] = List.unmodifiable(blocks);
    }
    availableSurahs = List.unmodifiable(_starts.keys);
  }
  final List<QuranPage> pages, sourcePages;
  final List<TranslationBlock> translations;
  final Map<int, String> names,
      arabicNames,
      arabicTitles,
      openingMetadata,
      descriptions;
  final Map<String, String> footnotes;
  final Map<String, dynamic> sources;

  /// Exact Diyanet passage-marker positions; independent of canonical text.
  final Set<String> sajdahMarkers;
  final _starts = <int, int>{};
  final _blocks = <int, List<TranslationBlock>>{};
  late final List<int> availableSurahs;
  static const datasets = [
    'pages',
    'verses',
    'translations',
    'surah_names_pdf',
    'surah_names_arabic',
    'surah_titles_diyanet',
    'surah_metadata',
    'surah_descriptions',
    'footnotes',
    'sajdah_markers',
  ];
  static Future<ReaderData> load({AssetBundle? bundle}) async {
    final strings = await Future.wait([
      for (final name in datasets)
        // The repository caches the validated snapshot. Do not also retain raw
        // strings (or failed reads) in the bundle: a retry must read fresh assets.
        (bundle ?? rootBundle).loadString(
          'assets/data/$name.json',
          cache: false,
        ),
    ]);
    // Decode, validate and build indexes together away from the native UI
    // isolate. No partially validated content is ever published.
    return compute(_decodeAndValidate, strings, debugLabel: 'reader-source');
  }

  static ReaderData _decodeAndValidate(List<String> strings) =>
      ReaderData.fromDocuments({
        for (var i = 0; i < datasets.length; i++)
          datasets[i]: jsonDecode(strings[i]),
      });

  factory ReaderData.fromDocuments(Map<String, dynamic> docs) {
    try {
      Never invalid(String message) => throw FormatException(message);
      List<Map<String, dynamic>> rows(String name) =>
          List<Map<String, dynamic>>.from(docs[name]['items'] as List);
      final counts = <int, int>{};
      final metadata = <int, String>{};
      for (final r in rows('surah_metadata')) {
        final s = r['surah'] as int, c = r['verseCount'] as int;
        final place = r['place'] as String;
        if (s < 1 ||
            s > 114 ||
            c <= 0 ||
            counts.containsKey(s) ||
            !['Mekge', 'Medine'].contains(place)) {
          invalid('Invalid surah metadata');
        }
        counts[s] = c;
        metadata[s] = '$place • $c aýat';
      }
      final verses = <String, QuranVerse>{};
      String? previous;
      bool follows(VerseRef a, VerseRef b) =>
          (a.surah == b.surah && b.ayah == a.ayah + 1) ||
          (b.surah == a.surah + 1 && b.ayah == 1);
      QuranVerse? last;
      for (final r in rows('verses')) {
        final v = QuranVerse(
          r['surah'] as int,
          r['ayah'] as int,
          r['text'] as String,
        );
        if (v.text.trim().isEmpty ||
            v.ayah < 1 ||
            v.ayah > (counts[v.surah] ?? 0) ||
            verses.containsKey(v.key) ||
            (last != null && !follows(last, v))) {
          invalid('Invalid verse order/record ${v.key}');
        }
        verses[v.key] = v;
        last = v;
      }
      if (verses.isEmpty || verses.keys.first != '1:1') {
        invalid('Content must begin at 1:1');
      }
      final pages = <QuranPage>[];
      final seen = <String>{};
      for (final r in rows('pages')) {
        if (r['id'] != pages.length + 1) invalid('Page order invalid');
        final refs = <QuranVerse>[];
        for (final ref in r['verses'] as List) {
          final key = '${ref['surah']}:${ref['ayah']}';
          final v = verses[key];
          if (v == null || !seen.add(key)) {
            invalid('Missing or repeated verse $key');
          }
          if (previous != null && !follows(verses[previous]!, v)) {
            invalid('Page verse order invalid');
          }
          previous = key;
          refs.add(v);
        }
        if (refs.isEmpty) invalid('Empty page');
        pages.add(
          QuranPage(
            r['id'] as int,
            r['printedPage'] as int?,
            List.unmodifiable(refs),
            r['pdfPage'] as int?,
          ),
        );
      }
      if (pages.isEmpty || seen.length != verses.length) {
        invalid('Unassigned verses');
      }
      Map<int, String> named(String file, String field) {
        final result = <int, String>{};
        for (final r in rows(file)) {
          final s = r['surah'] as int, value = r[field] as String;
          if (s < 1 ||
              s > 114 ||
              value.trim().isEmpty ||
              result.containsKey(s)) {
            invalid('Invalid/duplicate $file');
          }
          result[s] = value;
        }
        for (final v in verses.values) {
          if (!result.containsKey(v.surah)) invalid('Missing $file ${v.surah}');
        }
        return Map.unmodifiable(result);
      }

      final names = named('surah_names_pdf', 'name');
      final arabicNames = named('surah_names_arabic', 'name');
      final titles = named('surah_titles_diyanet', 'name');
      final descriptions = named('surah_descriptions', 'text');
      final notes = <String, String>{};
      final noteRows = <String, Map<String, dynamic>>{};
      for (final r in rows('footnotes')) {
        final id = r['id'] as String, text = r['text'] as String;
        if (id.isEmpty || text.trim().isEmpty || notes.containsKey(id)) {
          invalid('Invalid/duplicate note');
        }
        notes[id] = text;
        noteRows[id] = r;
      }
      final translations = <TranslationBlock>[];
      final translated = <String>{}, ids = <String>{}, usedNotes = <String>{};
      int order = -1;
      final verseOrder = {for (final (i, v) in verses.values.indexed) v.key: i};
      for (final r in rows('translations')) {
        final b = TranslationBlock(r);
        if (b.id.isEmpty ||
            !ids.add(b.id) ||
            b.text.trim().isEmpty ||
            b.fromAyah < 1 ||
            b.toAyah < b.fromAyah ||
            b.toAyah > (counts[b.surah] ?? 0)) {
          invalid('Invalid translation');
        }
        final first = verseOrder['${b.surah}:${b.fromAyah}'];
        if (first == null || first <= order) {
          invalid('Translation order invalid');
        }
        order = first;
        for (var a = b.fromAyah; a <= b.toAyah; a++) {
          final key = '${b.surah}:$a';
          if (!verses.containsKey(key) || !translated.add(key)) {
            invalid('Missing/overlapping translation $key');
          }
        }
        final uniqueNotes = <String>{};
        for (final id in b.footnoteIds) {
          final n = noteRows[id];
          if (n == null ||
              !uniqueNotes.add(id) ||
              n['surah'] != b.surah ||
              (n['fromAyah'] as int) > b.toAyah ||
              (n['toAyah'] as int) < b.fromAyah) {
            invalid('Invalid linked note $id');
          }
          usedNotes.add(id);
        }
        translations.add(b);
      }
      if (translated.length != verses.length ||
          usedNotes.length != notes.length) {
        invalid('Incomplete translation/note coverage');
      }
      // A complete book must agree with all declared metadata. Excerpt fixtures may stop early.
      if (docs['verses']['source']?['status'] == 'complete') {
        if (counts.length != 114 ||
            verses.length != counts.values.fold<int>(0, (a, b) => a + b)) {
          invalid('Incomplete full edition');
        }
      }
      final sajdahMarkers = <String>{};
      for (final r in (docs['sajdah_markers']?['items'] ?? const [])) {
        final key = '${r['surah']}:${r['ayah']}';
        if (!verses.containsKey(key) || !sajdahMarkers.add(key)) {
          invalid('Invalid/duplicate sajdah marker $key');
        }
        final sourcePage = r['sourcePage'] as int;
        if (sourcePage < 0 ||
            sourcePage >= pages.length ||
            !pages[sourcePage].verses.any((v) => v.key == key)) {
          invalid('Sajdah marker source page mismatch $key');
        }
      }
      if (docs['verses']['source']?['status'] == 'complete' &&
          sajdahMarkers.length != 14) {
        invalid('Incomplete Diyanet sajdah markers');
      }
      final readerPages = <QuranPage>[];
      if (pages.length > 1 &&
          pages[0].verses.every((v) => v.surah == 1) &&
          pages[1].verses.first.surah == 2) {
        readerPages.add(
          QuranPage(
            1,
            null,
            List.unmodifiable([...pages[0].verses, ...pages[1].verses]),
            null,
          ),
        );
        for (var i = 2; i < pages.length; i++) {
          readerPages.add(
            QuranPage(
              i,
              pages[i].printedPage,
              pages[i].verses,
              pages[i].pdfPage,
            ),
          );
        }
      } else {
        readerPages.addAll(pages);
      }
      return ReaderData._(
        List.unmodifiable(readerPages),
        List.unmodifiable(pages),
        List.unmodifiable(translations),
        names,
        arabicNames,
        titles,
        Map.unmodifiable(metadata),
        descriptions,
        Map.unmodifiable(notes),
        Map.unmodifiable({
          for (final n in datasets)
            if (docs[n] != null) n: docs[n]['source'],
        }),
        Set.unmodifiable(sajdahMarkers),
      );
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('Invalid reader assets: $e');
    }
  }

  /// Whole source groups are repeated at physical boundaries, never split or reworded.
  List<TranslationBlock> blocksFor(QuranPage page) =>
      _blocks[page.id] ?? const [];
  int startPage(int surah) => _starts[surah] ?? -1;
}
