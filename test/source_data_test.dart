import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuran_kitaphanasy/main.dart';
import 'package:kuran_kitaphanasy/reader_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Actual offline bundle loads all exact PDF page memberships and source strings', () async {
    final data = await ReaderData.load();
    List<dynamic> rows(String name) =>
        jsonDecode(File('assets/data/$name.json').readAsStringSync())['items']
            as List;
    final rawPages = rows('pages');
    final rawVerses = {
      for (final r in rows('verses')) '${r['surah']}:${r['ayah']}': r,
    };
    final rawBlocks = {for (final r in rows('translations')) r['id']: r};
    expect(
      data.sourcePages.map((p) => p.pdfPage),
      rawPages.map((p) => p['pdfPage']),
    );
    expect(
      data.sourcePages.map((p) => p.verses.last.ayah),
      rawPages.map((p) => p['verses'].last['ayah']),
    );
    expect(data.names.length, 114);
    expect(data.arabicNames.length, 114);
    expect(data.availableSurahs, List.generate(114, (i) => i + 1));
    for (final p in data.sourcePages) {
      final raw = rawPages[p.id - 1];
      expect(p.verses.map((v) => v.key), [
        for (final v in raw['verses']) '${v['surah']}:${v['ayah']}',
      ]);
      for (final v in p.verses) {
        expect(v.text, rawVerses[v.key]['text']);
      }
    }
    for (final b in data.translations) {
      final raw = rawBlocks[b.id];
      expect(b.text, raw['text']);
      expect(b.fromAyah, raw['fromAyah']);
      expect(b.toAyah, raw['toAyah']);
      expect(b.footnoteIds, raw['footnoteIds']);
    }
    for (final n in rows('footnotes')) {
      expect(data.footnotes[n['id']], n['text']);
    }
    for (final s in rows('surah_descriptions')) {
      expect(data.descriptions[s['surah']], s['text']);
    }
  });
  testWidgets(
    'Actual bundle opens first page, exact note, and labels physical PDF without invented printed zero',
    (t) async {
      late ReaderData data;
      await t.runAsync(() async {
        data = await ReaderData.load();
      });
      await t.pumpWidget(QuranApp(data: Future.value(data)));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('book-quran')));
      await t.pumpAndSettle();
      expect(find.text('Sahypa 1 (1/${data.pages.length})'), findsOneWidget);
      expect(find.text('PDF sahypasy: 2'), findsNothing);
      expect(data.pages.first.pdfPage, isNull);
      expect(data.sourcePages.first.pdfPage, 2);
      final id = data.translations.first.footnoteIds.first;
      await t.ensureVisible(find.byKey(Key('note-$id')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(Key('note-$id')));
      await t.pumpAndSettle();
      expect(
        find.text(data.footnotes[id]!.substring('Düşündiriş: '.length)),
        findsOneWidget,
      );
    },
  );
}
