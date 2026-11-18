import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kuran_kitaphanasy/audio/quran_audio_controller.dart';

import 'audio_fakes.dart';

class TimingPlayer extends ClipPlayer {
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
    expect(catalog['provider'], 'mp3quran');
    for (final p in catalog['packages']) {
      final model = AudioPackage.fromJson(Map<String, dynamic>.from(p));
      expect(model.format, AudioPackage.fullSurahFormat);
      expect(model.validMetadata, true, reason: model.key);
      expect(
        model.timingPrefix.last,
        (p['totalDurationMs'] as int) + (model.openingPrelude?.durationMs ?? 0),
      );
    }
  });
  late Directory root;
  late TimingPlayer q;
  late QuranAudioController c;
  // Original 4 s intro, ayah one 10 s, ayah two 20 s in one recording.
  Future<void> fixture() async {
    root = await Directory.systemTemp.createTemp('surah-timing');
    q = TimingPlayer();
    final p = timedPackage()
      ..['totalDurationMs'] = 34000
      ..['verseTimings'] = [
        {'ayah': 1, 'startMs': 4000, 'endMs': 14000},
        {'ayah': 2, 'startMs': 14000, 'endMs': 34000},
      ];
    c = QuranAudioController(
      directory: () async => root,
      playerFactory: () => q,
      downloader: (_, _) async* {
        yield syntheticZip;
      },
      catalogLoader: () async => catalog(p),
    );
    await c.selectVerse(1, 1);
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
    expect(c.isOpening, true);
    expect(q.index, 0);
    expect(api.surahPosition, const Duration(seconds: 2));
    await api.seekSurah(const Duration(seconds: 4));
    expect(c.isOpening, false);
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
      await c.selectVerse(1, 2);
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
