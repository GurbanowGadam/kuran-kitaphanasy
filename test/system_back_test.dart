import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuran_kitaphanasy/main.dart';
import 'package:kuran_kitaphanasy/reader_data.dart';

import 'reader_fixture.dart';

void main() {
  var exits = 0;
  setUp(() {
    exits = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'SystemNavigator.pop') exits++;
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> back(WidgetTester t) async {
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
  }

  testWidgets('system back returns to library and retains reading position', (
    t,
  ) async {
    await openReader(t);
    await t.drag(find.byKey(const Key('quran-pages')), const Offset(650, 0));
    await t.pumpAndSettle();
    expect(find.text('Sahypa 2 (2/9)'), findsOneWidget);
    await back(t);
    expect(exits, 0);
    expect(find.byKey(const Key('book-quran')), findsOneWidget);
    expect(find.byKey(const Key('quran-pages')), findsNothing);
    await t.tap(find.byKey(const Key('book-quran')));
    await t.pumpAndSettle();
    expect(find.text('Sahypa 2 (2/9)'), findsOneWidget);
    await back(t);
    await back(t);
    expect(exits, 1, reason: 'library back must remain an app exit');
  });

  testWidgets('back dismisses modal then reader, without exiting', (t) async {
    await openReader(t);
    await t.tap(find.byKey(const Key('surah-menu')));
    await t.pumpAndSettle();
    await back(t);
    expect(find.byKey(const Key('surah-sheet')), findsNothing);
    expect(find.byKey(const Key('quran-pages')), findsOneWidget);
    expect(exits, 0);
    await back(t);
    expect(find.byKey(const Key('book-quran')), findsOneWidget);
    expect(exits, 0);
  });

  testWidgets('fullscreen back restores chrome before returning to library', (
    t,
  ) async {
    await openReader(t);
    await t.tap(find.byKey(const Key('reader-fullscreen')));
    await t.pumpAndSettle();
    await t.pump(const Duration(seconds: 3));
    expect(find.byType(AppBar), findsNothing);
    await back(t);
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byKey(const Key('quran-pages')), findsOneWidget);
    expect(exits, 0);
    await back(t);
    expect(find.byKey(const Key('book-quran')), findsOneWidget);
    expect(exits, 0);
  });

  for (final failed in [false, true]) {
    testWidgets('system back leaves book while data pending/error=$failed', (
      t,
    ) async {
      final pending = Completer<ReaderData>();
      await t.pumpWidget(QuranApp(data: pending.future));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('book-quran')));
      await t.pump();
      if (failed) {
        pending.completeError(StateError('test source failed'));
        await t.pumpAndSettle();
        expect(find.byKey(const Key('reader-load-error')), findsOneWidget);
      }
      await t.binding.handlePopRoute();
      await t.pump();
      expect(exits, 0);
      expect(find.byKey(const Key('book-quran')), findsOneWidget);
      if (!failed) {
        pending.complete(fixture());
        await t.pumpAndSettle();
      }
    });
  }
}
