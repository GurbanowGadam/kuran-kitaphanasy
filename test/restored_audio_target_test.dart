import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuran_kitaphanasy/reader/presentation/reader.dart';
import 'package:kuran_kitaphanasy/reader/settings/reader_preferences.dart';

import 'reader_audio_test.dart' show FakeAudio;
import 'reader_fixture.dart';

void main() {
  testWidgets(
    'restored shared page selects visible surah before first audio open',
    (t) async {
      final store = MemoryReaderStore();
      final a = FakeAudio();
      Future<void> mount() async {
        await t.pumpWidget(
          MaterialApp(
            home: Reader(
              data: Future.value(fixture()),
              store: store,
              audioController: a,
              goHome: () {},
            ),
          ),
        );
        await t.pumpAndSettle();
      }

      await mount();
      final dynamic first = t.state(find.byType(Reader));
      final GlobalKey section = first.sectionKeys['1:2'];
      await Scrollable.ensureVisible(section.currentContext!);
      await t.pumpAndSettle();
      expect(first.activeSurah, 2);
      first.persist();
      await first.writer.flush();
      final offset = first.offsets[1] as double;
      expect(offset, greaterThan(0));
      await t.pumpWidget(const SizedBox());
      await mount();
      final dynamic restored = t.state(find.byType(Reader));
      expect(restored.offsets[1], closeTo(offset, 1));
      expect(
        t.widget<Text>(find.byKey(const Key('surah-title'))).data,
        '2. Bakara süresi',
      );
      await t.tap(find.byKey(const Key('audio-menu')));
      await t.pumpAndSettle();
      expect(a.surah, 2);
      await t.pumpWidget(const SizedBox());
    },
  );
}
