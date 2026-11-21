import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kuran_kitaphanasy/trackers/data/tracker_book.dart';
import 'package:kuran_kitaphanasy/trackers/domain/tracker.dart';

Tracker kaza({int days = 10}) => Tracker(
  id: 'k',
  name: 'Kaza namazlary',
  kind: TrackerKind.debt,
  unit: 'namaz',
  items: [
    for (final p in kazaPrayers)
      TrackerItem(label: p, value: days, target: days),
  ],
);

void main() {
  final day1 = DateTime(2026, 11, 20, 9);
  final day2 = DateTime(2026, 11, 21, 23, 59);
  final day3 = DateTime(2026, 11, 22, 0, 1);

  test('debt counts down, never below zero, and logs the day', () {
    var t = kaza(days: 2);
    t = t.record(0, 1, day1).record(0, 1, day1).record(0, 1, day1);
    expect(t.items[0].value, 0);
    expect(t.today(day1), 2);
    expect(t.total, 10);
    expect(t.fraction, closeTo(2 / 12, 1e-9));
    // Correction adds the prayer back and reduces today's log.
    t = t.record(0, -1, day1);
    expect(t.items[0].value, 1);
    expect(t.today(day1), 1);
    // Corrections cannot exceed the initial total.
    t = t.record(1, -5, day1);
    expect(t.items[1].value, 7);
  });

  test('progress clamps to target; counter rounds wrap', () {
    var book = const Tracker(
      id: 'b',
      name: 'Kitap',
      kind: TrackerKind.progress,
      items: [TrackerItem(label: '', value: 290, target: 300)],
    );
    book = book.record(0, 25, day1);
    expect(book.items.first.value, 300);
    expect(book.today(day1), 10);
    expect(book.fraction, 1);

    var tesbih = const Tracker(
      id: 't',
      name: 'Tesbih',
      kind: TrackerKind.counter,
      items: [TrackerItem(label: '', value: 0, target: 33)],
    );
    for (var i = 0; i < 33; i++) {
      tesbih = tesbih.record(0, 1, day1);
    }
    expect(tesbih.fraction, 1);
    tesbih = tesbih.record(0, 1, day1);
    expect(tesbih.fraction, closeTo(1 / 33, 1e-9));
    expect(tesbih.resetCount().items.first.value, 0);
    expect(tesbih.resetCount().today(day1), 34);
  });

  test('habit streak counts consecutive local days', () {
    var habit = const Tracker(id: 'h', name: 'Oraza', kind: TrackerKind.habit);
    habit = habit.toggleDay(day1).toggleDay(day2);
    expect(habit.streak(day2), 2);
    // Today still open: yesterday's streak is kept.
    expect(habit.streak(day3), 2);
    habit = habit.toggleDay(day3);
    expect(habit.streak(day3), 3);
    habit = habit.toggleDay(day2);
    expect(habit.streak(day3), 1);
  });

  test('encode/decode round trips and rejects anything inexact', () {
    final list = [kaza().record(2, 3, day1)];
    final json = jsonDecode(jsonEncode(encodeTrackers(list)));
    final back = decodeTrackers(json);
    expect(jsonEncode(encodeTrackers(back)), jsonEncode(encodeTrackers(list)));

    Map<String, dynamic> mutate(void Function(Map<String, dynamic>) f) {
      final copy = jsonDecode(jsonEncode(json)) as Map<String, dynamic>;
      f(copy);
      return copy;
    }

    for (final bad in [
      mutate((j) => j['version'] = 2),
      mutate((j) => j['format'] = 'other'),
      mutate((j) => j['trackers'][0]['kind'] = 'mystery'),
      mutate((j) => j['trackers'][0]['items'][0]['value'] = -1),
      mutate((j) => j['trackers'][0]['items'][0]['value'] = 99),
      mutate((j) => j['trackers'][0]['items'][0]['value'] = '3'),
      mutate((j) => j['trackers'][0]['days'] = {'yesterday': 1}),
      mutate((j) => j['trackers'][0]['name'] = ' '),
      mutate((j) => j['trackers'].add(j['trackers'][0])),
    ]) {
      expect(() => decodeTrackers(bad), throwsFormatException);
    }
  });

  test('corrupt storage stays untouched and the book is read-only', () async {
    final store = MemoryTrackerStore('{"format": broken');
    final book = TrackerBook(store: store);
    await book.load();
    expect(book.state, TrackerBookState.failed);
    book.add(kaza());
    await book.flush();
    expect(store.saves, 0);
    expect(store.value, '{"format": broken');
  });

  test('rapid edits are coalesced and persisted in order', () async {
    final store = MemoryTrackerStore();
    final book = TrackerBook(store: store, clock: () => day1);
    await book.load();
    expect(book.state, TrackerBookState.ready);
    book.add(
      const Tracker(
        id: 't',
        name: 'Tesbih',
        kind: TrackerKind.counter,
        items: [TrackerItem(label: '', value: 0, target: 33)],
      ),
    );
    for (var i = 0; i < 50; i++) {
      book.record('t', 0, 1);
    }
    await book.flush();
    expect(store.saves, lessThan(51));
    final restored = TrackerBook(store: store);
    await restored.load();
    expect(restored.trackers.single.items.single.value, 50);
    expect(restored.trackers.single.today(day1), 50);
  });

  test('templates all produce valid trackers', () {
    for (final t in trackerTemplates) {
      final tracker = Tracker(
        id: t.key,
        name: t.name,
        kind: t.kind,
        unit: t.unit,
        step: t.step,
        items: switch (t.kind) {
          TrackerKind.debt => [
            for (final l in t.labels)
              TrackerItem(label: l, value: 0, target: 0),
          ],
          TrackerKind.habit => const [],
          _ => [TrackerItem(label: '', value: 0, target: t.target)],
        },
      );
      expect(Tracker.problem(tracker), isNull, reason: t.key);
    }
  });
}
