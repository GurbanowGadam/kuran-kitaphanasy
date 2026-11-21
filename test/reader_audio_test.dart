import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuran_kitaphanasy/reader/presentation/reader.dart';

import 'reader_fixture.dart';

import 'package:kuran_kitaphanasy/audio/quran_audio_controller.dart';

class FakeAudio extends QuranAudioController {
  int initialized = 0, closed = 0, pauses = 0, selections = 0;
  int targetSurah = 1, targetAyah = 1;
  bool local = false, playing = false, downloading = false, supported = true;
  String reciter = 'a';
  @override
  Future<void> initialize() async {
    initialized++;
  }

  bool basmala = false;
  bool pending = false, opening = false;
  @override
  bool get isOpening => opening || isBasmala;
  @override
  bool get isPending => pending;
  @override
  bool get canDownload => supported && !pending;
  @override
  bool get isBasmala => basmala;
  @override
  int get surah => targetSurah;
  @override
  int get ayah => targetAyah;
  @override
  bool get isReady => local;
  @override
  bool get isSupported => supported;
  @override
  bool get isPlaying => playing;
  @override
  bool get isDownloading => downloading;
  @override
  double get downloadProgress => .4;
  Duration elapsed = Duration.zero;
  // Deliberately unequal measured fixture durations, never ayah-count estimates.
  final measuredSeconds = [30, 10, 60, 20, 40, 50, 90];
  bool timingAvailable = true;
  Duration? wholePosition, wholeDuration;
  final surahSeeks = <Duration>[];
  @override
  bool get hasSurahTiming => timingAvailable;
  @override
  Duration get surahPosition =>
      wholePosition ??
      Duration(
            seconds: measuredSeconds
                .take(targetAyah - 1)
                .fold(0, (a, b) => a + b),
          ) +
          elapsed;
  @override
  Duration get surahDuration => wholeDuration ?? const Duration(seconds: 300);
  @override
  Future<void> seekSurah(Duration target) async {
    surahSeeks.add(target);
    wholePosition = target;
    notifyListeners();
  }

  @override
  Duration get position => elapsed;
  @override
  AudioPackage get selectedPackage => const AudioPackage(
    reciterId: 'a',
    surah: 1,
    ayahCount: 7,
    bytes: 0,
    driveFileId: '',
    sha256Hash: '',
    files: {},
  );
  Duration length = const Duration(seconds: 30);
  @override
  Duration get duration => length;
  @override
  String get reciterId => reciter;
  @override
  List<AudioReciter> get reciters => const [
    AudioReciter(id: 'a', name: 'Reciter A', bitrate: 128),
    AudioReciter(id: 'b', name: 'Reciter B', bitrate: 64),
  ];
  @override
  Future<void> selectVerse(int s, int v) async {
    selections++;
    targetSurah = s;
    targetAyah = v;
    elapsed = Duration.zero;
    notifyListeners();
  }

  @override
  Future<void> selectReciter(String id) async {
    reciter = id;
    local = false;
    playing = false;
    notifyListeners();
  }

  @override
  Future<void> downloadSelected() async {
    downloading = true;
    notifyListeners();
  }

  @override
  Future<void> cancelDownload() async {
    downloading = false;
    notifyListeners();
  }

  @override
  Future<void> play() async {
    playing = true;
    notifyListeners();
  }

  @override
  Future<void> pause() async {
    pauses++;
    playing = false;
    notifyListeners();
  }

  @override
  Future<void> close() async {
    closed++;
    playing = false;
  }
}

class FailingAudio extends FakeAudio {
  @override
  Future<void> selectVerse(int s, int v) async =>
      throw const SocketException('Connection refused (OS Error)');

  @override
  String? get error => AudioFailure.network.message;
}

void main() {
  testWidgets('audio failures are shown only as Türkmen messages', (t) async {
    final a = FailingAudio();
    await t.pumpWidget(
      MaterialApp(
        home: Reader(
          data: Future.value(fixture()),
          audioController: a,
          goHome: () {},
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('audio-menu')));
    await t.pumpAndSettle();
    final shown = t.widget<Text>(find.byKey(const Key('audio-error'))).data!;
    expect(shown, AudioFailure.initialization.message);
    expect(shown, isNot(contains('Socket')));
    expect(find.textContaining('OS Error'), findsNothing);
  });
  testWidgets('pending MP3Quran has no download and keeps reciter selector', (
    t,
  ) async {
    final a = FakeAudio()..pending = true;
    await t.pumpWidget(
      MaterialApp(
        home: Reader(
          data: Future.value(fixture()),
          audioController: a,
          goHome: () {},
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('audio-menu')));
    await t.pumpAndSettle();
    expect(find.text('Sesler ýüklemäge taýýarlanýar'), findsOneWidget);
    expect(find.byKey(const Key('audio-download')), findsNothing);
    expect(
      t.widget<IconButton>(find.byKey(const Key('audio-reciter'))).onPressed,
      isNotNull,
    );
  });
  testWidgets(
    'generic recording intro is Başlangyç not Besmele or numbered verse',
    (t) async {
      final a = FakeAudio()
        ..local = true
        ..opening = true;
      await t.pumpWidget(
        MaterialApp(
          home: Reader(
            data: Future.value(fixture()),
            audioController: a,
            goHome: () {},
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('audio-menu')));
      await t.pumpAndSettle();
      expect(find.textContaining('Başlangyç'), findsOneWidget);
      expect(find.textContaining('Besmele'), findsNothing);
    },
  );
  Future<void> openPanel(WidgetTester t, FakeAudio a) async {
    await t.pumpWidget(
      MaterialApp(
        home: Reader(
          data: Future.value(fixture()),
          audioController: a,
          goHome: () {},
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('audio-menu')));
    await t.pumpAndSettle();
  }

  double progress(WidgetTester t) =>
      t.widget<Slider>(find.byKey(const Key('audio-seek'))).value;

  testWidgets(
    'timeline clocks retain measured surah prefixes and stable total',
    (t) async {
      final a = FakeAudio()..local = true;
      await openPanel(t, a);
      final semantics = t.ensureSemantics();
      Text clock(String key) => t.widget<Text>(find.byKey(Key(key)));
      expect(clock('audio-duration').data, '5:00');
      a.elapsed = const Duration(seconds: 14);
      a.length = const Duration(seconds: 78);
      a.notifyListeners();
      await t.pump();
      expect(clock('audio-position').data, '0:14');
      expect(clock('audio-duration').data, '5:00');
      expect(
        find.bySemanticsLabel('Süräniň geçen wagty: 0:14'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Süräniň dowamlylygy: 5:00'),
        findsOneWidget,
      );
      a.targetAyah = 3;
      a.elapsed = Duration.zero;
      a.length = Duration.zero;
      a.notifyListeners();
      await t.pump();
      expect(clock('audio-position').data, '0:40');
      expect(clock('audio-duration').data, '5:00');
      expect(progress(t), 40000);
      await t.pump(const Duration(seconds: 3));
      expect(progress(t), 40000);
      a.wholePosition = const Duration(minutes: 123, seconds: 4);
      a.wholeDuration = const Duration(minutes: 130, seconds: 9);
      a.notifyListeners();
      await t.pump();
      expect(clock('audio-position').data, '123:04');
      expect(clock('audio-duration').data, '130:09');
      semantics.dispose();
    },
  );

  testWidgets(
    'missing measured timing shows unknown clocks and disables seeking',
    (t) async {
      final a = FakeAudio()
        ..local = true
        ..timingAvailable = false;
      await openPanel(t, a);
      expect(
        t.widget<Text>(find.byKey(const Key('audio-position'))).data,
        '--:--',
      );
      expect(
        t.widget<Text>(find.byKey(const Key('audio-duration'))).data,
        '--:--',
      );
      final slider = t.widget<Slider>(find.byKey(const Key('audio-seek')));
      expect(slider.onChanged, isNull);
      expect(slider.onChangeEnd, isNull);
    },
  );

  testWidgets('ready transport is smaller with full sized invisible targets', (
    t,
  ) async {
    final a = FakeAudio()..local = true;
    await openPanel(t, a);
    expect(
      t.getSize(find.byKey(const Key('audio-panel'))).height,
      lessThanOrEqualTo(108),
    );
    for (final key in [
      'audio-reciter',
      'audio-previous',
      'audio-play',
      'audio-next',
      'audio-repeat-surah',
      'audio-close',
    ]) {
      final button = find.byKey(Key(key));
      final size = t.getSize(button);
      expect(size.width, greaterThanOrEqualTo(48 - 1e-6));
      expect(size.height, greaterThanOrEqualTo(48 - 1e-6));
      expect(
        t
            .widget<Icon>(
              find.descendant(of: button, matching: find.byType(Icon)),
            )
            .size,
        lessThanOrEqualTo(22),
      );
    }
    expect(
      t.widget<Text>(find.textContaining('Aýat 1/7')).style!.fontSize,
      lessThanOrEqualTo(11),
    );
  });

  testWidgets('opening Besmele contributes measured whole surah time', (
    t,
  ) async {
    final a = FakeAudio()..local = true;
    await openPanel(t, a);
    a.basmala = true;
    a.elapsed = const Duration(seconds: 14);
    a.length = const Duration(seconds: 78);
    a.notifyListeners();
    await t.pump();
    expect(find.textContaining('Besmele'), findsOneWidget);
    expect(find.textContaining('Aýat 1/7'), findsNothing);
    expect(
      progress(t),
      14000,
      reason: 'the unnumbered intro contributes actual elapsed time',
    );
    expect(
      t.widget<Text>(find.byKey(const Key('audio-position'))).data,
      '0:14',
    );
    expect(
      t.widget<Text>(find.byKey(const Key('audio-duration'))).data,
      '5:00',
    );
    a.basmala = false;
    a.elapsed = Duration.zero;
    a.notifyListeners();
    await t.pump();
    expect(find.textContaining('Besmele'), findsNothing);
    expect(find.textContaining('Aýat 1/7'), findsOneWidget);
  });

  testWidgets('playing samples interpolate without autonomous extrapolation', (
    t,
  ) async {
    final a = FakeAudio()
      ..local = true
      ..playing = true;
    await openPanel(t, a);
    a.elapsed = const Duration(seconds: 15);
    a.notifyListeners();
    await t.pump();
    expect(progress(t), 0, reason: 'incoming samples must not snap');
    await t.pump(const Duration(milliseconds: 80));
    expect(progress(t), closeTo(7500, .001));
    await t.pump(const Duration(milliseconds: 80));
    expect(progress(t), 15000);
    await t.pump(const Duration(seconds: 3));
    expect(progress(t), 15000, reason: 'no invented time while buffering');
    a.elapsed = const Duration(seconds: 24);
    a.notifyListeners();
    await t.pump();
    await t.pump(const Duration(milliseconds: 40));
    a.playing = false;
    a.notifyListeners();
    await t.pump();
    final paused = progress(t);
    await t.pump(const Duration(seconds: 3));
    expect(progress(t), paused, reason: 'pause cancels any pending tween');
    expect(paused, 24000);
  });

  testWidgets('atomic next ayah boundary never reuses late old fraction', (
    t,
  ) async {
    final a = FakeAudio()
      ..local = true
      ..playing = true;
    await openPanel(t, a);
    a.elapsed = const Duration(milliseconds: 29700);
    a.notifyListeners();
    await t.pumpAndSettle();
    expect(progress(t), 29700);
    a.targetAyah = 2;
    a.elapsed = Duration.zero;
    a.length = Duration.zero;
    a.notifyListeners();
    await t.pump();
    expect(progress(t), 29700);
    await t.pump(const Duration(milliseconds: 80));
    expect(progress(t), closeTo(29850, .0001));
    await t.pump(const Duration(milliseconds: 80));
    expect(progress(t), 30000);
    a.length = const Duration(seconds: 10);
    a.notifyListeners();
    await t.pumpAndSettle();
    expect(progress(t), 30000);
    a.elapsed = const Duration(seconds: 1);
    a.notifyListeners();
    await t.pump();
    await t.pump(const Duration(milliseconds: 80));
    expect(progress(t), closeTo(30500, .001));
    await t.pumpAndSettle();
    expect(progress(t), 31000);
    a.elapsed = Duration.zero; // Genuine same-ayah repeat/seek.
    a.notifyListeners();
    await t.pump();
    expect(progress(t), 30000);
    a.targetAyah = 1; // Surah repeat/previous must not be clamped.
    a.notifyListeners();
    await t.pump();
    expect(progress(t), 0);
    a.elapsed = const Duration(seconds: 8);
    a.notifyListeners();
    await t.pumpAndSettle();
    a.reciter = 'b';
    a.elapsed = Duration.zero;
    a.notifyListeners();
    await t.pump();
    expect(progress(t), 0, reason: 'new reciter starts a fresh progress state');
  });
  testWidgets('whole surah timeline commits one exact timestamp on drag end', (
    t,
  ) async {
    final a = FakeAudio()..local = true;
    await t.pumpWidget(
      MaterialApp(
        home: Reader(
          data: Future.value(fixture()),
          audioController: a,
          goHome: () {},
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('audio-menu')));
    await t.pumpAndSettle();
    Slider slider() => t.widget<Slider>(find.byKey(const Key('audio-seek')));
    expect(slider().max, 300000);
    expect(slider().value, 0);
    expect(find.textContaining('Aýat 1/7'), findsOneWidget);
    a.elapsed = const Duration(seconds: 15);
    a.notifyListeners();
    await t.pump();
    expect(slider().value, 15000);
    a.targetAyah = 2;
    a.elapsed = Duration.zero;
    a.notifyListeners();
    await t.pump();
    expect(slider().value, 30000);
    final beforeSeek = a.selections;
    slider().onChanged!(32000);
    slider().onChanged!(44444);
    await t.pump();
    expect(slider().value, 44444, reason: 'drag preview is immediate');
    expect(a.selections, beforeSeek);
    expect(a.ayah, 2); // Dragging must not repeatedly stop/reload playback.
    expect(a.surahSeeks, isEmpty);
    slider().onChangeEnd!(44444);
    await t.pumpAndSettle();
    expect(a.selections, beforeSeek);
    expect(a.surahSeeks, [const Duration(milliseconds: 44444)]);
    expect(slider().value, 44444);
    expect(a.playing, false);
    a.playing = true;
    a.notifyListeners();
    await t.pump();
    slider().onChanged!(300000);
    slider().onChangeEnd!(300000);
    await t.pumpAndSettle();
    expect(a.surahSeeks.last, const Duration(seconds: 300));
    expect(a.surahSeeks.length, 2);
    expect(a.playing, true);
    a.elapsed = const Duration(seconds: 30);
    a.notifyListeners();
    await t.pumpAndSettle();
    expect(slider().value, 300000);
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'compact transport replaces left repeat with accessible reciter picker $brightness',
      (t) async {
        t.view.physicalSize = const Size(320, 900);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final a = FakeAudio()..local = true;
        await t.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Reader(
                data: Future.value(fixture()),
                audioController: a,
                goHome: () {},
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('audio-menu')));
        await t.pumpAndSettle();
        final panel = t.getRect(find.byKey(const Key('audio-panel')));
        expect(panel.height, lessThanOrEqualTo(124));
        for (final key in [
          'audio-reciter',
          'audio-previous',
          'audio-play',
          'audio-next',
          'audio-repeat-surah',
          'audio-close',
        ]) {
          final rect = t.getRect(find.byKey(Key(key)));
          expect(rect.width, greaterThanOrEqualTo(48 - 1e-6));
          expect(rect.height, greaterThanOrEqualTo(48 - 1e-6));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(320));
        }
        final picker = t.getRect(find.byKey(const Key('audio-reciter')));
        final play = t.getRect(find.byKey(const Key('audio-play')));
        expect(picker.center.dy, play.center.dy);
        expect(picker.right, lessThan(play.left));
        expect(picker.width, greaterThanOrEqualTo(48 - 1e-6));
        expect(picker.height, greaterThanOrEqualTo(48 - 1e-6));
        expect(panel.bottom, 900);
        expect(find.byKey(const Key('reader-fullscreen')), findsNothing);
        expect(find.byKey(const Key('audio-menu')), findsNothing);
        expect(find.byKey(const Key('bookmarks-menu')), findsNothing);
        expect(find.byKey(const Key('audio-repeat-ayah')), findsNothing);
        expect(find.byKey(const Key('audio-delete')), findsNothing);
        expect(find.byKey(const Key('audio-repeat-surah')), findsOneWidget);
        await t.tap(find.byKey(const Key('audio-reciter')));
        await t.pumpAndSettle();
        await t.tap(find.text('Reciter B').last);
        await t.pumpAndSettle();
        expect(a.reciter, 'b');
        expect(t.takeException(), isNull);
        await t.tap(find.byKey(const Key('audio-close')));
        await t.pumpAndSettle();
        expect(find.byKey(const Key('audio-panel')), findsNothing);
        expect(find.byKey(const Key('reader-fullscreen')), findsOneWidget);
        expect(find.byKey(const Key('audio-menu')), findsOneWidget);
        expect(find.byKey(const Key('bookmarks-menu')), findsOneWidget);
      },
    );
  }

  testWidgets(
    'bottom audio is lazy download-first persistent and narrow-safe',
    (t) async {
      t.view.physicalSize = const Size(320, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final a = FakeAudio();
      Future<void> render({bool active = true}) async {
        await t.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
              child: Reader(
                data: Future.value(fixture()),
                audioController: a,
                active: active,
                goHome: () {},
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
      }

      await render();
      expect(a.initialized, 0);
      expect(
        t.getCenter(find.byKey(const Key('audio-menu'))).dx,
        greaterThan(t.getCenter(find.byKey(const Key('bookmarks-menu'))).dx),
      );
      await t.tap(find.byKey(const Key('audio-menu')));
      await t.pumpAndSettle();
      expect(a.initialized, 1);
      expect(a.targetSurah, 1);
      expect(a.targetAyah, 1);
      expect(find.byKey(const Key('audio-panel')), findsOneWidget);
      expect(find.byKey(const Key('quran-pages')), findsOneWidget);
      expect(
        t.widget<IconButton>(find.byKey(const Key('audio-play'))).onPressed,
        isNull,
      );
      await t.tap(find.byKey(const Key('audio-download')));
      await t.pump();
      expect(
        t
            .widget<LinearProgressIndicator>(
              find.byKey(const Key('audio-download-progress')),
            )
            .value,
        .4,
      );
      await t.tap(find.byKey(const Key('audio-cancel')));
      await t.pumpAndSettle();
      a.local = true;
      a.notifyListeners();
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('audio-play')));
      await t.pumpAndSettle();
      expect(a.playing, isTrue);
      await t.tap(find.byKey(const Key('audio-reciter')));
      await t.pumpAndSettle();
      await t.tap(find.text('Reciter B').last);
      await t.pumpAndSettle();
      expect(a.reciter, 'b');
      expect(a.playing, isFalse);
      a.supported = false;
      a.notifyListeners();
      await t.pumpAndSettle();
      expect(find.byKey(const Key('audio-unavailable')), findsOneWidget);
      expect(find.byKey(const Key('audio-download')), findsNothing);
      expect(t.takeException(), isNull);
      await render(active: false);
      expect(a.closed, greaterThan(0));
      expect(find.byKey(const Key('audio-panel')), findsNothing);
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
      a.notifyListeners();
      a.dispose();
    },
  );

  testWidgets('verse listen targets pressed group and closes with X', (
    t,
  ) async {
    final a = FakeAudio();
    await t.pumpWidget(
      MaterialApp(
        home: Reader(
          data: Future.value(fixture()),
          audioController: a,
          goHome: () {},
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.longPressAt(
      t.getTopLeft(find.byKey(const Key('translation-t1'))) +
          const Offset(30, 20),
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('verse-listen')));
    await t.pumpAndSettle();
    expect(a.targetSurah, 1);
    expect(a.targetAyah, 1);
    expect(a.playing, isFalse);
    await t.tap(find.byKey(const Key('audio-close')));
    await t.pumpAndSettle();
    expect(a.closed, 1);
    expect(find.byKey(const Key('audio-panel')), findsNothing);
  });
  testWidgets('verse listen starts downloaded audio without a second tap', (
    t,
  ) async {
    final a = FakeAudio()..local = true;
    await t.pumpWidget(
      MaterialApp(
        home: Reader(
          data: Future.value(fixture()),
          audioController: a,
          goHome: () {},
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.longPressAt(
      t.getTopLeft(find.byKey(const Key('translation-t1'))) +
          const Offset(30, 20),
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('verse-listen')));
    await t.pumpAndSettle();
    expect(a.targetSurah, 1);
    expect(a.targetAyah, 1);
    expect(a.playing, isTrue);
    await t.tap(find.byKey(const Key('audio-close')));
    await t.pumpAndSettle();
  });
  testWidgets('audio menu still waits for an explicit play tap', (t) async {
    final a = FakeAudio()..local = true;
    await t.pumpWidget(
      MaterialApp(
        home: Reader(
          data: Future.value(fixture()),
          audioController: a,
          goHome: () {},
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('audio-menu')));
    await t.pumpAndSettle();
    expect(a.playing, isFalse);
  });
  testWidgets('reciter sheet is titled Kary saýla', (t) async {
    final a = FakeAudio()..local = true;
    await t.pumpWidget(
      MaterialApp(
        home: Reader(
          data: Future.value(fixture()),
          audioController: a,
          goHome: () {},
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('audio-menu')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('audio-reciter')));
    await t.pumpAndSettle();
    expect(find.text('Kary saýla'), findsOneWidget);
    expect(find.textContaining('Käri'), findsNothing);
  });
  testWidgets('long press offers exactly two real verse actions', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: Reader(data: Future.value(fixture()), goHome: () {}),
      ),
    );
    await t.pumpAndSettle();
    await t.longPressAt(
      t.getTopLeft(find.byKey(const Key('translation-t1'))) +
          const Offset(30, 20),
    );
    await t.pumpAndSettle();
    expect(find.byKey(const Key('verse-actions')), findsOneWidget);
    expect(find.text('Aýaty diňle'), findsOneWidget);
    expect(find.byKey(const Key('verse-bookmarks')), findsOneWidget);
    await t.tap(find.byKey(const Key('verse-bookmarks')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('bookmark-chooser')), findsOneWidget);
  });
}
