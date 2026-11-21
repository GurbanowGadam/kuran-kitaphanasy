import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kuran_kitaphanasy/main.dart';

import 'reader_fixture.dart';

void main() {
  test('requested version and Material Icons license are bundled without legacy audio', () {
    final spec = File('pubspec.yaml').readAsStringSync();
    expect(spec, contains('version: 1.0.0+3'));
    expect(spec, isNot(contains('    - assets/audio/\n')));
    expect(spec, contains('    - assets/audio/yasir-fatiha-original.mp3'));
    expect(spec, contains('assets/licenses/MaterialIcons-LICENSE.txt'));
    expect(
      File('assets/licenses/MaterialIcons-LICENSE.txt').readAsStringSync(),
      contains('Apache License'),
    );
  });
  testWidgets(
    'Product credits identify PDF publisher and expose bundled font licenses',
    (t) async {
      await t.pumpWidget(QuranApp(data: Future.value(fixture())));
      await t.pumpAndSettle();
      await openAbout(t);
      expect(
        find.textContaining('Türkmenistanyň Müftüsiniň müdiriýeti'),
        findsOneWidget,
      );
      expect(find.textContaining('ulanyjy tarapyndan berlen'), findsNothing);
      expect(find.text('Şrift ygtyýarnamalary'), findsOneWidget);
      expect(find.textContaining('MP3Quran'), findsOneWidget);
      expect(find.textContaining('1.0.0'), findsOneWidget);
    },
  );
}
