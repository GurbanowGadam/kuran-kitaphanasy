part of 'reader.dart';

extension _ReaderAudio on _ReaderState {
  Future<void> openAudio(int surah, int ayah) async {
    if (audioOpening) return;
    final generation = ++audioOpenGeneration;
    audioOpening = true;
    audioTargetSurah = surah;
    audioTargetAyah = ayah;
    final controller = audio ??=
        widget.audioController ?? QuranAudioController();
    controller.removeListener(audioChanged);
    controller.addListener(audioChanged);
    setStateAudio(true);
    try {
      await audioClosing;
      if (!mounted || !widget.active || generation != audioOpenGeneration) {
        return;
      }
      // selectVerse publishes the target before its own initialization; never
      // initialize/verify the default Fatiha package ahead of the requested one.
      final selection = controller.selectVerse(surah, ayah);
      await Future.wait([
        selection,
        audioInitialization ??= controller.initialize(),
      ]);
    } catch (error) {
      if (mounted && generation == audioOpenGeneration) {
        audioUiError = 'Ses açylmady: $error';
      }
    } finally {
      if (mounted && generation == audioOpenGeneration) {
        setStateAudioOpening(false);
        audioChanged();
      }
    }
  }

  Future<void> audioAction(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (mounted) {
        audioUiError = 'Ses: $error';
        audioChanged();
      }
    }
  }

  void closeAudio() {
    audioOpenGeneration++;
    audioOpening = false;
    setStateAudio(false);
    if (audio != null) {
      audioClosing = audioAction(audio!.close);
      unawaited(audioClosing!);
    }
  }

  Widget audioPanel(ReaderData data) {
    final a = audio!;
    final surah = audioOpening ? audioTargetSurah : a.surah;
    final ayah = audioOpening ? audioTargetAyah : a.ayah;
    final count = audioOpening ? 0 : a.selectedPackage?.ayahCount ?? 0;
    final ready = !audioOpening && a.isReady;
    final timed =
        !audioOpening && a.hasSurahTiming && a.surahDuration > Duration.zero;
    final total = timed ? a.surahDuration.inMilliseconds.toDouble() : 1.0;
    final progress = timed
        ? a.surahPosition.inMilliseconds.toDouble().clamp(0.0, total)
        : 0.0;
    Widget control(
      String key,
      String tooltip,
      IconData icon,
      VoidCallback? action, {
      bool selected = false,
    }) => SizedBox(
      width: 48,
      height: 48,
      child: IconButton(
        key: Key(key),
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        color: selected ? readerTheme.colorScheme.primary : null,
        onPressed: action,
        icon: Icon(icon, size: key == 'audio-play' ? 22 : 20),
      ),
    );
    return Material(
      key: const Key('audio-panel'),
      color: readerTheme.colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${data.names[surah] ?? surah} · ${!audioOpening && a.isBasmala
                  ? 'Besmele'
                  : !audioOpening && a.isOpening
                  ? 'Başlangyç'
                  : 'Aýat $ayah${count > 0 ? '/$count' : ''}'}',
              style: const TextStyle(fontSize: 11, height: 1.1),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            if (audioOpening) const LinearProgressIndicator(),
            if (!audioOpening && a.isPending)
              const Text(
                'Sesler ýüklemäge taýýarlanýar',
                key: Key('audio-pending'),
              ),
            if (!audioOpening && !a.isSupported)
              const Text(
                'Bu süre üçin ses elýeterli däl.',
                key: Key('audio-unavailable'),
              ),
            if (audioUiError ?? a.error case final String message)
              Text(
                message,
                key: const Key('audio-error'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            if (!audioOpening && a.isDownloading) ...[
              LinearProgressIndicator(
                key: const Key('audio-download-progress'),
                value: a.downloadProgress.clamp(0, 1),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${(a.downloadProgress.clamp(0, 1) * 100).round()}%'),
                  TextButton(
                    key: const Key('audio-cancel'),
                    onPressed: () => audioAction(a.cancelDownload),
                    child: const Text('Ýatyr'),
                  ),
                ],
              ),
            ] else if (!audioOpening && a.canDownload && !a.isReady)
              TextButton.icon(
                key: const Key('audio-download'),
                onPressed: () => audioAction(a.downloadSelected),
                icon: const Icon(Icons.download),
                label: const Text('Süräni ýükle'),
              ),
            if (ready && count > 0)
              Row(
                children: [
                  _SurahAudioClock(
                    clockKey: 'audio-position',
                    time: timed ? a.surahPosition : null,
                    description: 'Süräniň geçen wagty',
                  ),
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: _SurahAudioSeek(
                        key: ValueKey('${a.reciterId}/${a.surah}'),
                        total: total,
                        enabled: timed,
                        progress: progress,
                        ayah: a.ayah,
                        playing: a.isPlaying,
                        seek: (time) => audioAction(() => a.seekSurah(time)),
                      ),
                    ),
                  ),
                  _SurahAudioClock(
                    clockKey: 'audio-duration',
                    time: timed ? a.surahDuration : null,
                    description: 'Süräniň dowamlylygy',
                  ),
                ],
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                control(
                  'audio-reciter',
                  'Käri saýla · ${a.reciters.where((r) => r.id == a.reciterId).map((r) => r.name).join()}',
                  Icons.record_voice_over_outlined,
                  audioOpening || a.reciters.isEmpty
                      ? null
                      : () => showModalBottomSheet<void>(
                          context: context,
                          builder: (context) => Theme(
                            data: readerTheme,
                            child: Material(
                              color: readerTheme.colorScheme.surface,
                              child: SafeArea(
                                child: ListView(
                                  shrinkWrap: true,
                                  children: [
                                    const ListTile(title: Text('Käri saýla')),
                                    for (final r in a.reciters)
                                      ListTile(
                                        title: Text(r.name),
                                        selected: r.id == a.reciterId,
                                        trailing: r.id == a.reciterId
                                            ? const Icon(Icons.check)
                                            : null,
                                        onTap: () {
                                          Navigator.pop(context);
                                          unawaited(
                                            audioAction(
                                              () => a.selectReciter(r.id),
                                            ),
                                          );
                                        },
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
                control(
                  'audio-previous',
                  'Öňki aýat',
                  Icons.skip_previous,
                  ready ? () => audioAction(a.previous) : null,
                ),
                control(
                  'audio-play',
                  a.isPlaying ? 'Sakla' : 'Diňle',
                  a.isPlaying
                      ? Icons.pause_circle_outline
                      : Icons.play_circle_outline,
                  ready
                      ? () => audioAction(a.isPlaying ? a.pause : a.play)
                      : null,
                ),
                control(
                  'audio-next',
                  'Indiki aýat',
                  Icons.skip_next,
                  ready ? () => audioAction(a.next) : null,
                ),
                control(
                  'audio-repeat-surah',
                  'Süräni gaýtala',
                  Icons.repeat,
                  audioOpening ? null : a.toggleRepeatSurah,
                  selected: a.repeatSurah,
                ),

                control('audio-close', 'Sesi ýap', Icons.close, closeAudio),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Measured whole-surah time; absent metadata is explicitly unknown.
class _SurahAudioClock extends StatelessWidget {
  const _SurahAudioClock({
    required this.clockKey,
    required this.time,
    required this.description,
  });

  final String clockKey;
  final Duration? time;
  final String description;

  @override
  Widget build(BuildContext context) {
    final seconds = (time?.inSeconds ?? 0).clamp(0, 1 << 53);
    final text = time == null
        ? '--:--'
        : '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
    return SizedBox(
      width: 46,
      child: Text(
        text,
        key: Key(clockKey),
        semanticsLabel: '$description: $text',
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3),
        style: const TextStyle(fontSize: 10, height: 1),
        maxLines: 1,
      ),
    );
  }
}

/// Measured duration-weighted surah timeline. A drag commits one timestamp.
class _SurahAudioSeek extends StatefulWidget {
  const _SurahAudioSeek({
    super.key,
    required this.total,
    required this.enabled,
    required this.progress,
    required this.ayah,
    required this.playing,
    required this.seek,
  });
  final double total;
  final bool enabled;
  final double progress;
  final int ayah;
  final bool playing;
  final Future<void> Function(Duration) seek;
  @override
  State<_SurahAudioSeek> createState() => _SurahAudioSeekState();
}

class _SurahAudioSeekState extends State<_SurahAudioSeek>
    with SingleTickerProviderStateMixin {
  double? draft;
  bool seeking = false;
  late final AnimationController samples;
  late double from;
  late double to;
  double get displayed => from + (to - from) * samples.value;

  @override
  void initState() {
    super.initState();
    from = to = widget.progress;
    samples = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
      value: 1,
    )..addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(covariant _SurahAudioSeek oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Interpolate observed samples only; never extrapolate a playback clock.
    // Atomic next-ayah samples start at the boundary (duration may be unknown),
    // not at the previous ayah's late fractional position. Backwards seeks,
    // repeats and nonadjacent navigation must reset rather than be clamped.
    final adjacent =
        widget.ayah == oldWidget.ayah || widget.ayah == oldWidget.ayah + 1;
    if (!widget.enabled ||
        widget.total != oldWidget.total ||
        !widget.playing ||
        draft != null ||
        seeking ||
        !adjacent ||
        widget.progress < oldWidget.progress) {
      samples.stop();
      from = to = widget.progress;
      samples.value = 1;
    } else if (widget.progress != oldWidget.progress) {
      from = displayed;
      to = widget.progress;
      samples.forward(from: 0);
    }
  }

  @override
  void dispose() {
    samples.dispose();
    super.dispose();
  }

  Duration target(double value) => Duration(milliseconds: value.round());
  String label(double value) {
    final seconds = target(value).inSeconds;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => Tooltip(
    message: widget.enabled
        ? 'Süräniň wagty boýunça geç'
        : 'Süräniň wagty elýeterli däl',
    child: Slider(
      key: const Key('audio-seek'),
      value: (draft ?? displayed).clamp(0.0, widget.total),
      max: widget.total,
      label: label(draft ?? displayed),
      semanticFormatterCallback: (value) => widget.enabled
          ? 'Süräniň wagty: ${label(value)} / ${label(widget.total)}'
          : 'Süräniň wagty elýeterli däl',
      onChanged: seeking || !widget.enabled
          ? null
          : (value) => setState(() => draft = value),
      onChangeEnd: seeking || !widget.enabled
          ? null
          : (value) async {
              setState(() {
                seeking = true;
                draft = value;
              });
              try {
                await widget.seek(target(value));
              } finally {
                if (mounted) {
                  setState(() {
                    seeking = false;
                    draft = null;
                  });
                }
              }
            },
    ),
  );
}
