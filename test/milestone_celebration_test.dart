// Tests for §4, the milestone celebration: the trigger/dedupe logic in
// `MilestoneCelebrationController`, and the full-screen widget it opens.
//
// The controller group drives `habitSnapshotsProvider` through a settable
// fake (`_fakeSnapshots`) rather than a real day-by-day check-off sequence
// through Drift — the arithmetic that turns check-offs into a streak is
// already exhaustively covered by `habit_streak_test.dart` and
// `habits_milestone_test.dart`; what's under test here is purely "does the
// controller fire exactly once per newly-crossed threshold". Settings
// persistence is real (an in-memory `AppDatabase`, shared across two
// `ProviderContainer`s to stand in for two app sessions), since that is the
// actual mechanism the "reopen mid-milestone" guarantee depends on.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:habit_tracker/core/habits/habit_streak.dart';
import 'package:habit_tracker/core/widgets/cairn_glyph.dart';
import 'package:habit_tracker/data/database/app_database.dart';
import 'package:habit_tracker/data/providers/database_provider.dart';
import 'package:habit_tracker/data/providers/habit_providers.dart';
import 'package:habit_tracker/data/repositories/habits_repository.dart';
import 'package:habit_tracker/features/habits/domain/milestone_celebration_controller.dart';
import 'package:habit_tracker/features/habits/presentation/milestone_celebration_screen.dart';
import 'package:habit_tracker/theme/app_theme.dart';

Habit _habit(String id, {String title = 'Evening walk', int allowance = 2}) =>
    Habit(
      id: id,
      title: title,
      colorIndex: 0,
      iconName: 'check',
      scheduleRule: 'FREQ=DAILY',
      anchorDate: '2026-01-01',
      targetCount: 1,
      skipAllowancePerMonth: allowance,
      status: 'active',
      sortOrder: 0,
      createdAt: 0,
      createdLocalDate: '2026-01-01',
      updatedAt: 0,
      deviceId: 'test',
    );

HabitSnapshot _snapshot({
  String id = 'h1',
  String title = 'Evening walk',
  int streak = 7,
  int? longest,
  int allowance = 2,
}) =>
    HabitSnapshot(
      habit: _habit(id, title: title, allowance: allowance),
      scheduledDates: const [],
      entries: const {},
      streaks: HabitStreakResult(
        current: streak,
        longest: longest ?? streak,
        outcomes: const {},
      ),
      todayLocalDate: '2026-09-23',
    );

/// Stands in for `habitSnapshotsProvider`'s real data: lets a test move a
/// habit's streak forward (or simulate a fresh session re-reading the same
/// streak) without driving check-offs through a real database day by day.
final _fakeSnapshots = StateProvider<List<HabitSnapshot>>((ref) => const []);

List<Override> _overridesOn(AppDatabase db) => [
      databaseProvider.overrideWithValue(db),
      habitSnapshotsProvider.overrideWith((ref) async => ref.watch(_fakeSnapshots)),
    ];

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('MilestoneCelebrationController', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('does not fire below the first threshold', () async {
      final container = ProviderContainer(overrides: _overridesOn(db));
      addTearDown(container.dispose);
      final controller =
          container.read(milestoneCelebrationControllerProvider.notifier);
      await controller.initialized;

      container.read(_fakeSnapshots.notifier).state = [_snapshot(streak: 6)];
      await container.read(habitSnapshotsProvider.future);

      expect(container.read(milestoneCelebrationControllerProvider), isNull);
    });

    test('fires exactly once when a streak lands on a threshold', () async {
      final container = ProviderContainer(overrides: _overridesOn(db));
      addTearDown(container.dispose);
      final controller =
          container.read(milestoneCelebrationControllerProvider.notifier);
      await controller.initialized;

      container.read(_fakeSnapshots.notifier).state = [_snapshot(streak: 7)];
      await container.read(habitSnapshotsProvider.future);

      final pending = container.read(milestoneCelebrationControllerProvider);
      expect(pending, isNotNull);
      expect(pending!.habitId, 'h1');
      expect(pending.streak, 7);

      controller.consume();
      expect(container.read(milestoneCelebrationControllerProvider), isNull);

      // The same streak recomputing again (an unrelated edit re-triggering
      // the provider, say) must not re-fire it.
      container.read(_fakeSnapshots.notifier).state = [
        _snapshot(streak: 7, longest: 7),
      ];
      await container.read(habitSnapshotsProvider.future);
      expect(container.read(milestoneCelebrationControllerProvider), isNull);
    });

    test('day 31 of a 30-day streak is not a milestone', () async {
      final container = ProviderContainer(overrides: _overridesOn(db));
      addTearDown(container.dispose);
      final controller =
          container.read(milestoneCelebrationControllerProvider.notifier);
      await controller.initialized;

      container.read(_fakeSnapshots.notifier).state = [_snapshot(streak: 30)];
      await container.read(habitSnapshotsProvider.future);
      expect(
          container.read(milestoneCelebrationControllerProvider)!.streak, 30);
      controller.consume();

      container.read(_fakeSnapshots.notifier).state = [
        _snapshot(streak: 31, longest: 31),
      ];
      await container.read(habitSnapshotsProvider.future);
      expect(container.read(milestoneCelebrationControllerProvider), isNull);
    });

    test(
        'reopening the app on the same still-open milestone day does not '
        're-fire it, and the next milestone still does', () async {
      // First "session": reaches and celebrates day 7.
      final first = ProviderContainer(overrides: _overridesOn(db));
      final firstController =
          first.read(milestoneCelebrationControllerProvider.notifier);
      await firstController.initialized;
      first.read(_fakeSnapshots.notifier).state = [_snapshot(streak: 7)];
      await first.read(habitSnapshotsProvider.future);
      expect(first.read(milestoneCelebrationControllerProvider)!.streak, 7);
      first.dispose();

      // "Reopen the app": a brand-new container over the same persisted
      // database. The habit has not been checked off again yet today, so a
      // fresh load still resolves its current streak to 7 — `HabitStats`
      // treats a not-yet-due today as pending rather than a break, so this
      // is a real state the app can be in, one step earlier than "day 31 of
      // a 30-day streak": *today itself*, reloaded, is still the milestone
      // day. This is exactly the case the persisted highest-celebrated
      // marker exists for; `MilestoneThresholds.reached` alone would fire
      // again here.
      final second = ProviderContainer(overrides: _overridesOn(db));
      addTearDown(second.dispose);
      final secondController =
          second.read(milestoneCelebrationControllerProvider.notifier);
      await secondController.initialized;
      second.read(_fakeSnapshots.notifier).state = [_snapshot(streak: 7)];
      await second.read(habitSnapshotsProvider.future);
      expect(second.read(milestoneCelebrationControllerProvider), isNull);

      // The habit keeps going and reaches the next threshold: it still
      // celebrates.
      second.read(_fakeSnapshots.notifier).state = [
        _snapshot(streak: 14, longest: 14),
      ];
      await second.read(habitSnapshotsProvider.future);
      expect(
          second.read(milestoneCelebrationControllerProvider)!.streak, 14);
    });

    test('two habits crossing thresholds together celebrate one at a time',
        () async {
      final container = ProviderContainer(overrides: _overridesOn(db));
      addTearDown(container.dispose);
      final controller =
          container.read(milestoneCelebrationControllerProvider.notifier);
      await controller.initialized;

      List<HabitSnapshot> both() => [
            _snapshot(id: 'a', streak: 7),
            _snapshot(id: 'b', streak: 14, longest: 14),
          ];

      container.read(_fakeSnapshots.notifier).state = both();
      await container.read(habitSnapshotsProvider.future);
      final first = container.read(milestoneCelebrationControllerProvider);
      expect(first, isNotNull);
      expect(first!.habitId, 'a');
      controller.consume();

      // Nothing about the data changed — re-running the same snapshots is
      // what surfaces the second habit's still-pending milestone.
      container.read(_fakeSnapshots.notifier).state = both();
      await container.read(habitSnapshotsProvider.future);
      final second = container.read(milestoneCelebrationControllerProvider);
      expect(second, isNotNull);
      expect(second!.habitId, 'b');
    });
  });

  // ── the screen ────────────────────────────────────────────────────────────

  Widget screen(ThemeData theme, HabitSnapshot snapshot) => ProviderScope(
        overrides: [
          habitSnapshotsProvider.overrideWith((ref) async => [snapshot]),
        ],
        child: MaterialApp(
          theme: theme,
          home: MilestoneCelebrationScreen(
            habitId: snapshot.habit.id,
            streak: snapshot.streaks.current,
          ),
        ),
      );

  final themes = <String, ThemeData Function()>{
    'light': () => AppTheme.light,
    'dark': () => AppTheme.dark,
  };

  for (final entry in themes.entries) {
    final themeName = entry.key;
    final buildTheme = entry.value;

    group('MilestoneCelebrationScreen ($themeName)', () {
      testWidgets('a fresh personal best shows the full cairn and its copy',
          (tester) async {
        await tester.pumpWidget(screen(buildTheme(), _snapshot(streak: 7)));
        await tester.pumpAndSettle();

        final glyph = tester.widget<CairnGlyph>(find.byType(CairnGlyph));
        expect(glyph.stoneCount, 4);
        expect(glyph.scale, 1.7);

        expect(find.text('7'), findsOneWidget);
        expect(find.text('day streak'), findsOneWidget);
        expect(
          find.text("You've never gone this far before. That's who you are now."),
          findsOneWidget,
        );
        expect(find.text('Keep going'), findsOneWidget);
        expect(find.text('Share your cairn'), findsOneWidget);
        expect(find.text('2 streak freezes in your pocket, saved for a rough day'),
            findsOneWidget);
      });

      testWidgets(
          'a milestone short of the habit\'s longest run skips the personal-best claim',
          (tester) async {
        await tester.pumpWidget(
          screen(buildTheme(), _snapshot(streak: 30, longest: 100)),
        );
        await tester.pumpAndSettle();

        expect(find.text('30'), findsOneWidget);
        expect(
          find.text("You've never gone this far before. That's who you are now."),
          findsNothing,
        );
        expect(find.text('30 days in, and still going strong.'), findsOneWidget);
      });

      testWidgets('a single remaining freeze is singular', (tester) async {
        await tester.pumpWidget(
          screen(buildTheme(), _snapshot(streak: 14, longest: 14, allowance: 1)),
        );
        await tester.pumpAndSettle();

        expect(find.text('1 streak freeze in your pocket, saved for a rough day'),
            findsOneWidget);
      });
    });
  }

  testWidgets('Keep going dismisses the celebration', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          habitSnapshotsProvider
              .overrideWith((ref) async => [_snapshot(streak: 7)]),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => MilestoneCelebrationScreen.open(
                    context,
                    habitId: 'h1',
                    streak: 7,
                  ),
                  child: const Text('open celebration'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open celebration'));
    await tester.pumpAndSettle();
    expect(find.byType(MilestoneCelebrationScreen), findsOneWidget);

    await tester.tap(find.text('Keep going'));
    await tester.pumpAndSettle();
    expect(find.byType(MilestoneCelebrationScreen), findsNothing);
    expect(find.text('open celebration'), findsOneWidget);
  });
}
