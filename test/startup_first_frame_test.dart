import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuran_kitaphanasy/main.dart';
import 'package:kuran_kitaphanasy/reader_data.dart';
import 'package:kuran_kitaphanasy/reader/settings/reader_preferences.dart';

class DeferredLibraryStore extends MemoryReaderStore {
  final pending = Completer<Map<String, dynamic>?>();
  @override
  Future<Map<String, dynamic>?> read(String id) =>
      id == '_library' ? pending.future : super.read(id);
}

// Separate test isolate: no unrelated widget test inherits a deferred binding.
void main() {
  for (final fail in [false, true]) {
    testWidgets(
      'deferred first frame waits only for preferences and reaches library/error fail=$fail',
      (t) async {
        final data = Completer<ReaderData>();
        final store = DeferredLibraryStore();
        final binding = t.binding;
        var releases = 0;
        binding.deferFirstFrame();
        addTearDown(() {
          if (releases == 0) binding.allowFirstFrame();
        });
        await t.pumpWidget(
          QuranApp(
            data: data.future,
            store: store,
            onStartupReady: () {
              expect(find.byKey(const Key('startup-loading')), findsNothing);
              expect(
                fail
                    ? find.byKey(const Key('startup-retry'))
                    : find.byKey(const Key('library-title')),
                findsOneWidget,
              );
              expect(binding.sendFramesToEngine, isFalse);
              releases++;
              binding.allowFirstFrame();
            },
          ),
        );
        await t.pump();
        expect(releases, 0);
        expect(binding.sendFramesToEngine, isFalse);
        if (fail) {
          store.pending.completeError(StateError('preferences unavailable'));
        } else {
          store.pending.complete({'version': 1, 'dark': true});
        }
        await t.pumpAndSettle();
        expect(
          data.isCompleted,
          isFalse,
          reason: 'unresolved source must not hold the native splash',
        );
        expect(releases, 1);
        expect(binding.sendFramesToEngine, isTrue);
        expect(find.byType(Reader, skipOffstage: false), findsNothing);
        // Even an injected source failing after first-frame release is observed.
        data.completeError(StateError('asset unavailable'));
        await t.pumpAndSettle();
        expect(releases, 1);
        expect(t.takeException(), isNull);
      },
    );
  }
}
