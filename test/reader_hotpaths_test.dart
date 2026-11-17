import 'dart:async';
import 'dart:io';

import 'package:kuran_kitaphanasy/reader/data/reader_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuran_kitaphanasy/reader/presentation/reader.dart';
import 'package:kuran_kitaphanasy/reader/presentation/reader_paging.dart';
import 'package:kuran_kitaphanasy/reader/settings/reader_preferences.dart';

import 'reader_fixture.dart';
import 'reader_audio_test.dart' show FakeAudio;
import 'reader_audio_follow_test.dart' show start;

class _PendingBookmarkStore extends MemoryReaderStore {
  final bookmarks = Completer<Map<String, dynamic>?>();
  bool reached = false;
  int reads = 0;

  @override
  Future<Map<String, dynamic>?> read(String bookId) {
    reads++;
    if (bookId.endsWith('.bookmarks')) {
      reached = true;
      return bookmarks.future;
    }
    return super.read(bookId);
  }
}

void main() {
  for (final phase in ['initial', 'restored', 'orientation']) {
    testWidgets('reader uses nested paging controller after $phase', (t) async {
      final pending = Completer<ReaderData>();
      final store = MemoryReaderStore();
      await store.write('quran', {'version': 1, 'page': 3});
      await t.pumpWidget(
        MaterialApp(
          home: Reader(data: pending.future, store: store, goHome: () {}),
        ),
      );
      final dynamic state = t.state(find.byType(Reader));
      if (phase != 'initial') {
        pending.complete(fixture());
        await t.pumpAndSettle();
        if (phase == 'orientation') {
          state.changeOrientation(true);
          await t.pumpAndSettle();
          state.changeOrientation(false);
          await t.pumpAndSettle();
        }
        expect(state.selected, 3);
        expect((state.pages as PageController).page, 3);
      }
      expect(state.pages, isA<ReaderPageController>());
      await t.pumpWidget(const SizedBox());
    });
  }

  testWidgets('pending data completion is harmless after reader disposal', (
    t,
  ) async {
    final pending = Completer<ReaderData>();
    await t.pumpWidget(
      MaterialApp(
        home: Reader(data: pending.future, goHome: () {}),
      ),
    );
    final dynamic state = t.state(find.byType(Reader));
    final result = state.source as Future<ReaderData>;
    await t.pumpWidget(const SizedBox());
    final data = fixture();
    final checked = expectLater(result, completion(same(data)));
    pending.complete(data);
    await t.pump();
    await checked;
    expect(state.audioPageIndex, isEmpty);
    expect(t.takeException(), isNull);
  });

  testWidgets('pending bookmark restore stops after reader disposal', (
    t,
  ) async {
    final store = _PendingBookmarkStore();
    final data = fixture();
    await t.pumpWidget(
      MaterialApp(
        home: Reader(data: Future.value(data), store: store, goHome: () {}),
      ),
    );
    await t.pump();
    expect(store.reached, isTrue);
    final dynamic state = t.state(find.byType(Reader));
    final result = state.source as Future<ReaderData>;
    await t.pumpWidget(const SizedBox());
    final checked = expectLater(result, completion(same(data)));
    store.bookmarks.complete(null);
    await t.pump();
    await checked;
    expect(store.reads, 1, reason: 'no preference I/O after disposal');
    expect(t.takeException(), isNull);
  });
  testWidgets('book theme is allocated once per inherited theme and override', (
    t,
  ) async {
    final data = Future.value(fixture());
    Future<void> mount(Brightness brightness) => t.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: Reader(data: data, goHome: () {}),
      ),
    );
    await mount(Brightness.light);
    await t.pumpAndSettle();
    final dynamic state = t.state(find.byType(Reader));
    state.bookDark = true;
    final first = state.readerTheme;
    final identities = Set<ThemeData>.identity();
    for (var i = 0; i < 100; i++) {
      identities.add(state.readerTheme as ThemeData);
      expect(identical(state.readerTheme, first), isTrue);
    }
    expect(identities, hasLength(1));
    debugPrint(
      'reader-theme 100 repeated reads distinct-instances=${identities.length}',
    );
    state.bookDark = false;
    final lightOverride = state.readerTheme as ThemeData;
    expect(lightOverride.brightness, Brightness.light);
    expect(identical(lightOverride, first), isFalse);
    await mount(Brightness.dark);
    await t.pumpAndSettle();
    expect(identical(state.readerTheme, lightOverride), isFalse);
    expect(state.readerTheme.brightness, Brightness.light);
    state.bookDark = null;
    expect(state.readerTheme.brightness, Brightness.dark);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('twenty position samples do not rebuild scripture', (t) async {
    final audio = FakeAudio()..local = true;
    await start(t, audio);
    final finder = find.byKey(const Key('arabic-flow-1'));
    var previous = t.widget<Text>(finder);
    var rebuilds = 0;
    for (var i = 1; i <= 20; i++) {
      audio.elapsed = Duration(milliseconds: i * 100);
      audio.notifyListeners();
      await t.pump(const Duration(milliseconds: 100));
      final next = t.widget<Text>(finder);
      if (!identical(previous, next)) rebuilds++;
      previous = next;
      expect(
        t.widget<Text>(find.byKey(const Key('audio-position'))).data,
        '0:${audio.elapsed.inSeconds.toString().padLeft(2, '0')}',
        reason: 'isolating scripture rebuilds must not freeze the player clock',
      );
    }
    expect(rebuilds, 0);
    debugPrint(
      'reader-audio samples=20 scripture-widget-replacements=$rebuilds clock=0:02',
    );
    await t.pumpAndSettle();
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('surah geometry updates header without rebuilding scripture', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        home: Reader(data: Future.value(fixture()), goHome: () {}),
      ),
    );
    await t.pumpAndSettle();
    final dynamic state = t.state(find.byType(Reader));
    final finder = find.byKey(const Key('arabic-t1'));
    final before = t.widget<Text>(finder);
    state.activeSurah = 2;
    await t.pump();
    expect(
      t.widget<Text>(find.byKey(const Key('surah-title'))).data,
      contains('Bakara'),
    );
    expect(identical(t.widget<Text>(finder), before), isTrue);
    state.trackActiveSurah();
    await t.pump();
    expect(state.activeSurah, 1);
    expect(
      t.widget<Text>(find.byKey(const Key('surah-title'))).data,
      contains('Fatyha'),
    );
    expect(identical(t.widget<Text>(finder), before), isTrue);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets(
    'UTF16 indexes match rendered scripture with multi-digit markers and supplementary marks',
    (t) async {
      final docs = fixtureDocuments();
      for (var ayah = 10; ayah <= 12; ayah++) {
        (docs['pages']['items'].last['verses'] as List).add({
          'surah': 2,
          'ayah': ayah,
        });
        (docs['verses']['items'] as List).add({
          'surah': 2,
          'ayah': ayah,
          'text': 'بِسْمِ اللّٰهِ\u{10efe}',
        });
        (docs['translations']['items'] as List).add({
          'id': 'extra-$ayah',
          'surah': 2,
          'fromAyah': ayah,
          'toAyah': ayah,
          'text': 'TEST ONLY',
          'footnoteIds': [],
          'pdfPage': 10,
        });
      }
      final data = ReaderData.fromDocuments(docs);
      await t.pumpWidget(
        MaterialApp(
          home: Reader(data: Future.value(data), goHome: () {}),
        ),
      );
      await t.pumpAndSettle();
      final dynamic state = t.state(find.byType(Reader));
      state.go(data.pages.length - 1);
      await t.pumpAndSettle();
      for (final mode in ['arabic', 'both']) {
        await setMode(t, mode);
        for (final verse in data.pages.last.verses) {
          final dynamic target = (state.arabicTargets as Map)[verse.key];
          final render =
              (target.key as GlobalKey).currentContext!.findRenderObject()
                  as RenderParagraph;
          final plain = render.text.toPlainText(includeSemanticsLabels: false);
          final digits = verse.ayah
              .toString()
              .split('')
              .map((c) => '٠١٢٣٤٥٦٧٨٩'[int.parse(c)])
              .join();
          final expected = '${verse.text}\u00a0\u200f﴿$digits﴾\u200f ';
          final length = (state.audioVerseLength as Map)[verse.key] as int;
          expect(length, expected.length);
          expect(
            plain.substring(
              target.offset as int,
              (target.offset as int) + length,
            ),
            expected,
          );
        }
      }
      await t.pumpWidget(const SizedBox());
    },
  );

  for (final vertical in [false, true]) {
    testWidgets(
      'live target caches remain bounded across modes vertical=$vertical',
      (t) async {
        final data = fixture();
        await t.pumpWidget(
          MaterialApp(
            home: Reader(data: Future.value(data), goHome: () {}),
          ),
        );
        await t.pumpAndSettle();
        final dynamic state = t.state(find.byType(Reader));
        state.changeOrientation(vertical);
        await t.pumpAndSettle();
        var maximumKeys = 0;
        for (final mode in ['both', 'arabic', 'translation', 'both']) {
          await setMode(t, mode);
          for (final index in [8, 3, 0]) {
            state.go(index);
            await t.pumpAndSettle();
            for (final map in [
              state.sectionKeys,
              state.bookmarkTargets,
              state.arabicKeys,
            ]) {
              final keys = (map as Map).values.cast<GlobalKey>();
              expect(keys.where((key) => key.currentContext == null), isEmpty);
              maximumKeys = maximumKeys < keys.length
                  ? keys.length
                  : maximumKeys;
            }
            for (final dynamic target in (state.arabicTargets as Map).values) {
              expect((target.key as GlobalKey).currentContext, isNotNull);
            }
            if (mode == 'translation') expect(state.arabicTargets, isEmpty);
            expect(
              (state.offsets as Map).length,
              lessThanOrEqualTo(ReaderPreferences.offsetLimit),
            );
          }
        }
        debugPrint(
          'reader-cache vertical=$vertical maximum-live-keys-per-map=$maximumKeys',
        );
        await t.pumpWidget(const SizedBox());
      },
    );
  }

  test('startup offset indexing never constructs styled scripture spans', () {
    final source = File('lib/reader/presentation/reader.dart')
        .readAsStringSync();
    final restore = source.substring(
      source.indexOf('Future<ReaderData> restore()'),
      source.indexOf('void persist()'),
    );
    expect(restore, isNot(contains('arabic([verse])')));
    expect(restore, isNot(contains('toPlainText')));
  });

  testWidgets(
    'unmounted paragraph and bookmark keys are released after paging',
    (t) async {
      await t.pumpWidget(
        MaterialApp(
          home: Reader(
            data: Future.value(fixture()),
            store: MemoryReaderStore(),
            goHome: () {},
          ),
        ),
      );
      await t.pumpAndSettle();
      final dynamic state = t.state(find.byType(Reader));
      for (var i = 1; i < 9; i++) {
        state.go(i);
        await t.pumpAndSettle();
      }
      final keys = (state.arabicKeys as Map).values.cast<GlobalKey>();
      expect(keys.where((key) => key.currentContext == null), isEmpty);
      final blocks = (state.bookmarkTargets as Map).values.cast<GlobalKey>();
      expect(blocks.where((key) => key.currentContext == null), isEmpty);
      await t.pumpWidget(const SizedBox());
    },
  );
}
