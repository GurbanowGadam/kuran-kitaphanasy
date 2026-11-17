import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'reader_fixture.dart';
import 'reader_settings_test.dart' show settings, choose, close;

void main() {
  testWidgets(
    'Icon controls open named sheets; justify default and right alignment',
    (t) async {
      await openReader(t);
      expect(
        t.widget(find.byKey(const Key('reader-settings'))),
        isA<IconButton>(),
      );
      expect(t.widget(find.byKey(const Key('surah-menu'))), isA<IconButton>());
      expect(find.text('Sazlamalar'), findsNothing);
      expect(find.text('Süreler'), findsNothing);
      await settings(t);
      expect(find.text('Sazlamalar'), findsOneWidget);
      expect(
        t.widget<ChoiceChip>(find.byKey(const Key('align-justify'))).selected,
        isTrue,
      );
      expect(find.byKey(const Key('align-left')), findsNothing);
      await choose(t, 'align-right');
      await close(t);
      await setMode(t, 'arabic');
      expect(
        t.widget<Text>(find.byKey(const Key('arabic-flow-1'))).textAlign,
        TextAlign.right,
      );
      await settings(t);
      await choose(t, 'settings-reset');
      expect(
        t.widget<ChoiceChip>(find.byKey(const Key('align-justify'))).selected,
        isTrue,
      );
      await close(t);
      await t.tap(find.byKey(const Key('surah-menu')));
      await t.pumpAndSettle();
      expect(find.text('Süreler'), findsOneWidget);
    },
  );
  testWidgets(
    'Font previews use actual sizes and source Arabic at narrow width',
    (t) async {
      t.view.physicalSize = const Size(320, 740);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await openReader(t);
      await settings(t);
      Text preview(String key) => t.widget<Text>(find.byKey(Key(key)));
      expect(
        preview('arabic-size-preview').data,
        fixture().pages.first.verses.first.text,
      );
      expect(preview('arabic-size-preview').style!.fontSize, 34);
      expect(preview('translation-size-preview').style!.fontSize, 20);
      await choose(t, 'arabic-increase');
      expect(preview('arabic-size-preview').style!.fontSize, 36);
      expect(preview('translation-size-preview').style!.fontSize, 20);
      await choose(t, 'translation-increase');
      expect(preview('translation-size-preview').style!.fontSize, 22);
      expect(preview('arabic-size-preview').textDirection, TextDirection.rtl);
      expect(t.takeException(), isNull);
    },
  );
}
