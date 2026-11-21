import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuran_kitaphanasy/audio/quran_audio_controller.dart';

import 'audio_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late List<int> zip;
  late Map<String, dynamic> package;
  late ClipPlayer q;
  QuranAudioController make({AudioDownload? download}) => QuranAudioController(
    directory: () async => root,
    catalogLoader: () async => catalog(package),
    playerFactory: () => q,
    downloader:
        download ??
        (uri, cancel) async* {
          yield zip;
        },
  );
  String localFile() =>
      '${root.path}/quran_audio/mp3quran-0.0.1/mp3quran_123/1/001.mp3';

  setUp(() async {
    root = await Directory.systemTemp.createTemp('quran-audio-test');
    q = ClipPlayer();
    zip = syntheticZip;
    package = timedPackage();
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });

  test(
    'native clip queue advances atomically without re-preparation',
    () async {
      final c = make();
      await c.downloadSelected();
      await c.play();
      expect(q.preparations, 1);
      // Original intro + two canonical ayahs, all from one verified file.
      expect(q.clips.map((v) => v.ayah), [null, 1, 2]);
      expect(c.isOpening, true);
      q.tick(1, seconds: 2, duration: 4);
      expect(c.isOpening, false);
      expect(c.ayah, 1);
      final observed = <(int, Duration, Duration)>[];
      c.addListener(() => observed.add((c.ayah, c.position, c.duration)));
      q.tick(2, duration: 5);
      expect(observed, [(2, Duration.zero, const Duration(seconds: 5))]);
      expect(q.preparations, 1);
      q.tick(2, seconds: 5, duration: 5, completed: true);
      expect(c.isPlaying, false);
      expect(c.position, c.duration);
      c.dispose();
    },
  );

  test('finished surah auto-plays the next downloaded surah', () async {
    package = timedPackageFor(1);
    final secondZip = ZipEncoder().encode(
      Archive()
        ..addFile(ArchiveFile('002.mp3', syntheticMp3.length, syntheticMp3)),
    );
    final second = timedPackageFor(2)
      ..['bytes'] = secondZip.length
      ..['sha256'] = sha256.convert(secondZip).toString();
    var transport = secondZip;
    final c = QuranAudioController(
      directory: () async => root,
      catalogLoader: () async => catalogOf([package, second]),
      playerFactory: () => q,
      downloader: (uri, cancel) async* {
        yield transport;
      },
    );
    await c.selectVerse(2, 1);
    await c.downloadSelected();
    expect(c.isReady, true);
    transport = zip;
    await c.selectVerse(1, 1);
    await c.downloadSelected();
    await c.play();
    q.tick(2, seconds: 5, duration: 5, completed: true);
    for (var i = 0; i < 100 && !(c.surah == 2 && c.isPlaying); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(c.surah, 2);
    expect(c.ayah, 1);
    expect(c.isPlaying, true);
    expect(q.playing, true);
    expect(q.preparations, 2);
    c.dispose();
  });

  test(
    'finished surah selects an undownloaded next surah without playing',
    () async {
      var requests = 0;
      package = timedPackageFor(1);
      final second = timedPackageFor(2);
      final c = QuranAudioController(
        directory: () async => root,
        catalogLoader: () async => catalogOf([package, second]),
        playerFactory: () => q,
        downloader: (uri, cancel) async* {
          requests++;
          yield zip;
        },
      );
      await c.downloadSelected();
      await c.play();
      q.tick(2, seconds: 5, duration: 5, completed: true);
      for (var i = 0; i < 100 && c.surah != 2; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(c.surah, 2);
      expect(c.ayah, 1);
      expect(c.isReady, false);
      expect(c.canDownload, true);
      expect(c.isPlaying, false);
      expect(c.isDownloading, false);
      expect(requests, 1);
      expect(q.preparations, 1);
      c.dispose();
    },
  );

  test('repeat surah keeps looping instead of advancing', () async {
    package = timedPackageFor(1);
    final c = QuranAudioController(
      directory: () async => root,
      catalogLoader: () async => catalogOf([package, timedPackageFor(2)]),
      playerFactory: () => q,
      downloader: (uri, cancel) async* {
        yield zip;
      },
    );
    await c.downloadSelected();
    await c.play();
    c.toggleRepeatSurah();
    q.tick(2, seconds: 5, duration: 5, completed: true);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(c.surah, 1);
    expect(c.isPlaying, true);
    c.dispose();
  });

  test('stale events are ignored after pause, selection and close', () async {
    final c = make();
    await c.downloadSelected();
    await c.play();
    await c.pause();
    q.tick(2, duration: 99);
    expect(c.ayah, 1);
    expect(c.position, Duration.zero);
    await c.next();
    expect(c.ayah, 2);
    expect(c.isPlaying, false);
    await c.play();
    expect(q.preparations, 1);
    expect(q.index, 2);
    c.toggleRepeatAyah();
    c.toggleRepeatSurah();
    await Future<void>.delayed(Duration.zero);
    expect(q.repeatOne, true);
    expect(q.repeatAll, true);
    final old = q.generation;
    await c.selectVerse(1, 1);
    await c.play();
    q.tick(2, token: old);
    expect(c.ayah, 1);
    await c.close();
    q.tick(2);
    expect(c.ayah, 1);
    expect(c.duration, Duration.zero);
    c.dispose();
  });

  test('pending queue preparation cannot restart after pause', () async {
    final c = make();
    await c.downloadSelected();
    q.preparationGate = Completer<void>();
    final pending = c.play();
    for (var i = 0; i < 100 && q.preparations == 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    await c.pause();
    q.preparationGate!.complete();
    await pending;
    expect(c.isPlaying, false);
    expect(q.playing, false);
    c.dispose();
  });

  test(
    'download-first: no network before request, then verified local playback',
    () async {
      var requests = 0;
      final c = make(
        download: (uri, cancel) async* {
          requests++;
          expect(uri.host, 'drive.google.com');
          expect(uri.queryParameters['id'], 'test-only-drive-id-0000000000');
          yield zip;
        },
      );
      await c.initialize();
      await c.play();
      expect(c.isPlaying, false);
      expect(c.failure, AudioFailure.notDownloaded);
      expect(requests, 0);
      await c.downloadSelected();
      expect(c.isReady, true);
      expect(c.downloadProgress, 1);
      expect(File(localFile()).readAsBytesSync(), syntheticMp3);
      await c.play();
      expect(c.isPlaying, true);
      expect(c.error, isNull);
      expect(q.paths.toSet().single, localFile());
      await c.deleteSelected();
      expect(c.isReady, false);
      expect(File(localFile()).existsSync(), false);
      c.dispose();
    },
  );

  test('large compressed recording is streamed to disk and verified', () async {
    // ~6 MB of compressible data exercises chunked transport + inflate.
    final random = Random(7);
    final mp3 = List<int>.generate(
      6 * 1024 * 1024,
      (i) => i % 4096 < 64 ? random.nextInt(256) : 0,
    );
    final archive = ZipEncoder().encode(
      Archive()..addFile(ArchiveFile('001.mp3', mp3.length, mp3)),
    );
    expect(archive.length, lessThan(mp3.length));
    zip = archive;
    package = timedPackage(zip: archive)
      ..['files'] = {'001.mp3': sha256.convert(mp3).toString()};
    final progress = <double>[];
    final c = make(
      download: (uri, cancel) async* {
        for (var i = 0; i < zip.length; i += 64 * 1024) {
          yield zip.sublist(i, min(i + 64 * 1024, zip.length));
        }
      },
    );
    c.addListener(() => progress.add(c.downloadProgress));
    await c.downloadSelected();
    expect(c.error, isNull, reason: c.errorDetail);
    expect(c.isReady, true);
    expect(progress.where((p) => p > 0 && p < 1), isNotEmpty);
    expect(
      sha256.convert(File(localFile()).readAsBytesSync()).toString(),
      sha256.convert(mp3).toString(),
    );
    expect(File('${localFile()}.part').existsSync(), false);
    expect(
      Directory('${root.path}/quran_audio/mp3quran-0.0.1/mp3quran_123')
          .listSync()
          .map((e) => e.path.split('/').last),
      ['1'],
    );
    c.dispose();
  });

  test(
    'restart validates persisted files and rejects later corruption',
    () async {
      final c = make();
      await c.initialize();
      await c.downloadSelected();
      c.dispose();
      final restored = make();
      await restored.initialize();
      expect(restored.isReady, true);
      restored.dispose();
      await File(localFile()).writeAsString('corrupt');
      final broken = make();
      await broken.initialize();
      expect(broken.isReady, false);
      broken.dispose();
    },
  );

  test('corruption after download fails playback before preparation', () async {
    final c = make();
    await c.downloadSelected();
    await c.play();
    q.tick(2, seconds: 5, duration: 5, completed: true);
    await c.close();
    await File(localFile()).writeAsString('corrupt');
    await c.play();
    expect(c.isReady, false);
    expect(c.isPlaying, false);
    expect(q.preparations, 1);
    expect(c.failure, AudioFailure.localCorrupt);
    expect(c.error, AudioFailure.localCorrupt.message);
    c.dispose();
  });

  test('truncated archive is never published', () async {
    final c = make(
      download: (uri, cancel) async* {
        yield zip.sublist(0, zip.length - 1);
      },
    );
    await c.downloadSelected();
    expect(c.isReady, false);
    expect(c.failure, AudioFailure.integrity);
    expect(c.downloadedPackages, isEmpty);
    expect(File(localFile()).existsSync(), false);
    c.dispose();
  });

  test('oversized transport is rejected before ZIP publication', () async {
    final c = make(
      download: (uri, cancel) async* {
        yield [...zip, 1];
      },
    );
    await c.downloadSelected();
    expect(c.isReady, false);
    expect(c.failure, AudioFailure.integrity);
    c.dispose();
  });

  for (final name in ['../escape.mp3', '002.mp3', '001.mp3/']) {
    test('unexpected ZIP entry "$name" rejected with valid digest', () async {
      final a = Archive()..addFile(ArchiveFile(name, 3, [1, 2, 3]));
      zip = ZipEncoder().encode(a);
      package = timedPackage(zip: zip);
      final c = make();
      await c.downloadSelected();
      expect(c.isReady, false);
      expect(c.failure, AudioFailure.integrity);
      expect(File('${root.path}/escape.mp3').existsSync(), false);
      c.dispose();
    });
  }

  test('MP3 hash mismatch inside a valid archive is rejected', () async {
    final valid = 'a' * 64;
    package['files']['001.mp3'] = valid;
    final c = make();
    await c.downloadSelected();
    expect(c.isReady, false);
    expect(c.failure, AudioFailure.integrity);
    expect(c.errorDetail, contains('checksum'));
    c.dispose();
  });

  test(
    'network failure shows Türkmen message, keeps detail internal',
    () async {
      final c = make(
        download: (uri, cancel) async* {
          yield zip.sublist(0, 4);
          throw const SocketException('Connection reset by peer');
        },
      );
      await c.downloadSelected();
      expect(c.isReady, false);
      expect(c.isDownloading, false);
      expect(c.failure, AudioFailure.network);
      expect(c.error, AudioFailure.network.message);
      expect(c.error, isNot(contains('Socket')));
      expect(c.errorDetail, contains('Connection reset'));
      c.dispose();
    },
  );

  test(
    'cancelled transfer leaves no playable partial package and no error',
    () async {
      final gate = Completer<void>();
      final c = make(
        download: (uri, cancel) async* {
          yield zip.sublist(0, 10);
          await gate.future;
          if (!cancel.cancelled) yield zip.sublist(10);
        },
      );
      await c.initialize();
      final task = c.downloadSelected();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(c.isDownloading, true);
      expect(c.downloadProgress, greaterThan(0));
      await c.cancelDownload();
      gate.complete();
      await task;
      expect(c.isReady, false);
      expect(c.isDownloading, false);
      expect(c.error, isNull);
      c.dispose();
      final d = make();
      await d.initialize();
      expect(d.isReady, false);
      await d.downloadSelected();
      expect(d.isReady, true);
      d.dispose();
    },
  );

  test('selection validates ayah and reciter with typed failures', () async {
    final c = make();
    await c.initialize();
    await c.selectVerse(1, 99);
    expect(c.ayah, 1);
    expect(c.failure, AudioFailure.invalidSelection);
    await c.selectReciter('missing');
    expect(c.reciterId, 'mp3quran_123');
    expect(c.failure, AudioFailure.unknownReciter);
    await c.selectVerse(2, 1);
    expect(c.isSupported, false);
    await c.downloadSelected();
    expect(c.failure, AudioFailure.unavailable);
    c.dispose();
  });

  test('legacy per-ayah catalogs are rejected, never partially used', () async {
    final legacy = jsonDecode(catalog(package)) as Map<String, dynamic>;
    legacy['packages'][0]['format'] = 'ayah-files-v1';
    final c = QuranAudioController(
      directory: () async => root,
      catalogLoader: () async => jsonEncode(legacy),
      playerFactory: () => q,
      downloader: (_, _) => const Stream.empty(),
    );
    await c.initialize();
    expect(c.failure, AudioFailure.initialization);
    expect(c.isSupported, false);
    c.dispose();
  });

  test('every user-facing audio message is Türkmen, not English', () {
    final english = RegExp(
      r'\b(failed|download|playback|invalid|error|the|please)\b',
      caseSensitive: false,
    );
    for (final f in AudioFailure.values) {
      expect(f.message, isNot(matches(english)), reason: f.name);
      expect(f.message.trim(), isNotEmpty);
    }
  });
}
