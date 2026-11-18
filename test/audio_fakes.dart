import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:kuran_kitaphanasy/audio/quran_audio_controller.dart';

/// In-memory native clip queue. Tests drive it with [tick].
class ClipPlayer implements AudioPlayback {
  final events = StreamController<PlaybackSnapshot>.broadcast(sync: true);
  @override
  Stream<PlaybackSnapshot> get snapshots => events.stream;

  int preparations = 0, generation = -1, index = 0;
  List<LocalAudioClip> clips = [];
  List<String> get paths => [for (final c in clips) c.path];
  bool playing = false, repeatOne = false, repeatAll = false;
  Duration? sought;
  Completer<void>? preparationGate;

  @override
  Future<void> prepareClips(
    List<LocalAudioClip> value,
    int initial,
    int token,
  ) async {
    preparations++;
    clips = value;
    index = initial;
    generation = token;
    await preparationGate?.future;
  }

  @override
  Future<void> seekIndex(int value) async {
    index = value;
  }

  @override
  Future<void> seek(Duration value) async {
    sought = value;
  }

  @override
  Future<void> setRepeats(bool ayah, bool surah) async {
    repeatOne = ayah;
    repeatAll = surah;
  }

  @override
  Future<void> play() async {
    playing = true;
  }

  @override
  Future<void> pause() async {
    playing = false;
  }

  @override
  Future<void> stop() async {
    playing = false;
  }

  void tick(
    int value, {
    int seconds = 0,
    int? duration,
    bool completed = false,
    int? token,
  }) {
    events.add((
      generation: token ?? generation,
      index: value,
      position: Duration(seconds: seconds),
      duration: duration == null ? null : Duration(seconds: duration),
      completed: completed,
    ));
  }

  @override
  Future<void> dispose() async {
    await events.close();
  }
}

/// Former name of the queue fake; full-surah clips are the only queue now.
typedef QueuePlayer = ClipPlayer;

// Deliberately synthetic portable bytes, never a production recording.
final syntheticMp3 = utf8.encode('test-only full recording');
// Freeze one archive for catalog and transport: ZIP timestamps otherwise make
// separately encoded, identical MP3 fixtures acquire different SHA256 values.
final syntheticZip = ZipEncoder().encode(
  Archive()..addFile(ArchiveFile('001.mp3', syntheticMp3.length, syntheticMp3)),
);

Map<String, dynamic> timedPackage({
  String status = 'published',
  List<int>? zip,
}) {
  final archive = zip ?? syntheticZip;
  return {
    'reciterId': 'mp3quran_123',
    'surah': 1,
    'ayahCount': 2,
    'format': 'full-surah-timed-v1',
    'publicationStatus': status,
    'driveFileId': status == 'published'
        ? 'test-only-drive-id-0000000000'
        : null,
    'bytes': archive.length,
    'sha256': sha256.convert(archive).toString(),
    'files': {'001.mp3': sha256.convert(syntheticMp3).toString()},
    'audioFile': '001.mp3',
    'totalDurationMs': 10000,
    'verseTimings': [
      {'ayah': 1, 'startMs': 1000, 'endMs': 3000},
      {'ayah': 2, 'startMs': 5000, 'endMs': 8000},
    ],
    'source': {
      'provider': 'mp3quran',
      'reciterId': 123,
      'moshafId': 123,
      'url': 'https://server8.mp3quran.net/afs/001.mp3',
      'timingUrl':
          'https://www.mp3quran.net/api/v3/ayat_timing?surah=1&read=123',
      'timingSha256': sha256
          .convert(utf8.encode('raw fixture timings'))
          .toString(),
      'recordingStyle': 'Murattal',
    },
  };
}

String catalog(Map<String, dynamic> p) => catalogOf([p]);

String catalogOf(List<Map<String, dynamic>> packages) => jsonEncode({
  'version': 2,
  'provider': 'mp3quran',
  'contentVersion': '0.0.1',
  'reciters': [
    {'id': 'mp3quran_123', 'name': 'Afasi', 'bitrate': 128},
  ],
  'packages': packages,
});

/// [timedPackage] for another surah with consistent file name and source URLs.
Map<String, dynamic> timedPackageFor(int surah, {List<int>? mp3}) {
  final name = '${surah.toString().padLeft(3, '0')}.mp3';
  final bytes = mp3 ?? syntheticMp3;
  final p = timedPackage()
    ..['surah'] = surah
    ..['audioFile'] = name
    ..['files'] = {name: sha256.convert(bytes).toString()};
  p['source']['url'] = 'https://server8.mp3quran.net/afs/$name';
  p['source']['timingUrl'] =
      'https://www.mp3quran.net/api/v3/ayat_timing?surah=$surah&read=123';
  return p;
}

String localAudioPath(Directory root, int surah) =>
    '${root.path}/quran_audio/mp3quran-0.0.1/mp3quran_123/$surah/'
    '${surah.toString().padLeft(3, '0')}.mp3';
