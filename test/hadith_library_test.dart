import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuran_kitaphanasy/library.dart';

void main() {
  for (final dark in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      for (final title in ['Sahih Muslim', 'Sahih Buhari']) {
        testWidgets('$title is coming soon, dark=$dark scale=$scale', (
          t,
        ) async {
          t.view.physicalSize = const Size(320, 640);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          var opened = false;
          await t.pumpWidget(
            MaterialApp(
              theme: ThemeData(
                brightness: dark ? Brightness.dark : Brightness.light,
              ),
              builder: (_, child) => MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: LibraryPage(dark: dark, openBook: (_) => opened = true),
            ),
          );
          await t.pumpAndSettle();
          expect(find.text('Hadyslar'), findsOneWidget);
          expect(find.text('Sahih Muslim'), findsOneWidget);
          expect(find.text('Sahih Buhari'), findsOneWidget);
          expect(
            t.getTopLeft(find.text('Hadyslar')).dy,
            greaterThan(
              t.getBottomLeft(find.byKey(const Key('book-quran'))).dy,
            ),
          );
          await t.ensureVisible(find.text(title));
          await t.tap(find.text(title));
          await t.pumpAndSettle();
          expect(find.byType(AlertDialog), findsOneWidget);
          expect(find.text('Ýakyn wagtda taýýar bolar.'), findsOneWidget);
          expect(opened, false);
          await t.tap(find.text('Ýap'));
          await t.pumpAndSettle();
          expect(find.byType(AlertDialog), findsNothing);
          await t.ensureVisible(find.text('Okap başla'));
          await t.tap(find.text('Okap başla'));
          expect(opened, true);
          expect(t.takeException(), isNull);
        });
      }
    }
  }
}
