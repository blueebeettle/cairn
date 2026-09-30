// First-run tutorial: the persisted flag, the slides, and the gate that shows
// the tutorial once and then never again.
//
// "Survives an app restart" is exercised for real rather than mocked: one
// in-memory database is shared across two separately built provider scopes,
// and the second scope's starting value is read back off that database through
// the same `loadOnboardingCompleted` that `main()` calls. Tearing the first
// scope down and building another is what a relaunch is, as far as the
// providers are concerned.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:habit_tracker/app.dart';
import 'package:habit_tracker/data/database/app_database.dart';
import 'package:habit_tracker/data/providers/database_provider.dart';
import 'package:habit_tracker/data/providers/onboarding_providers.dart';
import 'package:habit_tracker/data/repositories/settings_repository.dart';
import 'package:habit_tracker/features/navigation/presentation/navigation_shell.dart';
import 'package:habit_tracker/features/onboarding/presentation/onboarding_gate.dart';
import 'package:habit_tracker/features/onboarding/presentation/onboarding_screen.dart';
import 'package:habit_tracker/theme/app_theme.dart';

/// A settings store that cannot be read or written.
///
/// A closed in-memory Drift database is no substitute: it quietly reopens as an
/// empty one, so nothing would throw and the failure paths would go untested.
class _ThrowingSettings extends SettingsRepository {
  _ThrowingSettings(AppDatabase db) : super(db: db);

  @override
  Future<int?> getInt(String key) async => throw StateError('unreadable');

  @override
  Future<void> setInt(String key, int value) async =>
      throw StateError('unwritable');
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  late AppDatabase db;
  late SettingsRepository settings;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    settings = SettingsRepository(db: db);
  });

  tearDown(() async {
    await db.close();
  });

  // ── Harness ────────────────────────────────────────────────────────────────

  /// The app's root, standing in for one launch: the starting flag is whatever
  /// [loadOnboardingCompleted] reads off [db] at that moment, exactly as
  /// `main()` does before `runApp`.
  Future<Widget> launch({
    double textScale = 1.0,
    Widget child = const Text('THE APP'),
    ThemeData? theme,
  }) async {
    final completed = await loadOnboardingCompleted(settings);
    return ProviderScope(
      // A fresh key per launch, so a second launch is a genuinely new scope.
      key: UniqueKey(),
      overrides: [
        databaseProvider.overrideWithValue(db),
        initialOnboardingCompletedProvider.overrideWithValue(completed),
      ],
      child: MaterialApp(
        theme: theme ?? AppTheme.light,
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: app!,
        ),
        home: OnboardingGate(child: child),
      ),
    );
  }

  /// The five slides' headings, in order.
  const titles = [
    'Welcome to Cairn',
    'Today and Focus',
    'Capture a task in one line',
    'Habits keep a streak',
    'See how it adds up',
  ];

  Future<void> tapNext(WidgetTester tester) async {
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
  }

  /// Advances [n] slides from wherever the tutorial currently is.
  Future<void> advance(WidgetTester tester, int n) async {
    for (var i = 0; i < n; i++) {
      await tapNext(tester);
    }
  }

  bool backIsVisible(WidgetTester tester) => tester
      .widget<Visibility>(
        find
            .ancestor(of: find.text('Back'), matching: find.byType(Visibility))
            .first,
      )
      .visible;

  // ── The persisted flag ─────────────────────────────────────────────────────

  group('onboarding flag', () {
    test('unset reads as not completed, so a fresh install shows the tutorial',
        () async {
      expect(await loadOnboardingCompleted(settings), isFalse);
    });

    test('0 is not completed and 1 is', () async {
      await settings.setInt(onboardingCompletedSettingsKey, 0);
      expect(await loadOnboardingCompleted(settings), isFalse);

      await settings.setInt(onboardingCompletedSettingsKey, 1);
      expect(await loadOnboardingCompleted(settings), isTrue);
    });

    test('is an int 0/1 under onboarding_completed, like the info-card flags',
        () async {
      expect(onboardingCompletedSettingsKey, 'onboarding_completed');

      final notifier =
          OnboardingCompletedNotifier(settings, initial: false);
      await notifier.complete();

      expect(notifier.state, isTrue);
      // getInt, not getBool: the same storage shape FeatureInfo's
      // `dismissedSettingsKey` uses.
      expect(await settings.getInt(onboardingCompletedSettingsKey), 1);
    });

    test('an unreadable settings table counts as completed, not as a trap',
        () async {
      expect(await loadOnboardingCompleted(_ThrowingSettings(db)), isTrue);
    });

    test('finishing still succeeds if the write fails', () async {
      final notifier =
          OnboardingCompletedNotifier(_ThrowingSettings(db), initial: false);

      await notifier.complete(); // must not throw
      expect(notifier.state, isTrue);
    });
  });

  // ── The slides ─────────────────────────────────────────────────────────────

  group('OnboardingScreen', () {
    testWidgets('walks the five slides in order, Back hidden on the first',
        (tester) async {
      await tester.pumpWidget(await launch());
      await tester.pumpAndSettle();

      for (var i = 0; i < titles.length; i++) {
        expect(find.text(titles[i]), findsOneWidget,
            reason: 'slide ${i + 1} should be showing');
        expect(backIsVisible(tester), i > 0,
            reason: 'Back only exists after the first slide');
        if (i < titles.length - 1) await tapNext(tester);
      }
    });

    testWidgets('Back returns to the previous slide', (tester) async {
      await tester.pumpWidget(await launch());
      await tester.pumpAndSettle();

      await advance(tester, 2);
      expect(find.text(titles[2]), findsOneWidget);

      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(find.text(titles[1]), findsOneWidget);
    });

    testWidgets('the primary button is Next until the last slide, then Get started',
        (tester) async {
      await tester.pumpWidget(await launch());
      await tester.pumpAndSettle();

      for (var i = 0; i < titles.length - 1; i++) {
        expect(find.text('Next'), findsOneWidget);
        expect(find.text('Get started'), findsNothing);
        await tapNext(tester);
      }

      expect(find.text('Get started'), findsOneWidget);
      expect(find.text('Next'), findsNothing);
    });

    testWidgets('Skip is on every slide, in the same place', (tester) async {
      await tester.pumpWidget(await launch());
      await tester.pumpAndSettle();

      Offset? skipAt;
      for (var i = 0; i < titles.length; i++) {
        expect(find.text('Skip'), findsOneWidget,
            reason: 'slide ${i + 1} should offer Skip');
        final at = tester.getTopRight(find.text('Skip'));
        // Persistent: outside the PageView, so it does not move with the page.
        skipAt ??= at;
        expect(at, skipAt);
        if (i < titles.length - 1) await tapNext(tester);
      }
    });

    testWidgets('the tasks slide teaches the quick-capture syntax',
        (tester) async {
      await tester.pumpWidget(await launch());
      await tester.pumpAndSettle();
      await advance(tester, 2);

      expect(find.text(titles[2]), findsOneWidget);
      // Every token the parser really understands.
      expect(find.text('fri 5pm'), findsOneWidget);
      expect(find.text('!p1 – !p4'), findsOneWidget);
      expect(find.text('#work'), findsOneWidget);
      expect(find.text('~2p'), findsOneWidget);
      // `#` makes a tag, not a project — the slide must not claim otherwise.
      expect(find.textContaining('A tag'), findsOneWidget);
      expect(find.textContaining('project'), findsNothing);
    });

    testWidgets('the habits slide points at the ? button rather than teaching it',
        (tester) async {
      await tester.pumpWidget(await launch());
      await tester.pumpAndSettle();
      await advance(tester, 3);

      expect(find.text(titles[3]), findsOneWidget);
      expect(find.textContaining('Every screen has a ? button'), findsOneWidget);
      expect(find.byIcon(Icons.help_outline_rounded), findsOneWidget);
    });

    testWidgets('opening the tutorial writes nothing', (tester) async {
      await tester.pumpWidget(await launch());
      await tester.pumpAndSettle();
      await advance(tester, 3);

      // Three slides in, still not marked done.
      expect(await settings.getInt(onboardingCompletedSettingsKey), isNull);
    });

    testWidgets('a system back press steps back a slide instead of leaving',
        (tester) async {
      await tester.pumpWidget(await launch());
      await tester.pumpAndSettle();
      await advance(tester, 2);
      expect(find.text(titles[2]), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text(titles[1]), findsOneWidget);
      // ...and it is still the tutorial, not the app.
      expect(find.text('THE APP'), findsNothing);
    });

    // Lazy thunks, not values: `AppTheme` reaches for Google Fonts' asset
    // manifest, which needs the binding `testWidgets` installs.
    final themes = <String, ThemeData Function()>{
      'light': () => AppTheme.light,
      'dark': () => AppTheme.dark,
    };

    for (final theme in themes.entries) {
      testWidgets(
          'every slide fits a 360x640 phone at 200% text (${theme.key}) without overflow',
          (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
            await launch(textScale: 2.0, theme: theme.value()));
        await tester.pumpAndSettle();

        for (var i = 0; i < titles.length; i++) {
          expect(find.text(titles[i]), findsOneWidget);
          expect(tester.takeException(), isNull,
              reason: 'slide ${i + 1} overflowed');
          if (i < titles.length - 1) await tapNext(tester);
        }
        // The last slide's primary button is the widest label of all.
        expect(find.text('Get started'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  // ── The gate ───────────────────────────────────────────────────────────────

  group('OnboardingGate', () {
    testWidgets('a fresh install shows the tutorial and not the app',
        (tester) async {
      await tester.pumpWidget(await launch());
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.text('THE APP'), findsNothing);
    });

    testWidgets('an already-completed install goes straight to the app',
        (tester) async {
      await settings.setInt(onboardingCompletedSettingsKey, 1);

      await tester.pumpWidget(await launch());
      await tester.pumpAndSettle();

      expect(find.text('THE APP'), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
    });

    testWidgets('Skip from the very first slide finishes it outright',
        (tester) async {
      await tester.pumpWidget(await launch());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(find.text('THE APP'), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(await settings.getInt(onboardingCompletedSettingsKey), 1);
    });

    for (final skipAfter in [1, 2, 3]) {
      testWidgets('Skip from slide ${skipAfter + 1} is not partial — it finishes it',
          (tester) async {
        await tester.pumpWidget(await launch());
        await tester.pumpAndSettle();
        await advance(tester, skipAfter);

        await tester.tap(find.text('Skip'));
        await tester.pumpAndSettle();

        expect(find.text('THE APP'), findsOneWidget);
        expect(await settings.getInt(onboardingCompletedSettingsKey), 1);
      });
    }

    testWidgets('Get started on the last slide finishes it', (tester) async {
      await tester.pumpWidget(await launch());
      await tester.pumpAndSettle();
      await advance(tester, titles.length - 1);

      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();

      expect(find.text('THE APP'), findsOneWidget);
      expect(await settings.getInt(onboardingCompletedSettingsKey), 1);
    });

    testWidgets('once finished it never comes back, across a restart',
        (tester) async {
      // Launch one: a fresh install, finished through Get started.
      await tester.pumpWidget(await launch());
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsOneWidget);
      await advance(tester, titles.length - 1);
      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();
      expect(find.text('THE APP'), findsOneWidget);

      // The app is killed…
      await tester.pumpWidget(const SizedBox.shrink());

      // …and launched again, reading the flag off the same database.
      await tester.pumpWidget(await launch());
      await tester.pumpAndSettle();
      expect(find.text('THE APP'), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);

      // And a third time, for good measure.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(await launch());
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsNothing);
    });

    testWidgets('a skip is remembered across a restart too', (tester) async {
      await tester.pumpWidget(await launch());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(await launch());
      await tester.pumpAndSettle();

      expect(find.text('THE APP'), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
    });

    testWidgets(
        'force-quitting mid-tutorial shows it again from the start next launch',
        (tester) async {
      await tester.pumpWidget(await launch());
      await tester.pumpAndSettle();
      await advance(tester, 3);
      expect(find.text(titles[3]), findsOneWidget);

      // Killed on slide four: nothing was finished, so nothing was written.
      await tester.pumpWidget(const SizedBox.shrink());
      expect(await settings.getInt(onboardingCompletedSettingsKey), isNull);

      await tester.pumpWidget(await launch());
      await tester.pumpAndSettle();

      // Not the app, and not resumed halfway — restarted.
      expect(find.text('THE APP'), findsNothing);
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.text(titles[0]), findsOneWidget);
    });
  });

  // ── Wired into the real app ────────────────────────────────────────────────

  group('FocusStackApp', () {
    Widget realApp({required bool completed}) => ProviderScope(
          key: UniqueKey(),
          overrides: [
            databaseProvider.overrideWithValue(db),
            initialOnboardingCompletedProvider.overrideWithValue(completed),
            todayEventsStreamProvider.overrideWith(
              (ref) => Stream<List<Event>>.value(const []),
            ),
          ],
          child: const FocusStackApp(),
        );

    testWidgets('a fresh install lands on the tutorial, then the shell',
        (tester) async {
      await tester.pumpWidget(realApp(completed: false));
      await tester.pump();
      await tester.pump();

      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.byType(NavigationShell), findsNothing);

      await tester.tap(find.text('Skip'));
      // pump() rather than pumpAndSettle(): the shell's screens hold streams
      // that never go idle, exactly as `widget_test.dart` notes.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(NavigationShell), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(await settings.getInt(onboardingCompletedSettingsKey), 1);
    });

    testWidgets('a completed install lands straight on the shell',
        (tester) async {
      await tester.pumpWidget(realApp(completed: true));
      await tester.pump();
      await tester.pump();

      expect(find.byType(NavigationShell), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
    });
  });
}
