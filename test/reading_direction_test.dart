import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'reader_fixture.dart';

void main() {
  for (final mode in ['translation', 'arabic', 'both']) {
    testWidgets(
      '$mode uses its reading direction for real swipes and page bounds',
      (t) async {
        t.view.physicalSize = const Size(390, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        await openReader(t);
        await setMode(t, mode);
        final finder = find.byKey(const Key('quran-pages'));
        final view = t.widget<PageView>(finder);
        final controller = view.controller!;
        final advance = mode == 'translation' ? -280.0 : 280.0;
        expect(view.reverse, mode != 'translation');
        expect(controller.page, 0);
        await t.drag(finder, Offset(-advance, 0));
        await t.pumpAndSettle();
        expect(controller.page, 0, reason: 'Cannot move before first page.');
        await t.drag(finder, Offset(advance, 0));
        await t.pumpAndSettle();
        expect(controller.page, 1);
        await t.drag(finder, Offset(-advance, 0));
        await t.pumpAndSettle();
        expect(controller.page, 0);
        final last = fixture().pages.length - 1;
        controller.jumpToPage(last);
        await t.pumpAndSettle();
        await t.drag(finder, Offset(advance, 0));
        await t.pumpAndSettle();
        expect(controller.page, last, reason: 'Cannot move beyond last page.');
        await t.drag(finder, Offset(-advance, 0));
        await t.pumpAndSettle();
        expect(controller.page, last - 1);
        expect(t.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'switching reading direction retains the selected noninitial page and controller',
    (t) async {
      await openReader(t);
      final finder = find.byKey(const Key('quran-pages'));
      final controller = t.widget<PageView>(finder).controller!;
      controller.jumpToPage(3);
      await t.pumpAndSettle();
      for (final mode in ['translation', 'arabic', 'both', 'translation']) {
        await setMode(t, mode);
        final view = t.widget<PageView>(finder);
        expect(view.controller, same(controller));
        expect(controller.page, 3);
        expect(view.reverse, mode != 'translation');
        expect(
          find.text('Sahypa 4 (4/${fixture().pages.length})'),
          findsOneWidget,
        );
        expect(t.takeException(), isNull);
      }
    },
  );
}
