import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuran_kitaphanasy/audio/quran_audio_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Yasir short-surah preludes use exact same-reciter original Fatiha verse-one bytes and timing', () async {
    final catalog = jsonDecode(
      await rootBundle.loadString('assets/data/audio_catalog.json'),
    );
    final packages = (catalog['packages'] as List).cast<Map<String, dynamic>>();
    final source = packages.singleWhere(
      (p) => p['reciterId'] == 'mp3quran_92' && p['surah'] == 1,
    );
    final first = (source['verseTimings'] as List).first;
    var count = 0;
    for (final raw in packages) {
      final targeted =
          raw['reciterId'] == 'mp3quran_92' && (raw['surah'] as int) >= 79;
      if (!targeted) {
        expect(raw['openingPrelude'], isNull);
        continue;
      }
      count++;
      expect(
        raw['openingPrelude'],
        isNotNull,
        reason:
            'Yasir surah ${raw['surah']} needs the approved explicit prelude',
      );
      final p = AudioPackage.fromJson(raw);
      expect(p.validMetadata, true);
      final prelude = p.openingPrelude!;
      expect(prelude.reciterId, 'mp3quran_92');
      expect(prelude.sha256Hash, source['files']['001.mp3']);
      expect(prelude.startMs, first['startMs']);
      expect(prelude.endMs, first['endMs']);
      expect(prelude.sourceDurationMs, source['totalDurationMs']);
      expect(p.timingPrefix.last, p.totalDurationMs + prelude.durationMs);
    }
    expect(count, 36);
    final bytes = await rootBundle.load(
      'assets/audio/yasir-fatiha-original.mp3',
    );
    expect(
      sha256.convert(bytes.buffer.asUint8List()).toString(),
      source['files']['001.mp3'],
    );
  });
}
