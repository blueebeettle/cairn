import 'dart:async';

import 'package:drift/drift.dart' show LazyDatabase, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:habit_tracker/app.dart';
import 'package:habit_tracker/data/database/app_database.dart';
import 'package:habit_tracker/data/providers/database_provider.dart';
import 'package:habit_tracker/features/reminders/reminder_service.dart';
import 'package:habit_tracker/features/startup/presentation/startup_error_screen.dart';
import 'package:habit_tracker/main.dart';

/// Records open/close order so a test can prove a failed attempt's connection
/// was closed before anything tried again.
class _TrackedDatabase extends AppDatabase {
  _TrackedDatabase(this.name, this.log, super.executor) {
    log.add('open $name');
  }

  final String name;
  final List<String> log;
  Object? closeError;

  @override
  Future<void> close() async {
    log.add('close $name');
    await super.close();
    final error = closeError;
    if (error != null) throw error;
  }
}

/// A database whose first query throws, which is where a real open failure
/// (bad migration, corrupt file, full disk) surfaces: Drift opens lazily.
_TrackedDatabase _failingDatabase(String name, List<String> log, Object error) =>
    _TrackedDatabase(name, log, LazyDatabase(() async => throw error));

_TrackedDatabase _workingDatabase(String name, List<String> log) =>
    _TrackedDatabase(name, log, NativeDatabase.memory());

Future<StartedApp> _attempt({
  required AppDatabase Function() openDatabase,
  Future<String> Function()? resolveTimezone,
  Future<void> Function(ReminderService, String)? initializeReminders,
}) =>
    attemptStartup(
      openDatabase: openDatabase,
      registerHomeWidgetCallback: () async {},
      resolveTimezone: resolveTimezone ?? () async => 'America/Edmonton',
      initializeReminders: initializeReminders ?? (_, _) async {},
    );

StartedApp _fakeApp({void Function()? onFinish}) => StartedApp(
      app: const MaterialApp(home: Text('the app')),
      finishStartup: () async => onFinish?.call(),
    );

/// Collects what [launchApp] asks to show, in place of [runApp].
class _Shown {
  Widget? pending;

  void call(Widget widget) => pending = widget;
}

/// Mounts whatever [launchApp] last showed once pending async work has run.
Future<void> _mount(WidgetTester tester, _Shown shown) async {
  await tester.pump();
  final widget = shown.pending;
  if (widget == null) return;
  shown.pending = null;
  await tester.pumpWidget(widget);
}

Future<_Shown> _launch(
  WidgetTester tester,
  Future<StartedApp> Function() attempt,
) async {
  final shown = _Shown();
  await launchApp(attempt: attempt, show: shown.call);
  await _mount(tester, shown);
  return shown;
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    // A retry is a second AppDatabase by design, opened after the first was
    // closed; Drift's debug-only check counts instances, not live ones.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('launchApp', () {
    testWidgets('a startup exception shows the error screen, not a crash',
        (tester) async {
      await _launch(tester, () async => throw StateError('disk I/O error'));

      expect(tester.takeException(), isNull);
      expect(find.byType(StartupErrorScreen), findsOneWidget);
      expect(find.text("Cairn couldn't open its data"), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.byType(FocusStackApp), findsNothing);
    });

    testWidgets('the real exception and trace are reachable from the screen',
        (tester) async {
      final boom = StateError('disk I/O error');

      await _launch(tester, () async => throw boom);

      final screen =
          tester.widget<StartupErrorScreen>(find.byType(StartupErrorScreen));
      expect(screen.error, same(boom));
      expect(screen.stackTrace.toString(), isNotEmpty);
    });

    testWidgets('details are collapsed until asked for, then show the message',
        (tester) async {
      await _launch(tester, () async => throw StateError('disk I/O error'));

      expect(find.textContaining('disk I/O error'), findsNothing);

      await tester.tap(find.text('Show details'));
      await tester.pump();
      expect(find.textContaining('disk I/O error'), findsOneWidget);
      expect(find.text('Hide details'), findsOneWidget);

      await tester.tap(find.text('Hide details'));
      await tester.pump();
      expect(find.textContaining('disk I/O error'), findsNothing);
    });

    testWidgets('Copy details puts the exception text on the clipboard',
        (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      await _launch(tester, () async => throw StateError('disk I/O error'));
      await tester.tap(find.text('Show details'));
      await tester.pump();
      await tester.tap(find.text('Copy details'));
      await tester.pump();

      expect(copied, contains('disk I/O error'));
      expect(find.text('Details copied'), findsOneWidget);
    });

    testWidgets('the only actions offered are retry, details and copy',
        (tester) async {
      await _launch(tester, () async => throw StateError('disk I/O error'));

      List<String> buttonLabels() => find
          .descendant(
            of: find.byWidgetPredicate((w) => w is ButtonStyleButton),
            matching: find.byType(Text),
          )
          .evaluate()
          .map((element) => (element.widget as Text).data!)
          .toList();

      expect(buttonLabels(), ['Try again', 'Show details']);

      await tester.tap(find.text('Show details'));
      await tester.pump();
      expect(
        buttonLabels(),
        ['Try again', 'Hide details', 'Copy details'],
        reason: 'A new action on this screen needs its own confirmation '
            'flow; update this test only after that exists.',
      );
    });

    testWidgets('Try again re-runs startup and the app renders once it passes',
        (tester) async {
      var attempts = 0;
      var finished = 0;

      final shown = await _launch(tester, () async {
        attempts++;
        if (attempts == 1) throw StateError('disk I/O error');
        return _fakeApp(onFinish: () => finished++);
      });
      expect(find.byType(StartupErrorScreen), findsOneWidget);
      expect(attempts, 1);
      expect(finished, 0, reason: 'deferred startup must not run on failure');

      await tester.tap(find.text('Try again'));
      await _mount(tester, shown);

      expect(attempts, 2);
      expect(find.text('the app'), findsOneWidget);
      expect(find.byType(StartupErrorScreen), findsNothing);
      expect(finished, 1);
    });

    testWidgets('a retry that fails again shows the error screen again',
        (tester) async {
      var attempts = 0;

      final shown = await _launch(tester, () async {
        attempts++;
        if (attempts < 3) throw StateError('failure $attempts');
        return _fakeApp();
      });
      expect(find.textContaining("Still couldn't open it"), findsNothing);

      await tester.tap(find.text('Try again'));
      await _mount(tester, shown);

      expect(find.byType(StartupErrorScreen), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text("Still couldn't open it (attempt 2)."), findsOneWidget);
      expect(
        tester
            .widget<StartupErrorScreen>(find.byType(StartupErrorScreen))
            .error,
        isA<StateError>().having((e) => e.message, 'message', 'failure 2'),
      );

      await tester.tap(find.text('Try again'));
      await _mount(tester, shown);
      expect(find.text('the app'), findsOneWidget);
      expect(attempts, 3);
    });

    testWidgets('a retry in flight cannot be started a second time',
        (tester) async {
      final gate = Completer<StartedApp>();
      var attempts = 0;

      final shown = await _launch(tester, () {
        attempts++;
        if (attempts == 1) throw StateError('disk I/O error');
        return gate.future;
      });

      await tester.tap(find.text('Try again'));
      await _mount(tester, shown);
      expect(attempts, 2);
      expect(find.text('Trying again…'), findsOneWidget);

      await tester.tap(find.text('Trying again…'), warnIfMissed: false);
      await _mount(tester, shown);
      expect(attempts, 2);

      gate.complete(_fakeApp());
      await _mount(tester, shown);
      expect(find.text('the app'), findsOneWidget);
    });

    testWidgets('a clean startup shows the app and never the error screen',
        (tester) async {
      var attempts = 0;
      var finished = 0;

      await _launch(tester, () async {
        attempts++;
        return _fakeApp(onFinish: () => finished++);
      });

      expect(find.text('the app'), findsOneWidget);
      expect(find.byType(StartupErrorScreen), findsNothing);
      expect(attempts, 1);
      expect(finished, 1);
    });
  });

  group('attemptStartup', () {
    test('a failing bootstrap step rejects and closes the database it opened',
        () async {
      final log = <String>[];
      final boom = StateError('timezone channel exploded');

      await expectLater(
        _attempt(
          openDatabase: () => _workingDatabase('a', log),
          resolveTimezone: () async => throw boom,
        ),
        throwsA(same(boom)),
      );

      expect(log, ['open a', 'close a']);
    });

    test('a database that fails on first use rejects and is closed', () async {
      final log = <String>[];
      final boom = StateError('disk I/O error');

      await expectLater(
        _attempt(openDatabase: () => _failingDatabase('a', log, boom)),
        throwsA(same(boom)),
      );

      expect(log, ['open a', 'close a']);
    });

    test('a failure after the bootstrap also closes the database', () async {
      final log = <String>[];
      final boom = StateError('notification plugin unavailable');

      await expectLater(
        _attempt(
          openDatabase: () => _workingDatabase('a', log),
          initializeReminders: (_, _) async => throw boom,
        ),
        throwsA(same(boom)),
      );

      expect(log, ['open a', 'close a']);
    });

    test('a close that itself throws does not mask the original error',
        () async {
      final log = <String>[];
      final boom = StateError('disk I/O error');
      final db = _failingDatabase('a', log, boom)
        ..closeError = StateError('close failed too');

      await expectLater(
        _attempt(openDatabase: () => db),
        throwsA(same(boom)),
      );

      expect(log, ['open a', 'close a']);
    });

    test('a clean attempt returns the app and leaves the database open',
        () async {
      final log = <String>[];
      final db = _workingDatabase('a', log);

      final started = await _attempt(openDatabase: () => db);

      expect(log, ['open a']);
      final scope = started.app as UncontrolledProviderScope;
      expect(scope.child, isA<FocusStackApp>());
      expect(scope.container.read(databaseProvider), same(db));

      scope.container.dispose();
      await db.close();
    });
  });

  group('launchApp with the real startup sequence', () {
    testWidgets(
        'a failed database is closed before the retry opens a new one, '
        'then the real app renders', (tester) async {
      final log = <String>[];
      late final _TrackedDatabase second;
      var opened = 0;

      Future<StartedApp> attempt() async {
        final started = await _attempt(
          openDatabase: () {
            opened++;
            if (opened == 1) {
              return _failingDatabase('first', log, StateError('disk I/O error'));
            }
            return second = _workingDatabase('second', log);
          },
        );
        // The real deferred half reaches for Supabase and the notification
        // plugin; this test is about the half before it.
        return StartedApp(app: started.app, finishStartup: () async {});
      }

      final shown = _Shown();
      await tester.runAsync(() => launchApp(attempt: attempt, show: shown.call));
      await _mount(tester, shown);

      expect(find.byType(StartupErrorScreen), findsOneWidget);
      expect(log, ['open first', 'close first']);

      await tester.tap(find.text('Try again'));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await _mount(tester, shown);

      expect(log, ['open first', 'close first', 'open second']);
      expect(find.byType(StartupErrorScreen), findsNothing);
      expect(find.byType(FocusStackApp), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(second.close);
    });
  });

  group('StartupErrorScreen layout', () {
    testWidgets('fits a small phone at 200% text with details expanded',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearAllTestValues();
      });

      await tester.pumpWidget(
        StartupErrorScreen(
          error: StateError('disk I/O error'),
          stackTrace: StackTrace.fromString(
            [
              for (var i = 0; i < 40; i++)
                '#$i  someFunction (package:habit_tracker/some/file.dart:$i:1)',
            ].join('\n'),
          ),
          attempt: 2,
          onRetry: () async {},
        ),
      );
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.text('Try again'));
      await tester.tap(find.text('Show details'));
      await tester.pump();
      await tester.ensureVisible(find.text('Copy details'));

      expect(tester.takeException(), isNull);
      expect(find.text('Copy details'), findsOneWidget);
    });
  });
}
