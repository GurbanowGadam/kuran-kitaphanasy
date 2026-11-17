import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String vector;
  setUp(
    () =>
        vector = File('android/app/src/main/res/drawable/startup_book.xml')
            .readAsStringSync(),
  );
  String path(String name) =>
      RegExp(r'<path\b[^>]*>')
          .allMatches(vector)
          .map((m) => m.group(0)!)
          .singleWhere((p) => p.contains('android:name="$name"'));
  String? attribute(String xml, String name) =>
      RegExp('android:$name="([^"]*)"').firstMatch(xml)?.group(1);

  test(
    'stationary and turning page borders share explicit stroke and color',
    () {
      final stationary = path('book');
      final turning = path('turning_leaf');
      expect(attribute(stationary, 'strokeWidth'), isNotNull);
      expect(
        attribute(stationary, 'strokeWidth'),
        attribute(turning, 'strokeWidth'),
      );
      expect(
        attribute(stationary, 'strokeColor'),
        attribute(turning, 'strokeColor'),
      );
      expect(attribute(stationary, 'fillColor'), '@color/launch_surface');
      expect(
        attribute(stationary, 'strokeLineJoin'),
        attribute(turning, 'strokeLineJoin'),
      );
      expect(
        attribute(stationary, 'pathData'),
        contains(attribute(turning, 'pathData')!),
      );
    },
  );
  test(
    'both stationary pages carry the same three fine lines as the turning page',
    () {
      expect(vector, contains('android:name="static_page_lines"'));
      final stationary = path('static_page_lines');
      final turning = path('page_lines');
      for (final name in [
        'strokeColor',
        'strokeWidth',
        'strokeAlpha',
        'strokeLineCap',
      ]) {
        expect(
          attribute(stationary, name),
          attribute(turning, name),
          reason: name,
        );
      }
      final lines = attribute(stationary, 'pathData')!;
      expect(RegExp('M').allMatches(lines), hasLength(6));
      expect(lines, contains(attribute(turning, 'pathData')!));
      expect(lines, contains('M48,44'));
      expect(lines, contains('M60,44'));
    },
  );
}
