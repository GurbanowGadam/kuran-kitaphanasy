import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/about_dialog.dart';
import '../audio/quran_audio_controller.dart';
import '../trackers/data/tracker_book.dart';
import '../trackers/domain/tracker.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.dark,
    required this.setDark,
    required this.trackers,
    required this.audio,
    required this.surahNames,
  });

  final bool dark;
  final ValueChanged<bool> setDark;
  final TrackerBook trackers;
  final QuranAudioController Function() audio;
  final Future<Map<int, String>> Function() surahNames;

  void snack(BuildContext context, String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  /// Hasaplar may not have been opened yet; never export or replace a list
  /// that failed to load.
  Future<bool> ensureTrackers(BuildContext context) async {
    if (trackers.state != TrackerBookState.ready) await trackers.load();
    if (trackers.state == TrackerBookState.ready) return true;
    if (context.mounted) snack(context, 'Hasaplary okap bolmady.');
    return false;
  }

  Future<void> export(BuildContext context) async {
    if (!await ensureTrackers(context) || !context.mounted) return;
    try {
      await Clipboard.setData(ClipboardData(text: trackers.exportJson()));
      if (context.mounted) {
        snack(
          context,
          '${trackers.trackers.length} hasap bufere göçürildi. '
          'Ony ygtybarly ýere (meselem, özüňize hat) goýuň.',
        );
      }
    } catch (_) {
      if (context.mounted) snack(context, 'Bufere göçürip bolmady.');
    }
  }

  Future<void> import(BuildContext context) async {
    if (!await ensureTrackers(context) || !context.mounted) return;
    final parsed = await showDialog<List<Tracker>>(
      context: context,
      builder: (_) => const _ImportDialog(),
    );
    if (parsed == null || !context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hasaplar çalşyrylsynmy?'),
        content: Text(
          'Häzirki ${trackers.trackers.length} hasap ätiýaçlyk nusgadaky '
          '${parsed.length} hasap bilen çalşyrylar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Ýatyr'),
          ),
          FilledButton(
            key: const Key('import-replace'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Çalyş'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    trackers.replaceWith(parsed);
    snack(context, 'Hasaplar dikeldildi.');
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: colors.primary,
        ),
      ),
    );
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.settings_outlined,
                        color: colors.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Sazlamalar',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: colors.outlineVariant),
                header('Görnüş'),
                SwitchListTile(
                  key: const Key('settings-dark'),
                  secondary: Icon(
                    dark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                  ),
                  title: const Text('Garaňky görnüş'),
                  value: dark,
                  onChanged: setDark,
                ),
                header('Sesler'),
                ListTile(
                  key: const Key('settings-audio'),
                  leading: const Icon(Icons.library_music_outlined),
                  title: const Text('Ýüklenen sesler'),
                  subtitle: const Text('Göwrümini görüň we gereksizini pozuň'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          DownloadsPage(audio: audio(), surahNames: surahNames),
                    ),
                  ),
                ),
                header('Hasaplar'),
                ListTile(
                  key: const Key('settings-export'),
                  leading: const Icon(Icons.copy_all_outlined),
                  title: const Text('Hasaplary göçür'),
                  subtitle: const Text(
                    'Ätiýaçlyk nusgany tekst görnüşinde bufere göçürýär',
                  ),
                  onTap: () => export(context),
                ),
                ListTile(
                  key: const Key('settings-import'),
                  leading: const Icon(Icons.restore_outlined),
                  title: const Text('Hasaplary dikelt'),
                  subtitle: const Text('Göçürilen ätiýaçlyk nusgany goýuň'),
                  onTap: () => import(context),
                ),
                header('Programma'),
                ListTile(
                  key: const Key('source-about'),
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Çeşmeler we programma barada'),
                  subtitle: const Text('Gizlinlik, ygtyýarnamalar, wersiýa'),
                  onTap: () => showAboutSources(context),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ImportDialog extends StatefulWidget {
  const _ImportDialog();
  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  final text = TextEditingController();
  String? error;

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  Future<void> paste() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (mounted && data?.text != null) {
        setState(() => text.text = data!.text!);
      }
    } catch (_) {
      if (mounted) setState(() => error = 'Buferi okap bolmady.');
    }
  }

  void submit() {
    try {
      Navigator.pop(context, TrackerBook.parseBackup(text.text));
    } catch (_) {
      setState(() => error = 'Ätiýaçlyk nusga nädogry. Hiç zat üýtgedilmedi.');
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Hasaplary dikelt'),
    content: SizedBox(
      width: 480,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('import-field'),
            controller: text,
            minLines: 3,
            maxLines: 6,
            decoration: InputDecoration(
              hintText: 'Göçürilen teksti şu ýere goýuň',
              errorText: error,
              errorMaxLines: 3,
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: const Key('import-paste'),
              onPressed: paste,
              icon: const Icon(Icons.content_paste),
              label: const Text('Buferden goý'),
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Ýatyr'),
      ),
      FilledButton(
        key: const Key('import-confirm'),
        onPressed: submit,
        child: const Text('Dikelt'),
      ),
    ],
  );
}

String _size(int bytes) {
  final mb = bytes / (1024 * 1024);
  return mb >= 100 ? '${mb.round()} MB' : '${mb.toStringAsFixed(1)} MB';
}

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({
    super.key,
    required this.audio,
    required this.surahNames,
  });
  final QuranAudioController audio;
  final Future<Map<int, String>> Function() surahNames;

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  late Future<List<({AudioPackage package, int bytes})>> scan;
  Map<int, String> names = const {};

  @override
  void initState() {
    super.initState();
    scan = widget.audio.scanDownloads();
    widget
        .surahNames()
        .then((n) {
          if (mounted) setState(() => names = n);
        })
        .catchError((Object _) {});
  }

  // A block body: a setState callback must not return the Future.
  void rescan() => setState(() {
    scan = widget.audio.scanDownloads();
  });

  Future<void> delete(AudioPackage p, String title) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ses pozulsynmy?'),
        content: Text(
          '$title enjamdan pozular. Gerek bolsa täzeden ýükläp bolýar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Ýatyr'),
          ),
          FilledButton(
            key: const Key('download-delete-confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Poz'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.audio.deletePackage(p);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AudioFailure.storage.message)));
      }
    }
    if (mounted) rescan();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ýüklenen sesler')),
    body: SafeArea(
      child: FutureBuilder(
        future: scan,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final error = snapshot.error;
            return Center(
              key: const Key('downloads-error'),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      error is AudioException
                          ? error.failure.message
                          : AudioFailure.initialization.message,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: rescan,
                      child: const Text('Täzeden synanyş'),
                    ),
                  ],
                ),
              ),
            );
          }
          final found = snapshot.data!;
          if (found.isEmpty) {
            return const Center(
              key: Key('downloads-empty'),
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Entek ýüklenen ses ýok. Süräni okaýan wagtyňyz '
                  'ses düwmesinden ýükläp bilersiňiz.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final reciters = {
            for (final r in widget.audio.reciters) r.id: r.name,
          };
          final total = found.fold(0, (a, f) => a + f.bytes);
          return ListView(
            children: [
              ListTile(
                key: const Key('downloads-total'),
                title: Text('Jemi: ${found.length} süre · ${_size(total)}'),
              ),
              const Divider(height: 1),
              for (final f in found)
                Builder(
                  builder: (context) {
                    final p = f.package;
                    final title =
                        '${p.surah}. ${names[p.surah] ?? 'Süre ${p.surah}'}';
                    return ListTile(
                      key: Key('download-${p.reciterId}-${p.surah}'),
                      title: Text(title),
                      subtitle: Text(
                        '${reciters[p.reciterId] ?? p.reciterId} · ${_size(f.bytes)}',
                      ),
                      trailing: IconButton(
                        key: Key('download-delete-${p.reciterId}-${p.surah}'),
                        tooltip: 'Poz',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => delete(p, title),
                      ),
                    );
                  },
                ),
            ],
          );
        },
      ),
    ),
  );
}
