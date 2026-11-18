import 'dart:convert';

final _sha256Hex = RegExp(r'^[a-f0-9]{64}$');

class AudioReciter {
  final String id, name;
  final int bitrate;
  const AudioReciter({
    required this.id,
    required this.name,
    required this.bitrate,
  });
}

/// Explicit same-reciter opening (besmele) clip prepended to a full recording.
class AudioOpeningPrelude {
  final String asset, sha256Hash, reciterId;
  final int startMs, endMs, sourceDurationMs, sourceSurah, sourceAyah;
  const AudioOpeningPrelude({
    required this.asset,
    required this.sha256Hash,
    required this.reciterId,
    required this.startMs,
    required this.endMs,
    required this.sourceDurationMs,
    required this.sourceSurah,
    required this.sourceAyah,
  });
  factory AudioOpeningPrelude.fromJson(Map<String, dynamic> j) =>
      AudioOpeningPrelude(
        asset: j['asset'] is String ? j['asset'] : '',
        sha256Hash: j['sha256'] is String ? j['sha256'] : '',
        reciterId: j['reciterId'] is String ? j['reciterId'] : '',
        startMs: j['startMs'] is int ? j['startMs'] : -1,
        endMs: j['endMs'] is int ? j['endMs'] : -1,
        sourceDurationMs: j['sourceDurationMs'] is int
            ? j['sourceDurationMs']
            : -1,
        sourceSurah: j['sourceSurah'] is int ? j['sourceSurah'] : -1,
        sourceAyah: j['sourceAyah'] is int ? j['sourceAyah'] : -1,
      );
  int get durationMs => endMs - startMs;
  bool validFor(String reciter, int target) =>
      target != 1 &&
      target != 9 &&
      reciterId.isNotEmpty &&
      reciterId == reciter &&
      sourceSurah == 1 &&
      sourceAyah == 1 &&
      RegExp(r'^assets/audio/[A-Za-z0-9_-]+\.mp3$').hasMatch(asset) &&
      _sha256Hex.hasMatch(sha256Hash) &&
      startMs >= 0 &&
      endMs > startMs &&
      sourceDurationMs > 0 &&
      endMs <= sourceDurationMs;
}

/// One complete MP3Quran surah recording with official per-ayah timings.
class AudioPackage {
  static const fullSurahFormat = 'full-surah-timed-v1';
  static const maxArchiveBytes = 128 * 1024 * 1024;

  final String reciterId, driveFileId, sha256Hash;
  final int surah, ayahCount, bytes;
  final Map<String, String> files;
  final AudioOpeningPrelude? openingPrelude;
  final String format, publicationStatus;
  final String? audioFile;
  final int totalDurationMs;
  final List<Map<String, dynamic>> verseTimings;
  final Map<String, dynamic> source;

  const AudioPackage({
    required this.reciterId,
    required this.surah,
    required this.ayahCount,
    required this.bytes,
    required this.driveFileId,
    required this.sha256Hash,
    required this.files,
    this.openingPrelude,
    this.format = fullSurahFormat,
    this.publicationStatus = 'published',
    this.audioFile,
    this.totalDurationMs = 0,
    this.verseTimings = const [],
    this.source = const {},
  });

  factory AudioPackage.fromJson(Map<String, dynamic> j) => AudioPackage(
    reciterId: j['reciterId'],
    surah: j['surah'],
    ayahCount: j['ayahCount'],
    bytes: j['bytes'],
    driveFileId: j['driveFileId'] ?? '',
    format: j['format'] ?? '',
    publicationStatus: j['publicationStatus'] ?? 'pending-upload',
    audioFile: j['audioFile'],
    totalDurationMs: j['totalDurationMs'] ?? 0,
    verseTimings: (j['verseTimings'] as List? ?? [])
        .map((t) => Map<String, dynamic>.from(t))
        .toList(),
    source: Map<String, dynamic>.from(j['source'] ?? {}),
    sha256Hash: j['sha256'],
    files: Map<String, String>.from(j['files']),
    openingPrelude: j['openingPrelude'] == null
        ? null
        : AudioOpeningPrelude.fromJson(
            j['openingPrelude'] is Map
                ? Map<String, dynamic>.from(j['openingPrelude'])
                : {},
          ),
  );

  /// Storage key. Kept stable so recordings downloaded by 1.0.0 stay valid.
  String get key => 'mp3quran-0.0.1/$reciterId/$surah';

  bool get isPublished =>
      publicationStatus == 'published' &&
      RegExp(r'^[A-Za-z0-9_-]{20,}$').hasMatch(driveFileId);

  bool get validMetadata {
    if (format != fullSurahFormat) return false;
    if (openingPrelude != null && !openingPrelude!.validFor(reciterId, surah)) {
      return false;
    }
    if (surah < 1 ||
        surah > 114 ||
        ayahCount < 1 ||
        audioFile != '${surah.toString().padLeft(3, '0')}.mp3' ||
        files.length != 1 ||
        !files.containsKey(audioFile) ||
        !_sha256Hex.hasMatch(files[audioFile] ?? '') ||
        !_sha256Hex.hasMatch(sha256Hash) ||
        bytes <= 0 ||
        bytes > maxArchiveBytes ||
        totalDurationMs <= 0 ||
        verseTimings.length != ayahCount ||
        source['provider'] != 'mp3quran' ||
        !_sha256Hex.hasMatch(source['timingSha256']?.toString() ?? '') ||
        !{'Murattal', 'Mojawwad'}.contains(source['recordingStyle'])) {
      return false;
    }
    final moshaf = source['moshafId'];
    if (moshaf is! int ||
        reciterId != 'mp3quran_$moshaf' ||
        !{92, 4, 123, 54, 133}.contains(moshaf) ||
        source['reciterId'] != (moshaf == 133 ? 102 : moshaf) ||
        source['recordingStyle'] != (moshaf == 133 ? 'Mojawwad' : 'Murattal')) {
      return false;
    }
    final audio = Uri.tryParse(source['url']?.toString() ?? '');
    final timing = Uri.tryParse(source['timingUrl']?.toString() ?? '');
    if (audio == null ||
        audio.scheme != 'https' ||
        !audio.host.endsWith('.mp3quran.net') ||
        audio.path.split('/').last != audioFile ||
        timing == null ||
        timing.scheme != 'https' ||
        !{'www.mp3quran.net', 'mp3quran.net'}.contains(timing.host) ||
        timing.path != '/api/v3/ayat_timing' ||
        timing.queryParameters['surah'] != '$surah' ||
        timing.queryParameters['read'] != '$moshaf') {
      return false;
    }
    var previousStart = -1, previousEnd = -1;
    for (var i = 0; i < verseTimings.length; i++) {
      final t = verseTimings[i];
      final start = t['startMs'], end = t['endMs'];
      if (t['ayah'] != i + 1 ||
          start is! int ||
          end is! int ||
          start < 0 ||
          start >= totalDurationMs ||
          start <= previousStart ||
          start < previousEnd ||
          end <= start ||
          end > totalDurationMs + (i == verseTimings.length - 1 ? 500 : 0)) {
        return false;
      }
      previousStart = start;
      previousEnd = end;
    }
    // Raw official annotations remain untouched. Only the final annotation
    // may overrun; native clips and the seek timeline still end at actual EOF.
    final beyond = previousEnd > totalDurationMs
        ? previousEnd - totalDurationMs
        : 0;
    if ((beyond > 0 || source.containsKey('timingEndBeyondAudioMs')) &&
        (source['timingEndBeyondAudioMs'] is! int ||
            source['timingEndBeyondAudioMs'] != beyond)) {
      return false;
    }
    if ((beyond > 0 || source.containsKey('timingPolicy')) &&
        source['timingPolicy'] != 'original-starts-eof-500ms-v1') {
      return false;
    }
    return true;
  }

  /// Original recording has audio (e.g. isti'adha) before ayah 1.
  bool get hasOriginalIntro =>
      validMetadata && verseTimings.first['startMs'] > 0;

  /// Queue entries before canonical ayah 1: prelude and/or original intro.
  int get openingCount =>
      (hasOriginalIntro ? 1 : 0) +
      (validMetadata && openingPrelude != null ? 1 : 0);
  bool get hasOpening => openingCount > 0;
  bool get hasTiming => validMetadata;

  static final _prefixes = Expando<List<int>>();

  /// Cumulative queue start times in milliseconds, ending with the total.
  List<int> get timingPrefix => _prefixes[this] ??= _prefix();
  List<int> _prefix() {
    if (!validMetadata) return const [0];
    final prelude = openingPrelude?.durationMs ?? 0;
    return [
      0,
      if (openingPrelude != null) prelude,
      ...verseTimings
          .map((t) => t['startMs'] as int)
          .where((s) => s > 0)
          .map((s) => s + prelude),
      totalDurationMs + prelude,
    ];
  }
}

typedef AudioCatalog = ({
  List<AudioReciter> reciters,
  List<AudioPackage> packages,
});

/// Decodes the bundled catalog. Runs in a background isolate via `compute`.
AudioCatalog decodeAudioCatalog(String raw) {
  final json = jsonDecode(raw) as Map<String, dynamic>;
  final reciters = (json['reciters'] as List)
      .map(
        (r) =>
            AudioReciter(id: r['id'], name: r['name'], bitrate: r['bitrate']),
      )
      .toList();
  final packages = (json['packages'] as List)
      .map((p) => AudioPackage.fromJson(Map<String, dynamic>.from(p)))
      .toList();
  if (json['provider'] != 'mp3quran' ||
      json['version'] != 2 ||
      json['contentVersion'] != '0.0.1' ||
      packages.any((p) => p.format != AudioPackage.fullSurahFormat)) {
    throw const FormatException('Invalid MP3Quran catalog schema');
  }
  return (reciters: reciters, packages: packages);
}
