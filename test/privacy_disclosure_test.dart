import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuran_kitaphanasy/main.dart';

import 'reader_fixture.dart';

void main() {
  testWidgets(
    'About visibly discloses download privacy and local data deletion',
    (t) async {
      await t.pumpWidget(QuranApp(data: Future.value(fixture())));
      await t.pumpAndSettle();
      await t.ensureVisible(find.byKey(const Key('source-about')));
      await t.tap(find.byKey(const Key('source-about')));
      await t.pumpAndSettle();

      final dialog = find.byType(AlertDialog);
      for (final text in [
        'Gizlinlik we maglumatlar',
        'Sesleri ýüklemegi özüňiz saýlanyňyzda, programma Google Drive-daky '
            'hemmeler üçin açyk faýllary internet arkaly ýükleýär. Şonda Google '
            'Drive tor haýyşlaryny we IP salgyňyz ýaly tehniki maglumatlary alýar. '
            'Ýüklenen ses faýllarynyň bitewiligi barlanýar.',
        'Programmanyň gizlinlik syýasaty:',
        'https://gurbanowgadam.github.io/kuran-kitaphanasy/privacy.html',
        'Habarlaşmak üçin: kurankitaphanasy@gmail.com',
        'Google hyzmatynyň gizlinlik syýasaty:',
        'https://policies.google.com/privacy',
        'Sazlamalar, okalyş ýagdaýy, bellikler we ýüklenen sesler diňe şu '
            'enjamda saklanýar. Hasap açmak talap edilmeýär; mahabat we '
            'analitika ýok.',
        'Ýerli maglumatlary pozmak üçin enjamyň ulgam sazlamalarynda '
            'programmanyň maglumatlaryny arassalaň ýa-da programmany aýryň. '
            'Şonda şu enjamdaky sazlamalar, okalyş ýagdaýy, bellikler we '
            'ýüklenen sesler pozular.',
      ]) {
        final disclosure = find.descendant(
          of: dialog,
          matching: find.text(text),
        );
        expect(disclosure, findsOneWidget);
        await t.ensureVisible(disclosure);
        await t.pumpAndSettle();
        expect(disclosure.hitTestable(), findsOneWidget);
      }
      expect(
        find.descendant(
          of: dialog,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is SelectableText &&
                widget.data == 'https://policies.google.com/privacy',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: dialog,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is SelectableText &&
                widget.data ==
                    'https://gurbanowgadam.github.io/kuran-kitaphanasy/privacy.html',
          ),
        ),
        findsOneWidget,
      );
      await t.tap(find.widgetWithText(TextButton, 'Ýap'));
      await t.pumpAndSettle();
      expect(dialog, findsNothing);
      expect(t.takeException(), isNull);
    },
  );
}
