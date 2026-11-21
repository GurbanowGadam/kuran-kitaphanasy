import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/tracker.dart';

/// Raw text storage. Unlike the reader preference store it never hides a read
/// failure as "nothing saved": that would let an empty list overwrite data.
abstract interface class TrackerStore {
  Future<String?> load();
  Future<void> save(String value);
}

class MemoryTrackerStore implements TrackerStore {
  MemoryTrackerStore([this.value]);
  String? value;
  int saves = 0;
  @override
  Future<String?> load() async => value;
  @override
  Future<void> save(String v) async {
    saves++;
    value = v;
  }
}

class SharedPreferencesTrackerStore implements TrackerStore {
  static const key = 'kuran_kitaphanasy.trackers';
  @override
  Future<String?> load() async =>
      (await SharedPreferences.getInstance()).getString(key);
  @override
  Future<void> save(String value) async {
    final ok = await (await SharedPreferences.getInstance()).setString(
      key,
      value,
    );
    if (!ok) throw StateError('Trackers could not be saved');
  }
}

enum TrackerBookState { loading, ready, failed }

/// All trackers plus serialized persistence. While loading failed the book is
/// read-only, so a corrupt save is kept for a retry instead of being replaced.
class TrackerBook extends ChangeNotifier {
  TrackerBook({required this.store, DateTime Function()? clock})
    : clock = clock ?? DateTime.now;

  final TrackerStore store;
  final DateTime Function() clock;

  TrackerBookState _state = TrackerBookState.loading;
  List<Tracker> _trackers = const [];
  bool _saveFailed = false, _writing = false, _dirty = false, _disposed = false;
  Future<void>? _loading, _flush;
  int _ids = 0;

  TrackerBookState get state => _state;
  List<Tracker> get trackers => _trackers;
  bool get saveFailed => _saveFailed;

  Future<void> load() => _loading ??= _load();
  Future<void> _load() async {
    _state = TrackerBookState.loading;
    _emit();
    try {
      final raw = await store.load();
      _trackers = raw == null
          ? const []
          : List.unmodifiable(decodeTrackers(jsonDecode(raw)));
      _state = TrackerBookState.ready;
    } catch (e) {
      debugPrint('Trackers load failed: $e');
      _state = TrackerBookState.failed;
    }
    _loading = null;
    _emit();
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  String newId() =>
      't${clock().microsecondsSinceEpoch.toRadixString(36)}${_ids++}';

  Tracker? byId(String id) {
    for (final t in _trackers) {
      if (t.id == id) return t;
    }
    return null;
  }

  void _replaceAll(List<Tracker> next) {
    if (_state != TrackerBookState.ready) return;
    _trackers = List.unmodifiable(next);
    _emit();
    unawaited(_persist());
  }

  void add(Tracker t) => _replaceAll([..._trackers, t]);

  void update(Tracker t) =>
      _replaceAll([for (final x in _trackers) x.id == t.id ? t : x]);

  void remove(String id) => _replaceAll([
    for (final x in _trackers)
      if (x.id != id) x,
  ]);

  void move(int from, int to) {
    final next = [..._trackers];
    if (from < 0 || from >= next.length) return;
    final t = next.removeAt(from);
    next.insert(to.clamp(0, next.length), t);
    _replaceAll(next);
  }

  void record(String id, int item, int amount) {
    final t = byId(id);
    if (t != null) update(t.record(item, amount, clock()));
  }

  void toggleToday(String id) {
    final t = byId(id);
    if (t != null) update(t.toggleDay(clock()));
  }

  String exportJson() =>
      const JsonEncoder.withIndent(' ').convert(encodeTrackers(_trackers));

  /// Strictly parses a backup without changing anything.
  static List<Tracker> parseBackup(String text) =>
      decodeTrackers(jsonDecode(text.trim()));

  void replaceWith(List<Tracker> trackers) => _replaceAll(trackers);

  /// Coalesces rapid edits (tesbih taps) into sequential whole-list writes.
  Future<void> _persist() {
    _dirty = true;
    if (_writing) return _flush!;
    _writing = true;
    return _flush = () async {
      while (_dirty) {
        _dirty = false;
        try {
          await store.save(jsonEncode(encodeTrackers(_trackers)));
          if (_saveFailed) {
            _saveFailed = false;
            _emit();
          }
        } catch (e) {
          debugPrint('Trackers save failed: $e');
          _saveFailed = true;
          _emit();
        }
      }
      _writing = false;
    }();
  }

  /// Completes once every pending change has been written (or failed).
  Future<void> flush() => _flush ?? Future.value();
}
