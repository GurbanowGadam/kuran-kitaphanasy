import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kuran_kitaphanasy/audio/quran_audio_controller.dart';

const _moshafIds = [92, 4, 123, 54, 133];
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

void main() {
  test(
    'activation requires all 570 remotely verified published Drive packages',
    () async {
      final catalog = jsonDecode(
        await File('assets/data/audio_catalog.json').readAsString(),
      ) as Map<String, dynamic>;
      expect(
        catalog['remoteVerified'],
        true,
        reason: 'Activation requires the real remote ZIP audit, not pending local packages.',
      );
      expect(catalog['driveFolderId'], '1Ju0a7zKN_mySZdZavuCVND-ieSSrSpK_');
      final packages = (catalog['packages'] as List)
          .cast<Map<String, dynamic>>();
      expect(packages, hasLength(570));
      expect(catalog['provider'], 'mp3quran');
      expect(
        (catalog['reciters'] as List).map((r) => r['id']),
        unorderedEquals(_moshafIds.map((id) => 'mp3quran_$id')),
      );
      var total = 0;
      final ids = <String>{};
      final keys = <String>{};
      for (final raw in packages) {
        final p = AudioPackage.fromJson(raw);
        expect(p.isPublished, true, reason: p.key);
        expect(p.validMetadata, true, reason: p.key);
        expect(raw['remoteVerified'], true, reason: p.key);
        expect(p.isFullSurah, true, reason: p.key);
        expect(p.surah, inInclusiveRange(1, 114));
        expect(p.ayahCount, _counts[p.surah - 1], reason: p.key);
        expect(p.verseTimings, hasLength(p.ayahCount));
        total += p.ayahCount;
        final mid = int.parse(p.reciterId.split('_').last);
        expect(_moshafIds, contains(mid));
        expect(p.source['provider'], 'mp3quran');
        expect(p.source['moshafId'], mid);
        expect(p.source['reciterId'], mid == 133 ? 102 : mid);
        expect(
          p.source['recordingStyle'],
          mid == 133 ? 'Mojawwad' : 'Murattal',
        );
        final timing = Uri.parse(p.source['timingUrl'] as String);
        expect(timing.host, 'www.mp3quran.net');
        expect(timing.path, '/api/v3/ayat_timing');
        expect(timing.queryParameters, {'surah': '${p.surah}', 'read': '$mid'});
        expect(RegExp(r'^[A-Za-z0-9_-]{20,}$').hasMatch(p.driveFileId), true);
        expect(p.driveFileId.toLowerCase(), isNot(contains('test')));
        expect(
          ids.add(p.driveFileId),
          true,
          reason: 'Duplicate Drive ID: ${p.key}',
        );
        expect(keys.add('${p.reciterId}/${p.surah}'), true);
      }
      expect(total, 31180);
      for (final reciter in catalog['reciters'] as List) {
        final selected = packages
            .where((p) => p['reciterId'] == reciter['id'])
            .toList();
        expect(selected, hasLength(114));
        expect(
          selected.map((p) => p['surah']),
          unorderedEquals(List.generate(114, (i) => i + 1)),
        );
        expect(
          selected.fold<int>(0, (n, p) => n + (p['ayahCount'] as int)),
          6236,
        );
      }
    },
  );
}
