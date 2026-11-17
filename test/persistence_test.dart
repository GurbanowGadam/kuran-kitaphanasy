import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kuran_kitaphanasy/reader/settings/reader_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('versioned settings survive store restart, scoped to book; fullscreen excluded', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SharedPreferencesReaderStore();
    await store.write('quran', {
      'version': 1,
      'page': 603,
      'mode': 'translation',
      'vertical': true,
      'dark': true,
      'arabicSize': 46.0,
      'translationSize': 30.0,
      'alignment': 'right',
      'offsets': {'604': 124.0},
    });
    final state = ReaderPreferences.restore(
      await SharedPreferencesReaderStore().read('quran'),
      604,
    );
    expect(state.page, 603);
    expect(state.mode, 'translation');
    expect(state.vertical, isTrue);
    expect(state.dark, isTrue);
    expect(state.arabicSize, 46);
    expect(state.translationSize, 30);
    expect(state.alignment, 'right');
    expect(state.offsets[604], 124);
    expect(state.toJson().containsKey('fullscreen'), isFalse);
    expect(await store.read('another-book'), isNull);
  });
  test(
    'corrupt, future and out of range values recover safely; offsets bounded',
    () {
      expect(ReaderPreferences.restore({'version': 99, 'page': 7}, 9).page, 0);
      final state = ReaderPreferences.restore({
        'version': 1,
        'page': 999,
        'mode': 'fake',
        'arabicSize': double.nan,
        'translationSize': -20,
        'offsets': {
          for (var i = 1; i < 100; i++) '$i': i.toDouble(),
          '100': -2,
        },
      }, 20);
      expect(state.page, 0);
      expect(state.mode, 'both');
      expect(state.arabicSize, 34);
      expect(state.translationSize, 20);
      expect(
        state.offsets.length,
        lessThanOrEqualTo(ReaderPreferences.offsetLimit),
      );
      expect(state.offsets.keys.every((k) => k >= 1 && k <= 20), isTrue);
    },
  );
  test('legacy offset history restores only the selected page', () {
    final state = ReaderPreferences.restore({
      'version': 1,
      'page': 6,
      'mode': 'arabic',
      'dark': true,
      'offsets': {for (var i = 1; i <= 24; i++) '$i': i * 10.0},
    }, 604);
    expect(state.offsets, {7: 70.0});
    expect(state.mode, 'arabic');
    expect(state.dark, isTrue);
  });
  test('save contains only selected offset including zero', () {
    expect(
      ReaderPreferences(
        page: 6,
        offsets: {1: 120, 7: 0, 8: 80},
      ).toJson()['offsets'],
      {'7': 0.0},
    );
    expect(ReaderPreferences(page: 6).toJson()['offsets'], {'7': 0.0});
  });
  test('invalid selected page and corrupt selected offsets are safe', () {
    for (final page in [null, '6', -1, 604, double.nan, double.infinity]) {
      final state = ReaderPreferences.restore({
        'version': 1,
        'page': page,
        'offsets': {'1': 10, '7': 70},
      }, 604);
      expect(state.page, 0);
      expect(state.offsets, isEmpty);
    }
    for (final offset in [
      null,
      'bad',
      -1,
      double.nan,
      double.infinity,
      1000001,
    ]) {
      expect(
        ReaderPreferences.restore({
          'version': 1,
          'page': 6,
          'offsets': {'7': offset, '1': 20},
        }, 604).offsets,
        isEmpty,
      );
    }
  });
  test(
    'debounced writes flush immediately and serialize latest state',
    () async {
      final memory = MemoryReaderStore();
      final saves = PreferenceWriter(memory, 'quran');
      saves.schedule({'version': 1, 'page': 1});
      saves.schedule({'version': 1, 'page': 2});
      await saves.flush();
      expect((await memory.read('quran'))!['page'], 2);
      saves.dispose();
    },
  );
}
