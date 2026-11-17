import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'reader_fixture.dart';

void main() {
  for (final width in [320.0, 390.0]) {
    testWidgets(
      'Reference header: title left, counter below, mode right at $width',
      (t) async {
        t.view.physicalSize = Size(width, 800);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        await openReader(t);
        for (final mode in ['translation', 'arabic', 'both']) {
          await setMode(t, mode);
          final title = find.byKey(const Key('surah-title'));
          final counter = find.byKey(const Key('page-counter'));
          final menu = find.byKey(const Key('mode-dropdown'));
          expect(t.getCenter(title).dx, lessThan(t.getCenter(menu).dx));
          expect(t.getTopLeft(counter).dx, t.getTopLeft(title).dx);
          expect(
            t.getTopLeft(counter).dy,
            greaterThanOrEqualTo(t.getBottomLeft(title).dy),
          );
          expect(
            t.getCenter(find.byKey(const Key('surah-info'))).dx,
            lessThan(t.getCenter(menu).dx),
          );
          expect(find.text('A + T'), findsNothing);
          expect(
            find.text(
              {
                'both': 'Arapça + Türkmençe',
                'arabic': 'Arapça',
                'translation': 'Türkmençe',
              }[mode]!,
            ),
            findsOneWidget,
          );
        }
        t.platformDispatcher.textScaleFactorTestValue = 1.5;
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        await t.pumpAndSettle();
      },
    );
  }
}
