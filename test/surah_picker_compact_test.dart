import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuran_kitaphanasy/reader/presentation/reader.dart';
import 'package:kuran_kitaphanasy/reader/presentation/surah_picker_list.dart';
import 'package:kuran_kitaphanasy/reader/settings/reader_preferences.dart';

import 'reader_fixture.dart';

void main() {
  Future<void> open(WidgetTester t) async {
    await t.pumpWidget(
      MaterialApp(
        home: Reader(
          data: Future.value(fixture()),
          store: MemoryReaderStore(),
          goHome: () {},
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('surah-menu')));
    await t.pumpAndSettle();
  }

  testWidgets('surah sheet heading and close artwork are compact', (t) async {
    await open(t);
    final header = find.byKey(const Key('surah-sheet-header'));
    final title = t.widget<Text>(
      find.descendant(of: header, matching: find.text('Süreler')),
    );
    expect(title.style!.fontSize, 18);
    final close = find.descendant(
      of: header,
      matching: find.byType(IconButton),
    );
    expect((t.widget<IconButton>(close).icon as Icon).size, 20);
    expect(t.getSize(close).height, greaterThanOrEqualTo(48));
  });
  testWidgets('surah rows use smaller typography artwork and spacing', (
    t,
  ) async {
    await open(t);
    final row = find.byKey(const Key('surah-1'));
    final tile = t.widget<ListTile>(row);
    expect((tile.title as Text).style!.fontSize, 14);
    expect(
      t.getSize(find.byKey(const Key('surah-origin-1'))),
      const Size(24, 26),
    );
    expect(t.getSize(row).height, lessThanOrEqualTo(78));
    expect(t.getSize(row).height, greaterThanOrEqualTo(48));
    final metadata = (tile.subtitle as Padding).child as Text;
    expect(metadata.style!.fontSize, 11);
    final badge = t.widget<Container>(find.byKey(const Key('surah-page-1')));
    expect((badge.child as Text).style!.fontSize, 11);
  });
  testWidgets('surah search is compact but remains a full touch target', (
    t,
  ) async {
    await open(t);
    final field = find.byKey(const Key('surah-name-search'));
    final widget = t.widget<TextField>(field);
    expect(
      (widget.style ?? Theme.of(t.element(field)).textTheme.bodyLarge)!
          .fontSize,
      14,
    );
    expect((widget.decoration!.prefixIcon as Icon).size, 20);
    expect(t.getSize(field).height, inInclusiveRange(48, 52));
    await t.enterText(field, 'Bakara');
    await t.pumpAndSettle();
    expect(find.byKey(const Key('surah-1')), findsNothing);
    expect(find.byKey(const Key('surah-2')), findsOneWidget);
    expect(find.byType(SurahPickerList), findsOneWidget);
  });
}
