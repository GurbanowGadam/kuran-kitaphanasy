import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

abstract interface class ReaderStore {
  Future<Map<String, dynamic>?> read(String bookId);
  Future<void> write(String bookId, Map<String, dynamic> value);
}

class MemoryReaderStore implements ReaderStore {
  final _values = <String, String>{};
  @override
  Future<Map<String, dynamic>?> read(String bookId) async =>
      _values[bookId] == null
      ? null
      : Map<String, dynamic>.from(jsonDecode(_values[bookId]!));
  @override
  Future<void> write(String bookId, Map<String, dynamic> value) async {
    _values[bookId] = jsonEncode(value);
  }
}

class SharedPreferencesReaderStore implements ReaderStore {
  String _key(String id) => 'kuran_kitaphanasy.reader.$id';
  @override
  Future<Map<String, dynamic>?> read(String bookId) async {
    try {
      final value = (await SharedPreferences.getInstance()).getString(
        _key(bookId),
      );
      return value == null
          ? null
          : Map<String, dynamic>.from(jsonDecode(value));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String bookId, Map<String, dynamic> value) async {
    final ok = await (await SharedPreferences.getInstance()).setString(
      _key(bookId),
      jsonEncode(value),
    );
    if (!ok) {
      throw StateError('Preferences could not be saved');
    }
  }
}

class ReaderPreferences {
  ReaderPreferences({
    this.page = 0,
    this.mode = 'both',
    this.vertical = false,
    this.dark,
    this.arabicSize = 34,
    this.translationSize = 20,
    this.alignment = 'justify',
    Map<int, double>? offsets,
  }) : offsets = offsets ?? {};
  static const version = 1, offsetLimit = 24;
  final int page;
  final String mode, alignment;
  final bool vertical;
  final bool? dark;
  final double arabicSize, translationSize;
  final Map<int, double> offsets;
  factory ReaderPreferences.restore(Map<String, dynamic>? raw, int pageCount) {
    if (raw == null || raw['version'] != version) {
      return ReaderPreferences();
    }
    double size(String key, double fallback, double min, double max) {
      final v = raw[key];
      return v is num && v.isFinite && v >= min && v <= max
          ? v.toDouble()
          : fallback;
    }

    final p = raw['page'];
    final validPage = p is int && p >= 0 && p < pageCount;
    final page = validPage ? p : 0;
    final offsets = <int, double>{};
    final entries = raw['offsets'];
    // Version 1 also contained session history. Read just the last page, so
    // existing installations get the new restart policy without losing settings.
    if (validPage && entries is Map) {
      final v = entries['${page + 1}'];
      if (v is num && v.isFinite && v >= 0 && v <= 1000000) {
        offsets[page + 1] = v.toDouble();
      }
    }
    return ReaderPreferences(
      page: page,
      mode: ['both', 'arabic', 'translation'].contains(raw['mode'])
          ? raw['mode'] as String
          : 'both',
      vertical: raw['vertical'] == true,
      dark: raw['dark'] is bool ? raw['dark'] as bool : null,
      arabicSize: size('arabicSize', 34, 24, 48),
      translationSize: size('translationSize', 20, 14, 32),
      alignment: ['center', 'right', 'justify'].contains(raw['alignment'])
          ? raw['alignment'] as String
          : 'justify',
      offsets: offsets,
    );
  }
  Map<String, dynamic> toJson() => {
    'version': version,
    'page': page,
    'mode': mode,
    'vertical': vertical,
    'dark': dark,
    'arabicSize': arabicSize,
    'translationSize': translationSize,
    'alignment': alignment,
    'offsets': {'${page + 1}': offsets[page + 1] ?? 0.0},
  };
}

/// Ordered writes, debounced during gestures, explicitly flushable at lifecycle boundaries.
class PreferenceWriter {
  PreferenceWriter(this.store, this.bookId);
  final ReaderStore store;
  final String bookId;
  Timer? _timer;
  Map<String, dynamic>? _pending;
  Future<void> _writing = Future.value();
  Object? lastError;
  void schedule(Map<String, dynamic> state) {
    _pending = state;
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 350), () => unawaited(flush()));
  }

  Future<void> flush() {
    _timer?.cancel();
    final value = _pending;
    _pending = null;
    if (value != null) {
      _writing = _writing.then((_) async {
        try {
          await store.write(bookId, value);
          lastError = null;
        } catch (e) {
          lastError = e;
        }
      });
    }
    return _writing;
  }

  void dispose() {
    _timer?.cancel();
    unawaited(flush());
  }
}
