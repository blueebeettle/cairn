import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:habit_tracker/core/stats/habit_statistics.dart';
import 'package:habit_tracker/core/stats/statistics.dart';
import 'package:habit_tracker/data/providers/analytics_providers.dart';
import 'package:habit_tracker/data/providers/habit_analytics_providers.dart';
import 'package:habit_tracker/data/repositories/analytics_repository.dart';
import 'package:habit_tracker/features/stats/presentation/stats_screen.dart';
import 'package:habit_tracker/theme/app_theme.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  PeakWindow emptyPeak() => PeakWindow(
        minutesByHour: List<double>.filled(24, 0.0),
        totalCompletedSessions: 0,
      );

  WeekdayProfile emptyProfile() => WeekdayProfile([
        for (var i = 1; i <= 7; i++)
          WeekdayBin(weekday: i, activeDays: 0, totalMinutes: 0),
      ]);

  InterruptionRate emptyInterruption() => const InterruptionRate(
        internal: 0,
        external: 0,
        focusMinutes: 0,
        abandonedInternal: 0,
        abandonedExternal: 0,
      );

  HabitStatsBundle emptyHabitBundle(StatsPeriod period) => HabitStatsBundle(
        period: period,
        completionRate: HabitCompletionRate.empty,
        weekdayProfile: const HabitWeekdayProfile([]),
        totalCheckOffs: 0,
        activeHabitCount: 0,
        leaderboard: const [],
      );

  Widget createTestWidget({
    StatsBundle? bundle,
    List<HeatmapCell>? heatmapCells,
    HeatmapThresholds? thresholds,
    // Habit-side overrides. Defaulted to "no habits at all" (an
    // `activeHabitCount` of 0) so every existing (focus-only) scenario below
    // renders exactly as it did before the Stats screen grew a habits
    // section, without having to know these providers exist. A test that
    // DOES care about habits passes its own `habitBundle`.
    HabitStatsBundle? habitBundle,
    List<HabitHeatmapCell>? habitHeatmapCells,
    HeatmapThresholds? habitThresholds,
  }) {
    return ProviderScope(
      overrides: [
        if (bundle != null)
          statsBundleProvider.overrideWith(
            (ref) => Stream<StatsBundle>.value(bundle),
          ),
        if (heatmapCells != null)
          heatmapProvider.overrideWith(
            (ref) => Stream<List<HeatmapCell>>.value(heatmapCells),
          ),
        if (thresholds != null)
          heatmapThresholdsProvider.overrideWith(
            (ref) => Future.value(thresholds),
          ),
        // Always overridden (never left to the real, database-backed
        // provider) — `StatsScreen` watches these three unconditionally to
        // decide whether to show a habits section at all, so every test that
        // pumps it must supply them.
        habitStatsBundleProvider.overrideWith(
          (ref) => Stream<HabitStatsBundle>.value(
            habitBundle ??
                emptyHabitBundle(
                  bundle?.period ??
                      const StatsPeriod(start: '2026-08-15', end: '2026-09-14'),
                ),
          ),
        ),
        habitHeatmapProvider.overrideWith(
          (ref) => Stream<List<HabitHeatmapCell>>.value(habitHeatmapCells ?? const []),
        ),
        habitHeatmapThresholdsProvider.overrideWith(
          (ref) => Future.value(habitThresholds ?? habitHeatmapFallbackThresholds),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const StatsScreen(),
      ),
    );
  }

  group('StatsScreen — Empty & Null Semantics (SPEC §4)', () {
    testWidgets('empty state renders only range picker and "Nothing logged yet"',
        (WidgetTester tester) async {
      final emptyBundle = StatsBundle(
        period: const StatsPeriod(start: '2026-08-15', end: '2026-09-14'),
        completionRate: CompletionRate.empty,
        peakWindow: emptyPeak(),
        weekdayProfile: emptyProfile(),
        interruptions: emptyInterruption(),
        focusRating: FocusRatingStats.empty,
        timeAllocation: TimeAllocation.empty,
        minutesByDate: const {},
        totalFocusMinutes: 0,
        activeDayCount: 0,
      );

      await tester.pumpWidget(
        createTestWidget(
          bundle: emptyBundle,
          heatmapCells: const [],
          thresholds: HeatmapThresholds.fallback,
        ),
      );
      await tester.pumpAndSettle();

      // Range picker is present
      expect(find.text('Week'), findsOneWidget);
      expect(find.text('30d'), findsOneWidget);
      expect(find.text('90d'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);

      // Centered empty state
      expect(find.text('Nothing logged yet'), findsOneWidget);
      expect(find.text('Finish a focus session and this screen fills in.'),
          findsOneWidget);

      // No cards should be rendered
      expect(find.text('When you focus best'), findsNothing);
      expect(find.text('Activity'), findsNothing);
      expect(find.text('By day of week'), findsNothing);
      expect(find.text('Where the time went'), findsNothing);
      expect(find.text('Interruptions'), findsNothing);
      expect(find.text('How focused you felt'), findsNothing);
    });

    testWidgets(
        'Card 2 peak window: gated when < 10 completed sessions shows em dash and needs message',
        (WidgetTester tester) async {
      final bundle = StatsBundle(
        period: const StatsPeriod(start: '2026-08-15', end: '2026-09-14'),
        completionRate: const CompletionRate(completed: 3, abandoned: 1),
        peakWindow: const PeakWindow(
          minutesByHour: [
            0, 0, 0, 0, 0, 0, 0, 0, 0, 50, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
          ],
          totalCompletedSessions: 3,
        ),
        weekdayProfile: emptyProfile(),
        interruptions: emptyInterruption(),
        focusRating: FocusRatingStats.empty,
        timeAllocation: TimeAllocation.empty,
        minutesByDate: const {'2026-09-14': 50},
        totalFocusMinutes: 50,
        activeDayCount: 1,
      );

      await tester.pumpWidget(
        createTestWidget(
          bundle: bundle,
          heatmapCells: const [
            HeatmapCell(date: '2026-09-14', minutes: 50, level: 2),
          ],
          thresholds: HeatmapThresholds.fallback,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('When you focus best'), findsOneWidget);
      expect(find.text('Needs 10 finished sessions. You have 3.'), findsOneWidget);

      // Summary card shows real numbers
      expect(find.text('50m'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
      expect(find.text('3 of 4 sessions'), findsOneWidget);
    });

    testWidgets('Card 6 Interruptions: null rates render em dash and message',
        (WidgetTester tester) async {
      final bundle = StatsBundle(
        period: const StatsPeriod(start: '2026-08-15', end: '2026-09-14'),
        completionRate: const CompletionRate(completed: 0, abandoned: 1),
        peakWindow: emptyPeak(),
        weekdayProfile: emptyProfile(),
        interruptions: emptyInterruption(), // focusMinutes = 0 -> perHourTotal == null
        focusRating: FocusRatingStats.empty, // mean == null
        timeAllocation: TimeAllocation.empty,
        minutesByDate: const {'2026-09-14': 0},
        totalFocusMinutes: 0,
        activeDayCount: 1,
      );

      await tester.pumpWidget(
        createTestWidget(
          bundle: bundle,
          heatmapCells: const [
            HeatmapCell(date: '2026-09-14', minutes: 0, level: 0),
          ],
          thresholds: HeatmapThresholds.fallback,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Interruptions'), findsOneWidget);
      expect(find.text('Finish a session to see this.'), findsOneWidget);

      expect(find.text('How focused you felt'), findsOneWidget);
      expect(find.text('Rate a session when it ends and this fills in.'),
          findsOneWidget);
    });

    testWidgets('Full stats with real data render all charts and captions',
        (WidgetTester tester) async {
      final bundle = StatsBundle(
        period: const StatsPeriod(start: '2026-08-15', end: '2026-09-14'),
        completionRate: const CompletionRate(completed: 10, abandoned: 2),
        peakWindow: const PeakWindow(
          minutesByHour: [
            0, 0, 0, 0, 0, 0, 0, 0, 0, 150, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
          ],
          totalCompletedSessions: 10,
        ),
        weekdayProfile: const WeekdayProfile([
          WeekdayBin(weekday: 1, activeDays: 3, totalMinutes: 150),
          WeekdayBin(weekday: 2, activeDays: 2, totalMinutes: 80),
          WeekdayBin(weekday: 3, activeDays: 0, totalMinutes: 0),
          WeekdayBin(weekday: 4, activeDays: 1, totalMinutes: 25),
          WeekdayBin(weekday: 5, activeDays: 2, totalMinutes: 120),
          WeekdayBin(weekday: 6, activeDays: 0, totalMinutes: 0),
          WeekdayBin(weekday: 7, activeDays: 1, totalMinutes: 30),
        ]),
        interruptions: const InterruptionRate(
          internal: 4,
          external: 2,
          focusMinutes: 120,
          abandonedInternal: 1,
          abandonedExternal: 0,
        ),
        focusRating: const FocusRatingStats(
          n: 8,
          sum: 32,
          distribution: [0, 1, 2, 3, 2],
        ),
        timeAllocation: const TimeAllocation(
          slices: [
            AllocationSlice(
              projectId: 'p1',
              label: 'Cairn',
              minutes: 150,
              totalMinutes: 250,
            ),
            AllocationSlice(
              projectId: null,
              label: 'Unassigned',
              minutes: 100,
              totalMinutes: 250,
            ),
          ],
          totalMinutes: 250,
        ),
        minutesByDate: const {'2026-09-14': 250},
        totalFocusMinutes: 250,
        activeDayCount: 5,
      );

      await tester.pumpWidget(
        createTestWidget(
          bundle: bundle,
          heatmapCells: const [
            HeatmapCell(date: '2026-09-14', minutes: 250, level: 4),
          ],
          thresholds: const HeatmapThresholds(
            level1Max: 25,
            level2Max: 50,
            level3Max: 100,
            level4Nominal: 180,
            provisional: false,
            nonZeroDayCount: 15,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Summary
      expect(find.text('4h 10m'), findsOneWidget); // 250 min = 4h 10m
      expect(find.text('83%'), findsOneWidget);
      expect(find.text('10 of 12 sessions'), findsOneWidget);
      expect(find.text('5'), findsNWidgets(2)); // active days + rating 5 label

      // Peak Window unlocked (>= 10 sessions)
      expect(find.text('When you focus best'), findsOneWidget);
      expect(find.text('You focus most around 9–10am.'), findsOneWidget);
      expect(find.text('12a'), findsOneWidget);
      expect(find.text('6a'), findsOneWidget);
      expect(find.text('12p'), findsOneWidget);
      expect(find.text('6p'), findsOneWidget);

      // Where the time went
      expect(find.text('Where the time went'), findsOneWidget);
      expect(find.text('Cairn'), findsOneWidget);
      expect(find.text('Unassigned'), findsOneWidget);
      expect(find.text('2h 30m'), findsOneWidget); // 150m
      expect(find.text('1h 40m'), findsOneWidget); // 100m
      expect(find.text('60%'), findsOneWidget);
      expect(find.text('40%'), findsOneWidget);

      // Interruptions
      expect(find.text('Interruptions'), findsOneWidget);
      expect(find.text('My own thought'), findsOneWidget);
      expect(find.text('Someone else'), findsOneWidget);
      expect(
          find.text('1 more on sessions you stopped, not counted above.'),
          findsOneWidget);

      // Focus Rating
      expect(find.text('How focused you felt'), findsOneWidget);
      expect(find.text('4.0'), findsOneWidget);
      expect(find.text(' / 5'), findsOneWidget);
      expect(find.text('from 8 rated sessions'), findsOneWidget);
    });

    testWidgets(
        'habits-only data (no focus sessions) skips the empty state and shows the Habits cards',
        (WidgetTester tester) async {
      final emptyBundle = StatsBundle(
        period: const StatsPeriod(start: '2026-08-15', end: '2026-09-14'),
        completionRate: CompletionRate.empty,
        peakWindow: emptyPeak(),
        weekdayProfile: emptyProfile(),
        interruptions: emptyInterruption(),
        focusRating: FocusRatingStats.empty,
        timeAllocation: TimeAllocation.empty,
        minutesByDate: const {},
        totalFocusMinutes: 0,
        activeDayCount: 0,
      );

      final habitBundle = HabitStatsBundle(
        period: const StatsPeriod(start: '2026-08-15', end: '2026-09-14'),
        completionRate: const HabitCompletionRate(done: 6, eligible: 8),
        weekdayProfile: const HabitWeekdayProfile([]),
        totalCheckOffs: 11,
        activeHabitCount: 2,
        leaderboard: const [
          HabitLeaderboardEntry(
            habitId: 'h1',
            title: 'Read',
            colorIndex: 0,
            iconName: 'book',
            currentStreak: 9,
            longestStreak: 14,
          ),
          HabitLeaderboardEntry(
            habitId: 'h2',
            title: 'Walk',
            colorIndex: 1,
            iconName: 'walk',
            currentStreak: 3,
            longestStreak: 3,
          ),
        ],
      );

      await tester.pumpWidget(
        createTestWidget(
          bundle: emptyBundle,
          heatmapCells: const [],
          thresholds: HeatmapThresholds.fallback,
          habitBundle: habitBundle,
          habitHeatmapCells: const [
            HabitHeatmapCell(date: '2026-09-14', doneCount: 2, level: 4),
          ],
          habitThresholds: habitHeatmapFallbackThresholds,
        ),
      );
      await tester.pumpAndSettle();

      // No whole-screen empty state — habits have data even though focus
      // sessions don't.
      expect(find.text('Nothing logged yet'), findsNothing);

      // None of the focus-only cards render when the focus bundle is empty.
      expect(find.text('When you focus best'), findsNothing);
      expect(find.text('Where the time went'), findsNothing);

      // The habits cards do.
      expect(find.text('Habits'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget); // 6 of 8 eligible days
      expect(find.text('11'), findsOneWidget); // total check-offs
      expect(find.text('2'), findsOneWidget); // active habits
      expect(find.text('Current streaks'), findsOneWidget);
      expect(find.text('Read'), findsOneWidget);
      expect(find.text('Walk'), findsOneWidget);
      expect(find.text('9'), findsOneWidget); // Read's current streak
      expect(find.text('3'), findsOneWidget); // Walk's current streak

      expect(find.text('Habit activity'), findsOneWidget);
    });

    testWidgets(
        'a habit with no eligible days yet renders an em dash, not 0%',
        (WidgetTester tester) async {
      final emptyBundle = StatsBundle(
        period: const StatsPeriod(start: '2026-08-15', end: '2026-09-14'),
        completionRate: CompletionRate.empty,
        peakWindow: emptyPeak(),
        weekdayProfile: emptyProfile(),
        interruptions: emptyInterruption(),
        focusRating: FocusRatingStats.empty,
        timeAllocation: TimeAllocation.empty,
        minutesByDate: const {},
        totalFocusMinutes: 0,
        activeDayCount: 0,
      );

      final habitBundle = HabitStatsBundle(
        period: const StatsPeriod(start: '2026-08-15', end: '2026-09-14'),
        completionRate: HabitCompletionRate.empty, // rate == null
        weekdayProfile: const HabitWeekdayProfile([]),
        totalCheckOffs: 0,
        activeHabitCount: 1,
        leaderboard: const [
          HabitLeaderboardEntry(
            habitId: 'h1',
            title: 'Meditate',
            colorIndex: 2,
            iconName: 'meditate',
            currentStreak: 0,
            longestStreak: 0,
          ),
        ],
      );

      await tester.pumpWidget(
        createTestWidget(
          bundle: emptyBundle,
          heatmapCells: const [],
          thresholds: HeatmapThresholds.fallback,
          habitBundle: habitBundle,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Habits'), findsOneWidget);
      // Governing rule (SPEC §4/§10.5): a zero-denominator rate is an em
      // dash, never 0%.
      expect(find.text('—'), findsWidgets);
      expect(find.text('0%'), findsNothing);
    });
  });
}
