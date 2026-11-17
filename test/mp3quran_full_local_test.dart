import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuran_kitaphanasy/audio/quran_audio_controller.dart';

import 'mp3quran_migration_test.dart' show ClipPlayer;

// Verification of existing behavior, not feature-TDD or a Drive publication gate.
// No production catalog is modified. No network transport/native decoder is used.
const _root = String.fromEnvironment('FULL_QURAN_ROOT');
const _ids = [92, 4, 123, 54, 133];
const _counts = [
  7,
  286,
  200,
  176,
  120,
  165,
  206,
  75,
  129,
  109,
  123,
  111,
  43,
  52,
  99,
  128,
  111,
  110,
  98,
  135,
  112,
  78,
  118,
  64,
  77,
  227,
  93,
  88,
  69,
  60,
  34,
  30,
  73,
  54,
  45,
  83,
  182,
  88,
  75,
  85,
  54,
  53,
  89,
  59,
  37,
  35,
  38,
  29,
  18,
  45,
  60,
  49,
  62,
  55,
  78,
  96,
  29,
  22,
  24,
  13,
  14,
  11,
  11,
  18,
  12,
  12,
  30,
  52,
  52,
  44,
  28,
  28,
  20,
  56,
  40,
  31,
  50,
  40,
  46,
  42,
  29,
  19,
  36,
  25,
  22,
  17,
  19,
  26,
  30,
  20,
  15,
  21,
  11,
  8,
  8,
  19,
  5,
  8,
  8,
  11,
  11,
  8,
  3,
  9,
  5,
  4,
  7,
  3,
  6,
  3,
  5,
  4,
  5,
  6,
];
Map<String, dynamic> _read(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
Map<String, dynamic> _candidate() =>
    _read('$_root/audio_catalog.candidate.json');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final skip = _root.isEmpty
      ? 'Set FULL_QURAN_ROOT to a complete local release'
      : false;
  test('full candidate: 570 pending packages, exact source and 31180 canonical verses', () {
    final catalog = _candidate();
    expect(catalog['version'], 2);
    expect(catalog['provider'], 'mp3quran');
    expect(catalog['contentVersion'], '0.0.1');
    expect(catalog['driveFolderId'], isNull);
    expect(
      (catalog['reciters'] as List).map((r) => r['id']).toSet(),
      _ids.map((id) => 'mp3quran_$id').toSet(),
    );
    expect(_counts, hasLength(114));
    expect(_counts.fold<int>(0, (a, b) => a + b), 6236);
    final packages = catalog['packages'] as List;
    expect(packages, hasLength(570));
    final keys = <String>{};
    var total = 0;
    for (final raw in packages) {
      final p = AudioPackage.fromJson(Map<String, dynamic>.from(raw));
      expect(p.validMetadata, true, reason: p.key);
      expect(p.isFullSurah, true);
      expect(keys.add(p.key), true);
      expect(p.ayahCount, _counts[p.surah - 1]);
      expect(p.verseTimings, hasLength(p.ayahCount));
      total += p.ayahCount;
      expect(p.publicationStatus, 'pending-upload');
      expect(raw['driveFileId'], isNull);
      expect(p.isPublished, false);
      expect(p.openingOverride, isNull);
      final mid = int.parse(p.reciterId.split('_').last);
      expect(_ids, contains(mid));
      expect(p.source['moshafId'], mid);
      expect(p.source['reciterId'], mid == 133 ? 102 : mid);
      expect(p.source['recordingStyle'], mid == 133 ? 'Mojawwad' : 'Murattal');
      final timing = Uri.parse(p.source['timingUrl'] as String);
      expect(timing.path, '/api/v3/ayat_timing');
      expect(timing.queryParameters, {'surah': '${p.surah}', 'read': '$mid'});
      final record = _read(
        '$_root/provenance/packages/$mid-${p.surah.toString().padLeft(3, '0')}.json',
      );
      expect(record['validationError'], isNull);
      final original = record['package'] as Map;
      // Preservation means equality to archived metadata, not runtime collection immutability.
      for (final field in [
        'verseTimings',
        'ayahCount',
        'source',
        'files',
        'sha256',
        'bytes',
        'totalDurationMs',
      ]) {
        expect(
          raw[field],
          original[field],
          reason: '${p.key}: immutable $field',
        );
      }
      expect(p.verseTimings, original['verseTimings']);
      expect(p.source, original['source']);
      expect(p.timingPrefix.last, p.totalDurationMs);
    }
    expect(total, 31180);
    for (final id in _ids) {
      final group = packages.where((p) => p['reciterId'] == 'mp3quran_$id');
      expect(group, hasLength(114));
      expect(group.map((p) => p['surah']).toSet(), {
        for (var s = 1; s <= 114; s++) s,
      });
      expect(group.fold<int>(0, (n, p) => n + (p['ayahCount'] as int)), 6236);
    }
  }, skip: skip);

  for (final id in _ids) {
    for (final surah in [2, 9]) {
      test(
        'real local ZIP and clipped boundaries/restart: moshaf=$id surah=$surah',
        () async {
          final catalog = _candidate();
          final raw = (catalog['packages'] as List).singleWhere(
            (p) => p['reciterId'] == 'mp3quran_$id' && p['surah'] == surah,
          ) as Map<String, dynamic>;
          expect(raw['publicationStatus'], 'pending-upload');
          final immutable = jsonEncode(raw);
          // TEST ONLY: unlock the published guard for injected local transport.
          // This syntactic ID is never requested and DOES NOT prove Drive availability.
          final selected = Map<String, dynamic>.from(raw)
            ..['publicationStatus'] = 'published'
            ..['driveFileId'] = 'TEST_ONLY_LOCAL_ZIP_NOT_DRIVE_$id';
          final testCatalog = Map<String, dynamic>.from(catalog)
            ..['packages'] = [selected];
          final p = AudioPackage.fromJson(selected);
          expect(p.validMetadata, true);
          final zipFile = File(
            '$_root/packages/${p.reciterId}/${surah.toString().padLeft(3, '0')}.zip',
          );
          expect(
            await zipFile.exists(),
            true,
            reason: 'Full local release prerequisite',
          );
          final temp = await Directory.systemTemp.createTemp(
            'full-quran-local-',
          );
          var downloads = 0, restartDownloads = 0;
          var player = ClipPlayer();
          QuranAudioController make({required bool restart}) =>
              QuranAudioController(
                directory: () async => temp,
                catalogLoader: () async => jsonEncode(testCatalog),
                playerFactory: () => player,
                downloader: (_, _) async* {
                  if (restart) {
                    restartDownloads++;
                    throw StateError('Restart must not download');
                  }
                  downloads++;
                  final bytes = await zipFile.readAsBytes();
                  expect(bytes.length, p.bytes);
                  expect(sha256.convert(bytes).toString(), p.sha256Hash);
                  yield bytes;
                },
              );
          var c = make(restart: false);
          addTearDown(() async {
            c.dispose();
            await temp.delete(recursive: true);
          });
          await c.initialize();
          await c.selectReciter(p.reciterId);
          await c.selectVerse(surah, 1);
          expect(c.canDownload, true);
          await c.downloadSelected();
          expect(c.error, isNull);
          expect(c.isReady, true);
          expect(downloads, 1);
          await c.play();
          expect(c.isPlaying, true);
          final starts = [
            if (p.hasOpening) 0,
            ...p.verseTimings.map((t) => t['startMs'] as int),
          ];
          final ends = [...starts.skip(1), p.totalDurationMs];
          expect(player.clips.map((clip) => clip.start.inMilliseconds), starts);
          expect(player.clips.map((clip) => clip.end.inMilliseconds), ends);
          expect(player.clips.map((clip) => clip.ayah), [
            if (p.hasOpening) null,
            for (var a = 1; a <= p.ayahCount; a++) a,
          ]);
          expect(player.paths.toSet(), hasLength(1));
          final path = player.paths.first;
          expect(File(path).isAbsolute, true);
          expect(path, startsWith(temp.path));
          expect(
            sha256.convert(await File(path).readAsBytes()).toString(),
            p.files[p.audioFile],
          );
          // Also bind extracted original to the direct-source download hash.
          final provenance = _read(
            '$_root/provenance/packages/$id-${surah.toString().padLeft(3, '0')}.json',
          );
          expect(p.files[p.audioFile], provenance['download']['sha256']);
          expect(
            c.isBasmala,
            false,
          ); // Generic intro, including Tevbe: never invented besmele.
          await c.pause();
          expect(player.playing, false);
          if (p.hasOpening) {
            final boundary = starts[1];
            await c.seekSurah(Duration(milliseconds: boundary - 1));
            expect(c.isOpening, true);
            expect(c.isBasmala, false);
            await c.seekSurah(Duration(milliseconds: boundary));
            expect(c.isOpening, false);
            expect(c.ayah, 1);
            expect(player.sought, Duration.zero);
          }
          final second = p.verseTimings[1]['startMs'] as int;
          await c.seekSurah(Duration(milliseconds: second));
          expect(c.ayah, 2);
          expect(c.isOpening, false);
          expect(player.sought, Duration.zero);
          await c.seekSurah(Duration(milliseconds: p.totalDurationMs - 1));
          expect(c.ayah, p.ayahCount);
          expect(
            player.sought,
            Duration(milliseconds: p.totalDurationMs - 1 - starts.last),
          );
          await c.seekSurah(Duration(milliseconds: p.totalDurationMs + 1000));
          expect(c.surahPosition, Duration(milliseconds: p.totalDurationMs));
          expect(c.surahDuration, Duration(milliseconds: p.totalDurationMs));
          expect(
            player.sought,
            Duration(milliseconds: p.totalDurationMs - starts.last),
          );
          expect(c.isPlaying, false);
          expect(player.playing, false);
          expect(player.preparations, 1);
          expect(jsonEncode(raw), immutable);
          expect(c.selectedPackage!.verseTimings, raw['verseTimings']);
          await c.close();
          c.dispose();
          player = ClipPlayer();
          c = make(restart: true);
          await c.initialize();
          await c.selectReciter(p.reciterId);
          await c.selectVerse(surah, 1);
          expect(c.isReady, true);
          await c.play();
          expect(c.error, isNull);
          expect(c.isPlaying, true);
          expect(player.paths.toSet(), {path});
          expect(
            sha256.convert(await File(path).readAsBytes()).toString(),
            p.files[p.audioFile],
          );
          expect(restartDownloads, 0);
          expect(downloads, 1);
        },
        skip: skip,
        timeout: const Timeout(Duration(minutes: 4)),
      );
    }
  }
}
