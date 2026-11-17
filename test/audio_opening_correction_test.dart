import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuran_kitaphanasy/audio/quran_audio_controller.dart';

import 'audio_service_test.dart' show QueuePlayer, LocalPlayer;

// All compatibility bytes are explicitly synthetic, never a bundled recording.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final queued in [false, true]) {
    for (final mismatch in [false, true]) {
      test(
        'portable legacy opening replacement queued=$queued mismatch=$mismatch',
        () async {
          final root = await Directory.systemTemp.createTemp('opening-legacy');
          final LocalPlayer player = queued ? QueuePlayer() : LocalPlayer();
          final original = {
            '002000.mp3': utf8.encode('test istiadhah'),
            '002001.mp3': utf8.encode('test canonical one'),
          };
          final bytes = utf8.encode('test-only replacement');
          final archive = Archive();
          original.forEach(
            (k, v) => archive.addFile(ArchiveFile(k, v.length, v)),
          );
          final zip = ZipEncoder().encode(archive);
          final c = QuranAudioController(
            directory: () async => root,
            playerFactory: () => player,
            openingAssetLoader: (_) async => mismatch ? [1, 2, 3] : bytes,
            catalogLoader: () async => jsonEncode({
              'reciters': [
                {'id': 'Alafasy_128kbps', 'name': 'fixture', 'bitrate': 128},
              ],
              'packages': [
                {
                  'reciterId': 'Alafasy_128kbps',
                  'surah': 2,
                  'ayahCount': 1,
                  'bytes': zip.length,
                  'driveFileId': 'fixture',
                  'sha256': sha256.convert(zip).toString(),
                  'files': original.map(
                    (k, v) => MapEntry(k, sha256.convert(v).toString()),
                  ),
                  'durationsMs': {'002000.mp3': 9000, '002001.mp3': 10000},
                  'openingOverride': {
                    'asset': 'fixture',
                    'sha256': sha256.convert(bytes).toString(),
                    'durationMs': 6513,
                  },
                },
              ],
            }),
            downloader: (_, _) async* {
              yield zip;
            },
          );
          try {
            await c.selectVerse(2, 1);
            await c.downloadSelected();
            await c.play();
            if (mismatch) {
              expect(c.isPlaying, false);
              expect(player.loads, 0);
              expect(c.error, contains('hash'));
              return;
            }
            final path = player is QueuePlayer
                ? player.paths.first
                : player.path!;
            expect(File(path).readAsBytesSync(), bytes);
            expect(c.isBasmala, true);
            if (player is QueuePlayer) {
              await c.seekSurah(const Duration(milliseconds: 6512));
              expect(c.isBasmala, true);
              await c.seekSurah(const Duration(milliseconds: 6513));
              expect(c.isBasmala, false);
            } else {
              player.done.add(null);
              await Future<void>.delayed(const Duration(milliseconds: 50));
              expect(c.isBasmala, false);
              expect(c.ayah, 1);
              expect(c.surahPosition.inMilliseconds, 6513);
              c.toggleRepeatAyah();
              player.done.add(null);
              await Future<void>.delayed(const Duration(milliseconds: 50));
              expect(c.isBasmala, false);
              expect(player.path, endsWith('002001.mp3'));
            }
            await c.close();
            await File(path).writeAsString('corrupt');
            await c.selectVerse(2, 1);
            await c.play();
            expect(c.isPlaying, false);
            expect(c.error, contains('hash'));
          } finally {
            c.dispose();
            await root.delete(recursive: true);
          }
        },
      );
    }
  }
}
