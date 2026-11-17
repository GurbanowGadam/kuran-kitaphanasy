import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuran_kitaphanasy/audio/quran_audio_controller.dart';

import 'audio_service_test.dart' show QueuePlayer;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late QueuePlayer q;
  late QuranAudioController c;
  var requests = 0;
  Future<void> fixture(int surah, {bool opening = true, int ayah = 1}) async {
    final prefix = surah.toString().padLeft(3, '0');
    final files = <String, List<int>>{
      if (opening) '${prefix}000.mp3': utf8.encode('verified opening $surah'),
      '${prefix}001.mp3': utf8.encode('verse one $surah'),
      '${prefix}002.mp3': utf8.encode('verse two $surah'),
    };
    final archive = Archive();
    for (final e in files.entries) {
      archive.addFile(ArchiveFile(e.key, e.value.length, e.value));
    }
    final zip = ZipEncoder().encode(archive);
    c = QuranAudioController(
      directory: () async => root,
      playerFactory: () => q,
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
          },
        ],
      }),
      downloader: (_, _) async* {
        requests++;
        yield zip;
      },
    );
    await c.selectVerse(surah, ayah);
    await c.downloadSelected();
    expect(c.isReady, true);
    await c.play();
  }

  bool opening() => c.isBasmala;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('basmala-test');
    q = QueuePlayer();
    requests = 0;
  });
  tearDown(() async {
    c.dispose();
    await root.delete(recursive: true);
  });

  test(
    'verified opening precedes canonical ayah one with atomic mapping',
    () async {
      await fixture(2);
      expect(q.paths.map((p) => p.split('/').last), [
        '002000.mp3',
        '002001.mp3',
        '002002.mp3',
      ]);
      expect(q.index, 0);
      expect(opening(), true);
      expect(c.ayah, 1);
      q.tick(0, seconds: 2, duration: 4);
      expect(c.position, const Duration(seconds: 2));
      expect(c.duration, const Duration(seconds: 4));
      final observed = <(bool, int, Duration, Duration)>[];
      c.addListener(
        () => observed.add((opening(), c.ayah, c.position, c.duration)),
      );
      q.tick(1, duration: 12);
      expect(observed, [
        (false, 1, Duration.zero, const Duration(seconds: 12)),
      ]);
      q.tick(2, duration: 8);
      expect(c.ayah, 2);
      expect(q.preparations, 1);
      expect(requests, 1);
    },
  );
  for (final surah in [1, 9]) {
    test('surah $surah never queues a separate opening', () async {
      await fixture(surah);
      expect(q.paths.length, 2);
      expect(q.paths.first, endsWith('001.mp3'));
      expect(opening(), false);
    });
  }
  test(
    'later start skips intro and previous targets canonical ayah one',
    () async {
      await fixture(2, ayah: 2);
      expect(q.index, 2);
      expect(opening(), false);
      await c.previous();
      expect(q.index, 1);
      expect(c.ayah, 1);
      expect(opening(), false);
      await c.previous();
      expect(q.index, 1);
      await c.next();
      expect(q.index, 2);
    },
  );
  test(
    'pause resumes opening without reload and ignores stale snapshots',
    () async {
      await fixture(2);
      q.tick(0, seconds: 2, duration: 4);
      await c.pause();
      q.tick(2, duration: 99, completed: true);
      expect(opening(), true);
      expect(c.ayah, 1);
      await c.play();
      expect(c.position, const Duration(seconds: 2));
      expect(q.preparations, 1);
      final old = q.generation;
      await c.selectVerse(2, 1);
      await c.play();
      q.tick(2, token: old);
      expect(opening(), true);
      expect(c.ayah, 1);
      await c.close();
      q.tick(0, duration: 99);
      expect(opening(), false);
      expect(c.duration, Duration.zero);
    },
  );
  test(
    'repeat ayah never loops intro and surah repeat includes opening',
    () async {
      await fixture(2);
      c.toggleRepeatAyah();
      await Future<void>.delayed(Duration.zero);
      expect(q.repeatOne, false);
      q.tick(1, duration: 12);
      await Future<void>.delayed(Duration.zero);
      expect(q.repeatOne, true);
      expect(opening(), false);
      c.toggleRepeatAyah();
      c.toggleRepeatSurah();
      await Future<void>.delayed(Duration.zero);
      expect(q.repeatAll, true);
      q.tick(2, duration: 8);
      q.tick(0, duration: 4);
      expect(c.ayah, 1);
      expect(opening(), true);
      expect(c.isPlaying, true);
    },
  );
  test('EOF uses offset final index and subsequent play skips intro', () async {
    await fixture(2);
    q.tick(2, seconds: 8, duration: 8, completed: true);
    expect(c.isPlaying, false);
    expect(c.ayah, 2);
    expect(c.position, c.duration);
    await c.play();
    expect(q.index, 2);
    expect(opening(), false);
  });
  test(
    'legacy catalog without opening deliberately plays canonical tracks',
    () async {
      await fixture(2, opening: false);
      expect(q.paths.length, 2);
      expect(opening(), false);
      q.tick(1, duration: 8);
      expect(c.ayah, 2);
    },
  );
  test(
    'corrupt catalog opening blocks preparation without extra download',
    () async {
      await fixture(2);
      final openingPath =
          '${root.path}/quran_audio/Alafasy_128kbps/2/002000.mp3';
      await c.close();
      await File(openingPath).writeAsString('corrupt');
      await c.play();
      expect(c.isReady, false);
      expect(c.isPlaying, false);
      expect(q.preparations, 1);
      expect(requests, 1);
    },
  );
}
