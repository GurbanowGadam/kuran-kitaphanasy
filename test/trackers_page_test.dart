import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuran_kitaphanasy/main.dart';
import 'package:kuran_kitaphanasy/trackers/data/tracker_book.dart';
import 'package:kuran_kitaphanasy/trackers/domain/tracker.dart';

import 'reader_fixture.dart';

Future<MemoryTrackerStore> openTrackers(
  WidgetTester t, {
  MemoryTrackerStore? store,
}) async {
  final s = store ?? MemoryTrackerStore();
  await t.pumpWidget(QuranApp(data: Future.value(fixture()), trackerStore: s));
  await t.pumpAndSettle();
  await t.tap(find.byKey(const Key('tab-trackers')));
  await t.pumpAndSettle();
  return s;
}

Future<void> chooseTemplate(WidgetTester t, String key) async {
  await t.tap(find.byKey(const Key('tracker-add')));
  await t.pumpAndSettle();
  await t.ensureVisible(find.byKey(Key('template-$key')));
  await t.pumpAndSettle();
  await t.tap(find.byKey(Key('template-$key')));
  await t.pumpAndSettle();
}

Future<void> save(WidgetTester t) async {
  await t.tap(find.byKey(const Key('editor-save')));
  await t.pumpAndSettle();
}

Tracker only(MemoryTrackerStore s) =>
    decodeTrackers(jsonDecode(s.value!)).single;

String valueText(WidgetTester t, String id) {
  final w = t.widget(find.byKey(Key('tracker-value-$id')));
  return w is Text ? (w.data ?? w.textSpan!.toPlainText()) : '';
}

void main() {
  testWidgets('bottom navigation shows Kitaphana, Hasaplar, Sazlamalar', (
    t,
  ) async {
    await t.pumpWidget(QuranApp(data: Future.value(fixture())));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('main-navigation')), findsOneWidget);
    expect(find.byKey(const Key('library-title')), findsOneWidget);
    for (final label in ['Kitaphana', 'Hasaplar', 'Sazlamalar']) {
      expect(
        find.descendant(
          of: find.byKey(const Key('main-navigation')),
          matching: find.text(label),
        ),
        findsOneWidget,
      );
    }
    await t.tap(find.byKey(const Key('tab-trackers')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('trackers-empty')), findsOneWidget);
    // System back from another tab returns to the library, not out of the app.
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(
      find.byKey(const Key('library-title')).hitTestable(),
      findsOneWidget,
    );
    // The reader stays full screen without the bottom navigation.
    await t.tap(find.byKey(const Key('book-quran')));
    await t.pumpAndSettle();
    expect(
      find.byKey(const Key('main-navigation')).hitTestable(),
      findsNothing,
    );
  });

  testWidgets('kaza template fills every prayer and counts down', (t) async {
    final store = await openTrackers(t);
    await chooseTemplate(t, 'kaza');
    expect(find.byKey(const Key('editor-item-label-0')), findsOneWidget);
    await t.enterText(find.byKey(const Key('editor-years')), '1');
    await t.enterText(find.byKey(const Key('editor-days')), '10');
    await t.tap(find.byKey(const Key('editor-fill')));
    await t.pumpAndSettle();
    await save(t);
    var k = only(store);
    expect(k.kind, TrackerKind.debt);
    expect(k.items.map((i) => i.label), kazaPrayers);
    expect(k.items.every((i) => i.value == 375 && i.target == 375), isTrue);

    await t.tap(find.byKey(Key('tracker-done-${k.id}-0')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(Key('tracker-done-${k.id}-0')));
    await t.tap(find.byKey(Key('tracker-undo-${k.id}-0')));
    await t.pumpAndSettle();
    expect(valueText(t, k.id), 'Galan: 2249 namaz');
    // Several at once through the amount dialog.
    await t.tap(find.byKey(Key('tracker-amount-${k.id}-1')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('amount-field')), '5');
    await t.tap(find.byKey(const Key('amount-add')));
    await t.pumpAndSettle();
    expect(find.text('Bu gün: 6 · Tamamlanan: 0%'), findsOneWidget);
    k = only(store);
    expect(k.items[0].value, 374);
    expect(k.items[1].value, 370);
  });

  testWidgets('tesbih counts taps and resets for a new round', (t) async {
    final store = await openTrackers(t);
    await chooseTemplate(t, 'tesbih');
    await save(t);
    final id = only(store).id;
    for (var i = 0; i < 3; i++) {
      await t.tap(find.byKey(Key('tracker-inc-$id')));
    }
    await t.pumpAndSettle();
    expect(valueText(t, id), '3 / 33');
    expect(find.text('Bu gün: 3 gezek'), findsOneWidget);
    await t.tap(find.byKey(Key('tracker-menu-$id')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('tracker-reset')));
    await t.pumpAndSettle();
    expect(valueText(t, id), '0 / 33');
    expect(find.text('Bu gün: 3 gezek'), findsOneWidget);
  });

  testWidgets('custom progress tracker, edit and delete', (t) async {
    final store = await openTrackers(t);
    await chooseTemplate(t, 'custom');
    await t.tap(find.byKey(const Key('editor-kind')));
    await t.pumpAndSettle();
    await t.tap(find.text('Maksada çenli').last);
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('editor-name')), 'Riýazus-salihin');
    await t.enterText(find.byKey(const Key('editor-unit')), 'sahypa');
    await save(t);
    // Target is required for progress: fail closed, stay on the form.
    expect(find.text('San giriziň'), findsOneWidget);
    await t.enterText(find.byKey(const Key('editor-target')), '400');
    await t.enterText(find.byKey(const Key('editor-value')), '500');
    await save(t);
    expect(find.text('Maksatdan köp bolup bilmez'), findsOneWidget);
    await t.enterText(find.byKey(const Key('editor-value')), '20');
    await save(t);
    final id = only(store).id;
    expect(valueText(t, id), '20 / 400 sahypa · 5%');
    await t.tap(find.byKey(Key('tracker-amount-$id-0')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('amount-field')), '25');
    await t.tap(find.byKey(const Key('amount-add')));
    await t.pumpAndSettle();
    expect(valueText(t, id), '45 / 400 sahypa · 11%');

    await t.tap(find.byKey(Key('tracker-menu-$id')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('tracker-edit')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('editor-name')), 'Hadys kitaby');
    await save(t);
    expect(find.text('Hadys kitaby'), findsOneWidget);
    expect(only(store).today(DateTime.now()), 25);

    await t.tap(find.byKey(Key('tracker-menu-$id')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('tracker-delete')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('tracker-delete-confirm')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('trackers-empty')), findsOneWidget);
    expect(decodeTrackers(jsonDecode(store.value!)), isEmpty);
  });

  testWidgets('habit marks today and shows the streak', (t) async {
    final store = await openTrackers(t);
    await chooseTemplate(t, 'habit');
    await t.enterText(find.byKey(const Key('editor-name')), 'Oraza');
    await save(t);
    final id = only(store).id;
    expect(valueText(t, id), 'Yzygiderlilik: 0 gün');
    await t.tap(find.byKey(Key('tracker-today-$id')));
    await t.pumpAndSettle();
    expect(valueText(t, id), 'Yzygiderlilik: 1 gün');
    expect(find.text('Bu gün edildi'), findsOneWidget);
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    await t.tap(find.byKey(Key('tracker-day-$id-${dayKey(yesterday)}')));
    await t.pumpAndSettle();
    expect(valueText(t, id), 'Yzygiderlilik: 2 gün');
  });

  testWidgets('corrupt saved trackers are shown as an error, never replaced', (
    t,
  ) async {
    final store = await openTrackers(t, store: MemoryTrackerStore('[oops'));
    expect(find.byKey(const Key('trackers-load-error')), findsOneWidget);
    expect(find.byKey(const Key('tracker-add')), findsNothing);
    await t.tap(find.byKey(const Key('trackers-retry')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('trackers-load-error')), findsOneWidget);
    expect(store.saves, 0);
    expect(store.value, '[oops');
  });

  testWidgets('Sazlamalar exports and restores trackers through clipboard', (
    t,
  ) async {
    String? clipboard;
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String;
        }
        if (call.method == 'Clipboard.getData') return {'text': clipboard};
        return null;
      },
    );
    addTearDown(
      () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final backup = jsonEncode(
      encodeTrackers([
        const Tracker(id: 'a', name: 'Oraza', kind: TrackerKind.habit),
      ]),
    );
    final store = MemoryTrackerStore(backup);
    await t.pumpWidget(
      QuranApp(data: Future.value(fixture()), trackerStore: store),
    );
    await t.pumpAndSettle();
    // Export works before the Hasaplar tab was ever opened.
    await t.tap(find.byKey(const Key('tab-settings')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('settings-export')));
    await t.pumpAndSettle();
    expect(decodeTrackers(jsonDecode(clipboard!)).single.name, 'Oraza');

    await t.tap(find.byKey(const Key('settings-import')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('import-field')), '{"x": 1}');
    await t.tap(find.byKey(const Key('import-confirm')));
    await t.pumpAndSettle();
    expect(
      find.text('Ätiýaçlyk nusga nädogry. Hiç zat üýtgedilmedi.'),
      findsOneWidget,
    );
    clipboard = jsonEncode(
      encodeTrackers([
        const Tracker(id: 'b', name: 'Sadaka', kind: TrackerKind.habit),
        const Tracker(id: 'c', name: 'Zikir', kind: TrackerKind.habit),
      ]),
    );
    await t.tap(find.byKey(const Key('import-paste')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('import-confirm')));
    await t.pumpAndSettle();
    expect(
      find.text(
        'Häzirki 1 hasap ätiýaçlyk nusgadaky 2 hasap bilen çalşyrylar.',
      ),
      findsOneWidget,
    );
    await t.tap(find.byKey(const Key('import-replace')));
    await t.pumpAndSettle();
    expect(decodeTrackers(jsonDecode(store.value!)).map((t) => t.name), [
      'Sadaka',
      'Zikir',
    ]);
  });

  testWidgets('every tracker kind fits 320px at 1.8x text', (t) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    final store = MemoryTrackerStore(
      jsonEncode(
        encodeTrackers([
          for (final tpl in trackerTemplates)
            Tracker(
              id: tpl.key,
              name: tpl.name,
              kind: tpl.kind,
              unit: tpl.unit,
              step: tpl.step,
              items: switch (tpl.kind) {
                TrackerKind.debt => [
                  for (final l in tpl.labels)
                    TrackerItem(label: l, value: 12345, target: 20000),
                ],
                TrackerKind.habit => const [],
                _ => [TrackerItem(label: '', value: 7, target: tpl.target)],
              },
            ),
        ]),
      ),
    );
    await openTrackers(t, store: store);
    expect(t.takeException(), isNull);
    for (final tpl in trackerTemplates) {
      await t.scrollUntilVisible(
        find.byKey(Key('tracker-${tpl.key}')),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull, reason: tpl.key);
    }
    await t.tap(find.byKey(const Key('tab-settings')));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
}
