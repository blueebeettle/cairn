// Widget cover for the redesigned Stats screen: the pill range picker, the
// "This month" hero, the "Your journey" trail, the ringed activity heatmap,
// the 2×2 tile grid and the "See more" entry point.
//
// The cards this screen used to stack below the fold now live on
// `StatsDetailScreen`; their assertions moved with them to
// `stats_detail_screen_test.dart`, which is the regression check that the
// extraction lost nothing.
//
// Everything is driven through `ProviderScope` overrides rather than a real
// database — the arithmetic underneath is covered without widgets in
// `statistics_test.dart`, `stats_focus_test.dart` and `stats_redesign_test.dart`.
// Both themes are pumped for each case.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:habit_tracker/core/habits/habit_streak.dart';
import 'package:habit_tracker/core/stats/habit_statistics.dart';
import 'package:habit_tracker/core/stats/statistics.dart';
import 'package:habit_tracker/core/time/time_service.dart';
import 'package:habit_tracker/core/widgets/cairn_glyph.dart';
import 'package:habit_tracker/data/database/app_database.dart';
import 'package:habit_tracker/data/providers/analytics_providers.dart';
import 'package:habit_tracker/data/providers/database_provider.dart';
import 'package:habit_tracker/data/providers/habit_analytics_providers.dart';
import 'package:habit_tracker/data/providers/habit_providers.dart';
import 'package:habit_tracker/data/repositories/analytics_repository.dart';
import 'package:habit_tracker/data/repositories/habits_repository.dart';
import 'package:habit_tracker/data/repositories/stats_repository.dart';
import 'package:habit_tracker/features/habits/presentation/widgets/habit_milestone.dart';
import 'package:habit_tracker/features/stats/presentation/stats_detail_screen.dart';
import 'package:habit_tracker/features/stats/presentation/stats_screen.dart';
import 'package:habit_tracker/theme/app_theme.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  const today = '2026-09-14'; // a Monday, so week starts land on it

  /// A [TimeService] pinned to [today] in UTC, so the period the screen
  /// derives from the range picker is the same on every machine.
  TimeService fixedTime() => TimeService(
        weekStart: DateTime.monday,
        nowProvider: () =>
            DateTime.utc(2026, 9, 14, 12).millisecondsSinceEpoch,
        localize: (ms) =>
            DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
        offsetMinutesAt: (_) => 0,
        tzIdProvider: () => 'UTC',
      );

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

  StatsBundle bundleOf({
    required StatsPeriod period,
    CompletionRate completionRate = CompletionRate.empty,
    WeekdayProfile? weekdayProfile,
    Map<String, int> minutesByDate = const {},
    int totalFocusMinutes = 0,
    int activeDayCount = 0,
  }) =>
      StatsBundle(
        period: period,
        completionRate: completionRate,
        peakWindow: emptyPeak(),
        weekdayProfile: weekdayProfile ?? emptyProfile(),
        interruptions: emptyInterruption(),
        focusRating: FocusRatingStats.empty,
        timeAllocation: TimeAllocation.empty,
        minutesByDate: minutesByDate,
        totalFocusMinutes: totalFocusMinutes,
        activeDayCount: activeDayCount,
      );

  HabitStatsBundle habitBundleOf({
    required StatsPeriod period,
    int totalCheckOffs = 0,
    int activeHabitCount = 0,
  }) =>
      HabitStatsBundle(
        period: period,
        completionRate: HabitCompletionRate.empty,
        weekdayProfile: const HabitWeekdayProfile([]),
        totalCheckOffs: totalCheckOffs,
        activeHabitCount: activeHabitCount,
        leaderboard: const [],
      );

  /// A habit snapshot whose only job is to carry [excusedDates] into
  /// `excusedThisMonth` for the "freezes used" tile.
  HabitSnapshot snapshotWithExcused(String id, List<String> excusedDates) =>
      HabitSnapshot(
        habit: Habit(
          id: id,
          title: 'Habit $id',
          colorIndex: 0,
          iconName: 'check',
          scheduleRule: 'FREQ=DAILY',
          anchorDate: '2026-01-01',
          targetCount: 1,
          skipAllowancePerMonth: 4,
          status: 'active',
          sortOrder: 0,
          createdAt: 0,
          createdLocalDate: '2026-01-01',
          updatedAt: 0,
          deviceId: 'test',
        ),
        scheduledDates: excusedDates,
        entries: const {},
        streaks: HabitStreakResult(
          current: 0,
          longest: 0,
          outcomes: {
            for (final d in excusedDates) d: HabitDayOutcome.neutral,
          },
        ),
        todayLocalDate: today,
      );

  /// The milestone ring: the only 1.5px-bordered box on the screen.
  final ringFinder = find.byWidgetPredicate((w) {
    if (w is! DecoratedBox) return false;
    final decoration = w.decoration;
    if (decoration is! BoxDecoration) return false;
    final border = decoration.border;
    return border is Border && border.top.width == 1.5;
  });

  StatsPeriod periodFor(StatsRange range) => switch (range) {
        StatsRange.week => StatsPeriod.week(fixedTime(), today),
        StatsRange.month => StatsPeriod.lastNDays(today, 30),
        StatsRange.quarter => StatsPeriod.lastNDays(today, 90),
        StatsRange.allTime => StatsPeriod.allTime,
      };

  Widget createTestWidget({
    required ThemeData Function() buildTheme,
    StatsRange range = StatsRange.month,
    StatsBundle? bundle,
    List<HeatmapCell> heatmapCells = const [],
    HeatmapThresholds? thresholds,
    Set<String> milestoneDates = const {},
    double? trend,
    FocusStats focusStats = FocusStats.empty,
    HabitStatsBundle? habitBundle,
    List<HabitSnapshot> habitSnapshots = const [],
  }) {
    final period = bundle?.period ?? periodFor(range);
    return ProviderScope(
      // A fresh key per call, so a test that re-pumps with different
      // overrides gets a new scope rather than the first pump's already
      // resolved providers.
      key: UniqueKey(),
      overrides: [
        timeServiceProvider.overrideWithValue(fixedTime()),
        statsRangeProvider.overrideWith((ref) => range),
        statsBundleProvider.overrideWith(
          (ref) => Stream<StatsBundle>.value(
            bundle ?? bundleOf(period: period),
          ),
        ),
        heatmapProvider.overrideWith(
          (ref) => Stream<List<HeatmapCell>>.value(heatmapCells),
        ),
        heatmapThresholdsProvider.overrideWith(
          (ref) => Future.value(thresholds ?? HeatmapThresholds.fallback),
        ),
        focusMilestoneDatesProvider.overrideWith(
          (ref) => Stream<Set<String>>.value(milestoneDates),
        ),
        statsTrendProvider.overrideWith((ref) async => trend),
        focusStatsProvider.overrideWith(
          (ref) => Stream<FocusStats>.value(focusStats),
        ),
        habitStatsBundleProvider.overrideWith(
          (ref) => Stream<HabitStatsBundle>.value(
            habitBundle ?? habitBundleOf(period: period),
          ),
        ),
        habitSnapshotsProvider.overrideWith((ref) async => habitSnapshots),
      ],
      child: MaterialApp(theme: buildTheme(), home: const StatsScreen()),
    );
  }

  // Lazy thunks, not values: `AppTheme` reaches for Google Fonts' asset
  // manifest, which needs the binding `testWidgets` installs.
  final themes = <String, ThemeData Function()>{
    'light': () => AppTheme.light,
    'dark': () => AppTheme.dark,
  };

  for (final entry in themes.entries) {
    final themeName = entry.key;
    final buildTheme = entry.value;

    group('StatsScreen ($themeName) — empty state', () {
      testWidgets('nothing logged anywhere shows the picker and the message',
          (tester) async {
        await tester.pumpWidget(createTestWidget(buildTheme: buildTheme));
        await tester.pumpAndSettle();

        expect(find.text('Week'), findsOneWidget);
        expect(find.text('30d'), findsOneWidget);
        expect(find.text('90d'), findsOneWidget);
        expect(find.text('All'), findsOneWidget);

        expect(find.text('Nothing logged yet'), findsOneWidget);
        expect(find.text('Finish a focus session and this screen fills in.'),
            findsOneWidget);

        // None of the redesigned sections render behind the empty state.
        expect(find.text('YOUR JOURNEY'), findsNothing);
        expect(find.text('ACTIVITY'), findsNothing);
        expect(find.text('See more'), findsNothing);
      });
    });

    group('StatsScreen ($themeName) — hero card', () {
      testWidgets('shows the period completion rate and its label',
          (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            buildTheme: buildTheme,
            bundle: bundleOf(
              period: periodFor(StatsRange.month),
              completionRate: const CompletionRate(completed: 89, abandoned: 11),
              minutesByDate: const {today: 120},
              totalFocusMinutes: 120,
              activeDayCount: 4,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('89%'), findsOneWidget);
        expect(find.text('completion rate'), findsOneWidget);
        // The label follows the picker rather than saying "This month" at
        // every range, which is what the board's literal copy would do.
        expect(find.text('LAST 30 DAYS'), findsOneWidget);
      });

      testWidgets('no sessions in the period is an em dash, never 0%',
          (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            buildTheme: buildTheme,
            bundle: bundleOf(
              period: periodFor(StatsRange.month),
              completionRate: CompletionRate.empty,
              activeDayCount: 2, // events, but no sessions
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('—'), findsWidgets);
        expect(find.text('0%'), findsNothing);
      });

      testWidgets('all sessions abandoned is a real 0%, not an em dash',
          (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            buildTheme: buildTheme,
            bundle: bundleOf(
              period: periodFor(StatsRange.month),
              completionRate: const CompletionRate(completed: 0, abandoned: 8),
              activeDayCount: 3,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('0%'), findsOneWidget);
      });

      testWidgets('a positive trend renders as a signed chip', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            buildTheme: buildTheme,
            trend: 0.12,
            bundle: bundleOf(
              period: periodFor(StatsRange.month),
              completionRate: const CompletionRate(completed: 9, abandoned: 1),
              activeDayCount: 3,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('+12%'), findsOneWidget);
      });

      testWidgets('a negative trend keeps its minus sign', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            buildTheme: buildTheme,
            trend: -0.09,
            bundle: bundleOf(
              period: periodFor(StatsRange.month),
              completionRate: const CompletionRate(completed: 5, abandoned: 5),
              activeDayCount: 3,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('-9%'), findsOneWidget);
      });

      testWidgets('a null trend hides the chip entirely', (tester) async {
        // All time, or a prior period with no sessions in it. Either way
        // there is no comparison to draw, and the chip must not appear as
        // "+0%" or "+∞%".
        await tester.pumpWidget(
          createTestWidget(
            buildTheme: buildTheme,
            range: StatsRange.allTime,
            trend: null,
            bundle: bundleOf(
              period: periodFor(StatsRange.allTime),
              completionRate: const CompletionRate(completed: 9, abandoned: 1),
              activeDayCount: 3,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('%'), findsOneWidget); // only the rate
        expect(find.text('90%'), findsOneWidget);
      });

      testWidgets('behind the personal best, the line names the gap',
          (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            buildTheme: buildTheme,
            focusStats: const FocusStats(
              focusMinutesToday: 30,
              currentStreakDays: 30,
              longestStreakDays: 45,
              dailyGoalMinutes: 25,
            ),
            bundle: bundleOf(
              period: periodFor(StatsRange.month),
              activeDayCount: 3,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Longest streak: 45 days — 15 more takes you past your '
              'all-time best.'),
          findsOneWidget,
        );
      });

      testWidgets('on a new best, the line does not claim days remain',
          (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            buildTheme: buildTheme,
            focusStats: const FocusStats(
              focusMinutesToday: 30,
              currentStreakDays: 45,
              longestStreakDays: 45,
              dailyGoalMinutes: 25,
            ),
            bundle: bundleOf(
              period: periodFor(StatsRange.month),
              activeDayCount: 3,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text("You're on your best streak yet."), findsOneWidget);
        expect(find.textContaining('0 more takes you'), findsNothing);
      });

      testWidgets('the boards\' unverifiable headline is not rendered',
          (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            buildTheme: buildTheme,
            bundle: bundleOf(
              period: periodFor(StatsRange.month),
              activeDayCount: 3,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Your best month yet'), findsNothing);
      });
    });

    group('StatsScreen ($themeName) — journey trail', () {
      /// Focus minutes on every day of the last 100, so each range has data
      /// across its whole span.
      Map<String, int> denseMinutes() => {
            for (var i = 0; i < 100; i++) TimeService.addDays(today, -i): 40,
          };

      Future<void> pumpRange(WidgetTester tester, StatsRange range) async {
        await tester.pumpWidget(
          createTestWidget(
            buildTheme: buildTheme,
            range: range,
            bundle: bundleOf(
              period: periodFor(range),
              completionRate: const CompletionRate(completed: 40, abandoned: 5),
              minutesByDate: denseMinutes(),
              totalFocusMinutes: 4000,
              activeDayCount: 100,
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      testWidgets('Week renders exactly one glyph, labelled Now',
          (tester) async {
        await pumpRange(tester, StatsRange.week);
        expect(find.text('YOUR JOURNEY'), findsOneWidget);
        expect(find.byType(CairnGlyph), findsOneWidget);
        expect(find.text('Now'), findsOneWidget);
        expect(find.text('W1'), findsNothing);
      });

      testWidgets('30d renders six columns, the last one Now', (tester) async {
        await pumpRange(tester, StatsRange.month);
        expect(find.byType(CairnGlyph), findsNWidgets(6));
        expect(find.text('Now'), findsOneWidget);
        expect(find.text('W1'), findsOneWidget);
        expect(find.text('W5'), findsOneWidget);
        // The last column is "Now", not "W6".
        expect(find.text('W6'), findsNothing);
      });

      testWidgets('90d is capped at eight columns rather than overflowing',
          (tester) async {
        await pumpRange(tester, StatsRange.quarter);
        expect(find.byType(CairnGlyph), findsNWidgets(8));
        expect(find.text('Now'), findsOneWidget);
        expect(find.text('W7'), findsOneWidget);
        expect(find.text('W8'), findsNothing);
      });

      testWidgets('All time is capped at eight columns too', (tester) async {
        await pumpRange(tester, StatsRange.allTime);
        expect(find.byType(CairnGlyph), findsNWidgets(8));
        expect(find.text('Now'), findsOneWidget);
      });

      for (final range in StatsRange.values) {
        testWidgets('${range.label}: the trail row does not overflow',
            (tester) async {
          // The narrowest phone the redesign targets is the boards' own
          // 390-wide frame; 360 is the smallest Android width in common use.
          tester.view.physicalSize = const Size(360, 800);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await pumpRange(tester, range);

          // A RenderFlex overflow reports through the exception channel, and
          // `pumpAndSettle` would already have surfaced it — assert on it
          // explicitly so the intent of this test is not silent.
          expect(tester.takeException(), isNull);

          // Every glyph is inside the card, and the row is bottom-aligned.
          final glyphs = tester.widgetList<CairnGlyph>(find.byType(CairnGlyph));
          expect(glyphs, isNotEmpty);
          for (final glyph in glyphs) {
            expect(glyph.scale, lessThanOrEqualTo(journeyMaxScale));
            expect(glyph.scale, greaterThanOrEqualTo(journeyMinScale));
          }
          // Only the newest column carries the marker.
          expect(glyphs.where((g) => g.showMarker), hasLength(1));
        });
      }
    });

    group('StatsScreen ($themeName) — activity heatmap', () {
      testWidgets('renders the legend and its Less/More labels',
          (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            buildTheme: buildTheme,
            bundle: bundleOf(
              period: periodFor(StatsRange.month),
              minutesByDate: const {today: 60},
              activeDayCount: 1,
            ),
            heatmapCells: const [
              HeatmapCell(date: '2026-09-14', minutes: 60, level: 3),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('ACTIVITY'), findsOneWidget);
        expect(find.text('Less'), findsOneWidget);
        expect(find.text('More'), findsOneWidget);
      });

      testWidgets('a milestone date gets a ring and an ordinary day does not',
          (tester) async {
        const cells = [
          HeatmapCell(date: '2026-09-13', minutes: 60, level: 3),
          HeatmapCell(date: '2026-09-14', minutes: 60, level: 3),
        ];

        Future<void> pump(Set<String> milestoneDates) async {
          await tester.pumpWidget(
            createTestWidget(
              buildTheme: buildTheme,
              bundle: bundleOf(
                period: periodFor(StatsRange.month),
                minutesByDate: const {today: 60},
                activeDayCount: 1,
              ),
              heatmapCells: cells,
              milestoneDates: milestoneDates,
            ),
          );
          await tester.pumpAndSettle();
        }

        // Without a milestone set, no square is ringed.
        await pump(const {});
        expect(ringFinder, findsNothing);

        // With one of the two dates marked, exactly one ring appears, in the
        // milestone accent rather than a hardcoded lavender.
        await pump(const {'2026-09-14'});
        expect(ringFinder, findsOneWidget);

        final ring = tester.widget<DecoratedBox>(ringFinder);
        final border = (ring.decoration as BoxDecoration).border! as Border;
        final context = tester.element(find.byType(StatsScreen));
        expect(border.top.color, equals(MilestoneChrome.accent(context)));

        // Both marked: two rings, so it tracks the set rather than being
        // drawn once on whatever cell happens to be first.
        await pump(const {'2026-09-13', '2026-09-14'});
        expect(ringFinder, findsNWidgets(2));
      });

      testWidgets('a provisional scale still says so', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            buildTheme: buildTheme,
            bundle: bundleOf(
              period: periodFor(StatsRange.month),
              minutesByDate: const {today: 60},
              activeDayCount: 1,
            ),
            heatmapCells: const [
              HeatmapCell(date: '2026-09-14', minutes: 60, level: 3),
            ],
            thresholds: const HeatmapThresholds(
              level1Max: 25,
              level2Max: 50,
              level3Max: 100,
              level4Nominal: 180,
              provisional: true,
              nonZeroDayCount: 5,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Provisional scale — 5 days of focus so far.'),
          findsOneWidget,
        );
      });
    });

    group('StatsScreen ($themeName) — heatmap vs the range picker', () {
      testWidgets('an empty range still shows the trailing-365-day heatmap',
          (tester) async {
        // The bug: `heatmapProvider` is fixed to the trailing 365 days on
        // purpose, but the card was gated on the *selected range* having
        // sessions. Picking "Week" during a quiet week hid a whole year of
        // history that had nothing to do with the selection.
        await tester.pumpWidget(
          createTestWidget(
            buildTheme: buildTheme,
            range: StatsRange.week,
            bundle: bundleOf(
              period: periodFor(StatsRange.week),
              completionRate: CompletionRate.empty,
              minutesByDate: const {},
              activeDayCount: 0, // nothing at all in the selected week
            ),
            // ...but the year behind it is not empty.
            heatmapCells: const [
              HeatmapCell(date: '2026-06-01', minutes: 90, level: 4),
              HeatmapCell(date: '2026-06-02', minutes: 45, level: 2),
            ],
            // A habit exists, so the screen is past its whole-screen empty
            // state and we are testing the card's own gate.
            habitBundle: habitBundleOf(
              period: periodFor(StatsRange.week),
              activeHabitCount: 1,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('ACTIVITY'), findsOneWidget);
        expect(find.text('Less'), findsOneWidget);
        expect(find.text('More'), findsOneWidget);

        // The trail is genuinely period-scoped, so it correctly stays away.
        expect(find.text('YOUR JOURNEY'), findsNothing);
      });

      testWidgets("a brand-new user gets the heatmap's own empty state",
          (tester) async {
        // Zero sessions ever: the card still renders and shows its em dash
        // rather than erroring or vanishing.
        await tester.pumpWidget(
          createTestWidget(
            buildTheme: buildTheme,
            bundle: bundleOf(
              period: periodFor(StatsRange.month),
              activeDayCount: 0,
            ),
            heatmapCells: const [],
            habitBundle: habitBundleOf(
              period: periodFor(StatsRange.month),
              activeHabitCount: 1,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('ACTIVITY'), findsOneWidget);
        expect(find.text('—'), findsWidgets);
      });
    });

    group('StatsScreen ($themeName) — label clarity', () {
      StatsBundle heatmapBundle() => bundleOf(
            period: periodFor(StatsRange.month),
            minutesByDate: const {today: 60},
            activeDayCount: 4,
            weekdayProfile: const WeekdayProfile([
              WeekdayBin(weekday: 1, activeDays: 3, totalMinutes: 60),
              WeekdayBin(weekday: 2, activeDays: 2, totalMinutes: 180),
              WeekdayBin(weekday: 3, activeDays: 0, totalMinutes: 0),
              WeekdayBin(weekday: 4, activeDays: 0, totalMinutes: 0),
              WeekdayBin(weekday: 5, activeDays: 0, totalMinutes: 0),
              WeekdayBin(weekday: 6, activeDays: 0, totalMinutes: 0),
              WeekdayBin(weekday: 7, activeDays: 0, totalMinutes: 0),
            ]),
          );

      testWidgets('the Activity card says what it measures and over what window',
          (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            buildTheme: buildTheme,
            bundle: heatmapBundle(),
            heatmapCells: const [
              HeatmapCell(date: '2026-09-12', minutes: 34, level: 2),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('ACTIVITY'), findsOneWidget);
        // Visible without any interaction — the window is fixed at 365 days
        // and does not follow the range picker right above it.
        expect(find.text('Focus minutes · last 365 days'), findsOneWidget);
      });

      testWidgets('each heatmap square carries its own date and minutes',
          (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            buildTheme: buildTheme,
            bundle: heatmapBundle(),
            heatmapCells: const [
              HeatmapCell(date: '2026-09-12', minutes: 34, level: 2),
              HeatmapCell(date: '2026-09-13', minutes: 0, level: 0),
              HeatmapCell(date: '2026-09-14', minutes: 95, level: 4),
            ],
          ),
        );
        await tester.pumpAndSettle();

        final messages = tester
            .widgetList<Tooltip>(find.byType(Tooltip))
            .map((t) => t.message)
            .toList();

        expect(messages, contains('Sep 12 · 34m focused'));
        expect(messages, contains('Sep 14 · 1h 35m focused'));
        // A zero day says what happened, not "0m focused".
        expect(messages, contains('Sep 13 · no sessions'));
        expect(messages, isNot(contains('Sep 13 · 0m focused')));
      });

      testWidgets('the four tiles state their scope in the visible label',
          (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            buildTheme: buildTheme,
            bundle: heatmapBundle(),
            habitBundle: habitBundleOf(
              period: periodFor(StatsRange.month),
              totalCheckOffs: 30,
              activeHabitCount: 2,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('best streak ever (days)'), findsOneWidget);
        expect(find.text('strongest day (avg)'), findsOneWidget);
        expect(find.text('habits kept / day'), findsOneWidget);
        expect(find.text('freezes used (this month)'), findsOneWidget);

        // The old, ambiguous wordings are gone.
        expect(find.text('best streak (days)'), findsNothing);
        expect(find.text('your strongest day'), findsNothing);
        expect(find.text('freezes used'), findsNothing);
      });

      testWidgets('the scope-sensitive tiles also carry a tooltip',
          (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            buildTheme: buildTheme,
            bundle: heatmapBundle(),
          ),
        );
        await tester.pumpAndSettle();

        String tooltipOver(String label) => tester
            .widget<Tooltip>(find.ancestor(
              of: find.text(label),
              matching: find.byType(Tooltip),
            ))
            .message!;

        expect(tooltipOver('best streak ever (days)'),
            contains('not limited to the range above'));
        expect(tooltipOver('strongest day (avg)'),
            contains('not your highest total'));
        expect(tooltipOver('freezes used (this month)'),
            contains('Not affected by the range above'));
      });

      testWidgets('tile labels do not overflow at 390pt', (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          createTestWidget(buildTheme: buildTheme, bundle: heatmapBundle()),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    });

    group('StatsScreen ($themeName) — tile grid', () {
      testWidgets('all four tiles read off their own providers',
          (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            buildTheme: buildTheme,
            focusStats: const FocusStats(
              focusMinutesToday: 30,
              currentStreakDays: 12,
              longestStreakDays: 45,
              dailyGoalMinutes: 25,
            ),
            bundle: bundleOf(
              period: periodFor(StatsRange.month),
              activeDayCount: 6,
              weekdayProfile: const WeekdayProfile([
                WeekdayBin(weekday: 1, activeDays: 3, totalMinutes: 60),
                WeekdayBin(weekday: 2, activeDays: 2, totalMinutes: 180), // 90
                WeekdayBin(weekday: 3, activeDays: 0, totalMinutes: 0),
                WeekdayBin(weekday: 4, activeDays: 1, totalMinutes: 25),
                WeekdayBin(weekday: 5, activeDays: 0, totalMinutes: 0),
                WeekdayBin(weekday: 6, activeDays: 0, totalMinutes: 0),
                WeekdayBin(weekday: 7, activeDays: 0, totalMinutes: 0),
              ]),
            ),
            habitBundle: habitBundleOf(
              period: periodFor(StatsRange.month),
              totalCheckOffs: 72,
              activeHabitCount: 3,
            ),
            habitSnapshots: [
              snapshotWithExcused('h1', const ['2026-09-02', '2026-09-09']),
              snapshotWithExcused('h2', const ['2026-09-05']),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('45'), findsOneWidget); // best streak
        expect(find.text('best streak ever (days)'), findsOneWidget);

        expect(find.text('Tue'), findsOneWidget); // highest mean, not total
        expect(find.text('strongest day (avg)'), findsOneWidget);

        expect(find.text('2.4'), findsOneWidget); // 72 check-offs / 30 days
        expect(find.text('habits kept / day'), findsOneWidget);

        expect(find.text('3'), findsOneWidget); // 2 + 1 excused this month
        expect(find.text('freezes used (this month)'), findsOneWidget);
      });

      testWidgets('All time leaves habits-per-day undefined', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            buildTheme: buildTheme,
            range: StatsRange.allTime,
            bundle: bundleOf(
              period: periodFor(StatsRange.allTime),
              activeDayCount: 6,
            ),
            habitBundle: habitBundleOf(
              period: periodFor(StatsRange.allTime),
              totalCheckOffs: 500,
              activeHabitCount: 3,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('habits kept / day'), findsOneWidget);
        expect(find.text('—'), findsWidgets);
      });

      testWidgets('no habits at all does not crash the habit tiles',
          (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            buildTheme: buildTheme,
            bundle: bundleOf(
              period: periodFor(StatsRange.month),
              activeDayCount: 4,
            ),
            habitSnapshots: const [],
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        // The ratio is undefined with no habits; the freeze count is a real
        // zero. Both tiles are read through their own semantics label, since
        // a bare "0" also matches the best-streak tile.
        expect(
          find.bySemanticsLabel('— habits kept / day'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(RegExp(r'^0 freezes used \(this month\)\.')),
          findsOneWidget,
        );
      });

      testWidgets('the freezes tile says it is not range-scoped',
          (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            buildTheme: buildTheme,
            bundle: bundleOf(
              period: periodFor(StatsRange.month),
              activeDayCount: 4,
            ),
            habitSnapshots: [
              snapshotWithExcused('h1', const ['2026-09-02']),
            ],
          ),
        );
        await tester.pumpAndSettle();

        final tooltip = tester.widget<Tooltip>(
          find.ancestor(
            of: find.text('freezes used (this month)'),
            matching: find.byType(Tooltip),
          ),
        );
        expect(tooltip.message, contains('calendar'));
        expect(tooltip.message, contains('Not affected by the range'));
      });
    });

    group('StatsScreen ($themeName) — range picker and See more', () {
      testWidgets('tapping a segment moves the range', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            buildTheme: buildTheme,
            bundle: bundleOf(
              period: periodFor(StatsRange.month),
              activeDayCount: 4,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // The hero labels the selected range, so the label is the assertion.
        expect(find.text('LAST 30 DAYS'), findsOneWidget);
        await tester.tap(find.text('Week'));
        await tester.pumpAndSettle();
        expect(find.text('THIS WEEK'), findsOneWidget);
      });

      testWidgets('See more opens the detail screen', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            buildTheme: buildTheme,
            bundle: bundleOf(
              period: periodFor(StatsRange.month),
              activeDayCount: 4,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('See more'), findsOneWidget);
        await tester.ensureVisible(find.text('See more'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('See more'));
        await tester.pumpAndSettle();

        expect(find.byType(StatsDetailScreen), findsOneWidget);
        expect(find.text('More stats'), findsOneWidget);
      });
    });
  }
}
