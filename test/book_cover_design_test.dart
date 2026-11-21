import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuran_kitaphanasy/library.dart';

const coverAsset = 'assets/images/kurany-kerim-cover.jpg';

void main() {
  testWidgets(
    'cover uses approved offline artwork without cropping or duplicate lettering',
    (t) async {
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BookCover(book: libraryBooks.first)),
        ),
      );
      final cover = find.byType(BookCover);
      final imageFinder = find.descendant(
        of: cover,
        matching: find.byType(Image),
      );
      expect(imageFinder, findsOneWidget);
      final image = t.widget<Image>(imageFinder);
      expect((image.image as AssetImage).assetName, coverAsset);
      expect(image.fit, BoxFit.contain);
      expect(image.semanticLabel, 'KURANY KERIM — TÜRKMENÇE MANY TERJIMESI');
      expect(
        find.descendant(of: cover, matching: find.byType(Text)),
        findsNothing,
        reason: 'The retouched reference already contains both titles; never overlay duplicate text.',
      );
      final rect = t.getRect(cover);
      expect(rect.width / rect.height, closeTo(1696 / 2528, .001));
      await t.runAsync(
        () => precacheImage(const AssetImage(coverAsset), t.element(cover)),
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    },
  );

  for (final dark in [false, true]) {
    for (final width in [320.0, 390.0, 1024.0]) {
      testWidgets(
        'approved cover preserves library action at $width dark=$dark enlarged text',
        (t) async {
          t.view.physicalSize = Size(width, 1100);
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
                data: MediaQueryData(
                  size: Size(width, 1100),
                  textScaler: const TextScaler.linear(1.8),
                ),
                child: child!,
              ),
              home: LibraryPage(dark: dark, openBook: (_) => opened = true),
            ),
          );
          await t.pumpAndSettle();
          final cover = find.byType(BookCover);
          expect(
            find.descendant(of: cover, matching: find.byType(Image)),
            findsOneWidget,
          );
          expect(find.text('القرآن الكريم'), findsNothing);
          final rect = t.getRect(cover);
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(width));
          expect(rect.width / rect.height, closeTo(1696 / 2528, .001));
          await t.ensureVisible(find.text('Okap başla'));
          await t.tap(find.text('Okap başla'));
          expect(opened, true);
          expect(t.takeException(), isNull);
        },
      );
    }
  }

  if (const bool.fromEnvironment('CAPTURE_COVER')) {
    testWidgets('capture approved retouched artwork in both themes', (t) async {
      for (final dark in [false, true]) {
        final key = GlobalKey();
        final background = dark
            ? const Color(0xff142320)
            : const Color(0xfffaf7ef);
        await t.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              brightness: dark ? Brightness.dark : Brightness.light,
            ),
            home: Scaffold(
              backgroundColor: background,
              body: Center(
                child: RepaintBoundary(
                  key: key,
                  child: ColoredBox(
                    color: background,
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: BookCover(book: libraryBooks.first),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await t.runAsync(
          () => precacheImage(
            const AssetImage(coverAsset),
            t.element(find.byType(BookCover)),
          ),
        );
        await t.pumpAndSettle();
        await t.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 3);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final output = File(
            'reports/cover-reference/cover-${dark ? 'dark' : 'light'}.png',
          );
          await output.parent.create(recursive: true);
          await output.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        expect(t.takeException(), isNull);
      }
    });
  }
}
