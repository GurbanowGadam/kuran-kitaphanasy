import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const root = 'android/app/src/main/res';
  test('splash turns one leaf slowly around the book spine, not a pulse', () {
    final vector = File('$root/drawable/startup_book.xml').readAsStringSync();
    expect(vector, contains('android:name="turning_page"'));
    expect(vector, contains('android:pivotX="54"'));
    final animated = File('$root/drawable/startup_book_animated.xml')
        .readAsStringSync();
    expect(animated, contains('android:name="turning_page"'));
    expect(animated, contains('@animator/startup_page_turn'));
    expect(animated, isNot(contains('startup_book_pulse')));
    final animator = File('$root/animator/startup_page_turn.xml')
        .readAsStringSync();
    expect(animator, contains('android:propertyName="scaleX"'));
    expect(animator, contains('android:valueFrom="1"'));
    expect(animator, contains('android:valueTo="-1"'));
    expect(animator, contains('android:repeatCount="-1"'));
    final duration = int.parse(
      RegExp(r'android:duration="(\d+)"').firstMatch(animator)!.group(1)!,
    );
    expect(duration, inInclusiveRange(2000, 3000));
    expect(animator, contains('@android:interpolator/accelerate_decelerate'));
  });
  test('both native themes use same slow page-turn timing', () {
    for (final directory in ['values-v31', 'values-night-v31']) {
      final xml = File('$root/$directory/styles.xml').readAsStringSync();
      expect(
        xml,
        contains(
          '<item name="android:windowSplashScreenAnimationDuration">2400</item>',
        ),
      );
    }
  });
}
