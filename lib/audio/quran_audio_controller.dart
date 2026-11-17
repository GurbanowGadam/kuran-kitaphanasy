import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

class AudioReciter {
  final String id, name;
  final int bitrate;
  const AudioReciter({
    required this.id,
    required this.name,
    required this.bitrate,
  });
}

class AudioOpeningOverride {
  final String asset, sha256Hash;
  final int durationMs;
  const AudioOpeningOverride(this.asset, this.sha256Hash, this.durationMs);
  factory AudioOpeningOverride.fromJson(Map<String, dynamic> j) =>
      AudioOpeningOverride(j['asset'], j['sha256'], j['durationMs']);
}

/// Explicit same-reciter source identity; independent of legacy openingOverride.
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
      RegExp(r'^[a-f0-9]{64}$').hasMatch(sha256Hash) &&
      startMs >= 0 &&
      endMs > startMs &&
      sourceDurationMs > 0 &&
      endMs <= sourceDurationMs;
}

class AudioPackage {
  final String reciterId, driveFileId, sha256Hash;
  final int surah, ayahCount, bytes;
  final Map<String, String> files;
  final Map<String, int> durationsMs;
  final AudioOpeningOverride? openingOverride;
  final AudioOpeningPrelude? openingPrelude;
  final String format, publicationStatus;
  final String? audioFile;
  final int totalDurationMs;
  final List<Map<String, dynamic>> verseTimings;
  final Map<String, dynamic> source;
  bool get isFullSurah => format == 'full-surah-timed-v1';
  bool get isPublished =>
      publicationStatus == 'published' &&
      driveFileId.isNotEmpty &&
      (!isFullSurah || RegExp(r'^[A-Za-z0-9_-]{20,}$').hasMatch(driveFileId));
  bool get validMetadata {
    if (openingPrelude != null &&
        (!isFullSurah || !openingPrelude!.validFor(reciterId, surah))) {
      return false;
    }
    if (!isFullSurah) return format == 'ayah-files-v1';
    final hash = RegExp(r'^[a-f0-9]{64}$');
    if (surah < 1 ||
        surah > 114 ||
        ayahCount < 1 ||
        audioFile != '${surah.toString().padLeft(3, '0')}.mp3' ||
        files.length != 1 ||
        !files.containsKey(audioFile) ||
        !hash.hasMatch(files[audioFile] ?? '') ||
        !hash.hasMatch(sha256Hash) ||
        bytes <= 0 ||
        bytes > 128 * 1024 * 1024 ||
        totalDurationMs <= 0 ||
        verseTimings.length != ayahCount ||
        openingOverride != null ||
        source['provider'] != 'mp3quran' ||
        !hash.hasMatch(source['timingSha256']?.toString() ?? '') ||
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

  bool get hasOriginalIntro =>
      isFullSurah && validMetadata && verseTimings.first['startMs'] > 0;
  int get openingCount => isFullSurah
      ? (hasOriginalIntro ? 1 : 0) +
            (validMetadata && openingPrelude != null ? 1 : 0)
      : (hasOpening ? 1 : 0);
  bool get hasOpening => isFullSurah
      ? validMetadata && (openingPrelude != null || hasOriginalIntro)
      : timingFiles.length > ayahCount;
  const AudioPackage({
    required this.reciterId,
    required this.surah,
    required this.ayahCount,
    required this.bytes,
    required this.driveFileId,
    required this.sha256Hash,
    required this.files,
    this.durationsMs = const {},
    this.openingOverride,
    this.openingPrelude,
    this.format = 'ayah-files-v1',
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
    format: j['format'] ?? 'ayah-files-v1',
    publicationStatus:
        j['publicationStatus'] ??
        (j['format'] == 'full-surah-timed-v1' ? 'pending-upload' : 'published'),
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
    openingOverride: j['openingOverride'] == null
        ? null
        : AudioOpeningOverride.fromJson(
            Map<String, dynamic>.from(j['openingOverride']),
          ),
    durationsMs: j['durationsMs'] is Map
        ? Map<String, int>.from(j['durationsMs'])
        : const {},
  );
  String get key =>
      isFullSurah ? 'mp3quran-0.0.1/$reciterId/$surah' : '$reciterId/$surah';
  List<String> get timingFiles => [
    if (surah != 1 &&
        surah != 9 &&
        files.containsKey('${surah.toString().padLeft(3, '0')}000.mp3'))
      '${surah.toString().padLeft(3, '0')}000.mp3',
    for (var a = 1; a <= ayahCount; a++)
      '${surah.toString().padLeft(3, '0')}${a.toString().padLeft(3, '0')}.mp3',
  ];
  bool get hasTiming => isFullSurah
      ? validMetadata
      : timingFiles.every((f) => (durationsMs[f] ?? 0) > 0);
  static final _prefixes = Expando<List<int>>();
  List<int> get timingPrefix => _prefixes[this] ??= _prefix();
  List<int> _prefix() {
    if (isFullSurah) {
      return validMetadata
          ? [
              0,
              if (openingPrelude != null) openingPrelude!.durationMs,
              ...verseTimings
                  .map((t) => t['startMs'] as int)
                  .where((s) => s > 0)
                  .map((s) => s + (openingPrelude?.durationMs ?? 0)),
              totalDurationMs + (openingPrelude?.durationMs ?? 0),
            ]
          : [0];
    }
    final result = <int>[0];
    if (hasTiming) {
      for (final f in timingFiles) {
        result.add(
          result.last +
              (f == timingFiles.first &&
                      timingFiles.length > ayahCount &&
                      openingOverride != null
                  ? openingOverride!.durationMs
                  : durationsMs[f]!),
        );
      }
    }
    return result;
  }
}

class AudioCancellation {
  bool cancelled = false;
  void Function()? onCancel;
  void cancel() {
    cancelled = true;
    onCancel?.call();
  }

  void check() {
    if (cancelled) throw const _Cancelled();
  }
}

class _Cancelled implements Exception {
  const _Cancelled();
}

typedef AudioDownload = Stream<List<int>> Function(
  Uri uri,
  AudioCancellation cancel,
);

abstract class AudioPlayback {
  Stream<void> get completed;
  Stream<Duration> get positions;
  Stream<Duration?> get durations;
  Future<void> load(String localPath);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> dispose();
}

/// Optional native playlist capability; legacy AudioPlayback fakes stay valid.
abstract class QueuedAudioPlayback {
  Stream<
    ({
      int generation,
      int index,
      Duration position,
      Duration? duration,
      bool completed,
    })
  >
  get snapshots;
  Future<void> prepareQueue(List<String> paths, int index, int generation);
  Future<void> seekIndex(int index);
  Future<void> setRepeats(bool ayah, bool surah);
}

/// A lossless interval of the same verified local original recording.
class LocalAudioClip {
  final String path;
  final Duration start, end;
  final int? ayah;
  const LocalAudioClip(this.path, this.start, this.end, this.ayah);
}

/// Optional capability: full recordings MUST NOT fall back to per-ayah files.
abstract class ClippedAudioPlayback implements QueuedAudioPlayback {
  Future<void> prepareClips(
    List<LocalAudioClip> clips,
    int index,
    int generation,
  );
}

class _LocalPlayback implements AudioPlayback, ClippedAudioPlayback {
  final AudioPlayer _player = AudioPlayer(useLazyPreparation: false);
  final _snapshots =
      StreamController<
        ({
          int generation,
          int index,
          Duration position,
          Duration? duration,
          bool completed,
        })
      >.broadcast(sync: true);
  final List<StreamSubscription<dynamic>> _nativeSubscriptions = [];
  int _generation = -1;
  _LocalPlayback() {
    // Every update reads one PlaybackEvent: never combine a new index with an
    // independently delivered old duration/position stream value.
    _nativeSubscriptions.add(
      _player.playbackEventStream.listen(
        (_) => _snapshot(),
        onError: _snapshots.addError,
      ),
    );
    _nativeSubscriptions.add(
      _player.currentIndexStream.listen((_) => _snapshot()),
    );
    _nativeSubscriptions.add(_player.positionStream.listen((_) => _snapshot()));
    _nativeSubscriptions.add(_player.errorStream.listen(_snapshots.addError));
  }
  void _snapshot() {
    final event = _player.playbackEvent;
    if (event.currentIndex == null || _generation < 0) return;
    _snapshots.add((
      generation: _generation,
      index: event.currentIndex!,
      position: _player.position,
      duration: event.duration,
      completed: event.processingState == ProcessingState.completed,
    ));
  }

  @override
  Stream<
    ({
      int generation,
      int index,
      Duration position,
      Duration? duration,
      bool completed,
    })
  >
  get snapshots => _snapshots.stream;
  @override
  Future<void> prepareQueue(
    List<String> paths,
    int index,
    int generation,
  ) async {
    _generation = -1;
    await _player.setAudioSources(
      paths.map((p) => AudioSource.file(p)).toList(),
      initialIndex: index,
      initialPosition: Duration.zero,
      preload: true,
    );
    _generation = generation;
  }

  @override
  Future<void> prepareClips(
    List<LocalAudioClip> clips,
    int index,
    int generation,
  ) async {
    _generation = -1;
    await _player.setAudioSources(
      clips
          .map(
            (clip) => ClippingAudioSource(
              child: AudioSource.file(clip.path),
              start: clip.start,
              end: clip.end,
            ),
          )
          .toList(),
      initialIndex: index,
      initialPosition: Duration.zero,
      preload: true,
    );
    _generation = generation;
  }

  @override
  Future<void> seekIndex(int index) =>
      _player.seek(Duration.zero, index: index);
  @override
  Future<void> setRepeats(bool ayah, bool surah) => _player.setLoopMode(
    ayah
        ? LoopMode.one
        : surah
        ? LoopMode.all
        : LoopMode.off,
  );
  @override
  Stream<void> get completed => _player.processingStateStream
      .where((s) => s == ProcessingState.completed)
      .map((_) {});
  @override
  Stream<Duration> get positions => _player.positionStream;
  @override
  Stream<Duration?> get durations => _player.durationStream;
  @override
  Future<void> load(String path) async {
    await _player.setFilePath(path);
  }

  // just_audio.play resolves at end of playback, not when playback starts.
  @override
  Future<void> play() async {
    unawaited(
      _player.play().catchError((Object error, StackTrace stack) {
        if (!_snapshots.isClosed) _snapshots.addError(error, stack);
      }),
    );
  }

  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> stop() => _player.stop();
  @override
  Future<void> seek(Duration p) => _player.seek(p);
  @override
  Future<void> dispose() async {
    for (final s in _nativeSubscriptions) {
      await s.cancel();
    }
    await _snapshots.close();
    await _player.dispose();
  }
}

// Decode and model allocation run off the UI isolate on native platforms.
({List<AudioReciter> reciters, List<AudioPackage> packages})
_decodeAudioCatalog(String raw) {
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
  if (json['provider'] == 'mp3quran' &&
      (json['version'] != 2 ||
          json['contentVersion'] != '0.0.1' ||
          packages.any((p) => !p.isFullSurah))) {
    throw const FormatException('Invalid MP3Quran catalog schema');
  }
  return (reciters: reciters, packages: packages);
}

/// Download-first, persistent local-file audio. Constructors never touch plugins.
class QuranAudioController extends ChangeNotifier {
  QuranAudioController({
    Future<Directory> Function()? directory,
    Future<String> Function()? catalogLoader,
    AudioPlayback Function()? playerFactory,
    AudioDownload? downloader,
    Future<List<int>> Function(String asset)? openingAssetLoader,
  }) : _directory = directory ?? getApplicationSupportDirectory,
       _catalogLoader =
           catalogLoader ??
           (() => rootBundle.loadString('assets/data/audio_catalog.json')),
       _playerFactory = playerFactory ?? _LocalPlayback.new,
       _downloader = downloader ?? _driveDownload,
       _openingAssetLoader =
           openingAssetLoader ??
           ((asset) async =>
               (await rootBundle.load(asset)).buffer.asUint8List());
  final Future<List<int>> Function(String asset) _openingAssetLoader;
  final Future<Directory> Function() _directory;
  final Future<String> Function() _catalogLoader;
  final AudioPlayback Function() _playerFactory;
  final AudioDownload _downloader;
  Directory? _root;
  AudioPlayback? _player;
  String? _loadedPath;
  String? _queueKey;
  bool _isBasmala = false;
  int _queueOpeningCount = 0, _queueIndex = 0;
  int _queueGeneration = 0, _operation = 0;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  List<AudioReciter> _reciters = [];
  List<AudioPackage> _packages = [];
  final Set<String> _ready = {};
  final Map<String, Future<void>> _localChecks = {};
  int _selectionGeneration = 0;
  String _reciterId = 'Alafasy_128kbps';
  int _surah = 1, _ayah = 1;
  bool _playing = false,
      _downloading = false,
      _disposed = false,
      _repeatAyah = false,
      _repeatSurah = false;
  double _progress = 0;
  Duration _position = Duration.zero, _duration = Duration.zero;
  String? _error;
  Future<void>? _initializing, _downloadTask;
  bool _initialized = false;
  AudioCancellation? _cancel;
  List<AudioReciter> get reciters => List.unmodifiable(_reciters);
  String get reciterId => _reciterId;
  int get surah => _surah;
  int get ayah => _ayah;
  bool get isPlaying => _playing;

  /// Unnumbered, verified opening audio; canonical [ayah] remains 1.
  bool get isBasmala =>
      _isBasmala &&
      (selectedPackage?.isFullSurah != true ||
          (selectedPackage?.openingPrelude != null &&
              _queueKey != null &&
              _queueIndex == 0));
  bool get isOpening => _isBasmala;
  bool get isPending =>
      selectedPackage != null &&
      selectedPackage!.publicationStatus != 'published';
  bool get canDownload =>
      selectedPackage != null &&
      selectedPackage!.isPublished &&
      selectedPackage!.validMetadata;
  bool get isDownloading => _downloading;
  bool get isReady => canDownload && _ready.contains(selectedPackage!.key);
  bool get isSupported => selectedPackage != null;
  double get downloadProgress => _progress;
  Duration get position => _position;
  Duration get duration => _duration;
  bool _timingCleared = true, _surahEnded = false;
  bool get hasSurahTiming => (selectedPackage?.timingPrefix.length ?? 0) > 1;
  Duration get surahDuration => hasSurahTiming
      ? Duration(milliseconds: selectedPackage!.timingPrefix.last)
      : Duration.zero;
  Duration get surahPosition {
    if (!hasSurahTiming || _timingCleared) return Duration.zero;
    if (_surahEnded) return surahDuration;
    final p = selectedPackage!;
    final index = isOpening ? _queueIndex : _ayah - 1 + p.openingCount;
    final prefix = p.timingPrefix;
    final local = _position.inMilliseconds.clamp(
      0,
      prefix[index + 1] - prefix[index],
    );
    return Duration(milliseconds: prefix[index] + local);
  }

  /// Seek on the verified complete local queue, retaining playback intent.
  /// Legacy catalogs deliberately expose no whole-surah time or seek target.
  Future<void> seekSurah(Duration target) async {
    await initialize();
    if (!hasSurahTiming || !isReady || _disposed) return;
    final resume = _playing;
    if (_queueKey == null) {
      await _play(start: false);
      if (_queueKey == null || _disposed) return;
    }
    final queue = _player;
    if (queue is! QueuedAudioPlayback) return;
    final operation = ++_operation;
    _playing = false; // Reject transient old-source native snapshots.
    await _player!.pause();
    if (_disposed || operation != _operation) return;
    final p = selectedPackage!;
    final prefix = p.timingPrefix;
    final ms = target.inMilliseconds.clamp(0, prefix.last);
    var index = 0;
    while (index + 1 < prefix.length - 1 && ms >= prefix[index + 1]) {
      index++;
    }
    final local = Duration(milliseconds: ms - prefix[index]);
    await (queue as QueuedAudioPlayback).seekIndex(index);
    if (_disposed || operation != _operation) return;
    await _player!.seek(local);
    if (_disposed || operation != _operation) return;
    _queueIndex = index;
    _isBasmala = index < _queueOpeningCount;
    _ayah = _isBasmala ? 1 : index + 1 - _queueOpeningCount;
    _position = local;
    _duration = Duration(milliseconds: prefix[index + 1] - prefix[index]);
    _timingCleared = false;
    _surahEnded = ms == prefix.last;
    await (queue as QueuedAudioPlayback).setRepeats(
      _repeatAyah && !_isBasmala,
      _repeatSurah && !(_repeatAyah && _isBasmala),
    );
    if (_disposed || operation != _operation) return;
    _playing = resume;
    if (resume) await _player!.play();
    if (_disposed || operation != _operation) return;
    _emit();
  }

  String? get error => _error;
  bool get repeatAyah => _repeatAyah;
  bool get repeatSurah => _repeatSurah;
  AudioPackage? get selectedPackage {
    for (final p in _packages) {
      if (p.reciterId == _reciterId && p.surah == _surah) return p;
    }
    return null;
  }

  List<AudioPackage> get downloadedPackages =>
      _packages.where((p) => _ready.contains(p.key)).toList(growable: false);
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _selectionGeneration++;
    _operation++;
    _queueGeneration++;
    _cancel?.cancel();
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    unawaited(_player?.dispose() ?? Future<void>.value());
    super.dispose();
  }

  Future<void> initialize() => _initializing ??= _initialize();
  Future<void> _initialize() async {
    try {
      final catalog = await compute(
        _decodeAudioCatalog,
        await _catalogLoader(),
      );
      if (_disposed) return;
      _reciters = catalog.reciters;
      _packages = catalog.packages;
      if (_reciters.any((r) => r.id == 'mp3quran_123')) {
        _reciterId = 'mp3quran_123';
      }
      final directory = await _directory();
      if (_disposed) return;
      _root = Directory('${directory.path}/quran_audio');
      await _root!.create(recursive: true);
      if (_disposed) return;
      final p = selectedPackage;
      if (p != null) await _checkLocal(p);
      _initialized = true;
      _error = null;
    } catch (e) {
      _error = 'Audio initialization failed: $e';
    }
    _emit();
  }

  // Discover verified downloads on demand instead of hashing every surah.
  // Playback still revalidates each local source before loading a fresh queue.
  Future<void> _checkLocal(AudioPackage p) =>
      _localChecks.putIfAbsent(p.key, () async {
        if (_disposed || _root == null) return;
        if (await _validLocal(p)) {
          if (!_disposed) _ready.add(p.key);
        }
        if (_disposed) return;
        final stage = Directory('${_path(p)}.staging');
        if (await stage.exists()) await stage.delete(recursive: true);
        final part = File('${_path(p)}.part');
        if (await part.exists()) await part.delete();
      });

  String _path(AudioPackage p) => '${_root!.path}/${p.key}';
  Future<String> _openingPath(AudioPackage p) async {
    final override = p.openingOverride;
    if (override == null) return '${_path(p)}/${_filename(p.surah, 0)}';
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(override.sha256Hash) ||
        override.durationMs <= 0) {
      throw const FormatException('Invalid opening hash metadata');
    }
    final file = File('${_root!.path}/openings/${override.sha256Hash}.mp3');
    if (await file.exists()) {
      if ((await sha256.bind(file.openRead()).first).toString() !=
          override.sha256Hash) {
        throw const FormatException('Opening asset hash mismatch (cached)');
      }
      return file.path;
    }
    final bytes = await _openingAssetLoader(override.asset);
    if (sha256.convert(bytes).toString() != override.sha256Hash) {
      throw const FormatException('Opening asset hash mismatch');
    }
    await file.parent.create(recursive: true);
    final stage = File('${file.path}.part');
    await stage.writeAsBytes(bytes, flush: true);
    await stage.rename(file.path);
    return file.path;
  }

  Future<String> _preludePath(AudioPackage p, int operation) async {
    void check() {
      if (_disposed || operation != _operation) throw const _Cancelled();
    }

    final prelude = p.openingPrelude!;
    // Validate BOTH the bundled source and any cached copy on each fresh queue.
    final bytes = await _openingAssetLoader(prelude.asset);
    check();
    if (sha256.convert(bytes).toString() != prelude.sha256Hash) {
      throw const FormatException('Prelude asset hash mismatch');
    }
    final file = File('${_root!.path}/openings/${prelude.sha256Hash}.mp3');
    final exists = await file.exists();
    check();
    if (!exists) {
      await file.parent.create(recursive: true);
      check();
      final stage = File('${file.path}.$operation.part');
      try {
        await stage.writeAsBytes(bytes, flush: true);
        check();
        await stage.rename(file.path);
        check();
      } finally {
        if (await stage.exists()) await stage.delete();
      }
    }
    final digest = await sha256.bind(file.openRead()).first;
    check();
    if (digest.toString() != prelude.sha256Hash) {
      throw const FormatException('Prelude cached hash mismatch');
    }
    return file.path;
  }

  String _filename(int s, int a) =>
      '${s.toString().padLeft(3, '0')}${a.toString().padLeft(3, '0')}.mp3';
  Future<bool> _validLocal(AudioPackage p) async {
    if (!p.isPublished || !p.validMetadata || p.files.isEmpty) return false;
    for (var i = 1; !p.isFullSurah && i <= p.ayahCount; i++) {
      if (!p.files.containsKey(_filename(p.surah, i))) return false;
    }
    for (final e in p.files.entries) {
      if (!_safeName(e.key, p)) return false;
      final f = File('${_path(p)}/${e.key}');
      if (!await f.exists() ||
          (await sha256.bind(f.openRead()).first).toString() != e.value) {
        return false;
      }
    }
    return true;
  }

  bool _safeName(String name, AudioPackage p) => p.isFullSurah
      ? name == p.audioFile
      : RegExp(r'^\d{6}\.mp3$').hasMatch(name);

  /// A fresh selection of ayah 1 intentionally starts the surah with its
  /// verified opening (except Fatiha/Tawba). Previous/next target only canonical
  /// ayahs; seek(Duration) and pause/resume retain the current audio source.
  Future<void> selectVerse(int surah, int ayah) async {
    if (_disposed) return;
    final generation = ++_selectionGeneration;
    final previousSurah = _surah, previousAyah = _ayah;
    final known = _packages.where(
      (p) => p.reciterId == _reciterId && p.surah == surah,
    );
    if (surah < 1 ||
        surah > 114 ||
        ayah < 1 ||
        (known.isNotEmpty && ayah > known.first.ayahCount)) {
      _error = 'Invalid verse';
      _emit();
      return;
    }
    _surah = surah;
    _ayah = ayah;
    _playing = false;
    _emit();
    await initialize();
    if (_disposed || generation != _selectionGeneration) return;
    if (!_initialized) return;
    final candidates = _packages.where(
      (p) => p.reciterId == _reciterId && p.surah == surah,
    );
    if (surah < 1 ||
        surah > 114 ||
        ayah < 1 ||
        (candidates.isNotEmpty && ayah > candidates.first.ayahCount)) {
      _surah = previousSurah;
      _ayah = previousAyah;
      _error = 'Invalid verse';
      _emit();
      return;
    }
    await cancelDownload();
    if (_disposed || generation != _selectionGeneration) return;
    await _stop();
    if (_disposed || generation != _selectionGeneration) return;
    final p = selectedPackage;
    if (p != null && _root != null) await _checkLocal(p);
    if (_disposed || generation != _selectionGeneration) return;
    _surah = surah;
    _ayah = ayah;
    _timingCleared = false;
    _error = null;
    _emit();
  }

  Future<void> selectReciter(String id) async {
    final generation = ++_selectionGeneration;
    await initialize();
    if (_disposed || generation != _selectionGeneration) return;
    if (!_reciters.any((r) => r.id == id)) {
      _error = 'Unknown reciter';
      _emit();
      return;
    }
    await cancelDownload();
    if (_disposed || generation != _selectionGeneration) return;
    await _stop();
    if (_disposed || generation != _selectionGeneration) return;
    _reciterId = id;
    final p = selectedPackage;
    if (p != null && _root != null) await _checkLocal(p);
    if (_disposed || generation != _selectionGeneration) return;
    _error = null;
    _emit();
  }

  Future<void> _stop() async {
    _timingCleared = true;
    _surahEnded = false;
    _operation++;
    _queueGeneration++;
    _queueKey = null;
    _playing = false;
    _loadedPath = null;
    _queueOpeningCount = 0;
    _queueIndex = 0;
    _isBasmala = false;
    await _player?.stop();
    _position = Duration.zero;
    _duration = Duration.zero;
  }

  Future<void> downloadSelected() async {
    await initialize();
    if (_downloading) return;
    final p = selectedPackage;
    if (p == null || !canDownload) {
      _error = 'This surah is not available for this reciter.';
      _emit();
      return;
    }
    final cancel = AudioCancellation();
    _cancel = cancel;
    _downloading = true;
    _progress = 0;
    _error = null;
    _emit();
    final task = _download(p, cancel);
    _downloadTask = task;
    await task;
  }

  Future<void> _download(AudioPackage p, AudioCancellation cancel) async {
    final part = File('${_path(p)}.part');
    final stage = Directory('${_path(p)}.staging');
    IOSink? sink;
    try {
      if (p.bytes <= 0 || p.bytes > 128 * 1024 * 1024) {
        throw const FormatException('Archive exceeds safe size limit');
      }
      await part.parent.create(recursive: true);
      sink = part.openWrite();
      var count = 0;
      final uri = Uri.https('drive.google.com', '/uc', {
        'export': 'download',
        'id': p.driveFileId,
      });
      await for (final chunk in _downloader(uri, cancel)) {
        cancel.check();
        count += chunk.length;
        if (count > p.bytes) {
          throw const FormatException(
            'Unexpected archive length / HTML response',
          );
        }
        sink.add(chunk);
        _progress = count / p.bytes;
        _emit();
      }
      await sink.flush();
      await sink.close();
      sink = null;
      cancel.check();
      if (count != p.bytes ||
          (await sha256.bind(part.openRead()).first).toString() !=
              p.sha256Hash) {
        throw const FormatException(
          'Archive is incomplete or SHA256 does not match. Retry download.',
        );
      }
      final archive = ZipDecoder().decodeBytes(
        await part.readAsBytes(),
        verify: true,
      );
      final seen = <String>{};
      var expanded = 0;
      if (await stage.exists()) await stage.delete(recursive: true);
      await stage.create();
      for (final entry in archive) {
        cancel.check();
        // EveryAyah's verified ZIPs also contain this root-level attribution.
        // It is covered by the archive hash, never rendered or sent to a player.
        if (!p.isFullSurah &&
            entry.name == '000_license.html' &&
            entry.isFile &&
            !entry.isSymbolicLink &&
            entry.size < 65536) {
          continue;
        }
        if (!entry.isFile ||
            entry.isSymbolicLink ||
            !_safeName(entry.name, p) ||
            !p.files.containsKey(entry.name) ||
            !seen.add(entry.name)) {
          throw const FormatException('Unsafe or unexpected ZIP entry');
        }
        expanded += entry.size;
        if (entry.size > (p.isFullSurah ? 128 : 32) * 1024 * 1024 ||
            expanded > 256 * 1024 * 1024) {
          throw const FormatException('Expanded archive too large');
        }
        final data = entry.content;
        if (sha256.convert(data).toString() != p.files[entry.name]) {
          throw const FormatException('MP3 checksum mismatch');
        }
        await File('${stage.path}/${entry.name}')
            .writeAsBytes(data, flush: true);
      }
      for (var i = 1; !p.isFullSurah && i <= p.ayahCount; i++) {
        if (!seen.contains(_filename(p.surah, i))) {
          throw const FormatException('Missing verse in archive');
        }
      }
      if (seen.length != p.files.length) {
        throw const FormatException('Incomplete package');
      }
      cancel.check();
      final target = Directory(_path(p));
      if (await target.exists()) await target.delete(recursive: true);
      await stage.rename(target.path);
      _ready.add(p.key);
      _progress = 1;
    } catch (e) {
      if (e is! _Cancelled && !cancel.cancelled) _error = 'Download failed: $e';
    } finally {
      await sink?.close();
      if (await part.exists()) await part.delete();
      if (await stage.exists()) await stage.delete(recursive: true);
      _downloading = false;
      _cancel = null;
      _downloadTask = null;
      if (cancel.cancelled) _progress = 0;
      _emit();
    }
  }

  Future<void> cancelDownload() async {
    _cancel?.cancel();
    _progress = 0;
    _emit();
  }

  Future<void> deleteSelected() async {
    await cancelDownload();
    await _downloadTask;
    await _stop();
    final p = selectedPackage;
    if (p != null && _root != null) {
      _ready.remove(p.key);
      final d = Directory(_path(p));
      if (await d.exists()) await d.delete(recursive: true);
    }
    _emit();
  }

  void _ensurePlayer() {
    if (_player != null) return;
    _player = _playerFactory();
    final queue = _player is QueuedAudioPlayback
        ? _player as QueuedAudioPlayback
        : null;
    if (queue is QueuedAudioPlayback) {
      _subscriptions.add(
        queue.snapshots.listen(
          (s) {
            if (_disposed ||
                !_playing ||
                _queueKey == null ||
                s.generation != _queueGeneration ||
                s.index < 0 ||
                s.index >=
                    (selectedPackage?.ayahCount ?? 0) + _queueOpeningCount) {
              return;
            }
            final wasBasmala = _isBasmala;
            _timingCleared = false;
            _surahEnded = false;
            _queueIndex = s.index;
            _isBasmala = s.index < _queueOpeningCount;
            _ayah = _isBasmala ? 1 : s.index + 1 - _queueOpeningCount;
            _position = s.position;
            _duration = s.duration ?? Duration.zero;
            if (wasBasmala != _isBasmala) _updateRepeats();
            if (s.completed && !_repeatAyah && !_repeatSurah) {
              _surahEnded = true;
              _playing = false;
              _position = _duration;
              _queueKey = null;
              unawaited(_player!.pause());
            }
            _emit();
          },
          onError: (Object error) {
            if (_disposed || _queueKey == null) return;
            _playing = false;
            _queueKey = null;
            _error = 'Playback failed: $error';
            _emit();
          },
        ),
      );
      return;
    }
    _subscriptions.add(
      _player!.completed.listen((_) {
        unawaited(_advance());
      }),
    );
    _subscriptions.add(
      _player!.positions.listen((p) {
        _position = p;
        _emit();
      }),
    );
    _subscriptions.add(
      _player!.durations.listen((d) {
        _duration = d ?? Duration.zero;
        _emit();
      }),
    );
  }

  Future<void> play() => _play();
  Future<void> _play({bool start = true}) async {
    final operation = ++_operation;
    await initialize();
    if (_disposed || operation != _operation) return;
    _timingCleared = false;
    final p = selectedPackage;
    if (start && _surahEnded && p?.openingPrelude != null) {
      // A completed full-surah replay starts the complete queue. A seek to EOF
      // retains its already verified queue rather than loading/hashing again.
      final queue = _player;
      if (_queueKey == p!.key && queue is QueuedAudioPlayback) {
        await (queue as QueuedAudioPlayback).seekIndex(0);
        if (_disposed || operation != _operation) return;
        _queueIndex = 0;
        _isBasmala = true;
      }
      _ayah = 1;
      _position = Duration.zero;
      _duration = Duration.zero;
    }
    _surahEnded = false;
    if (p == null || !isReady) {
      _error = 'Download this surah completely before playback.';
      _playing = false;
      _emit();
      return;
    }
    try {
      _ensurePlayer();
      final queue = _player is QueuedAudioPlayback
          ? _player as QueuedAudioPlayback
          : null;
      if (queue is QueuedAudioPlayback) {
        if (_queueKey != p.key) {
          if (!await _validLocal(p)) {
            _ready.remove(p.key);
            throw const FormatException(
              'Local MP3 missing or corrupt; download again.',
            );
          }
          if (_disposed || operation != _operation) return;
          final generation = ++_queueGeneration;
          // Retain the opening on later-ayah starts for native surah repeat.
          // Old catalogs may omit it: never synthesize or borrow a source.
          final hasBasmala = p.isFullSurah
              ? p.hasOpening
              : p.surah != 1 &&
                    p.surah != 9 &&
                    p.files.containsKey(_filename(p.surah, 0));
          if (p.isFullSurah) {
            if (queue is! ClippedAudioPlayback) {
              throw const FormatException(
                'Player lacks verified local clip support',
              );
            }
            final prelude = p.openingPrelude;
            final preludePath = prelude == null
                ? null
                : await _preludePath(p, operation);
            if (_disposed || operation != _operation) return;
            // Source starts/EOF are immutable. The extra source is PREPENDED,
            // never substituted for the original 0..first-ayah interval.
            final starts = <int>[
              if (p.hasOriginalIntro) 0,
              ...p.verseTimings.map((t) => t['startMs'] as int),
              p.totalDurationMs,
            ];
            await queue.prepareClips(
              [
                if (prelude != null)
                  LocalAudioClip(
                    preludePath!,
                    Duration(milliseconds: prelude.startMs),
                    Duration(milliseconds: prelude.endMs),
                    null,
                  ),
                for (var i = 0; i < starts.length - 1; i++)
                  LocalAudioClip(
                    '${_path(p)}/${p.audioFile}',
                    Duration(milliseconds: starts[i]),
                    Duration(milliseconds: starts[i + 1]),
                    p.hasOriginalIntro && i == 0
                        ? null
                        : i + 1 - (p.hasOriginalIntro ? 1 : 0),
                  ),
              ],
              _ayah == 1 ? 0 : _ayah - 1 + p.openingCount,
              generation,
            );
          } else {
            await queue.prepareQueue(
              [
                if (hasBasmala) await _openingPath(p),
                for (var a = 1; a <= p.ayahCount; a++)
                  '${_path(p)}/${_filename(p.surah, a)}',
              ],
              _ayah == 1 ? 0 : _ayah - 1 + (hasBasmala ? 1 : 0),
              generation,
            );
          }
          if (_disposed || operation != _operation) return;
          _queueKey = p.key;
          _queueOpeningCount = p.openingCount;
          _queueIndex = _ayah == 1 ? 0 : _ayah - 1 + p.openingCount;
          _isBasmala = hasBasmala && _ayah == 1;
          _position = Duration.zero;
          _duration = Duration.zero;
        }
        await queue.setRepeats(
          _repeatAyah && !_isBasmala,
          _repeatSurah && !(_repeatAyah && _isBasmala),
        );
        if (_disposed || operation != _operation) return;
        _playing = start;
        _error = null;
        if (start) await _player!.play();
        _emit();
        return;
      }
      if (p.isFullSurah) {
        throw const FormatException('Player lacks verified local clip support');
      }
      final intro =
          _ayah == 1 &&
          p.surah != 1 &&
          p.surah != 9 &&
          p.files.containsKey(_filename(p.surah, 0)) &&
          (_loadedPath == null || _isBasmala);
      final file = File(
        intro
            ? await _openingPath(p)
            : '${_path(p)}/${_filename(_surah, _ayah)}',
      );
      if (!await file.exists() ||
          (await sha256.bind(file.openRead()).first).toString() !=
              (intro
                  ? (p.openingOverride?.sha256Hash ??
                        p.files[_filename(_surah, 0)])
                  : p.files[_filename(_surah, _ayah)])) {
        _ready.remove(p.key);
        throw const FormatException(
          'Local MP3 missing or corrupt; download again.',
        );
      }
      if (_disposed || operation != _operation) return;
      _isBasmala = intro;
      if (_loadedPath != file.path) {
        await _player!.load(file.path);
        if (_disposed || operation != _operation) return;
        _loadedPath = file.path;
        _position = Duration.zero;
      }
      _playing = true;
      _error = null;
      await _player!.play();
    } catch (e) {
      if (_disposed || operation != _operation) return;
      _playing = false;
      _error = 'Playback failed: $e';
    }
    _emit();
  }

  Future<void> _advance() async {
    if (!_playing) return;
    if (_isBasmala) {
      _isBasmala = false;
      // Sentinel keeps canonical ayah one from restarting its opening.
      _loadedPath = '';
      _position = Duration.zero;
      _duration = Duration.zero;
      await play();
      return;
    }
    if (!_repeatAyah) {
      if (_ayah < (selectedPackage?.ayahCount ?? 0)) {
        _ayah++;
      } else if (_repeatSurah) {
        _ayah = 1;
      } else {
        // Keep the completed final ayah visible at the end of the surah bar.
        _playing = false;
        _position = _duration;
        _surahEnded = true;
        // A subsequent play must reload from the start, not resume at EOF.
        _loadedPath = null;
        await _player?.pause();
        _emit();
        return;
      }
    }
    _loadedPath = _repeatAyah ? '' : null;
    _position = Duration.zero;
    _duration = Duration.zero;
    await play();
  }

  Future<void> pause() async {
    _operation++;
    _playing = false;
    await _player?.pause();
    _emit();
  }

  Future<bool> _queueNavigate(int delta) async {
    final queue = _player is QueuedAudioPlayback
        ? _player as QueuedAudioPlayback
        : null;
    if (queue is! QueuedAudioPlayback || _queueKey == null) return false;
    final resume = _playing;
    final operation = ++_operation;
    _playing = false;
    await _player!.pause();
    if (_disposed || operation != _operation) return true;
    _ayah = (_ayah + delta).clamp(1, selectedPackage!.ayahCount);
    _surahEnded = false;
    _timingCleared = false;
    // Previous/next target canonical ayahs, never the opening. selectVerse(…, 1)
    // intentionally starts a surah; seek(Duration) seeks the current source.
    _isBasmala = false;
    _position = Duration.zero;
    _duration = Duration.zero;
    _queueIndex = _ayah - 1 + _queueOpeningCount;
    await queue.seekIndex(_queueIndex);
    if (_disposed || operation != _operation) return true;
    await queue.setRepeats(_repeatAyah, _repeatSurah);
    if (_disposed || operation != _operation) return true;
    _playing = resume;
    if (resume) await _player!.play();
    _emit();
    return true;
  }

  void _updateRepeats() {
    final queue = _player is QueuedAudioPlayback
        ? _player as QueuedAudioPlayback
        : null;
    if (queue is QueuedAudioPlayback) {
      unawaited(
        queue.setRepeats(
          _repeatAyah && !_isBasmala,
          _repeatSurah && !(_repeatAyah && _isBasmala),
        ),
      );
    }
  }

  Future<void> previous() async {
    if (await _queueNavigate(-1)) return;
    final resume = _playing;
    await _stop();
    if (_ayah > 1) _ayah--;
    _loadedPath = ''; // Canonical navigation never replays an opening.
    if (resume) await play();
    _emit();
  }

  Future<void> next() async {
    if (await _queueNavigate(1)) return;
    final resume = _playing;
    await _stop();
    if (_ayah < (selectedPackage?.ayahCount ?? _ayah)) _ayah++;
    if (resume) await play();
    _emit();
  }

  Future<void> seek(Duration p) async {
    if (p < Duration.zero) p = Duration.zero;
    if (_duration > Duration.zero && p > _duration) p = _duration;
    await _player?.seek(p);
    _position = p;
    _emit();
  }

  void toggleRepeatAyah() {
    _repeatAyah = !_repeatAyah;
    _updateRepeats();
    _emit();
  }

  void toggleRepeatSurah() {
    _repeatSurah = !_repeatSurah;
    _updateRepeats();
    _emit();
  }

  Future<void> close() async {
    _selectionGeneration++;
    await cancelDownload();
    await _stop();
    _emit();
  }

  static Stream<List<int>> _driveDownload(
    Uri uri,
    AudioCancellation cancel,
  ) async* {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    cancel.onCancel = () => client.close(force: true);
    try {
      for (var attempt = 0; attempt < 2; attempt++) {
        cancel.check();
        final request = await client.getUrl(uri);
        final response = await request.close().timeout(
          const Duration(seconds: 45),
        );
        if (response.statusCode != 200) {
          throw HttpException(
            'Google Drive HTTP ${response.statusCode}; retry later or check sharing permissions',
          );
        }
        final type = response.headers.contentType?.mimeType ?? '';
        if (type.contains('html')) {
          final bytes = <int>[];
          await for (final chunk in response) {
            bytes.addAll(chunk);
            if (bytes.length > 1024 * 1024) {
              throw const FormatException('Drive returned HTML, not audio');
            }
          }
          final html = utf8.decode(bytes, allowMalformed: true);
          final action = RegExp(r'<form[^>]*action="([^"]+)"')
              .firstMatch(html)
              ?.group(1);
          if (attempt > 0 || action == null) {
            throw const FormatException(
              'Google Drive download unavailable (quota, permissions or confirmation). Retry later.',
            );
          }
          final next = Uri.parse(action.replaceAll('&amp;', '&'));
          if (next.scheme != 'https' ||
              !{
                'drive.google.com',
                'drive.usercontent.google.com',
              }.contains(next.host)) {
            throw const FormatException('Unsafe Drive confirmation URL');
          }
          final params = <String, String>{...next.queryParameters};
          for (final input in RegExp(r'<input[^>]*>').allMatches(html)) {
            final name = RegExp(r'name="([^"]+)"')
                .firstMatch(input.group(0)!)
                ?.group(1);
            final value = RegExp(r'value="([^"]*)"')
                .firstMatch(input.group(0)!)
                ?.group(1);
            if (name != null && value != null) {
              params[name] = value.replaceAll('&amp;', '&');
            }
          }
          uri = next.replace(queryParameters: params);
          continue;
        }
        yield* response.timeout(const Duration(seconds: 45));
        return;
      }
    } finally {
      cancel.onCancel = null;
      client.close(force: true);
    }
  }
}
