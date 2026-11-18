import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuran_kitaphanasy/audio/quran_audio_controller.dart';

import 'audio_fakes.dart';

final sourceBytes = utf8.encode(
  'synthetic complete Fatiha original, never decoded',
);
Map<String, dynamic> fixture({int intro = 10}) {
  final p = timedPackage();
  p['surah'] = 2;
  p['audioFile'] = '002.mp3';
  p['files'] = {'002.mp3': sha256.convert(syntheticMp3).toString()};
  p['source']['url'] = 'https://server8.mp3quran.net/afs/002.mp3';
  p['source']['timingUrl'] =
      'https://www.mp3quran.net/api/v3/ayat_timing?surah=2&read=123';
  p['verseTimings'][0]['startMs'] = intro;
  p['openingPrelude'] = {
    'asset': 'assets/audio/synthetic-fatiha.mp3',
    'sha256': sha256.convert(sourceBytes).toString(),
    'startMs': 300,
    'endMs': 3240,
    'sourceDurationMs': 48013,
    'reciterId': 'mp3quran_123',
    'sourceSurah': 1,
    'sourceAyah': 1,
  };
  return p;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late ClipPlayer q;
  late QuranAudioController c;
  late Map<String, dynamic> raw;
  var assetLoads = 0;
  Future<List<int>> Function(String)? loader;
  Future<void> setup({int intro = 10, int ayah = 1}) async {
    raw = fixture(intro: intro);
    c = QuranAudioController(
      directory: () async => root,
      catalogLoader: () async => catalog(raw),
      playerFactory: () => q,
      openingAssetLoader: (a) async {
        assetLoads++;
        return loader == null ? sourceBytes : await loader!(a);
      },
      downloader: (_, _) => throw StateError('No network allowed'),
    );
    final dir = Directory(
      '${root.path}/quran_audio/mp3quran-0.0.1/mp3quran_123/2',
    );
    await dir.create(recursive: true);
    await File('${dir.path}/002.mp3').writeAsBytes(syntheticMp3);
    await c.initialize();
    await c.selectVerse(2, ayah);
    expect(c.isReady, true);
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('prelude-test-');
    q = ClipPlayer();
    assetLoads = 0;
    loader = null;
  });
  tearDown(() async {
    c.dispose();
    await root.delete(recursive: true);
  });

  test('prepend external interval while retaining original tiny intro and all source intervals', () async {
    await setup();
    await c.play();
    expect(q.clips.map((v) => v.ayah), [null, null, 1, 2]);
    expect(q.clips.map((v) => v.start.inMilliseconds), [300, 0, 10, 5000]);
    expect(q.clips.map((v) => v.end.inMilliseconds), [3240, 10, 5000, 10000]);
    expect(q.paths.first, isNot(q.paths.last));
    expect(await File(q.paths.first).readAsBytes(), sourceBytes);
    expect(c.selectedPackage!.verseTimings, raw['verseTimings']);
    expect(c.selectedPackage!.totalDurationMs, 10000);
  });
  test(
    'prefix adds only prelude duration without rewriting archived timing',
    () async {
      await setup();
      expect(c.selectedPackage!.timingPrefix, [0, 2940, 2950, 7940, 12940]);
      expect(c.surahDuration.inMilliseconds, 12940);
    },
  );
  test('atomic canonical mapping distinguishes explicit besmele from generic original intro', () async {
    await setup();
    await c.play();
    expect(c.isBasmala, true);
    expect(c.ayah, 1);
    q.tick(1);
    expect(c.isOpening, true);
    expect(c.isBasmala, false);
    expect(c.ayah, 1);
    q.tick(2, seconds: 1);
    expect(c.isOpening, false);
    expect(c.ayah, 1);
    expect(c.surahPosition.inMilliseconds, 3950);
    q.tick(3, seconds: 1);
    expect(c.ayah, 2);
    expect(c.surahPosition.inMilliseconds, 8940);
  });
  test(
    'paused seek exact boundaries reuses queue and verified bytes',
    () async {
      await setup();
      await c.play();
      await c.pause();
      for (final row in [
        (2939, 0, 2939, true, true),
        (2940, 1, 0, true, false),
        (2949, 1, 9, true, false),
        (2950, 2, 0, false, false),
        (7940, 3, 0, false, false),
        (12940, 3, 5000, false, false),
      ]) {
        await c.seekSurah(Duration(milliseconds: row.$1));
        expect(q.index, row.$2);
        expect(q.sought!.inMilliseconds, row.$3);
        expect(c.isOpening, row.$4);
        expect(c.isBasmala, row.$5);
        expect(c.surahPosition.inMilliseconds, row.$1);
        expect(c.isPlaying, false);
      }
      expect(q.preparations, 1);
      expect(assetLoads, 1);
    },
  );
  test(
    'initial paused seek prepares without playing and includes prelude offset',
    () async {
      await setup();
      await c.seekSurah(const Duration(milliseconds: 7940));
      expect(q.index, 3);
      expect(c.ayah, 2);
      expect(c.isPlaying, false);
      expect(q.playing, false);
      expect(c.surahPosition.inMilliseconds, 7940);
    },
  );
  test(
    'later ayah starts keep both openings; canonical previous skips them',
    () async {
      await setup(ayah: 2);
      await c.play();
      expect(q.index, 3);
      expect(q.clips, hasLength(4));
      await c.previous();
      expect(q.index, 2);
      expect(c.ayah, 1);
      expect(c.isOpening, false);
      await c.next();
      expect(q.index, 3);
    },
  );
  test('repeat one waits through both openings; whole repeat includes prelude once; EOF replay', () async {
    await setup();
    await c.play();
    c.toggleRepeatAyah();
    expect(q.repeatOne, false);
    q.tick(1);
    expect(q.repeatOne, false);
    q.tick(2);
    expect(q.repeatOne, true);
    expect(c.ayah, 1);
    c.toggleRepeatAyah();
    c.toggleRepeatSurah();
    expect(q.repeatAll, true);
    q.tick(3);
    q.tick(0);
    expect(c.isBasmala, true);
    expect(c.surahPosition, Duration.zero);
    c.toggleRepeatSurah();
    q.tick(3, duration: 5, completed: true);
    expect(c.ayah, 2);
    expect(c.surahPosition.inMilliseconds, 12940);
    expect(c.isPlaying, false);
    await c.selectVerse(2, 1);
    await c.play();
    expect(q.index, 0);
    expect(c.isBasmala, true);
  });
  test(
    'zero original intro still has exactly one unnumbered prelude',
    () async {
      await setup(intro: 0);
      await c.play();
      expect(q.clips.map((v) => v.ayah), [null, 1, 2]);
      expect(c.selectedPackage!.timingPrefix, [0, 2940, 7940, 12940]);
    },
  );
  test('asset corruption fails before native preparation', () async {
    await setup();
    loader = (_) async => [1, 2, 3];
    await c.play();
    expect(q.preparations, 0);
    expect(c.isPlaying, false);
    expect(c.errorDetail, contains('hash'));
  });
  test('cached corruption fails closed, never silently replaced', () async {
    await setup();
    final hash = sha256.convert(sourceBytes).toString();
    final file = File('${root.path}/quran_audio/openings/$hash.mp3');
    await file.parent.create(recursive: true);
    await file.writeAsString('tampered');
    await c.play();
    expect(q.preparations, 0);
    expect(c.errorDetail, contains('hash'));
  });
  test(
    'asset is checked even when content-addressed cache already exists',
    () async {
      await setup();
      await c.play();
      await c.close();
      loader = (_) async => [0];
      await c.play();
      expect(c.isPlaying, false);
      expect(q.preparations, 1);
      expect(c.errorDetail, contains('hash'));
    },
  );
  test(
    'close cancels at reached asset await before any native preparation',
    () async {
      await setup();
      final reached = Completer<void>(), gate = Completer<List<int>>();
      loader = (_) {
        reached.complete();
        return gate.future;
      };
      final play = c.play();
      await reached.future.timeout(const Duration(seconds: 2));
      await c.close();
      gate.complete(sourceBytes);
      await play;
      expect(q.preparations, 0);
      expect(c.isPlaying, false);
      expect(c.isOpening, false);
    },
  );
  test(
    'close cancels reached native preparation without stale playback',
    () async {
      await setup();
      q.preparationGate = Completer<void>();
      final play = c.play();
      for (var i = 0; i < 1000 && q.preparations == 0; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      expect(q.clips, hasLength(4));
      await c.close();
      q.preparationGate!.complete();
      await play;
      expect(c.isPlaying, false);
      expect(q.playing, false);
    },
  );
  test(
    'EOF replay restarts whole surah with prelude rather than last ayah',
    () async {
      await setup();
      await c.play();
      q.tick(3, duration: 5, completed: true);
      expect(c.surahPosition.inMilliseconds, 12940);
      await c.play();
      expect(q.index, 0);
      expect(c.ayah, 1);
      expect(c.isBasmala, true);
    },
  );
  test('terminal timestamp play restarts whole surah with prelude', () async {
    await setup();
    await c.seekSurah(const Duration(milliseconds: 12940));
    await c.play();
    expect(q.index, 0);
    expect(c.isBasmala, true);
    expect(c.surahPosition, Duration.zero);
  });
  test(
    'metadata rejects unsafe identity, targets, bounds and non-full formats',
    () async {
      await setup();
      for (final change in <void Function(Map<String, dynamic>)>[
        (p) => p['openingPrelude']['reciterId'] = 'mp3quran_92',
        (p) => p['openingPrelude']['sourceSurah'] = 2,
        (p) => p['openingPrelude']['sourceAyah'] = 2,
        (p) => p['openingPrelude']['startMs'] = -1,
        (p) => p['openingPrelude']['endMs'] = 300,
        (p) => p['openingPrelude']['endMs'] = 48014,
        (p) => p['openingPrelude']['sha256'] = 'bad',
        (p) => p['openingPrelude']['asset'] = '../escape.mp3',
        (p) => p['surah'] = 1,
        (p) => p['surah'] = 9,
        (p) => p['format'] = 'ayah-files-v1',
      ]) {
        final p = fixture();
        change(p);
        expect(
          AudioPackage.fromJson(p).validMetadata,
          false,
          reason: jsonEncode(p),
        );
      }
    },
  );
}
