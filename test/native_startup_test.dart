import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native startup contains only neutral book paths, no ornament', () {
    final xml = File('android/app/src/main/res/drawable/startup_book.xml')
        .readAsStringSync();
    expect(RegExp(r'<path\b').allMatches(xml), hasLength(4));
    for (final name in [
      'book',
      'static_page_lines',
      'turning_leaf',
      'page_lines',
    ]) {
      expect(xml, contains('android:name="$name"'));
    }
    expect(xml, isNot(contains('M54,20')));
  });

  test('production holds native splash until the app ready frame', () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(source, contains('binding.deferFirstFrame()'));
    expect(source, contains('onStartupReady:'));
    expect(source, contains('binding.allowFirstFrame()'));
    expect(
      source.indexOf('binding.deferFirstFrame()'),
      lessThan(source.indexOf('runApp(')),
    );
  });
  test('Android launch uses themed book art before Flutter first frame', () {
    const root = 'android/app/src/main/res';
    for (final directory in ['values-v31', 'values-night-v31']) {
      final file = File('$root/$directory/styles.xml');
      expect(file.existsSync(), isTrue, reason: directory);
      final xml = file.readAsStringSync();
      expect(xml, contains('android:windowSplashScreenAnimatedIcon'));
      expect(xml, contains('@drawable/startup_book_animated'));
      expect(xml, contains('@color/launch_surface'));
    }
    for (final directory in ['drawable', 'drawable-v21']) {
      final xml = File('$root/$directory/launch_background.xml')
          .readAsStringSync();
      expect(xml, contains('@color/launch_surface'));
      expect(xml, contains('@drawable/startup_book'));
    }
    final animated = File('$root/drawable/startup_book_animated.xml')
        .readAsStringSync();
    expect(animated, contains('android:name="turning_page"'));
    expect(animated, contains('@animator/startup_page_turn'));
  });
}
