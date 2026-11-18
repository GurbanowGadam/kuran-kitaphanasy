import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuran_kitaphanasy/audio/quran_audio_controller.dart';

import 'audio_fakes.dart';

class _RealNetwork extends HttpOverrides {}

// Default five Fatiha ZIPs; use 2 for Bakara or 9 for Tevbe.
// Real Drive transport/local originals, FAKE clip player (not native playback).
const _surah = int.fromEnvironment('AUDIO_LIVE_SURAH', defaultValue: 1);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'real Drive all five surah $_surah ZIPs verify, clip locally and restart without network (fake player, no audible claim)',
    () async {
      expect(_surah, inInclusiveRange(1, 114));
      final catalogText = await File('assets/data/audio_catalog.json')
          .readAsString();
      final catalog = jsonDecode(catalogText);
      expect(catalog['provider'], 'mp3quran');
      // Fail before any GET while activation is pending.
      expect(
        catalog['remoteVerified'],
        true,
        reason:
            'Publish the remotely audited catalog before running AUDIO_LIVE.',
      );
      final reciters = (catalog['reciters'] as List)
          .map((r) => r['id'] as String)
          .toList();
      expect(reciters, hasLength(5));
      await HttpOverrides.runWithHttpOverrides(() async {
        final root = await Directory.systemTemp.createTemp('quran-live-');
        try {
          for (final reciter in reciters) {
            final player = ClipPlayer();
            var c = QuranAudioController(
              directory: () async => root,
              catalogLoader: () async => catalogText,
              playerFactory: () => player,
              // No downloader injection: actual controller Drive transport and ZIP verification.
            );
            try {
              await c.initialize();
              await c.selectReciter(reciter);
              await c.selectVerse(_surah, 1);
              final p = c.selectedPackage!;
              expect(p.surah, _surah);
              if (_surah == 1) expect(p.ayahCount, 7);
              if (_surah == 2) expect(p.ayahCount, 286);
              if (_surah == 9) expect(p.ayahCount, 129);
              // Full-surah opening means the exact source's pre-ayah interval,
              // not an inserted besmele (including Fatiha/Tevbe lead-in).
              expect(
                p.hasOpening,
                (p.verseTimings.first['startMs'] as int) > 0,
              );
              expect(p.isPublished, true);
              expect(c.canDownload, true);
              await c.downloadSelected();
              expect(c.error, isNull);
              expect(c.isReady, true);
              await c.play();
              expect(c.error, isNull);
              expect(c.isPlaying, true);
              final starts = [
                0,
                ...p.verseTimings
                    .map((t) => t['startMs'] as int)
                    .where((s) => s > 0),
              ];
              final ends = [...starts.skip(1), p.totalDurationMs];
              expect(player.clips.map((v) => v.start.inMilliseconds), starts);
              expect(player.clips.map((v) => v.end.inMilliseconds), ends);
              expect(player.clips.map((v) => v.ayah), [
                if (p.hasOpening) null,
                for (var a = 1; a <= p.ayahCount; a++) a,
              ]);
              expect(player.clips.map((v) => v.path).toSet(), hasLength(1));
              final local = File(player.clips.first.path);
              expect(local.path, startsWith(root.path));
              expect(local.uri.scheme, 'file');
              expect(
                sha256.convert(await local.readAsBytes()).toString(),
                p.files[p.audioFile],
              );
              expect(c.surahDuration.inMilliseconds, p.totalDurationMs);
              expect(c.isOpening, p.hasOpening);
              expect(
                c.isBasmala,
                false,
                reason: 'Official intro is not semantically asserted to be besmele.',
              );
              expect(c.ayah, 1);
              await c.seekSurah(const Duration(milliseconds: -1));
              expect(c.surahPosition, Duration.zero);
              expect(player.index, 0);
              expect(player.sought, Duration.zero);
              expect(c.isOpening, p.hasOpening);
              c.toggleRepeatAyah();
              expect(player.repeatOne, !p.hasOpening);
              if (p.hasOpening) {
                final boundary = p.verseTimings.first['startMs'] as int;
                await c.seekSurah(Duration(milliseconds: boundary - 1));
                expect(c.isOpening, true);
                expect(player.sought!.inMilliseconds, boundary - 1);
                await c.seekSurah(Duration(milliseconds: boundary));
                expect(c.isOpening, false);
                expect(c.ayah, 1);
                expect(player.sought, Duration.zero);
              }
              final target = (p.verseTimings[1]['startMs'] as int) + 1;
              await c.seekSurah(Duration(milliseconds: target));
              expect(c.ayah, 2);
              expect(player.index, p.hasOpening ? 2 : 1);
              expect(player.sought, const Duration(milliseconds: 1));
              expect(c.surahPosition.inMilliseconds, target);
              final preparations = player.preparations;
              await c.pause();
              expect(c.isPlaying, false);
              expect(player.playing, false);
              await c.play();
              expect(c.isPlaying, true);
              expect(
                player.preparations,
                preparations,
                reason: 'Resume must not reload the verified queue.',
              );
              c.toggleRepeatAyah();
              c.toggleRepeatSurah();
              expect(player.repeatOne, false);
              expect(player.repeatAll, true);
              await c.pause();
              await c.seekSurah(Duration(milliseconds: p.totalDurationMs + 1));
              expect(c.surahPosition.inMilliseconds, p.totalDurationMs);
              expect(c.isPlaying, false);
              expect(player.clips.last.end.inMilliseconds, p.totalDurationMs);
              c.dispose();
              final offlinePlayer = ClipPlayer();
              var fallbackCalls = 0;
              c = QuranAudioController(
                directory: () async => root,
                catalogLoader: () async => catalogText,
                playerFactory: () => offlinePlayer,
                downloader: (_, _) {
                  fallbackCalls++;
                  throw StateError('Offline restart MUST NOT download');
                },
              );
              await c.initialize();
              await c.selectReciter(reciter);
              await c.selectVerse(_surah, 1);
              expect(c.isReady, true);
              await c.play();
              expect(c.error, isNull);
              expect(c.isPlaying, true);
              expect(offlinePlayer.clips.first.path, local.path);
              expect(fallbackCalls, 0);
              debugPrint(
                'REAL DRIVE VERIFIED $reciter surah $_surah: ${p.bytes} ZIP bytes, original MP3 hash, ${player.clips.length} exact clips; offline restart passed. Playback boundary FAKE: no native/audible verification.',
              );
            } finally {
              c.dispose();
            }
          }
        } finally {
          await root.delete(recursive: true);
        }
      }, _RealNetwork());
    },
    skip: !const bool.fromEnvironment('AUDIO_LIVE'),
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
