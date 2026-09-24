// Regression cover for the "See more" screen.
//
// Every scenario here was a `stats_screen_test.dart` case before the Stats
// redesign moved the peak window, the day-of-week profile, the time
// allocation, interruptions, the focus rating, the session summary, the habit
// leaderboard and the habit heatmap off the main screen. The assertions are
// carried over unchanged on purpose: if a card lost a number in the move, one
// of these fails.
//
// Both themes are pumped for each case — the cards were moved, not restyled,
// but the screen around them is new.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:habit_tracker/core/stats/habit_statistics.dart';
import 'package:habit_tracker/core/stats/statistics.dart';
import 'package:habit_tracker/data/providers/analytics_providers.dart';
import 'package:habit_tracker/data/providers/habit_analytics_providers.dart';
import 'package:habit_tracker/data/repositories/analytics_repository.dart';
import 'package:habit_tracker/features/stats/presentation/stats_detail_screen.dart';
import 'package:habit_tracker/theme/app_theme.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  const period = StatsPeriod(start: '2026-08-15', end: '2026-09-14');

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

  StatsBundle emptyBundle() => StatsBundle(
        period: period,
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

  HabitStatsBundle emptyHabitBundle() => const HabitStatsBundle(
        period: period,
        completionRate: HabitCompletionRate.empty,
        weekdayProfile: HabitWeekdayProfile([]),
        totalCheckOffs: 0,
        activeHabitCount: 0,
        leaderboard: [],
      );

  Widget createTestWidget({
    required ThemeData Function() buildTheme,
    StatsBundle? bundle,
    HabitStatsBundle? habitBundle,
    List<HabitHeatmapCell>? habitHeatmapCells,
    HeatmapThresholds? habitThresholds,
  }) {
    return ProviderScope(
      overrides: [
        statsBundleProvider.overrideWith(
          (ref) => Stream<StatsBundle>.value(bundle ?? emptyBundle()),
        ),
        habitStatsBundleProvider.overrideWith(
          (ref) => Stream<HabitStatsBundle>.value(
            habitBundle ?? emptyHabitBundle(),
          ),
        ),
        habitHeatmapProvider.overrideWith(
          (ref) =>
              Stream<List<HabitHeatmapCell>>.value(habitHeatmapCells ?? const []),
        ),
        habitHeatmapThresholdsProvider.overrideWith(
          (ref) => Future.value(habitThresholds ?? habitHeatmapFallbackThresholds),
        ),
      ],
      child: MaterialApp(theme: buildTheme(), home: const StatsDetailScreen()),
    );
  }

  // Lazy thunks, not values: `AppTheme` reaches for Google Fonts' asset
  // manifest, which needs the test binding that `testWidgets` installs.
  final themes = <String, ThemeData Function()>{
    'light': () => AppTheme.light,
    'dark': () => AppTheme.dark,
  };

  for (final entry in themes.entries) {
    final themeName = entry.key;
    final buildTheme = entry.value;

    group('StatsDetailScreen ($themeName)', () {
      testWidgets('peak window gated under 10 completed sessions', (tester) async {
        final bundle = StatsBundle(
          period: period,
          completionRate: const CompletionRate(completed: 3, abandoned: 1),
          peakWindow: const PeakWindow(
            minutesByHour: [
              0, 0, 0, 0, 0, 0, 0, 0, 0, 50, 0, 0, //
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

        await tester.pumpWidget(createTestWidget(buildTheme: buildTheme, bundle: bundle));
        await tester.pumpAndSettle();

        expect(find.text('When you focus best'), findsOneWidget);
        expect(
            find.text('Needs 10 finished sessions. You have 3.'), findsOneWidget);

        // The session summary came across with the rest.
        expect(find.text('50m'), findsOneWidget);
        expect(find.text('75%'), findsOneWidget);
        expect(find.text('3 of 4 sessions'), findsOneWidget);
      });

      testWidgets('interruptions and focus rating render their null messages',
          (tester) async {
        final bundle = StatsBundle(
          period: period,
          completionRate: const CompletionRate(completed: 0, abandoned: 1),
          peakWindow: emptyPeak(),
          weekdayProfile: emptyProfile(),
          interruptions: emptyInterruption(),
          focusRating: FocusRatingStats.empty,
          timeAllocation: TimeAllocation.empty,
          minutesByDate: const {'2026-09-14': 0},
          totalFocusMinutes: 0,
          activeDayCount: 1,
        );

        await tester.pumpWidget(createTestWidget(buildTheme: buildTheme, bundle: bundle));
        await tester.pumpAndSettle();

        expect(find.text('Interruptions'), findsOneWidget);
        expect(find.text('Finish a session to see this.'), findsOneWidget);
        expect(find.text('How focused you felt'), findsOneWidget);
        expect(find.text('Rate a session when it ends and this fills in.'),
            findsOneWidget);
      });

      testWidgets('full data renders every relocated card', (tester) async {
        final bundle = StatsBundle(
          period: period,
          completionRate: const CompletionRate(completed: 10, abandoned: 2),
          peakWindow: const PeakWindow(
            minutesByHour: [
              0, 0, 0, 0, 0, 0, 0, 0, 0, 150, 0, 0, //
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

        await tester.pumpWidget(createTestWidget(buildTheme: buildTheme, bundle: bundle));
        await tester.pumpAndSettle();

        // Summary
        expect(find.text('4h 10m'), findsOneWidget);
        expect(find.text('83%'), findsOneWidget);
        expect(find.text('10 of 12 sessions'), findsOneWidget);
        expect(find.text('5'), findsNWidgets(2)); // active days + rating label

        // Peak window, unlocked
        expect(find.text('When you focus best'), findsOneWidget);
        expect(find.text('You focus most around 9–10am.'), findsOneWidget);
        expect(find.text('12a'), findsOneWidget);
        expect(find.text('6a'), findsOneWidget);
        expect(find.text('12p'), findsOneWidget);
        expect(find.text('6p'), findsOneWidget);

        // Day of week
        expect(find.text('By day of week'), findsOneWidget);

        // Where the time went
        expect(find.text('Where the time went'), findsOneWidget);
        expect(find.text('Cairn'), findsOneWidget);
        expect(find.text('Unassigned'), findsOneWidget);
        expect(find.text('2h 30m'), findsOneWidget);
        expect(find.text('1h 40m'), findsOneWidget);
        expect(find.text('60%'), findsOneWidget);
        expect(find.text('40%'), findsOneWidget);

        // Interruptions
        expect(find.text('Interruptions'), findsOneWidget);
        expect(find.text('My own thought'), findsOneWidget);
        expect(find.text('Someone else'), findsOneWidget);
        expect(find.text('1 more on sessions you stopped, not counted above.'),
            findsOneWidget);

        // Focus rating
        expect(find.text('How focused you felt'), findsOneWidget);
        expect(find.text('4.0'), findsOneWidget);
        expect(find.text(' / 5'), findsOneWidget);
        expect(find.text('from 8 rated sessions'), findsOneWidget);
      });

      testWidgets('habit leaderboard and habit heatmap came across',
          (tester) async {
        const habitBundle = HabitStatsBundle(
          period: period,
          completionRate: HabitCompletionRate(done: 6, eligible: 8),
          weekdayProfile: HabitWeekdayProfile([]),
          totalCheckOffs: 11,
          activeHabitCount: 2,
          leaderboard: [
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
            buildTheme: buildTheme,
            bundle: emptyBundle(),
            habitBundle: habitBundle,
            habitHeatmapCells: const [
              HabitHeatmapCell(date: '2026-09-14', doneCount: 2, level: 4),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // No focus data, so the focus cards stay away — exactly as they did
        // on the pre-redesign Stats screen.
        expect(find.text('When you focus best'), findsNothing);
        expect(find.text('Where the time went'), findsNothing);

        expect(find.text('Habits'), findsOneWidget);
        expect(find.text('75%'), findsOneWidget); // 6 of 8 eligible days
        expect(find.text('11'), findsOneWidget); // total check-offs
        expect(find.text('2'), findsOneWidget); // active habits
        expect(find.text('Current streaks'), findsOneWidget);
        expect(find.text('Read'), findsOneWidget);
        expect(find.text('Walk'), findsOneWidget);
        expect(find.text('9'), findsOneWidget);
        expect(find.text('3'), findsOneWidget);

        expect(find.text('Habit activity'), findsOneWidget);
      });

      testWidgets('a habit with no eligible days renders an em dash, not 0%',
          (tester) async {
        const habitBundle = HabitStatsBundle(
          period: period,
          completionRate: HabitCompletionRate.empty, // rate == null
          weekdayProfile: HabitWeekdayProfile([]),
          totalCheckOffs: 0,
          activeHabitCount: 1,
          leaderboard: [
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
            buildTheme: buildTheme,
            bundle: emptyBundle(),
            habitBundle: habitBundle,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Habits'), findsOneWidget);
        expect(find.text('—'), findsWidgets);
        expect(find.text('0%'), findsNothing);
      });

      testWidgets('nothing anywhere falls back to the empty state',
          (tester) async {
        await tester.pumpWidget(createTestWidget(buildTheme: buildTheme));
        await tester.pumpAndSettle();

        expect(find.text('Nothing logged yet'), findsOneWidget);
        expect(find.text('When you focus best'), findsNothing);
        expect(find.text('Habits'), findsNothing);
      });
    });
  }
}
