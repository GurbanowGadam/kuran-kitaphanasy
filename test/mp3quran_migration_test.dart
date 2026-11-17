import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuran_kitaphanasy/audio/quran_audio_controller.dart';

import 'audio_service_test.dart' show QueuePlayer;

// Deliberately synthetic portable bytes, never a production recording.
final syntheticMp3 = utf8.encode('test-only full recording');
// Freeze one archive for catalog and transport: ZIP timestamps otherwise make
// separately encoded, identical MP3 fixtures acquire different SHA256 values.
final _syntheticZip = ZipEncoder().encode(
  Archive()..addFile(ArchiveFile('001.mp3', syntheticMp3.length, syntheticMp3)),
);
Map<String, dynamic> timedPackage({String status = 'published'}) {
  final zip = _syntheticZip;
  return {
    'reciterId': 'mp3quran_123',
    'surah': 1,
    'ayahCount': 2,
    'format': 'full-surah-timed-v1',
    'publicationStatus': status,
    'driveFileId': status == 'published'
        ? 'test-only-drive-id-0000000000'
        : null,
    'bytes': zip.length,
    'sha256': sha256.convert(zip).toString(),
    'files': {'001.mp3': sha256.convert(syntheticMp3).toString()},
    'audioFile': '001.mp3',
    'totalDurationMs': 10000,
    'verseTimings': [
      {'ayah': 1, 'startMs': 1000, 'endMs': 3000},
      {'ayah': 2, 'startMs': 5000, 'endMs': 8000},
    ],
    'source': {
      'provider': 'mp3quran',
      'reciterId': 123,
      'moshafId': 123,
      'url': 'https://server8.mp3quran.net/afs/001.mp3',
      'timingUrl':
          'https://www.mp3quran.net/api/v3/ayat_timing?surah=1&read=123',
      'timingSha256': sha256
          .convert(utf8.encode('raw fixture timings'))
          .toString(),
      'recordingStyle': 'Murattal',
    },
  };
}

String catalog(Map<String, dynamic> p) => jsonEncode({
  'version': 2,
  'provider': 'mp3quran',
  'contentVersion': '0.0.1',
  'reciters': [
    {'id': 'mp3quran_123', 'name': 'Afasi', 'bitrate': 128},
  ],
  'packages': [p],
});

class ClipPlayer extends QueuePlayer implements ClippedAudioPlayback {
  List<LocalAudioClip> clips = [];
  Duration? sought;
  @override
  Future<void> prepareClips(
    List<LocalAudioClip> value,
    int index,
    int generation,
  ) async {
    clips = value;
    await prepareQueue(value.map((v) => v.path).toList(), index, generation);
  }

  @override
  Future<void> seek(Duration p) async {
    sought = p;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'synthetic archive digest stays stable across ZIP clock boundaries',
    () async {
      final before = timedPackage();
      await Future<void>.delayed(const Duration(seconds: 3));
      expect(timedPackage()['sha256'], before['sha256']);
    },
  );
  for (final cancel in [false, true]) {
    test(
      'verified full MP3 clip queue, seek, repeat, restore and preparation cancellation=$cancel',
      () async {
        final root = await Directory.systemTemp.createTemp('full-clips');
        final q = ClipPlayer();
        final p = timedPackage();
        p['verseTimings'][1]['endMs'] = 10424;
        p['source']['timingEndBeyondAudioMs'] = 424;
        p['source']['timingPolicy'] = 'original-starts-eof-500ms-v1';
        final zip = _syntheticZip;
        var downloads = 0;
        QuranAudioController make() => QuranAudioController(
          directory: () async => root,
          catalogLoader: () async => catalog(p),
          playerFactory: () => q,
          downloader: (_, _) async* {
            downloads++;
            yield zip;
          },
        );
        var c = make();
        addTearDown(() async {
          c.dispose();
          await root.delete(recursive: true);
        });
        await c.downloadSelected();
        expect(c.isReady, true);
        q.preparationGate = cancel ? Completer<void>() : null;
        final play = c.play();
        for (var i = 0; i < 100 && q.clips.isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }
        expect(q.clips, hasLength(3));
        expect(q.clips.map((v) => v.start.inMilliseconds), [0, 1000, 5000]);
        expect(q.clips.map((v) => v.end.inMilliseconds), [1000, 5000, 10000]);
        expect(q.clips.map((v) => v.ayah), [null, 1, 2]);
        expect(q.paths.toSet(), hasLength(1));
        expect(
          q.paths.singleOrNull ?? q.paths.first,
          contains('mp3quran-0.0.1'),
        );
        if (cancel) {
          await c.close();
          q.preparationGate!.complete();
          await play;
          expect(c.isPlaying, false);
          expect(q.playing, false);
          return;
        }
        await play;
        expect(c.isOpening, true);
        expect(c.isBasmala, false);
        expect(c.ayah, 1);
        c.toggleRepeatAyah();
        expect(q.repeatOne, false);
        q.tick(1, seconds: 2, duration: 4);
        expect(c.isOpening, false);
        expect(c.ayah, 1);
        expect(q.repeatOne, true);
        expect(c.surahPosition, const Duration(seconds: 3));
        await c.pause();
        await c.seekSurah(const Duration(seconds: 6));
        expect(q.index, 2);
        expect(q.sought, const Duration(seconds: 1));
        expect(c.ayah, 2);
        expect(c.isPlaying, false);
        await c.seekSurah(const Duration(milliseconds: 10500));
        expect(c.surahDuration, const Duration(seconds: 10));
        expect(c.surahPosition, const Duration(seconds: 10));
        expect(q.sought, const Duration(seconds: 5));
        expect(q.clips.every((clip) => clip.end.inMilliseconds <= 10000), true);
        expect(c.selectedPackage!.verseTimings.last['endMs'], 10424);
        await c.previous();
        expect(q.index, 1);
        expect(c.isOpening, false);
        await c.seekSurah(const Duration(milliseconds: 500));
        expect(c.isOpening, true);
        await c.close();
        c.dispose();
        c = make();
        await c.initialize();
        expect(c.isReady, true);
        expect(downloads, 1);
        final path =
            '${root.path}/quran_audio/${c.selectedPackage!.key}/001.mp3';
        await File(path).writeAsString('corrupt');
        await c.play();
        expect(c.isPlaying, false);
        expect(c.isReady, false);
      },
    );
  }
  test(
    'bounded EOF annotations preserve raw values and validate declarations',
    () {
      for (final delta in [1, 424, 500]) {
        final raw = timedPackage();
        raw['verseTimings'][1]['endMs'] = 10000 + delta;
        raw['source']['timingEndBeyondAudioMs'] = delta;
        raw['source']['timingPolicy'] = 'original-starts-eof-500ms-v1';
        final p = AudioPackage.fromJson(raw);
        expect(p.validMetadata, true, reason: 'delta=$delta');
        expect(p.verseTimings.last['endMs'], 10000 + delta);
        expect(p.timingPrefix, [0, 1000, 5000, 10000]);
      }
      for (final defect in [
        '501',
        'nonfinal',
        'startEOF',
        'missingDelta',
        'wrongDelta',
        'missingPolicy',
        'wrongPolicy',
        'spuriousDelta',
      ]) {
        final raw = timedPackage();
        raw['verseTimings'][1]['endMs'] = 10500;
        raw['source']['timingEndBeyondAudioMs'] = 500;
        raw['source']['timingPolicy'] = 'original-starts-eof-500ms-v1';
        switch (defect) {
          case '501':
            raw['verseTimings'][1]['endMs'] = 10501;
            raw['source']['timingEndBeyondAudioMs'] = 501;
          case 'nonfinal':
            raw['verseTimings'][0]['endMs'] = 10001;
          case 'startEOF':
            raw['verseTimings'][1]['startMs'] = 10000;
          case 'missingDelta':
            raw['source'].remove('timingEndBeyondAudioMs');
          case 'wrongDelta':
            raw['source']['timingEndBeyondAudioMs'] = 499;
          case 'missingPolicy':
            raw['source'].remove('timingPolicy');
          case 'wrongPolicy':
            raw['source']['timingPolicy'] = 'clamped';
          case 'spuriousDelta':
            raw['verseTimings'][1]['endMs'] = 8000;
        }
        expect(AudioPackage.fromJson(raw).validMetadata, false, reason: defect);
      }
    },
  );
  test('full format requires explicit published status and rejects placeholder IDs', () {
    for (final id in [null, '', ' ', 'pending-upload', 'null']) {
      final raw = timedPackage()..['driveFileId'] = id;
      expect(AudioPackage.fromJson(raw).isPublished, false, reason: 'id=$id');
    }
    final raw = timedPackage()..remove('publicationStatus');
    expect(AudioPackage.fromJson(raw).isPublished, false);
  });
  test('source edition cannot claim a different reciter or style', () {
    for (final key in ['reciterId', 'recordingStyle']) {
      final raw = timedPackage();
      raw['source'][key] = key == 'reciterId' ? 4 : 'Mojawwad';
      expect(AudioPackage.fromJson(raw).validMetadata, false);
    }
  });
  test('full timeline partitions recording by authentic starts including Fatiha intro and suffix', () {
    final p = AudioPackage.fromJson(timedPackage());
    expect(p.hasTiming, true);
    expect(p.timingPrefix, [0, 1000, 5000, 10000]);
    expect(p.files.keys, ['001.mp3']);
  });
  test('pending upload parses null ID and never restores, downloads or plays cached bytes', () async {
    final root = await Directory.systemTemp.createTemp('pending-mp3');
    var downloads = 0, players = 0;
    final p = timedPackage(status: 'pending-upload');
    final old = File('${root.path}/quran_audio/mp3quran_123/1/001.mp3');
    await old.parent.create(recursive: true);
    await old.writeAsBytes(syntheticMp3);
    final c = QuranAudioController(
      directory: () async => root,
      catalogLoader: () async => catalog(p),
      playerFactory: () {
        players++;
        return QueuePlayer();
      },
      downloader: (_, _) async* {
        downloads++;
      },
    );
    addTearDown(() async {
      c.dispose();
      await root.delete(recursive: true);
    });
    await c.initialize();
    expect(c.error, isNull);
    expect(c.reciterId, 'mp3quran_123');
    expect(c.isSupported, true);
    expect(c.isReady, false);
    await c.downloadSelected();
    await c.play();
    expect(downloads, 0);
    expect(players, 0);
    expect(c.isPlaying, false);
  });
  for (final defect in [
    'end',
    'order',
    'missing',
    'source',
    'hash',
    'format',
    'override',
  ]) {
    test('invalid full metadata fails closed: $defect', () async {
      final p = timedPackage();
      switch (defect) {
        case 'end':
          p['verseTimings'][0]['endMs'] = 11000;
        case 'order':
          p['verseTimings'][1]['startMs'] = 500;
        case 'missing':
          p['verseTimings'].removeLast();
        case 'source':
          p['source']['moshafId'] = 4;
        case 'hash':
          p['files']['001.mp3'] = 'bad';
        case 'format':
          p['format'] = 'unknown';
        case 'override':
          p['openingOverride'] = {
            'asset': 'old',
            'sha256': 'x',
            'durationMs': 1,
          };
      }
      final root = await Directory.systemTemp.createTemp('invalid-mp3');
      var downloads = 0;
      final c = QuranAudioController(
        directory: () async => root,
        catalogLoader: () async => catalog(p),
        downloader: (_, _) async* {
          downloads++;
        },
      );
      addTearDown(() async {
        c.dispose();
        await root.delete(recursive: true);
      });
      await c.initialize();
      await c.selectReciter('mp3quran_123');
      await c.downloadSelected();
      await c.play();
      expect(downloads, 0);
      expect(c.isReady, false);
      expect(c.isPlaying, false);
      expect(c.error, isNotNull);
    });
  }
}
