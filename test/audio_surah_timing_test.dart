import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuran_kitaphanasy/audio/quran_audio_controller.dart';

import 'audio_service_test.dart' show QueuePlayer;

class TimingPlayer extends QueuePlayer {
  Duration? sought;
  Completer<void>? seekGate;
  bool reachedSeek = false;
  @override
  Future<void> seek(Duration p) async {
    sought = p;
    reachedSeek = true;
    await seekGate?.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('all 570 full-release packages have exact positive per-file timing coverage', () {
    final catalog = jsonDecode(
      File('assets/data/audio_catalog.json').readAsStringSync(),
    );
    expect(catalog['packages'], hasLength(570));
    for (final p in catalog['packages']) {
      if (catalog['provider'] == 'mp3quran') {
        final model = AudioPackage.fromJson(Map<String, dynamic>.from(p));
        expect(model.isFullSurah, true);
        expect(model.validMetadata, true, reason: model.key);
        expect(
          model.timingPrefix.last,
          (p['totalDurationMs'] as int) +
              (model.openingPrelude?.durationMs ?? 0),
        );
        expect(p['durationsMs'], isNull);
        continue;
      }
      expect(
        p['durationsMs'],
        isA<Map>(),
        reason: '${p['reciterId']}/${p['surah']}',
      );
      final times = p['durationsMs'] as Map;
      expect(times.keys.toSet(), (p['files'] as Map).keys.toSet());
      expect(times.values.every((v) => v is int && v > 0), true);
    }
  });
  late Directory root;
  late TimingPlayer q;
  late QuranAudioController c;
  Future<void> fixture({int surah = 2, bool timing = true}) async {
    root = await Directory.systemTemp.createTemp('surah-timing');
    q = TimingPlayer();
    final prefix = surah.toString().padLeft(3, '0');
    final files = {
      for (var i = 0; i < 3; i++)
        '$prefix${i.toString().padLeft(3, '0')}.mp3': utf8.encode('file $i'),
    };
    final archive = Archive();
    files.forEach((k, v) => archive.addFile(ArchiveFile(k, v.length, v)));
    final zip = ZipEncoder().encode(archive);
    c = QuranAudioController(
      directory: () async => root,
      playerFactory: () => q,
      downloader: (_, _) async* {
        yield zip;
      },
      catalogLoader: () async => jsonEncode({
        'reciters': [
          {'id': 'Alafasy_128kbps', 'name': 'Afasi', 'bitrate': 128},
        ],
        'packages': [
          {
            'reciterId': 'Alafasy_128kbps',
            'surah': surah,
            'ayahCount': 2,
            'bytes': zip.length,
            'driveFileId': 'fixture',
            'sha256': sha256.convert(zip).toString(),
            'files': files.map(
              (k, v) => MapEntry(k, sha256.convert(v).toString()),
            ),
            if (timing)
              'durationsMs': {
                '${prefix}000.mp3': 4000,
                '${prefix}001.mp3': 10000,
                '${prefix}002.mp3': 20000,
              },
          },
        ],
      }),
    );
    await c.selectVerse(surah, 1);
    await c.downloadSelected();
    await c.play();
    addTearDown(() async {
      c.dispose();
      await root.delete(recursive: true);
    });
  }

  test('prefix includes intro once and total stays stable across native transitions', () async {
    await fixture();
    final dynamic api = c;
    expect(api.hasSurahTiming, true);
    expect(api.surahDuration, const Duration(seconds: 34));
    q.tick(0, seconds: 2, duration: 4);
    expect(api.surahPosition, const Duration(seconds: 2));
    q.tick(1, seconds: 3, duration: 10);
    expect(api.surahPosition, const Duration(seconds: 7));
    q.tick(2, seconds: 5, duration: 21);
    expect(api.surahPosition, const Duration(seconds: 19));
    expect(api.surahDuration, const Duration(seconds: 34));
    q.tick(2, seconds: 21, duration: 21);
    expect(api.surahPosition, api.surahDuration);
  });
  for (final s in [1, 9]) {
    test('surah $s excludes archived zero file', () async {
      await fixture(surah: s);
      final dynamic api = c;
      expect(api.surahDuration, const Duration(seconds: 30));
      q.tick(1, seconds: 3);
      expect(api.surahPosition, const Duration(seconds: 13));
    });
  }
  test('legacy timings stay explicitly unavailable', () async {
    await fixture(timing: false);
    final dynamic api = c;
    q.tick(1, seconds: 3, duration: 10);
    expect(api.hasSurahTiming, false);
    expect(api.surahDuration, Duration.zero);
    expect(api.surahPosition, Duration.zero);
  });
  test('full seek maps intro boundaries and preserves paused or playing without reload', () async {
    await fixture();
    final dynamic api = c;
    await api.seekSurah(const Duration(seconds: 19));
    expect(q.index, 2);
    expect(q.sought, const Duration(seconds: 5));
    expect(c.isPlaying, true);
    expect(api.surahPosition, const Duration(seconds: 19));
    await c.pause();
    await api.seekSurah(const Duration(seconds: 2));
    expect(c.isPlaying, false);
    expect(c.isBasmala, true);
    expect(q.index, 0);
    expect(api.surahPosition, const Duration(seconds: 2));
    await api.seekSurah(const Duration(seconds: 4));
    expect(c.isBasmala, false);
    expect(c.ayah, 1);
    expect(q.index, 1);
    expect(api.surahPosition, const Duration(seconds: 4));
    expect(q.preparations, 1);
    await c.play();
    expect(api.surahPosition, const Duration(seconds: 4));
  });
  test(
    'EOF clamps to total and repeat resets prefix; clear resets clock',
    () async {
      await fixture();
      final dynamic api = c;
      c.toggleRepeatSurah();
      q.tick(2, seconds: 19, duration: 20);
      q.tick(0, seconds: 1, duration: 4);
      expect(api.surahPosition, const Duration(seconds: 1));
      c.toggleRepeatSurah();
      q.tick(2, seconds: 20, duration: 20, completed: true);
      expect(api.surahPosition, api.surahDuration);
      expect(c.isPlaying, false);
      await api.seekSurah(const Duration(seconds: 34));
      expect(api.surahPosition, api.surahDuration);
      expect(c.isPlaying, false);
      await c.close();
      expect(api.surahPosition, Duration.zero);
      await c.selectVerse(2, 2);
      expect(api.surahPosition, const Duration(seconds: 14));
    },
  );
  test(
    'seek while selected but not playing never briefly starts output',
    () async {
      await fixture();
      await c.close();
      var started = false;
      c.addListener(() {
        if (c.isPlaying) started = true;
      });
      final dynamic api = c;
      await api.seekSurah(const Duration(seconds: 19));
      expect(started, false);
      expect(c.isPlaying, false);
      expect(api.surahPosition, const Duration(seconds: 19));
    },
  );
  test(
    'close cancels a seek actually pending at native offset boundary',
    () async {
      await fixture();
      final dynamic api = c;
      q.seekGate = Completer<void>();
      final Future<void> pending = api.seekSurah(const Duration(seconds: 19));
      for (var i = 0; i < 20 && !q.reachedSeek; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(q.reachedSeek, true);
      await c.close();
      q.seekGate!.complete();
      await pending;
      expect(c.isPlaying, false);
      expect(api.surahPosition, Duration.zero);
      q.tick(2, seconds: 19);
      expect(api.surahPosition, Duration.zero);
    },
  );
}
