import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuran_kitaphanasy/library.dart';

void main() {
  for (final dark in [false, true]) {
    for (final size in [
      const Size(320, 640),
      const Size(384, 832),
      const Size(390, 844),
    ]) {
      testWidgets('one-book home fits without scrolling at $size dark=$dark', (
        t,
      ) async {
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        var opened = false;
        var toggled = false;
        await t.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              brightness: dark ? Brightness.dark : Brightness.light,
            ),
            builder: (_, child) => MediaQuery(
              data: MediaQueryData(
                size: size,
                padding: const EdgeInsets.only(top: 24, bottom: 24),
              ),
              child: child!,
            ),
            home: LibraryPage(
              dark: dark,
              toggleTheme: () => toggled = true,
              openBook: (_) => opened = true,
            ),
          ),
        );
        await t.pumpAndSettle();
        final scroll = t.state<ScrollableState>(find.byType(Scrollable).first);
        expect(
          scroll.position.maxScrollExtent,
          0,
          reason: 'A single book and all home actions must fit at normal text scale.',
        );
        final coverRect = t.getRect(find.byType(BookCover));
        expect(coverRect.width, lessThanOrEqualTo(144));
        expect(find.text('Okap başla').hitTestable(), findsOneWidget);
        expect(
          find.byKey(const Key('source-about')).hitTestable(),
          findsOneWidget,
        );
        await t.tap(find.text('Okap başla'));
        expect(opened, true);
        await t.tap(find.byType(IconButton).first);
        expect(toggled, true);
        await t.tap(find.byKey(const Key('source-about')));
        await t.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(t.takeException(), isNull);
      });
    }
  }
}
