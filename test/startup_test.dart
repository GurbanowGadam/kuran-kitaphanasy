import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuran_kitaphanasy/main.dart';
import 'package:kuran_kitaphanasy/library/data/book_repository.dart';
import 'package:kuran_kitaphanasy/library/domain/book.dart';
import 'package:kuran_kitaphanasy/reader_data.dart';
import 'package:kuran_kitaphanasy/reader/settings/reader_preferences.dart';

import 'reader_fixture.dart' show fixture;

class StartupRepository implements BookRepository {
  final pending = Completer<ReaderData>();
  int calls = 0;
  bool fail = false;
  bool throwSynchronously = false;
  @override
  List<LibraryBook> get books => libraryBooks;
  @override
  Future<ReaderData> load(String id) {
    calls++;
    if (throwSynchronously) throw StateError('synchronous asset failure');
    return fail
        ? Future.error(StateError('offline load failed'))
        : pending.future;
  }
}

class StartupStore extends MemoryReaderStore {
  final pending = Completer<Map<String, dynamic>?>();
  bool fail = false;
  @override
  Future<Map<String, dynamic>?> read(String id) => id == '_library'
      ? (fail
            ? Future.error(StateError('preferences unavailable'))
            : pending.future)
      : super.read(id);
}

class SwitchingRepository implements BookRepository {
  final first = Completer<ReaderData>();
  final second = Completer<ReaderData>();
  @override
  List<LibraryBook> get books => const [
    LibraryBook('first', 'TEST ONLY first', '', ''),
    LibraryBook('second', 'TEST ONLY second', '', ''),
  ];
  @override
  Future<ReaderData> load(String id) =>
      id == 'first' ? first.future : second.future;
}

void main() {
  testWidgets('synchronous repository errors are observed and retryable', (
    t,
  ) async {
    final repository = StartupRepository()..throwSynchronously = true;
    await t.pumpWidget(
      QuranApp(repository: repository, store: MemoryReaderStore()),
    );
    await t.pumpAndSettle();
    expect(find.text('Kitaphana'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.tap(find.byKey(const Key('book-quran')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('reader-load-error')), findsOneWidget);
    repository.throwSynchronously = false;
    await t.tap(find.byKey(const Key('reader-load-retry')));
    await t.pump();
    expect(find.byKey(const Key('reader-loading')), findsOneWidget);
    repository.pending.complete(fixture());
    await t.pumpAndSettle();
    expect(find.byType(Reader), findsOneWidget);
    expect(repository.calls, 2);
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'late preference failure after disposal never notifies or preloads',
    (t) async {
      final repository = StartupRepository();
      final store = StartupStore();
      var notifications = 0;
      await t.pumpWidget(
        QuranApp(
          repository: repository,
          store: store,
          onStartupReady: () => notifications++,
        ),
      );
      await t.pump();
      expect(find.byKey(const Key('startup-loading')), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      store.pending.completeError(StateError('late preference failure'));
      await t.pumpAndSettle();
      expect(notifications, 0);
      expect(repository.calls, 0);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('switching books never mounts a reader with stale source data', (
    t,
  ) async {
    final repository = SwitchingRepository()..first.complete(fixture());
    await t.pumpWidget(
      QuranApp(repository: repository, store: MemoryReaderStore()),
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('book-first')));
    await t.pumpAndSettle();
    expect(find.byType(Reader), findsOneWidget);
    t.widget<Reader>(find.byType(Reader)).goHome();
    await t.pumpAndSettle();
    await t.ensureVisible(find.byKey(const Key('book-second')));
    await t.tap(find.byKey(const Key('book-second')));
    await t.pump();
    expect(find.byType(Reader, skipOffstage: false), findsNothing);
    expect(find.byKey(const Key('reader-loading')), findsOneWidget);
    repository.second.completeError(StateError('second unavailable'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('reader-load-error')), findsOneWidget);
    expect(find.byType(Reader, skipOffstage: false), findsNothing);
    expect(t.takeException(), isNull);
  });

  for (final fail in [false, true]) {
    testWidgets('source completion after app disposal is safe fail=$fail', (
      t,
    ) async {
      final repository = StartupRepository();
      var notifications = 0;
      await t.pumpWidget(
        QuranApp(
          repository: repository,
          store: MemoryReaderStore(),
          onStartupReady: () => notifications++,
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('book-quran')));
      await t.pump();
      expect(find.byKey(const Key('reader-loading')), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      if (fail) {
        repository.pending.completeError(StateError('disposed asset failure'));
      } else {
        repository.pending.complete(fixture());
      }
      await t.pumpAndSettle();
      expect(notifications, 1);
      expect(t.takeException(), isNull);
    });
  }

  for (final accessible in [false, true]) {
    testWidgets(
      'pending book is static for reduced motion accessible=$accessible',
      (t) async {
        t.platformDispatcher.accessibilityFeaturesTestValue =
            FakeAccessibilityFeatures(
              disableAnimations: !accessible,
              accessibleNavigation: accessible,
            );
        addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
        final repository = StartupRepository();
        await t.pumpWidget(
          QuranApp(repository: repository, store: MemoryReaderStore()),
        );
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('book-quran')));
        await t.pumpAndSettle();
        expect(find.byKey(const Key('reader-loading')), findsOneWidget);
        expect(
          t
              .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator),
              )
              .value,
          0,
        );
        expect(t.hasRunningAnimations, isFalse);
        await t.tap(find.byKey(const Key('reader-load-home')));
        await t.pumpAndSettle();
        repository.pending.complete(fixture());
        await t.pumpAndSettle();
        expect(find.text('Kitaphana'), findsOneWidget);
        await t.tap(find.byKey(const Key('book-quran')));
        await t.pumpAndSettle();
        expect(find.byType(Reader), findsOneWidget);
        expect(repository.calls, 1);
      },
    );
  }

  testWidgets(
    'resolved data still does not instantiate a reader before selection',
    (t) async {
      await t.pumpWidget(QuranApp(data: Future.value(fixture())));
      await t.pumpAndSettle();
      expect(find.byType(Reader, skipOffstage: false), findsNothing);
    },
  );

  testWidgets(
    'library ready does not wait for source or construct hidden reader',
    (t) async {
      final repository = StartupRepository();
      final store = StartupStore();
      var notifications = 0;
      await t.pumpWidget(
        QuranApp(
          repository: repository,
          store: store,
          onStartupReady: () {
            notifications++;
            expect(find.text('Kitaphana'), findsOneWidget);
            expect(
              repository.calls,
              0,
              reason: 'preload starts after library layout',
            );
          },
        ),
      );
      expect(find.byKey(const Key('startup-loading')), findsOneWidget);
      expect(find.byType(Icon), findsNothing);
      expect(repository.calls, 0);
      store.pending.complete({'version': 1, 'dark': true});
      await t.pumpAndSettle();
      expect(find.text('Kitaphana'), findsOneWidget);
      expect(
        Theme.of(t.element(find.text('Kitaphana'))).brightness,
        Brightness.dark,
      );
      expect(find.byType(Reader, skipOffstage: false), findsNothing);
      expect(notifications, 1);
      expect(repository.calls, 1);
      repository.pending.complete(fixture());
      await t.pumpAndSettle();
      expect(find.byType(Reader, skipOffstage: false), findsNothing);
      await t.tap(find.byKey(const Key('book-quran')));
      await t.pumpAndSettle();
      expect(find.byType(Reader), findsOneWidget);
      expect(repository.calls, 1);
    },
  );

  testWidgets(
    'background source failure leaves library usable; book retry and home recover',
    (t) async {
      final repository = StartupRepository()..fail = true;
      await t.pumpWidget(
        QuranApp(repository: repository, store: MemoryReaderStore()),
      );
      await t.pumpAndSettle();
      expect(find.text('Kitaphana'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.tap(find.byKey(const Key('book-quran')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('reader-load-error')), findsOneWidget);
      expect(find.byType(Reader, skipOffstage: false), findsNothing);
      await t.tap(find.byKey(const Key('reader-load-home')));
      await t.pumpAndSettle();
      expect(find.text('Kitaphana'), findsOneWidget);
      await t.tap(find.byKey(const Key('book-quran')));
      await t.pumpAndSettle();
      repository.fail = false;
      await t.tap(find.byKey(const Key('reader-load-retry')));
      await t.pump();
      expect(find.byKey(const Key('reader-loading')), findsOneWidget);
      repository.pending.complete(fixture());
      await t.pumpAndSettle();
      expect(find.byType(Reader), findsOneWidget);
      expect(repository.calls, 2);
    },
  );

  testWidgets(
    'preference failure releases actionable frame and retries exactly once',
    (t) async {
      final store = StartupStore()..fail = true;
      final repository = StartupRepository();
      var notifications = 0;
      await t.pumpWidget(
        QuranApp(
          repository: repository,
          store: store,
          onStartupReady: () => notifications++,
        ),
      );
      await t.pumpAndSettle();
      expect(find.byKey(const Key('startup-retry')), findsOneWidget);
      expect(repository.calls, 0);
      expect(notifications, 1);
      store.fail = false;
      await t.tap(find.byKey(const Key('startup-retry')));
      store.pending.complete(null);
      await t.pumpAndSettle();
      expect(find.text('Kitaphana'), findsOneWidget);
      expect(notifications, 1);
      expect(repository.calls, 1);
    },
  );

  testWidgets('bundled repository evicts failed future for retry', (t) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMessageHandler('flutter/assets', (_) async => null);
    addTearDown(() => messenger.setMockMessageHandler('flutter/assets', null));
    final repository = BundledBookRepository();
    final first = repository.load('quran');
    await expectLater(first, throwsA(anything));
    final retry = repository.load('quran');
    await expectLater(retry, throwsA(anything));
    expect(identical(first, retry), isFalse);
  });

  for (final accessible in [false, true]) {
    testWidgets('reduced motion and pending disposal accessible=$accessible', (
      t,
    ) async {
      t.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(
            disableAnimations: !accessible,
            accessibleNavigation: accessible,
          );
      addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final repository = StartupRepository();
      final store = StartupStore();
      await t.pumpWidget(QuranApp(repository: repository, store: store));
      await t.pump();
      expect(find.byKey(const Key('startup-loading')), findsOneWidget);
      expect(t.hasRunningAnimations, isFalse);
      await t.pumpWidget(const SizedBox());
      store.pending.complete(null);
      await t.pump();
      expect(repository.calls, 0);
      expect(t.takeException(), isNull);
    });
  }
}
