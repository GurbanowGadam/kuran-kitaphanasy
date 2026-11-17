import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuran_kitaphanasy/audio/quran_audio_controller.dart';

class LocalPlayer implements AudioPlayback {
  final done = StreamController<void>.broadcast(sync: true);
  final positionEvents = StreamController<Duration>.broadcast(sync: true);
  final durationEvents = StreamController<Duration?>.broadcast(sync: true);
  String? path;
  bool playing = false;
  @override
  Stream<void> get completed => done.stream;
  @override
  Stream<Duration> get positions => positionEvents.stream;
  @override
  Stream<Duration?> get durations => durationEvents.stream;
  int loads = 0;
  @override
  Future<void> load(String value) async {
    path = value;
    loads++;
  }

  @override
  Future<void> play() async {
    playing = true;
  }

  @override
  Future<void> pause() async {
    playing = false;
  }

  @override
  Future<void> stop() async {
    playing = false;
  }

  @override
  Future<void> seek(Duration value) async {}
  @override
  Future<void> dispose() async {
    await done.close();
    await positionEvents.close();
    await durationEvents.close();
  }
}

class QueuePlayer extends LocalPlayer implements QueuedAudioPlayback {
  final events =
      StreamController<
        ({
          int generation,
          int index,
          Duration position,
          Duration? duration,
          bool completed,
        })
      >.broadcast(sync: true);
  @override
  Stream<
    ({
      int generation,
      int index,
      Duration position,
      Duration? duration,
      bool completed,
    })
  >
  get snapshots => events.stream;
  int preparations = 0, generation = -1, index = 0;
  List<String> paths = [];
  bool repeatOne = false, repeatAll = false;
  Completer<void>? preparationGate;
  @override
  Future<void> prepareQueue(List<String> value, int initial, int token) async {
    preparations++;
    paths = value;
    index = initial;
    generation = token;
    await preparationGate?.future;
  }

  @override
  Future<void> seekIndex(int value) async {
    index = value;
  }

  @override
  Future<void> setRepeats(bool ayah, bool surah) async {
    repeatOne = ayah;
    repeatAll = surah;
  }

  void tick(
    int value, {
    int seconds = 0,
    int? duration,
    bool completed = false,
    int? token,
  }) {
    events.add((
      generation: token ?? generation,
      index: value,
      position: Duration(seconds: seconds),
      duration: duration == null ? null : Duration(seconds: duration),
      completed: completed,
    ));
  }

  @override
  Future<void> dispose() async {
    await events.close();
    await super.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late List<int> zip;
  late Map<String, dynamic> catalog;
  late LocalPlayer player;
  QuranAudioController make({AudioDownload? download}) => QuranAudioController(
    directory: () async => root,
    catalogLoader: () async => jsonEncode(catalog),
    playerFactory: () => player,
    downloader:
        download ??
        (uri, cancel) async* {
          yield zip;
        },
  );
  setUp(() async {
    root = await Directory.systemTemp.createTemp('quran-audio-test');
    player = LocalPlayer();
    final files = {
      '001001.mp3': utf8.encode('ID3 verse one'),
      '001002.mp3': utf8.encode('ID3 verse two'),
    };
    final archive = Archive()
      ..addFile(ArchiveFile('000_license.html', 7, utf8.encode('license')));
    for (final e in files.entries) {
      archive.addFile(ArchiveFile(e.key, e.value.length, e.value));
    }
    zip = ZipEncoder().encode(archive);
    catalog = {
      'reciters': [
        {'id': 'Alafasy_128kbps', 'name': 'Afasi', 'bitrate': 128},
      ],
      'packages': [
        {
          'reciterId': 'Alafasy_128kbps',
          'surah': 1,
          'ayahCount': 2,
          'bytes': zip.length,
          'driveFileId': 'real-id',
          'sha256': sha256.convert(zip).toString(),
          'files': files.map(
            (k, v) => MapEntry(k, sha256.convert(v).toString()),
          ),
        },
      ],
    };
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });
  test(
    'native queue advances atomically without a load or file hash boundary',
    () async {
      final q = QueuePlayer();
      player = q;
      final c = make();
      await c.downloadSelected();
      await c.play();
      expect(q.preparations, 1);
      expect(q.paths.length, 2);
      q.tick(0, seconds: 10, duration: 10);
      final observed = <(int, Duration, Duration)>[];
      c.addListener(() => observed.add((c.ayah, c.position, c.duration)));
      // Removing the next file proves natural advancement does not reopen/hash it.
      await File(q.paths[1]).delete();
      q.tick(1, duration: 20);
      expect(observed, [(2, Duration.zero, const Duration(seconds: 20))]);
      expect(q.loads, 0);
      expect(q.preparations, 1);
      q.tick(1, seconds: 20, duration: 20, completed: true);
      expect(c.isPlaying, false);
      expect(c.position, c.duration);
      c.dispose();
    },
  );
  test('native queue ignores stale events on pause selection close and retains paused navigation', () async {
    final q = QueuePlayer();
    player = q;
    final c = make();
    await c.downloadSelected();
    await c.play();
    await c.pause();
    q.tick(1, duration: 99);
    expect(c.ayah, 1);
    expect(c.position, Duration.zero);
    await c.next();
    expect(c.ayah, 2);
    expect(c.isPlaying, false);
    await c.play();
    expect(q.preparations, 1);
    expect(q.index, 1);
    c.toggleRepeatAyah();
    c.toggleRepeatSurah();
    await Future<void>.delayed(Duration.zero);
    expect(q.repeatOne, true);
    expect(q.repeatAll, true);
    final old = q.generation;
    await c.selectVerse(1, 1);
    await c.play();
    q.tick(1, token: old);
    expect(c.ayah, 1);
    await c.close();
    q.tick(1);
    expect(c.ayah, 1);
    expect(c.duration, Duration.zero);
    c.dispose();
  });
  test(
    'native queue verifies all tracks before prepare and restarts final EOF',
    () async {
      final q = QueuePlayer();
      player = q;
      final c = make();
      await c.downloadSelected();
      await c.play();
      q.tick(1, seconds: 8, duration: 8, completed: true);
      await c.play();
      expect(q.preparations, 2);
      expect(c.position, Duration.zero);
      await c.close();
      await File('${root.path}/quran_audio/Alafasy_128kbps/1/001002.mp3')
          .writeAsString('corrupt');
      await c.play();
      expect(c.isReady, false);
      expect(c.isPlaying, false);
      expect(q.preparations, 2);
      expect(c.error, isNotNull);
      c.dispose();
    },
  );
  test('native queue pending preparation cannot restart after pause', () async {
    final q = QueuePlayer();
    player = q;
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
    'completion clears previous ayah duration and retains final progress',
    () async {
      final c = make();
      await c.initialize();
      await c.downloadSelected();
      await c.play();
      player.durationEvents.add(const Duration(seconds: 10));
      player.positionEvents.add(const Duration(seconds: 10));
      player.done.add(null);
      // Wait for real local file validation/load, not a guessed delay.
      for (var i = 0; i < 100 && player.loads < 2; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(c.ayah, 2);
      expect(c.position, Duration.zero);
      expect(
        c.duration,
        Duration.zero,
      ); // Unknown until the new file reports it.
      player.durationEvents.add(const Duration(seconds: 20));
      player.positionEvents.add(const Duration(seconds: 20));
      player.done.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(c.isPlaying, false);
      expect(c.position, const Duration(seconds: 20));
      expect(c.duration, const Duration(seconds: 20));
      await c.play();
      expect(c.position, Duration.zero);
      await c.close();
      expect(c.position, Duration.zero);
      c.dispose();
    },
  );
  test(
    'download-first local-only playback, advance, repeats, close reusable',
    () async {
      var requests = 0;
      final c = make(
        download: (uri, cancel) async* {
          requests++;
          expect(uri.host, 'drive.google.com');
          yield zip;
        },
      );
      await c.initialize();
      await c.play();
      expect(c.isPlaying, false);
      expect(c.error, isNotNull);
      expect(requests, 0);
      await c.downloadSelected();
      expect(c.isReady, true);
      expect(c.downloadProgress, 1);
      await c.play();
      expect(c.isPlaying, true);
      expect(player.path, startsWith(root.path));
      player.done.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(c.ayah, 2);
      c.toggleRepeatAyah();
      player.done.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(c.ayah, 2);
      c.toggleRepeatAyah();
      c.toggleRepeatSurah();
      player.done.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(c.ayah, 1);
      await c.pause();
      expect(c.isPlaying, false);
      await c.next();
      expect(c.ayah, 2);
      expect(c.isPlaying, false);
      await c.previous();
      expect(c.ayah, 1);
      await c.seek(const Duration(seconds: 1));
      await c.close();
      expect(c.position, Duration.zero);
      await c.play();
      expect(c.isPlaying, true);
      await c.selectVerse(2, 1);
      expect(c.isSupported, false);
      expect(c.isPlaying, false);
      expect(c.isReady, false);
      await c.selectVerse(1, 1);
      await c.deleteSelected();
      expect(c.isReady, false);
      c.dispose();
    },
  );
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
      final f = File('${root.path}/quran_audio/Alafasy_128kbps/1/001001.mp3');
      await f.writeAsString('corrupt');
      restored.dispose();
      final broken = make();
      await broken.initialize();
      expect(broken.isReady, false);
      broken.dispose();
    },
  );
  test('truncated or corrupt archive is never published', () async {
    final c = make(
      download: (uri, cancel) async* {
        yield zip.sublist(0, zip.length - 1);
      },
    );
    await c.initialize();
    await c.downloadSelected();
    expect(c.isReady, false);
    expect(c.error, isNotNull);
    expect(c.downloadedPackages, isEmpty);
    c.dispose();
  });
  test('unsafe ZIP paths rejected even with valid archive digest', () async {
    final a = Archive()..addFile(ArchiveFile('../escape.mp3', 3, [1, 2, 3]));
    zip = ZipEncoder().encode(a);
    catalog['packages'][0]['bytes'] = zip.length;
    catalog['packages'][0]['sha256'] = sha256.convert(zip).toString();
    final c = make();
    await c.initialize();
    await c.downloadSelected();
    expect(c.isReady, false);
    expect(c.error, isNotNull);
    expect(File('${root.path}/escape.mp3').existsSync(), false);
    c.dispose();
  });
  test('hash mismatch and missing coverage rejected', () async {
    catalog['packages'][0]['files']['001001.mp3'] = 'bad';
    final c = make();
    await c.initialize();
    await c.downloadSelected();
    expect(c.isReady, false);
    c.dispose();
    catalog['packages'][0]['files'].remove('001002.mp3');
    final d = make();
    await d.initialize();
    await d.downloadSelected();
    expect(d.isReady, false);
    d.dispose();
  });
  test(
    'cancel partial transfer and restart leave no playable partial package',
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
      expect(c.isReady, false);
      gate.complete();
      await task;
      expect(c.isDownloading, false);
      c.dispose();
      final d = make();
      await d.initialize();
      expect(d.isReady, false);
      await d.downloadSelected();
      expect(d.isReady, true);
      d.dispose();
    },
  );
  test('pause then play resumes loaded local clip without reloading', () async {
    final c = make();
    await c.initialize();
    await c.downloadSelected();
    await c.play();
    await c.seek(const Duration(seconds: 3));
    await c.pause();
    await c.play();
    expect(c.position, const Duration(seconds: 3));
    expect(player.loads, 1);
    c.dispose();
  });
  test('end of final verse stops without replaying and corrupt local playback fails', () async {
    final c = make();
    await c.initialize();
    await c.downloadSelected();
    await c.selectVerse(1, 2);
    await c.play();
    player.done.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(c.isPlaying, false);
    expect(c.ayah, 2);
    await File('${root.path}/quran_audio/Alafasy_128kbps/1/001002.mp3')
        .writeAsString('corrupt');
    await c.play();
    expect(c.isPlaying, false);
    expect(c.isReady, false);
    expect(c.error, isNotNull);
    c.dispose();
  });
  test('oversized transport is rejected before ZIP publication', () async {
    final c = make(
      download: (uri, cancel) async* {
        yield [...zip, 1];
      },
    );
    await c.initialize();
    await c.downloadSelected();
    expect(c.isReady, false);
    expect(c.error, isNotNull);
    c.dispose();
  });
  test('selection cancels old work, validates ayah and reciter', () async {
    final c = make();
    await c.initialize();
    await c.selectVerse(1, 99);
    expect(c.ayah, 1);
    expect(c.error, isNotNull);
    await c.selectReciter('missing');
    expect(c.reciterId, 'Alafasy_128kbps');
    expect(c.error, isNotNull);
    c.dispose();
  });
}
