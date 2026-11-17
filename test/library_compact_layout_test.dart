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
      testWidgets('library actions remain reachable at $size dark=$dark', (
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
        // The new hadith section may scroll on the shortest phone, but the
        // Quran action stays immediately reachable. Taller phones still fit.
        if (size.height >= 832) {
          expect(scroll.position.maxScrollExtent, 0);
        }
        final coverRect = t.getRect(find.byType(BookCover));
        expect(coverRect.width, lessThanOrEqualTo(144));
        expect(find.text('Okap başla').hitTestable(), findsOneWidget);
        await t.tap(find.text('Okap başla'));
        expect(opened, true);
        await t.tap(find.byType(IconButton).first);
        expect(toggled, true);
        await t.ensureVisible(find.text('Sahih Buhari'));
        expect(find.text('Sahih Buhari').hitTestable(), findsOneWidget);
        await t.ensureVisible(find.byKey(const Key('source-about')));
        expect(
          find.byKey(const Key('source-about')).hitTestable(),
          findsOneWidget,
        );
        await t.tap(find.byKey(const Key('source-about')));
        await t.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(t.takeException(), isNull);
      });
    }
  }
}
