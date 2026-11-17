import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuran_kitaphanasy/reader/presentation/page_scroll.dart';
import 'package:kuran_kitaphanasy/reader/presentation/reader_paging.dart';

const _frame = Duration(milliseconds: 16);
const _touch = Offset(400, 350);

Future<ReaderPageController> mountReader(
  WidgetTester tester, {
  bool short = false,
  int initialPage = 1,
  ReaderPageController? pageController,
  ScrollPhysics? physics,
  VoidCallback? onTap,
  VoidCallback? onLongPress,
}) async {
  final controller =
      pageController ?? ReaderPageController(initialPage: initialPage);
  if (pageController == null) addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 400,
            height: 600,
            child: PageView.builder(
              key: const Key('quran-pages'),
              controller: controller,
              physics: physics,
              // Matches the reader: LTR chrome, rightward swipe advances pages.
              reverse: true,
              itemCount: 3,
              itemBuilder: (_, index) => ReaderPageScroll(
                pageId: index,
                initialOffset: 0,
                onOffset: (_) {},
                child: GestureDetector(
                  onTap: onTap,
                  onLongPress: onLongPress,
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    height: short ? 120 : 1800,
                    child: Text('page $index'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  return controller;
}

ScrollPosition verticalPosition(WidgetTester tester, int page) => tester
    .state<ScrollableState>(
      find.descendant(
        of: find.byKey(Key('page-scroll-$page')),
        matching: find.byType(Scrollable),
      ),
    )
    .position;

// Leave a genuine touch-driven ballistic snap unfinished. Do not substitute
// animateToPage: its driven activity has a different cancellation lifecycle.
Future<void> beginPageSnap(WidgetTester tester, PageController pages) async {
  final swipe = await tester.startGesture(const Offset(280, 300));
  await swipe.moveBy(const Offset(30, 0));
  await tester.pump(_frame);
  await swipe.moveBy(
    const Offset(240, 0),
    timeStamp: const Duration(milliseconds: 160),
  );
  await tester.pump(const Duration(milliseconds: 160));
  await swipe.up();
  await tester.pump(_frame);
  expect(pages.position.isScrollingNotifier.value, isTrue);
  expect(pages.page, inExclusiveRange(.5, 1));
}

Future<void> horizontalSwipe(WidgetTester tester, double dx) async {
  await tester.timedDragFrom(
    dx > 0 ? const Offset(260, 350) : const Offset(540, 350),
    Offset(dx, 8),
    const Duration(milliseconds: 350),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('physics recreation retains page, nested offset and gestures', (
    tester,
  ) async {
    final pages = await mountReader(
      tester,
      physics: const ClampingScrollPhysics(),
    );
    await horizontalSwipe(tester, 280);
    verticalPosition(tester, 2).jumpTo(140);
    await tester.pumpAndSettle();
    final oldPosition = pages.position;
    await mountReader(
      tester,
      pageController: pages,
      physics: const BouncingScrollPhysics(),
    );
    expect(tester.takeException(), isNull);
    expect(pages.position, isNot(same(oldPosition)));
    expect(pages.page, closeTo(2, .001));
    expect(verticalPosition(tester, 2).pixels, closeTo(140, .001));
    await tester.dragFrom(_touch, const Offset(2, -150));
    await tester.pumpAndSettle();
    expect(verticalPosition(tester, 2).pixels, greaterThan(180));
    expect(pages.page, closeTo(2, .001));
    await horizontalSwipe(tester, -280);
    expect(pages.page, closeTo(1, .001));
  });

  testWidgets('vertical drag during horizontal snap reaches nested list', (
    tester,
  ) async {
    var taps = 0;
    var longPresses = 0;
    final pages = await mountReader(
      tester,
      initialPage: 0,
      onTap: () => taps++,
      onLongPress: () => longPresses++,
    );
    await beginPageSnap(tester, pages);
    final vertical = await tester.startGesture(_touch);
    await vertical.moveBy(const Offset(2, -50));
    await tester.pump(_frame);
    await vertical.moveBy(const Offset(2, -100));
    await tester.pump(_frame);
    expect(verticalPosition(tester, 1).pixels, greaterThan(40));
    await vertical.up();
    await tester.pumpAndSettle();
    expect(pages.page, closeTo(1, .001));
    expect(taps, 0);
    expect(longPresses, 0);
  });

  for (final dx in [-5.0, 5.0]) {
    for (final dy in [-40.0, 40.0]) {
      testWidgets('short page vertical diagonal ($dx, $dy) stays put', (
        tester,
      ) async {
        final pages = await mountReader(tester, short: true);
        expect(verticalPosition(tester, 1).maxScrollExtent, 0);
        final gesture = await tester.startGesture(_touch);
        for (var i = 0; i < 5; i++) {
          await gesture.moveBy(Offset(dx, dy));
          await tester.pump(_frame);
          // Check while the pointer is down, not just after snapping back.
          expect(pages.page, closeTo(1, .001));
          expect(verticalPosition(tester, 1).pixels, 0);
        }
        await gesture.up();
        await tester.pumpAndSettle();
        expect(pages.page, closeTo(1, .001));
      });
    }
  }

  for (final short in [false, true]) {
    testWidgets('deliberate horizontal RTL navigation, short=$short', (
      tester,
    ) async {
      var taps = 0;
      var longPresses = 0;
      final pages = await mountReader(
        tester,
        short: short,
        onTap: () => taps++,
        onLongPress: () => longPresses++,
      );
      await horizontalSwipe(tester, 280);
      expect(pages.page, closeTo(2, .001));
      expect(verticalPosition(tester, 2).pixels, 0);
      await horizontalSwipe(tester, -280);
      expect(pages.page, closeTo(1, .001));
      expect(verticalPosition(tester, 1).pixels, 0);
      expect(taps, 0);
      expect(longPresses, 0);
    });
  }

  for (final page in [0, 2]) {
    testWidgets('outward RTL swipe respects page $page boundary', (
      tester,
    ) async {
      final pages = await mountReader(tester, initialPage: page);
      await horizontalSwipe(tester, page == 0 ? -280 : 280);
      expect(pages.page, closeTo(page.toDouble(), .001));
      expect(pages.position.outOfRange, isFalse);
      // An edge rejection must not leave the next legitimate gesture stuck.
      await horizontalSwipe(tester, page == 0 ? 280 : -280);
      expect(pages.page, closeTo(1, .001));
    });
  }

  for (final duringSnap in [false, true]) {
    testWidgets('tap remains available, duringSnap=$duringSnap', (
      tester,
    ) async {
      var taps = 0;
      var longPresses = 0;
      final pages = await mountReader(
        tester,
        initialPage: duringSnap ? 0 : 1,
        onTap: () => taps++,
        onLongPress: () => longPresses++,
      );
      if (duringSnap) await beginPageSnap(tester, pages);
      await tester.tapAt(_touch);
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(longPresses, 0);
      expect(pages.page, closeTo(1, .001));
      expect(verticalPosition(tester, 1).pixels, 0);
    });

    testWidgets('long press remains available, duringSnap=$duringSnap', (
      tester,
    ) async {
      var taps = 0;
      var longPresses = 0;
      final pages = await mountReader(
        tester,
        initialPage: duringSnap ? 0 : 1,
        onTap: () => taps++,
        onLongPress: () => longPresses++,
      );
      if (duringSnap) await beginPageSnap(tester, pages);
      final press = await tester.startGesture(_touch);
      await tester.pump(const Duration(milliseconds: 600));
      expect(longPresses, 1);
      expect(taps, 0);
      await press.up();
      await tester.pumpAndSettle();
      expect(longPresses, 1);
      expect(taps, 0);
      expect(pages.page, closeTo(1, .001));
    });
  }

  for (final movement in [
    Offset.zero,
    const Offset(90, 2),
    const Offset(2, -90),
  ]) {
    testWidgets('pointer cancel $movement releases arena without actions', (
      tester,
    ) async {
      var taps = 0;
      var longPresses = 0;
      final pages = await mountReader(
        tester,
        onTap: () => taps++,
        onLongPress: () => longPresses++,
      );
      final gesture = await tester.startGesture(_touch);
      if (movement != Offset.zero) {
        await gesture.moveBy(movement);
        await tester.pump(_frame);
        await gesture.moveBy(movement);
        await tester.pump(_frame);
        if (movement.dx > movement.dy.abs()) {
          expect(pages.page, greaterThan(1));
        } else {
          expect(verticalPosition(tester, 1).pixels, greaterThan(0));
        }
      }
      await gesture.cancel();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 600));
      expect(taps, 0);
      expect(longPresses, 0);
      expect(pages.page, closeTo(1, .001));
      expect(pages.position.isScrollingNotifier.value, isFalse);
      expect(verticalPosition(tester, 1).isScrollingNotifier.value, isFalse);
      await tester.tapAt(_touch);
      await tester.pumpAndSettle();
      expect(taps, 1);
      await horizontalSwipe(tester, 280);
      expect(pages.page, closeTo(2, .001));
    });
  }

  testWidgets('cancel during snap settles and accepts the next vertical drag', (
    tester,
  ) async {
    var taps = 0;
    var longPresses = 0;
    final pages = await mountReader(
      tester,
      initialPage: 0,
      onTap: () => taps++,
      onLongPress: () => longPresses++,
    );
    await beginPageSnap(tester, pages);
    final touch = await tester.startGesture(_touch);
    await touch.cancel();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 600));
    expect(pages.page, closeTo(1, .001));
    expect(taps, 0);
    expect(longPresses, 0);
    await tester.dragFrom(_touch, const Offset(2, -150));
    await tester.pumpAndSettle();
    expect(verticalPosition(tester, 1).pixels, greaterThan(40));
    expect(pages.page, closeTo(1, .001));
  });
}
