import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'audio_catalog.dart';
import 'audio_download.dart';
import 'audio_failure.dart';
import 'audio_playback.dart';

export 'audio_catalog.dart';
export 'audio_download.dart' show AudioCancellation, AudioDownload;
export 'audio_failure.dart';
export 'audio_playback.dart';

/// Download-first, persistent local-file audio for full-surah recordings.
///
/// Owns selection, download state and the native clip queue. Catalog parsing,
/// verified installation and the native player live in sibling files.
/// Constructors never touch plugins; every dependency is injectable.
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
       _playerFactory = playerFactory ?? JustAudioPlayback.new,
       _downloader = downloader ?? driveDownload,
       _openingAssetLoader =
           openingAssetLoader ??
           ((asset) async =>
               (await rootBundle.load(asset)).buffer.asUint8List());

  static const defaultReciterId = 'mp3quran_123';

  final Future<List<int>> Function(String asset) _openingAssetLoader;
  final Future<Directory> Function() _directory;
  final Future<String> Function() _catalogLoader;
  final AudioPlayback Function() _playerFactory;
  final AudioDownload _downloader;

  Directory? _root;
  AudioPlayback? _player;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  List<AudioReciter> _reciters = [];
  List<AudioPackage> _packages = [];
  final Set<String> _ready = {};
  final Map<String, Future<void>> _localChecks = {};

  // Generation counters reject stale async continuations and native events.
  int _selectionGeneration = 0, _operation = 0, _queueGeneration = 0;

  String? _queueKey;
  int _queueOpeningCount = 0, _queueIndex = 0;
  bool _isBasmala = false;

  String _reciterId = defaultReciterId;
  int _surah = 1, _ayah = 1;
  bool _playing = false,
      _downloading = false,
      _disposed = false,
      _repeatAyah = false,
      _repeatSurah = false,
      _initialized = false,
      _timingCleared = true,
      _surahEnded = false;
  double _progress = 0;
  Duration _position = Duration.zero, _duration = Duration.zero;
  AudioFailure? _failure;
  String? _errorDetail;
  Future<void>? _initializing, _downloadTask;
  AudioCancellation? _cancel;

  List<AudioReciter> get reciters => List.unmodifiable(_reciters);
  String get reciterId => _reciterId;
  int get surah => _surah;
  int get ayah => _ayah;
  bool get isPlaying => _playing;

  /// The explicit same-reciter besmele prelude is playing; [ayah] stays 1.
  bool get isBasmala =>
      _isBasmala &&
      selectedPackage?.openingPrelude != null &&
      _queueKey != null &&
      _queueIndex == 0;

  /// Any unnumbered opening (prelude or original intro) is playing.
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

  /// Türkmen message for the current failure, safe to show to the user.
  String? get error => _failure?.message;
  AudioFailure? get failure => _failure;

  /// Technical cause of [failure]; for logs and tests, never for the UI.
  String? get errorDetail => _errorDetail;
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

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  void _fail(AudioFailure failure, [Object? detail]) {
    _failure = failure;
    _errorDetail = detail?.toString() ?? failure.name;
    debugPrint('Audio ${failure.name}: $_errorDetail');
  }

  void _clearFailure() {
    _failure = null;
    _errorDetail = null;
  }

  bool _stale(int operation) => _disposed || operation != _operation;

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
      final catalog = await compute(decodeAudioCatalog, await _catalogLoader());
      if (_disposed) return;
      _reciters = catalog.reciters;
      _packages = catalog.packages;
      if (!_reciters.any((r) => r.id == _reciterId) && _reciters.isNotEmpty) {
        _reciterId = _reciters.first.id;
      }
      final directory = await _directory();
      if (_disposed) return;
      _root = Directory('${directory.path}/quran_audio');
      await _root!.create(recursive: true);
      if (_disposed) return;
      final p = selectedPackage;
      if (p != null) await _checkLocal(p);
      _initialized = true;
      _clearFailure();
    } catch (e) {
      _fail(AudioFailure.initialization, e);
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

  Future<bool> _validLocal(AudioPackage p) async {
    if (!p.isPublished || !p.validMetadata) return false;
    for (final e in p.files.entries) {
      if (e.key != p.audioFile) return false;
      final f = File('${_path(p)}/${e.key}');
      if (!await f.exists() || await sha256OfFile(f) != e.value) return false;
    }
    return true;
  }

  Future<String> _preludePath(AudioPackage p, int operation) async {
    void check() {
      if (_stale(operation)) throw const AudioCancelled();
    }

    final prelude = p.openingPrelude!;
    // Validate BOTH the bundled source and any cached copy on each fresh queue.
    final bytes = await _openingAssetLoader(prelude.asset);
    check();
    if (sha256.convert(bytes).toString() != prelude.sha256Hash) {
      throw const AudioException(
        AudioFailure.playback,
        'Prelude asset hash mismatch',
      );
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
    final digest = await sha256OfFile(file);
    check();
    if (digest != prelude.sha256Hash) {
      throw const AudioException(
        AudioFailure.localCorrupt,
        'Prelude cached hash mismatch',
      );
    }
    return file.path;
  }

  /// A fresh selection of ayah 1 intentionally starts the surah with its
  /// verified opening (except Fatiha/Tawba). Previous/next target only canonical
  /// ayahs; seek(Duration) and pause/resume retain the current audio source.
  Future<void> selectVerse(int surah, int ayah) async {
    if (_disposed) return;
    final generation = ++_selectionGeneration;
    final previousSurah = _surah, previousAyah = _ayah;
    bool invalid() {
      final known = _packages.where(
        (p) => p.reciterId == _reciterId && p.surah == surah,
      );
      return surah < 1 ||
          surah > 114 ||
          ayah < 1 ||
          (known.isNotEmpty && ayah > known.first.ayahCount);
    }

    if (invalid()) {
      _fail(AudioFailure.invalidSelection, '$surah:$ayah');
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
    if (invalid()) {
      _surah = previousSurah;
      _ayah = previousAyah;
      _fail(AudioFailure.invalidSelection, '$surah:$ayah');
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
    _clearFailure();
    _emit();
  }

  Future<void> selectReciter(String id) async {
    final generation = ++_selectionGeneration;
    await initialize();
    if (_disposed || generation != _selectionGeneration) return;
    if (!_reciters.any((r) => r.id == id)) {
      _fail(AudioFailure.unknownReciter, id);
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
    _clearFailure();
    _emit();
  }

  Future<void> _stop() async {
    _timingCleared = true;
    _surahEnded = false;
    _operation++;
    _queueGeneration++;
    _queueKey = null;
    _playing = false;
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
      _fail(AudioFailure.unavailable, '$_reciterId/$_surah');
      _emit();
      return;
    }
    final cancel = AudioCancellation();
    _cancel = cancel;
    _downloading = true;
    _progress = 0;
    _clearFailure();
    _emit();
    final task = _download(p, cancel);
    _downloadTask = task;
    await task;
  }

  Future<void> _download(AudioPackage p, AudioCancellation cancel) async {
    try {
      await installAudioPackage(
        package: p,
        targetPath: _path(p),
        download: _downloader,
        cancel: cancel,
        onProgress: (value) {
          _progress = value;
          _emit();
        },
      );
      _ready.add(p.key);
      _progress = 1;
    } on AudioCancelled {
      // User cancellation is not an error.
    } on AudioException catch (e) {
      if (!cancel.cancelled) _fail(e.failure, e.detail);
    } catch (e) {
      if (!cancel.cancelled) _fail(AudioFailure.integrity, e);
    } finally {
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

  AudioPlayback _ensurePlayer() {
    final existing = _player;
    if (existing != null) return existing;
    final player = _player = _playerFactory();
    _subscriptions.add(
      player.snapshots.listen(
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
            unawaited(player.pause());
          }
          _emit();
        },
        onError: (Object error) {
          if (_disposed || _queueKey == null) return;
          _playing = false;
          _queueKey = null;
          _fail(AudioFailure.playback, error);
          _emit();
        },
      ),
    );
    return player;
  }

  Future<void> play() => _play();
  Future<void> _play({bool start = true}) async {
    final operation = ++_operation;
    await initialize();
    if (_stale(operation)) return;
    _timingCleared = false;
    final p = selectedPackage;
    if (start && _surahEnded && p?.openingPrelude != null) {
      // A completed surah replay starts the complete queue. A seek to EOF
      // retains its already verified queue rather than loading/hashing again.
      final player = _player;
      if (_queueKey == p!.key && player != null) {
        await player.seekIndex(0);
        if (_stale(operation)) return;
        _queueIndex = 0;
        _isBasmala = true;
      }
      _ayah = 1;
      _position = Duration.zero;
      _duration = Duration.zero;
    }
    _surahEnded = false;
    if (p == null || !isReady) {
      _fail(AudioFailure.notDownloaded);
      _playing = false;
      _emit();
      return;
    }
    try {
      final player = _ensurePlayer();
      if (_queueKey != p.key) {
        if (!await _validLocal(p)) {
          _ready.remove(p.key);
          throw const AudioException(
            AudioFailure.localCorrupt,
            'Local MP3 missing or corrupt',
          );
        }
        if (_stale(operation)) return;
        final generation = ++_queueGeneration;
        final prelude = p.openingPrelude;
        final preludePath = prelude == null
            ? null
            : await _preludePath(p, operation);
        if (_stale(operation)) return;
        // Source starts/EOF are immutable. The prelude is PREPENDED, never
        // substituted for the original 0..first-ayah interval.
        final starts = <int>[
          if (p.hasOriginalIntro) 0,
          ...p.verseTimings.map((t) => t['startMs'] as int),
          p.totalDurationMs,
        ];
        final initial = _ayah == 1 ? 0 : _ayah - 1 + p.openingCount;
        await player.prepareClips(
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
          initial,
          generation,
        );
        if (_stale(operation)) return;
        _queueKey = p.key;
        _queueOpeningCount = p.openingCount;
        _queueIndex = initial;
        _isBasmala = p.hasOpening && _ayah == 1;
        _position = Duration.zero;
        _duration = Duration.zero;
      }
      await player.setRepeats(
        _repeatAyah && !_isBasmala,
        _repeatSurah && !(_repeatAyah && _isBasmala),
      );
      if (_stale(operation)) return;
      _playing = start;
      _clearFailure();
      if (start) await player.play();
    } on AudioCancelled {
      return;
    } catch (e) {
      if (_stale(operation)) return;
      _playing = false;
      if (e is AudioException) {
        _fail(e.failure, e.detail);
      } else {
        _fail(AudioFailure.playback, e);
      }
    }
    _emit();
  }

  /// Seek on the verified complete local queue, retaining playback intent.
  Future<void> seekSurah(Duration target) async {
    await initialize();
    if (!hasSurahTiming || !isReady || _disposed) return;
    final resume = _playing;
    if (_queueKey == null) {
      await _play(start: false);
      if (_queueKey == null || _disposed) return;
    }
    final player = _player!;
    final operation = ++_operation;
    _playing = false; // Reject transient old-source native snapshots.
    await player.pause();
    if (_stale(operation)) return;
    final prefix = selectedPackage!.timingPrefix;
    final ms = target.inMilliseconds.clamp(0, prefix.last);
    var index = 0;
    while (index + 1 < prefix.length - 1 && ms >= prefix[index + 1]) {
      index++;
    }
    final local = Duration(milliseconds: ms - prefix[index]);
    await player.seekIndex(index);
    if (_stale(operation)) return;
    await player.seek(local);
    if (_stale(operation)) return;
    _queueIndex = index;
    _isBasmala = index < _queueOpeningCount;
    _ayah = _isBasmala ? 1 : index + 1 - _queueOpeningCount;
    _position = local;
    _duration = Duration(milliseconds: prefix[index + 1] - prefix[index]);
    _timingCleared = false;
    _surahEnded = ms == prefix.last;
    await player.setRepeats(
      _repeatAyah && !_isBasmala,
      _repeatSurah && !(_repeatAyah && _isBasmala),
    );
    if (_stale(operation)) return;
    _playing = resume;
    if (resume) await player.play();
    if (_stale(operation)) return;
    _emit();
  }

  Future<void> pause() async {
    _operation++;
    _playing = false;
    await _player?.pause();
    _emit();
  }

  /// Previous/next target canonical ayahs, never the opening.
  Future<void> _navigate(int delta) async {
    final player = _player;
    final count = selectedPackage?.ayahCount ?? _ayah;
    if (player == null || _queueKey == null) {
      final resume = _playing;
      await _stop();
      _ayah = (_ayah + delta).clamp(1, count);
      if (resume) await play();
      _emit();
      return;
    }
    final resume = _playing;
    final operation = ++_operation;
    _playing = false;
    await player.pause();
    if (_stale(operation)) return;
    _ayah = (_ayah + delta).clamp(1, count);
    _surahEnded = false;
    _timingCleared = false;
    _isBasmala = false;
    _position = Duration.zero;
    _duration = Duration.zero;
    _queueIndex = _ayah - 1 + _queueOpeningCount;
    await player.seekIndex(_queueIndex);
    if (_stale(operation)) return;
    await player.setRepeats(_repeatAyah, _repeatSurah);
    if (_stale(operation)) return;
    _playing = resume;
    if (resume) await player.play();
    _emit();
  }

  Future<void> previous() => _navigate(-1);
  Future<void> next() => _navigate(1);

  Future<void> seek(Duration p) async {
    if (p < Duration.zero) p = Duration.zero;
    if (_duration > Duration.zero && p > _duration) p = _duration;
    await _player?.seek(p);
    _position = p;
    _emit();
  }

  void _updateRepeats() {
    unawaited(
      _player?.setRepeats(
        _repeatAyah && !_isBasmala,
        _repeatSurah && !(_repeatAyah && _isBasmala),
      ),
    );
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
}
