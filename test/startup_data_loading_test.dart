import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuran_kitaphanasy/reader_data.dart';
import 'package:kuran_kitaphanasy/library/data/book_repository.dart';

class GatedBundle extends CachingAssetBundle {
  final requested = <String>[];
  final gate = Completer<void>();
  @override
  Future<ByteData> load(String key) => throw UnimplementedError();
  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    requested.add(key);
    await gate.future;
    return File(key).readAsString();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final corruption in [
    'missing asset',
    'invalid JSON',
    'incomplete markers',
  ]) {
    test(
      'bundled repository retries actual source after $corruption',
      () async {
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        void evictSources() {
          for (final name in ReaderData.datasets) {
            rootBundle.evict('assets/data/$name.json');
          }
        }

        evictSources();
        var damaged = true;
        var requests = 0;
        messenger.setMockMessageHandler('flutter/assets', (message) async {
          final key = utf8.decode(
            message!.buffer.asUint8List(
              message.offsetInBytes,
              message.lengthInBytes,
            ),
          );
          if (key == 'assets/data/sajdah_markers.json') {
            requests++;
            if (damaged) {
              if (corruption == 'missing asset') return null;
              final text = corruption == 'invalid JSON' ? '{' : '{"items":[]}';
              return ByteData.sublistView(utf8.encode(text));
            }
          }
          return ByteData.sublistView(await File(key).readAsBytes());
        });
        addTearDown(() {
          messenger.setMockMessageHandler('flutter/assets', null);
          evictSources();
        });
        final repository = BundledBookRepository();
        final first = repository.load('quran');
        expect(
          identical(first, repository.load('quran')),
          isTrue,
          reason: 'concurrent consumers share one operation',
        );
        await expectLater(
          first,
          corruption == 'missing asset'
              ? throwsA(isA<FlutterError>())
              : throwsFormatException,
        );
        damaged = false;
        final retry = repository.load('quran');
        expect(identical(first, retry), isFalse);
        final data = await retry;
        expect(
          requests,
          2,
          reason: 'retry must reread the asset, not cached failure',
        );
        expect(data.pages.length, 604);
        expect(data.sajdahMarkers.length, 14);
        expect(identical(retry, repository.load('quran')), isTrue);
      },
    );
  }
  test(
    'all source assets are requested concurrently before decoding',
    () async {
      final bundle = GatedBundle();
      final pending = ReaderData.load(bundle: bundle);
      // Release even on RED, so the test leaves no abandoned operation.
      final requested = List.of(bundle.requested);
      bundle.gate.complete();
      final data = await pending;
      expect(requested.length, ReaderData.datasets.length);
      expect(data.pages.length, 604);
    },
  );
  test(
    'production async load conserves every verse and translation exactly',
    () async {
      final watch = Stopwatch()..start();
      final data = await ReaderData.load();
      watch.stop();
      debugPrint('PRODUCTION_LOAD_MS=${watch.elapsedMicroseconds / 1000}');
      final docs = <String, dynamic>{};
      final cpu = Stopwatch()..start();
      for (final name in ReaderData.datasets) {
        docs[name] = jsonDecode(
          File('assets/data/$name.json').readAsStringSync(),
        );
      }
      final sync = ReaderData.fromDocuments(docs);
      cpu.stop();
      debugPrint(
        'SYNC_READ_DECODE_VALIDATE_MS=${cpu.elapsedMicroseconds / 1000}',
      );
      expect(
        data.pages.expand((p) => p.verses).map((v) => '${v.key}\n${v.text}'),
        sync.pages.expand((p) => p.verses).map((v) => '${v.key}\n${v.text}'),
      );
      expect(
        data.translations.map((b) => b.text),
        sync.translations.map((b) => b.text),
      );
      expect(data.footnotes, sync.footnotes);
      expect(data.sajdahMarkers, sync.sajdahMarkers);
    },
  );
}
