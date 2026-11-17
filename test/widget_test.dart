import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuran_kitaphanasy/main.dart';
import 'package:kuran_kitaphanasy/reader_data.dart';

import 'reader_fixture.dart';

void main() {
  test('Legacy PDF translation expectations and Arabic script integrity remain intact', () {
    final expected = jsonDecode(
      File('test/translation_expected.json').readAsStringSync(),
    );
    final legacy = jsonDecode(File('assets/quran.json').readAsStringSync());
    for (final s in legacy['surahs']) {
      expect(
        (s['blocks'] as List).map((b) => b['translation']).toList(),
        expected['${s['id']}'],
      );
      for (final b in s['blocks']) {
        expect(RegExp(r'[\u0600-\u06ff]').hasMatch(b['arabic']), isTrue);
      }
    }
    final grouped =
        (legacy['surahs'] as List).firstWhere((s) => s['id'] == 112)['blocks']
            as List;
    expect(grouped, hasLength(1));
    expect(grouped.single['range'], '1–4');
  });
  test(
    'Loader retains exact text and source grouping including cross-page groups',
    () {
      final docs = fixtureDocuments();
      final items = docs['translations']['items'] as List;
      items[1]['toAyah'] = 2;
      items.removeAt(2);
      final data = ReaderData.fromDocuments(docs);
      expect(data.blocksFor(data.pages[1]).single.text, items[1]['text']);
      expect(data.blocksFor(data.pages[0]).last.id, 't2');
      expect(data.blocksFor(data.pages[1]).single.range, '1–2');
    },
  );
  test('Incomplete pages and missing source references fail instead of inventing data', () {
    final empty = fixtureDocuments();
    (empty['pages']['items'] as List).clear();
    expect(() => ReaderData.fromDocuments(empty), throwsFormatException);
    final bad = fixtureDocuments();
    (bad['verses']['items'] as List).clear();
    expect(() => ReaderData.fromDocuments(bad), throwsFormatException);
    final note = fixtureDocuments();
    (note['footnotes']['items'] as List).clear();
    expect(() => ReaderData.fromDocuments(note), throwsFormatException);
  });
  testWidgets(
    'Unavailable data shows an honest error with working home action',
    (t) async {
      final pending = Completer<ReaderData>();
      var returnedHome = false;
      // Reader-level errors remain recoverable independently of the new
      // app-level startup/retry screen (covered in startup_test.dart).
      await t.pumpWidget(
        MaterialApp(
          home: Reader(data: pending.future, goHome: () => returnedHome = true),
        ),
      );
      pending.completeError(const FormatException('unverified'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('data-error')), findsOneWidget);
      await t.tap(find.byKey(const Key('back-library')));
      await t.pumpAndSettle();
      expect(returnedHome, isTrue);
    },
  );
}
