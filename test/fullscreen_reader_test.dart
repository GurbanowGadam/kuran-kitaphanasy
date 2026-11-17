import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:kuran_kitaphanasy/main.dart';

import 'reader_fixture.dart';
import 'reader_settings_test.dart' show settings, choose, close;

const hint = 'Doly ekrandan çykmak üçin ekrana iki gezek basyň.';
final fullscreen = find.byKey(const Key('reader-fullscreen'));
Future<void> enter(WidgetTester t) async {
  await t.tap(fullscreen);
  await t.pump();
}

Future<void> doubleTap(WidgetTester t) async {
  final point = t.getCenter(find.byKey(const Key('reader-gestures')));
  await t.tapAt(point);
  await t.pump(const Duration(milliseconds: 80));
  await t.tapAt(point);
  await t.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('320px fixed left cluster and home pinned far right', (t) async {
    t.view.physicalSize = const Size(320, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await openReader(t);
    final keys = ['reader-fullscreen', 'reader-settings', 'surah-menu'];
    var right = 8.0;
    for (final key in keys) {
      final rect = t.getRect(find.byKey(Key(key)));
      expect(rect.left, right);
      expect(rect.width, greaterThanOrEqualTo(40));
      right = rect.right;
    }
    expect(t.getRect(find.byKey(const Key('back-library'))).right, 312);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'fullscreen hides chrome, immersive UI, exact three second hint and double tap exit',
    (t) async {
      final calls = <MethodCall>[];
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(
        () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await openReader(t);
      await enter(t);
      expect(find.byType(AppBar), findsNothing);
      expect(find.byKey(const Key('reader-bottom-chrome')), findsNothing);
      expect(
        calls.any(
          (c) =>
              c.method == 'SystemChrome.setEnabledSystemUIMode' &&
              c.arguments == 'SystemUiMode.immersiveSticky',
        ),
        isTrue,
      );
      expect(find.text(hint), findsOneWidget);
      final ignore = find.ancestor(
        of: find.text(hint),
        matching: find.byType(IgnorePointer),
      );
      expect(t.widget<IgnorePointer>(ignore.first).ignoring, isTrue);
      await t.pump(const Duration(milliseconds: 2999));
      expect(find.text(hint), findsOneWidget);
      await t.pump(const Duration(milliseconds: 1));
      expect(find.text(hint), findsNothing);
      await doubleTap(t);
      expect(find.byType(AppBar), findsOneWidget);
      expect(fullscreen, findsOneWidget);
      expect(
        calls
            .lastWhere((c) => c.method == 'SystemChrome.setEnabledSystemUIMode')
            .arguments,
        'SystemUiMode.edgeToEdge',
      );
      final detector = t.widget<GestureDetector>(
        find.byKey(const Key('reader-gestures')),
      );
      expect(detector.onDoubleTap, isNull);
      await doubleTap(t);
      expect(fullscreen, findsOneWidget);
    },
  );
  for (final vertical in [false, true]) {
    testWidgets(
      'fullscreen retains mode/page/scroll and gestures vertical=$vertical',
      (t) async {
        await openReader(t);
        await setMode(t, 'translation');
        if (vertical) {
          await settings(t);
          await choose(t, 'orientation-vertical');
          await close(t);
        } else {
          await t.drag(
            find.byKey(const Key('quran-pages')),
            const Offset(-600, 0),
          );
          await t.pumpAndSettle();
        }
        final scrollFinder = vertical
            ? find.byKey(const Key('vertical-pages'))
            : find
                  .descendant(
                    of: find.byKey(const Key('quran-pages')),
                    matching: find.byType(ListView),
                  )
                  .hitTestable()
                  .first;
        final ScrollController? controller = vertical
            ? null
            : t.widget<ListView>(scrollFinder).controller!;
        if (vertical) {
          await t.drag(scrollFinder, const Offset(0, -180));
        } else {
          controller!.jumpTo(180);
        }
        await t.pumpAndSettle();
        double currentOffset() => vertical
            ? -t
                      .widget<ScrollablePositionedList>(scrollFinder)
                      .itemPositionsNotifier!
                      .itemPositions
                      .value
                      .first
                      .itemLeadingEdge *
                  t.getSize(scrollFinder).height
            : controller!.offset;
        final offset = currentOffset();
        final counter = t
            .widget<Text>(find.byKey(const Key('page-counter')))
            .data;
        await enter(t);
        expect(currentOffset(), closeTo(offset, .00001));
        await doubleTap(t);
        expect(currentOffset(), closeTo(offset, .00001));
        expect(
          t.widget<Text>(find.byKey(const Key('page-counter'))).data,
          counter,
        );
        expect(
          t
              .widget<PopupMenuButton<String>>(
                find.byKey(const Key('mode-dropdown')),
              )
              .initialValue,
          'translation',
        );
        await enter(t);
        await t.drag(
          find.byKey(const Key('reader-gestures')),
          const Offset(0, -140),
        );
        await t.pumpAndSettle();
        expect(currentOffset(), greaterThan(offset));
        if (!vertical) {
          await t.drag(
            find.byKey(const Key('quran-pages')),
            const Offset(-600, 0),
          );
          await t.pumpAndSettle();
        }
        await doubleTap(t);
        if (!vertical) {
          expect(
            t.widget<Text>(find.byKey(const Key('page-counter'))).data,
            isNot(counter),
          );
        }
      },
    );
  }
  testWidgets(
    'back exits fullscreen, reentry restarts hint, disposal cancels timer and restores UI',
    (t) async {
      final calls = <MethodCall>[];
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(
        () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await openReader(t);
      await enter(t);
      await t.pump(const Duration(seconds: 2));
      await t.binding.handlePopRoute();
      await t.pump();
      expect(fullscreen, findsOneWidget);
      expect(find.byKey(const Key('book-quran')), findsNothing);
      await enter(t);
      await t.pump(const Duration(seconds: 2));
      expect(find.text(hint), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 4));
      expect(
        calls
            .lastWhere((c) => c.method == 'SystemChrome.setEnabledSystemUIMode')
            .arguments,
        'SystemUiMode.edgeToEdge',
      );
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('retained reader leaving for library restores fullscreen UI', (
    t,
  ) async {
    await openReader(t);
    await enter(t);
    t.widget<Reader>(find.byType(Reader)).goHome();
    await t.pumpAndSettle();
    expect(find.byKey(const Key('book-quran')), findsOneWidget);
    await t.tap(find.byKey(const Key('book-quran')));
    await t.pumpAndSettle();
    expect(fullscreen, findsOneWidget);
    expect(find.text(hint), findsNothing);
  });
  testWidgets('notes remain tappable during fullscreen', (t) async {
    await openReader(t);
    await enter(t);
    final note = find.byKey(const Key('note-n1'));
    await t.ensureVisible(note);
    await t.pumpAndSettle();
    await t.tap(note);
    // A fullscreen double-tap recognizer defers single-tap arena resolution.
    await t.pump(const Duration(milliseconds: 300));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('detail-sheet')), findsOneWidget);
    await close(t);
    expect(fullscreen, findsNothing);
    await doubleTap(t);
    expect(fullscreen, findsOneWidget);
  });
}
