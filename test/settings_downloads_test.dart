import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuran_kitaphanasy/audio/quran_audio_controller.dart';
import 'package:kuran_kitaphanasy/main.dart';

import 'reader_fixture.dart';

AudioPackage package(String reciter, int surah) => AudioPackage(
  reciterId: reciter,
  surah: surah,
  ayahCount: 7,
  bytes: 0,
  driveFileId: '',
  sha256Hash: '',
  files: const {},
);

class DownloadsAudio extends QuranAudioController {
  final installed = [
    (package: package('a', 1), bytes: 3 * 1024 * 1024),
    (package: package('b', 2), bytes: 512 * 1024),
  ];
  final deleted = <String>[];
  @override
  List<AudioReciter> get reciters => const [
    AudioReciter(id: 'a', name: 'Reciter A', bitrate: 128),
    AudioReciter(id: 'b', name: 'Reciter B', bitrate: 64),
  ];
  @override
  Future<List<({AudioPackage package, int bytes})>> scanDownloads() async => [
    ...installed,
  ];
  @override
  Future<void> deletePackage(AudioPackage p) async {
    deleted.add(p.key);
    installed.removeWhere((f) => f.package.key == p.key);
  }
}

class BrokenAudio extends DownloadsAudio {
  @override
  Future<List<({AudioPackage package, int bytes})>> scanDownloads() async =>
      throw const AudioException(AudioFailure.initialization, 'test');
}

Future<void> openDownloads(WidgetTester t, QuranAudioController a) async {
  await t.pumpWidget(
    QuranApp(data: Future.value(fixture()), audioController: a),
  );
  await t.pumpAndSettle();
  await t.tap(find.byKey(const Key('tab-settings')));
  await t.pumpAndSettle();
  await t.tap(find.byKey(const Key('settings-audio')));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('downloaded recordings are listed with size and deletable', (
    t,
  ) async {
    final a = DownloadsAudio();
    await openDownloads(t, a);
    expect(find.text('Jemi: 2 süre · 3.5 MB'), findsOneWidget);
    expect(find.text('Reciter A · 3.0 MB'), findsOneWidget);
    expect(find.text('Reciter B · 0.5 MB'), findsOneWidget);
    await t.tap(find.byKey(const Key('download-delete-a-1')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('download-delete-confirm')));
    await t.pumpAndSettle();
    expect(a.deleted, ['mp3quran-0.0.1/a/1']);
    expect(find.byKey(const Key('download-a-1')), findsNothing);
    expect(find.text('Jemi: 1 süre · 0.5 MB'), findsOneWidget);
    await t.tap(find.byKey(const Key('download-delete-b-2')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('download-delete-confirm')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('downloads-empty')), findsOneWidget);
  });

  testWidgets('storage failure is a Türkmen message with retry', (t) async {
    await openDownloads(t, BrokenAudio());
    expect(find.byKey(const Key('downloads-error')), findsOneWidget);
    expect(find.text(AudioFailure.initialization.message), findsOneWidget);
    expect(find.text('Täzeden synanyş'), findsOneWidget);
  });
}
