import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:kuran_kitaphanasy/reader_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuran_kitaphanasy/reader/presentation/reader.dart';
import 'package:kuran_kitaphanasy/reader/settings/reader_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'reader_fixture.dart';

void main() {
  for (final mode in ['both', 'translation', 'arabic']) {
    testWidgets(
      '$mode chooser reuses named marker with feedback and persistence',
      (t) async {
        SharedPreferences.setMockInitialValues({});
        final store = SharedPreferencesReaderStore();
        await store.write('quran', ReaderPreferences(mode: mode).toJson());
        await store.write('quran.bookmarks', {
          'version': 1,
          'items': [
            {
              'name': 'Okalýan ýer',
              'page': 2,
              'surah': 2,
              'ayah': 2,
              'mode': 'translation',
            },
          ],
        });
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
        Future<void> start() async {
          await t.pumpWidget(
            MaterialApp(
              home: Reader(
                data: Future.value(fixture()),
                store: SharedPreferencesReaderStore(),
                goHome: () {},
              ),
            ),
          );
          await t.pumpAndSettle();
        }

        await start();
        final target = find.byKey(
          Key(mode == 'arabic' ? 'arabic-flow-1' : 'translation-t1'),
        );
        await t.longPressAt(t.getTopRight(target) + const Offset(-30, 20));
        await t.pump();
        expect(find.byKey(const Key('verse-actions')), findsOneWidget);
        expect(find.byKey(const Key('bookmark-feedback-1:1')), findsOneWidget);
        expect(calls.any((c) => c.method == 'HapticFeedback.vibrate'), isTrue);
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('verse-bookmarks')));
        await t.pumpAndSettle();
        expect(find.byKey(const Key('bookmark-chooser')), findsOneWidget);
        expect(find.byKey(const Key('bookmark-name')), findsNothing);
        await t.tap(find.text('Okalýan ýer'));
        await t.pumpAndSettle();
        final saved = await SharedPreferencesReaderStore().read(
          'quran.bookmarks',
        );
        expect(saved!['items'], [
          {
            'name': 'Okalýan ýer',
            'page': 1,
            'surah': 1,
            'ayah': 1,
            'mode': mode,
          },
        ]);
        await t.pump(const Duration(seconds: 1));
        expect(find.byKey(const Key('bookmark-feedback-1:1')), findsNothing);
        await t.pumpWidget(const SizedBox());
        await t.pumpAndSettle();
        await start();
        await t.tap(find.byKey(const Key('bookmarks-menu')));
        await t.pumpAndSettle();
        expect(find.text('Okalýan ýer'), findsOneWidget);
        await t.tap(find.text('Okalýan ýer'));
        await t.pumpAndSettle();
        expect(find.byKey(const Key('bookmark-icon-1:1')), findsOneWidget);
      },
    );
  }

  testWidgets(
    'group spanning pages bookmarks its visible continuation and survives restart',
    (t) async {
      final docs = fixtureDocuments();
      final rows = docs['translations']['items'] as List;
      rows[1]['toAyah'] = 2;
      rows.removeAt(2);
      final data = ReaderData.fromDocuments(docs);
      final store = MemoryReaderStore();
      await store.write(
        'quran',
        ReaderPreferences(page: 1, mode: 'translation').toJson(),
      );
      Future<void> start() async {
        await t.pumpWidget(
          MaterialApp(
            home: Reader(data: Future.value(data), store: store, goHome: () {}),
          ),
        );
        await t.pumpAndSettle();
      }

      await start();
      await t.longPressAt(
        t.getTopLeft(find.byKey(const Key('translation-t2'))) +
            const Offset(30, 20),
      );
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('verse-bookmarks')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('bookmark-add')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('bookmark-name')), 'Dowamy');
      await t.tap(find.text('Ýatda sakla'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('bookmark-icon-2:2')), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
      await start();
      await t.tap(find.byKey(const Key('bookmarks-menu')));
      await t.pumpAndSettle();
      expect(find.text('Dowamy'), findsOneWidget);
      await t.tap(find.text('Dowamy'));
      await t.pumpAndSettle();
      expect(find.text('Sahypa 2 (2/9)'), findsOneWidget);
      expect(
        t
            .widget<Text>(find.byKey(const Key('translation-t2')))
            .textSpan!
            .toPlainText(),
        startsWith('1–2. '),
      );
    },
  );

  for (final vertical in [false, true]) {
    testWidgets(
      'Arabic exact later ayah navigation from unmounted page vertical=$vertical',
      (t) async {
        final docs = fixtureDocuments();
        (docs['verses']['items'] as List).first['text'] = List.filled(
          100,
          'بِسْمِ اللّٰهِ',
        ).join(' ');
        (docs['pages']['items'] as List).first['verses'].add({
          'surah': 1,
          'ayah': 2,
        });
        (docs['verses']['items'] as List).insert(1, {
          'surah': 1,
          'ayah': 2,
          'text': 'اللّٰهِ',
        });
        (docs['translations']['items'] as List).first['toAyah'] = 2;
        final data = ReaderData.fromDocuments(docs);
        final store = MemoryReaderStore();
        await store.write(
          'quran',
          ReaderPreferences(
            page: 7,
            mode: 'translation',
            vertical: vertical,
          ).toJson(),
        );
        await store.write('quran.bookmarks', {
          'version': 1,
          'items': [
            {
              'name': 'Ikinji aýat',
              'page': 1,
              'surah': 1,
              'ayah': 2,
              'mode': 'arabic',
            },
          ],
        });
        await t.pumpWidget(
          MaterialApp(
            home: Reader(data: Future.value(data), store: store, goHome: () {}),
          ),
        );
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('bookmarks-menu')));
        await t.pumpAndSettle();
        await t.tap(find.text('Ikinji aýat'));
        await t.pumpAndSettle();
        final text = find.byKey(const Key('arabic-flow-1'));
        final paragraph = t.renderObject<RenderParagraph>(
          find.descendant(of: text, matching: find.byType(RichText)).first,
        );
        final plain = paragraph.text.toPlainText(includeSemanticsLabels: false);
        final offset = plain.lastIndexOf('اللّٰهِ');
        final box = paragraph
            .getBoxesForSelection(
              TextSelection(baseOffset: offset, extentOffset: offset + 1),
            )
            .first;
        final position = paragraph.localToGlobal(box.toRect().center);
        expect(position.dy, greaterThan(76));
        expect(position.dy, lessThan(550));
        await t.longPressAt(position);
        await t.pump();
        final feedback = find.byKey(const Key('bookmark-feedback-1:2'));
        expect(feedback, findsOneWidget);
        final dynamic painter = t
            .widget<CustomPaint>(
              find.descendant(of: feedback, matching: find.byType(CustomPaint)),
            )
            .painter;
        final rectangles = painter.rectangles() as List<Rect>;
        final expected = paragraph
            .getBoxesForSelection(
              TextSelection(baseOffset: offset, extentOffset: plain.length),
            )
            .map((box) => box.toRect())
            .toList();
        expect(rectangles, expected);
        expect(rectangles.every((rect) => rect.top >= box.top), isTrue);
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('verse-bookmarks')));
        await t.pumpAndSettle();
        expect(find.byKey(const Key('bookmark-chooser')), findsOneWidget);
        expect(find.text('Ikinji aýat'), findsOneWidget);
        expect(find.byKey(const Key('bookmark-name')), findsNothing);
        await t.tap(find.text('Ikinji aýat'));
        await t.pumpAndSettle();
        // The existing continuous paragraph and grouped translation remain intact.
        expect(
          plain.replaceAll('\uFFFC', ''),
          contains((docs['verses']['items'] as List).first['text']),
        );
        expect(data.blocksFor(data.pages.first).first.range, '1–2');
        expect(t.takeException(), isNull);
        if (vertical) {
          expect(find.byType(ScrollablePositionedList), findsOneWidget);
        }
      },
    );
  }

  for (final mode in ['both', 'translation', 'arabic']) {
    for (final vertical in [false, true]) {
      testWidgets(
        '$mode $vertical named bookmarks survive widget restart and navigate',
        (t) async {
          SharedPreferences.setMockInitialValues({});
          final store = SharedPreferencesReaderStore();
          await store.write(
            'quran',
            ReaderPreferences(
              mode: mode,
              vertical: vertical,
              dark: vertical,
            ).toJson(),
          );
          t.view.physicalSize = const Size(320, 900);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          Future<void> start([String book = 'quran']) async {
            await t.pumpWidget(
              MaterialApp(
                home: Reader(
                  bookId: book,
                  data: Future.value(fixture()),
                  store: SharedPreferencesReaderStore(),
                  goHome: () {},
                ),
              ),
            );
            await t.pumpAndSettle();
          }

          await start();
          expect(find.byKey(const Key('bookmarks-menu')), findsOneWidget);
          expect(
            t.getCenter(find.byKey(const Key('bookmarks-menu'))).dx,
            greaterThan(t.getCenter(find.byKey(const Key('surah-menu'))).dx),
          );
          final target = find.byKey(
            Key(mode == 'arabic' ? 'arabic-flow-1' : 'translation-t1'),
          );
          await t.longPressAt(t.getTopRight(target) + const Offset(-30, 20));
          await t.pumpAndSettle();
          await t.tap(find.byKey(const Key('verse-bookmarks')));
          await t.pumpAndSettle();
          expect(find.byKey(const Key('bookmark-chooser')), findsOneWidget);
          await t.tap(find.byKey(const Key('bookmark-add')));
          await t.pumpAndSettle();
          expect(find.byKey(const Key('bookmark-name')), findsOneWidget);
          await t.enterText(
            find.byKey(const Key('bookmark-name')),
            'Meniň belligim',
          );
          await t.tap(find.text('Ýatda sakla'));
          await t.pumpAndSettle();
          expect(find.byKey(const Key('bookmark-icon-1:1')), findsOneWidget);
          await t.pumpWidget(const SizedBox());
          await t.pumpAndSettle();
          await start();
          if (vertical) {
            t
                .widget<ScrollablePositionedList>(
                  find.byType(ScrollablePositionedList),
                )
                .itemScrollController!
                .jumpTo(index: 7);
          } else {
            t
                .widget<PageView>(find.byKey(const Key('quran-pages')))
                .controller!
                .jumpToPage(7);
          }
          await t.pumpAndSettle();
          // Short Arabic-only pages at the book end clamp to the final viewport.
          expect(
            t.widget<Text>(find.byKey(const Key('page-counter'))).data,
            isNot('Sahypa 1 (1/9)'),
          );
          await t.tap(find.byKey(const Key('bookmarks-menu')));
          await t.pumpAndSettle();
          expect(find.text('Meniň belligim'), findsOneWidget);
          await t.tap(find.byTooltip('Adyny üýtget'));
          await t.pumpAndSettle();
          await t.enterText(find.byKey(const Key('bookmark-name')), 'Täze at');
          await t.tap(find.text('Ýatda sakla'));
          await t.pumpAndSettle();
          await t.tap(find.text('Täze at'));
          await t.pumpAndSettle();
          expect(find.byKey(const Key('bookmarks-sheet')), findsNothing);
          expect(find.text('Sahypa 1 (1/9)'), findsOneWidget);
          final markerPosition = t.getCenter(
            find.byKey(const Key('bookmark-icon-1:1')),
          );
          expect(markerPosition.dy, greaterThanOrEqualTo(76));
          expect(markerPosition.dy, lessThan(852));
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox());
          await t.pumpAndSettle();
          await start('other-book');
          await t.tap(find.byKey(const Key('bookmarks-menu')));
          await t.pumpAndSettle();
          expect(find.text('Täze at'), findsNothing);
          await t.pumpWidget(const SizedBox());
          await t.pumpAndSettle();
          await start();
          await t.tap(find.byKey(const Key('bookmarks-menu')));
          await t.pumpAndSettle();
          await t.tap(find.byTooltip('Poz'));
          await t.pumpAndSettle();
          await t.tap(find.text('Poz').last);
          await t.pumpAndSettle();
          expect(find.text('Täze at'), findsNothing);
          await t.pumpWidget(const SizedBox());
          await t.pumpAndSettle();
          await start();
          expect(find.byKey(const Key('bookmark-icon-1:1')), findsNothing);
        },
      );
    }
  }
}
