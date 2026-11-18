import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kuran_kitaphanasy/audio/quran_audio_controller.dart';

void main() {
  final j = jsonDecode(
    File('assets/data/audio_catalog.json').readAsStringSync(),
  ) as Map;
  test('integrated MP3Quran 0.0.1 production catalog exact source and timeline contract', () {
    expect(j['version'], 2);
    expect(j['provider'], 'mp3quran');
    expect(j['contentVersion'], '0.0.1');
    expect((j['reciters'] as List).map((r) => r['id']).toSet(), {
      'mp3quran_92',
      'mp3quran_4',
      'mp3quran_123',
      'mp3quran_54',
      'mp3quran_133',
    });
    final pairs = <String>{};
    for (final raw in j['packages']) {
      final p = AudioPackage.fromJson(Map<String, dynamic>.from(raw));
      expect(p.format, AudioPackage.fullSurahFormat);
      expect(p.validMetadata, true, reason: p.key);
      expect(pairs.add(p.key), true);
      expect(p.files.keys, ['${p.surah.toString().padLeft(3, '0')}.mp3']);
      expect(p.source['url'], contains('mp3quran.net/'));
      expect(
        p.source['reciterId'],
        p.reciterId == 'mp3quran_133'
            ? 102
            : int.parse(p.reciterId.split('_').last),
      );
      expect(
        p.source['recordingStyle'],
        p.reciterId == 'mp3quran_133' ? 'Mojawwad' : 'Murattal',
      );
      expect(
        p.timingPrefix.last,
        p.totalDurationMs + (p.openingPrelude?.durationMs ?? 0),
      );
      expect(p.timingPrefix.length, p.ayahCount + p.openingCount + 1);
      expect(raw['durationsMs'], isNull);
      expect(raw['openingOverride'], isNull);
      if (p.publicationStatus == 'pending-upload') {
        expect(raw['driveFileId'], isNull);
        expect(j['driveFolderId'], isNull);
      } else {
        expect(p.publicationStatus, 'published');
        expect(p.driveFileId, isNotEmpty);
      }
    }
    expect(pairs, hasLength(570));
    for (final r in j['reciters']) {
      expect(
        (j['packages'] as List)
            .where((p) => p['reciterId'] == r['id'])
            .map((p) => p['surah'])
            .toSet(),
        Set.from(List.generate(114, (index) => index + 1)),
      );
    }
  });
}
