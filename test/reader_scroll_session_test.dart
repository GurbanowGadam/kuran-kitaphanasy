import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuran_kitaphanasy/reader/settings/reader_preferences.dart';

import 'production_navigation_test.dart' show open;

Finder scroll(int id) => find.byKey(Key('page-scroll-$id'));
ScrollController controller(WidgetTester t, int id) =>
    t.widget<ListView>(scroll(id)).controller!;
Future<void> next(WidgetTester t, int id, bool forward) async {
  await t.drag(scroll(id), Offset(forward ? 600 : -600, 0));
  await t.pumpAndSettle();
}

void main() {
  for (final boundary in [
    'restart',
    'paused',
    'hidden',
    'detached',
    'inactive',
    'foreground',
  ]) {
    testWidgets(
      '$boundary keeps only current offset across real session boundary',
      (t) async {
        final store = MemoryReaderStore();
        await store.write('quran', ReaderPreferences(page: 2).toJson());
        await open(t, store);
        controller(t, 3).jumpTo(170);
        await t.pumpAndSettle();
        expect(controller(t, 3).offset, closeTo(170, 1));

        await next(t, 3, true);
        expect(scroll(4), findsOneWidget);
        controller(t, 4).jumpTo(210);
        await t.pumpAndSettle();
        final current = controller(t, 4).offset;
        if (boundary == 'restart') {
          await t.pumpWidget(const SizedBox());
          await t.pump(const Duration(seconds: 1));
          await open(t, store);
        } else if (boundary != 'foreground') {
          final state = switch (boundary) {
            'paused' => AppLifecycleState.paused,
            'hidden' => AppLifecycleState.hidden,
            'detached' => AppLifecycleState.detached,
            _ => AppLifecycleState.inactive,
          };
          t.binding.handleAppLifecycleStateChanged(state);
          await t.pump();
          t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
          await t.pumpAndSettle();
          // Repeated resumed must not clear newly retained positions.
          t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
          await t.pumpAndSettle();
        }
        expect(controller(t, 4).offset, closeTo(current, 1));
        await next(t, 4, false);
        final preservesHistory =
            boundary == 'inactive' || boundary == 'foreground';
        expect(controller(t, 3).offset, closeTo(preservesHistory ? 170 : 0, 1));
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 1));
      },
    );
  }
}
