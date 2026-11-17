import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuran_kitaphanasy/audio/quran_audio_controller.dart';
import 'package:kuran_kitaphanasy/reader/presentation/reader.dart';
import 'package:kuran_kitaphanasy/reader/settings/reader_preferences.dart';

import 'reader_audio_test.dart' show FakeAudio;
import 'audio_service_test.dart' show QueuePlayer;
import 'reader_fixture.dart';

class DelayedAudio extends FakeAudio {
  final gate = Completer<void>();
  @override
  Future<void> selectVerse(int s, int v) async {
    await gate.future;
    await super.selectVerse(s, v);
  }

  @override
  Future<void> initialize() async {
    initialized++;
    await gate.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<void> mount(WidgetTester t, FakeAudio a) async {
    final store = MemoryReaderStore();
    await store.write('quran', {'version': 1, 'page': 1});
    await t.pumpWidget(
      MaterialApp(
        home: Reader(
          data: Future.value(fixture()),
          store: store,
          audioController: a,
          goHome: () {},
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets(
    'pending first open labels requested verse not controller default',
    (t) async {
      final a = DelayedAudio();
      await mount(t, a);
      await t.tap(find.byKey(const Key('audio-menu')));
      await t.pump();
      expect(a.initialized, 1);
      expect(find.text('Bakara · Aýat 2'), findsOneWidget);
      expect(find.textContaining('Fatyha ·'), findsNothing);
      a.gate.complete();
      await t.pumpAndSettle();
      expect(a.surah, 2);
    },
  );

  testWidgets('pending open never enables stale playback repeat or seek', (
    t,
  ) async {
    final a = DelayedAudio()..local = true;
    await mount(t, a);
    await t.tap(find.byKey(const Key('audio-menu')));
    await t.pump();
    for (final key in [
      'audio-previous',
      'audio-play',
      'audio-next',
      'audio-repeat-surah',
      'audio-reciter',
    ]) {
      expect(
        t.widget<IconButton>(find.byKey(Key(key))).onPressed,
        isNull,
        reason: key,
      );
    }
    expect(find.byKey(const Key('audio-seek')), findsNothing);
    expect(
      t.widget<IconButton>(find.byKey(const Key('audio-close'))).onPressed,
      isNotNull,
    );
    a.gate.complete();
    await t.pumpAndSettle();
    expect(
      t.widget<IconButton>(find.byKey(const Key('audio-play'))).onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'close then reopen during initialization retains newest request',
    (t) async {
      final a = DelayedAudio();
      await mount(t, a);
      await t.tap(find.byKey(const Key('audio-menu')));
      await t.pump();
      await t.tap(find.byKey(const Key('audio-close')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('audio-menu')));
      await t.pump();
      expect(find.byKey(const Key('audio-panel')), findsOneWidget);
      a.gate.complete();
      await t.pumpAndSettle();
      expect(a.selections, 2); // Both requests reached the delayed service.
      expect(a.initialized, 1); // Catalog initialization stays shared.
      expect(a.surah, 2);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    },
  );

  test('late selection verifies only requested local package on first open', () async {
    final root = await Directory.systemTemp.createTemp('audio-target-first');
    addTearDown(() => root.delete(recursive: true));
    final bytes = List<int>.filled(256 * 1024, 7);
    final hash = sha256.convert(bytes).toString();
    final packages = <Map<String, dynamic>>[];
    for (var s = 1; s <= 114; s++) {
      final name = '${s.toString().padLeft(3, '0')}001.mp3';
      final f = File('${root.path}/quran_audio/Alafasy_128kbps/$s/$name');
      await f.parent.create(recursive: true);
      await f.writeAsBytes(bytes);
      packages.add({
        'reciterId': 'Alafasy_128kbps',
        'surah': s,
        'ayahCount': 1,
        'bytes': 1,
        'driveFileId': 'fixture',
        'sha256': hash,
        'files': {name: hash},
      });
    }
    final c = QuranAudioController(
      directory: () async => root,
      catalogLoader: () async => jsonEncode({
        'reciters': [
          {'id': 'Alafasy_128kbps', 'name': 'fixture', 'bitrate': 128},
        ],
        'packages': packages,
      }),
    );
    addTearDown(c.dispose);
    final clock = Stopwatch()..start();
    await c.selectVerse(111, 1);
    debugPrint(
      'target-first 114 x 256KiB selection: ${clock.elapsedMilliseconds}ms; verified=${c.downloadedPackages.length}',
    );
    expect(c.isReady, true);
    expect(c.downloadedPackages.map((p) => p.surah), [111]);
    await c.selectVerse(112, 1);
    expect(c.isReady, true);
    expect(c.downloadedPackages.map((p) => p.surah), [111, 112]);
  });

  test(
    'close cancels selection waiting for catalog without mutating target later',
    () async {
      final catalog = Completer<String>();
      final root = await Directory.systemTemp.createTemp('audio-close-init');
      addTearDown(() => root.delete(recursive: true));
      final c = QuranAudioController(
        directory: () async => root,
        catalogLoader: () => catalog.future,
      );
      addTearDown(c.dispose);
      final selection = c.selectVerse(111, 1);
      await c.close();
      final closedSurah = c.surah;
      catalog.complete(jsonEncode({'reciters': [], 'packages': []}));
      await selection;
      expect(c.surah, closedSurah);
    },
  );

  test(
    'cold invalid ayah preserves prior selection and reports error',
    () async {
      final root = await Directory.systemTemp.createTemp('audio-invalid-first');
      addTearDown(() => root.delete(recursive: true));
      final c = QuranAudioController(
        directory: () async => root,
        catalogLoader: () async => jsonEncode({
          'reciters': [],
          'packages': [
            {
              'reciterId': 'Alafasy_128kbps',
              'surah': 111,
              'ayahCount': 5,
              'bytes': 1,
              'driveFileId': 'fixture',
              'sha256': '',
              'files': {},
            },
          ],
        }),
      );
      addTearDown(c.dispose);
      await c.selectVerse(111, 99);
      expect(c.surah, 1);
      expect(c.ayah, 1);
      expect(c.error, contains('Invalid verse'));
    },
  );

  test(
    'catalog failure remains actionable after first verse selection',
    () async {
      final c = QuranAudioController(catalogLoader: () async => 'invalid JSON');
      addTearDown(c.dispose);
      await c.selectVerse(111, 1);
      expect(c.error, contains('Audio initialization failed'));
      expect(c.isReady, false);
    },
  );

  test('dispose while catalog pending does not open storage or emit', () async {
    final catalog = Completer<String>();
    var storageCalls = 0, emissions = 0;
    final c = QuranAudioController(
      catalogLoader: () => catalog.future,
      directory: () async {
        storageCalls++;
        throw StateError('must not open');
      },
    );
    c.addListener(() => emissions++);
    final pending = c.selectVerse(111, 1);
    c.dispose();
    final before = emissions;
    catalog.complete(jsonEncode({'reciters': [], 'packages': []}));
    await pending;
    expect(storageCalls, 0);
    expect(emissions, before);
  });

  test('late persisted package is hash checked on selection and again before queue playback', () async {
    final root = await Directory.systemTemp.createTemp('audio-late-sha');
    addTearDown(() => root.delete(recursive: true));
    final bytes = utf8.encode('verified fixture');
    final hash = sha256.convert(bytes).toString();
    final path = '${root.path}/quran_audio/Alafasy_128kbps/111/111001.mp3';
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    String catalog() => jsonEncode({
      'reciters': [],
      'packages': [
        {
          'reciterId': 'Alafasy_128kbps',
          'surah': 111,
          'ayahCount': 1,
          'bytes': 1,
          'driveFileId': 'fixture',
          'sha256': hash,
          'files': {'111001.mp3': hash},
        },
      ],
    });
    final q = QueuePlayer();
    final c = QuranAudioController(
      directory: () async => root,
      catalogLoader: () async => catalog(),
      playerFactory: () => q,
    );
    await c.selectVerse(111, 1);
    expect(c.isReady, true);
    await file.writeAsString('corruption after selection');
    await c.play();
    expect(c.isPlaying, false);
    expect(c.isReady, false);
    expect(q.preparations, 0);
    expect(c.error, contains('corrupt'));
    c.dispose();
    final restored = QuranAudioController(
      directory: () async => root,
      catalogLoader: () async => catalog(),
    );
    await restored.selectVerse(111, 1);
    expect(restored.isReady, false);
    restored.dispose();
  });

  testWidgets(
    'disposal during pending panel open does not update detached reader',
    (t) async {
      final a = DelayedAudio();
      await mount(t, a);
      await t.tap(find.byKey(const Key('audio-menu')));
      await t.pump();
      expect(a.initialized, 1);
      await t.pumpWidget(const SizedBox());
      a.gate.complete();
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(a.closed, 1);
    },
  );

  test('measure bundled catalog decode versus empty-store initialization', () async {
    final raw = await File('assets/data/audio_catalog.json').readAsString();
    final clock = Stopwatch()..start();
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final decode = clock.elapsedMicroseconds;
    final packages = (json['packages'] as List)
        .map((p) => AudioPackage.fromJson(Map<String, dynamic>.from(p)))
        .toList();
    final models = clock.elapsedMicroseconds - decode;
    final root = await Directory.systemTemp.createTemp('audio-init-measure');
    final c = QuranAudioController(
      directory: () async => root,
      catalogLoader: () async => raw,
    );
    clock.reset();
    await c.initialize();
    debugPrint(
      'catalog bytes=${utf8.encode(raw).length} packages=${packages.length} jsonDecode=${decode}us models=${models}us initialize=${clock.elapsedMicroseconds}us',
    );
    c.dispose();
    await root.delete(recursive: true);
  });
}
