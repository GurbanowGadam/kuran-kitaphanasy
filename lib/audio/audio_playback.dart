import 'dart:async';

import 'package:just_audio/just_audio.dart';

/// One consistent native state sample. [generation] identifies the prepared
/// queue so that late events from a replaced queue can be ignored.
typedef PlaybackSnapshot = ({
  int generation,
  int index,
  Duration position,
  Duration? duration,
  bool completed,
});

/// A lossless interval of a verified local recording.
class LocalAudioClip {
  final String path;
  final Duration start, end;

  /// Canonical ayah number, or null for an opening/intro clip.
  final int? ayah;
  const LocalAudioClip(this.path, this.start, this.end, this.ayah);
}

/// Native gapless clip queue. Injected so tests never touch platform plugins.
abstract class AudioPlayback {
  Stream<PlaybackSnapshot> get snapshots;
  Future<void> prepareClips(
    List<LocalAudioClip> clips,
    int index,
    int generation,
  );
  Future<void> seekIndex(int index);
  Future<void> seek(Duration position);
  Future<void> setRepeats(bool ayah, bool surah);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> dispose();
}

class JustAudioPlayback implements AudioPlayback {
  JustAudioPlayback() {
    // Every update reads one PlaybackEvent: never combine a new index with an
    // independently delivered old duration/position stream value.
    _subscriptions
      ..add(
        _player.playbackEventStream.listen(
          (_) => _snapshot(),
          onError: _snapshots.addError,
        ),
      )
      ..add(_player.currentIndexStream.listen((_) => _snapshot()))
      ..add(_player.positionStream.listen((_) => _snapshot()))
      ..add(_player.errorStream.listen(_snapshots.addError));
  }

  final AudioPlayer _player = AudioPlayer(useLazyPreparation: false);
  final _snapshots = StreamController<PlaybackSnapshot>.broadcast(sync: true);
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  int _generation = -1;

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
  Stream<PlaybackSnapshot> get snapshots => _snapshots.stream;

  @override
  Future<void> prepareClips(
    List<LocalAudioClip> clips,
    int index,
    int generation,
  ) async {
    _generation = -1;
    await _player.setAudioSources(
      [
        for (final clip in clips)
          ClippingAudioSource(
            child: AudioSource.file(clip.path),
            start: clip.start,
            end: clip.end,
          ),
      ],
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
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setRepeats(bool ayah, bool surah) => _player.setLoopMode(
    ayah
        ? LoopMode.one
        : surah
        ? LoopMode.all
        : LoopMode.off,
  );

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
  Future<void> dispose() async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    await _snapshots.close();
    await _player.dispose();
  }
}
