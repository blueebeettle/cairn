// Pure arithmetic behind the redesigned Stats screen: the trend chip's
// date-window math, the "Your journey" trail's weekly buckets, and the two
// tile figures that are computed rather than read straight off a provider.
//
// None of this needs a widget or a database — that is the point of keeping
// these as top-level functions rather than private methods on the screen.

import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/stats/habit_statistics.dart';
import 'package:habit_tracker/core/stats/statistics.dart';
import 'package:habit_tracker/core/time/time_service.dart';
import 'package:habit_tracker/data/providers/analytics_providers.dart';
import 'package:habit_tracker/data/repositories/stats_repository.dart';
import 'package:habit_tracker/features/stats/presentation/stats_screen.dart';

void main() {
  const today = '2026-09-14'; // a Monday
  const time = TimeService(weekStart: DateTime.monday);

  StatsPeriod periodFor(StatsRange range) => switch (range) {
        StatsRange.week => StatsPeriod.week(time, today),
        StatsRange.month => StatsPeriod.lastNDays(today, 30),
        StatsRange.quarter => StatsPeriod.lastNDays(today, 90),
        StatsRange.allTime => StatsPeriod.allTime,
      };

  int lengthOf(StatsPeriod p) => TimeService.daysBetween(p.start, p.end) + 1;

  group('statsPriorPeriod — the trend chip\'s comparison window', () {
    test('All time has no prior period', () {
      expect(
        statsPriorPeriod(StatsRange.allTime, periodFor(StatsRange.allTime)),
        isNull,
      );
    });

    for (final range in [
      StatsRange.week,
      StatsRange.month,
      StatsRange.quarter,
    ]) {
      test('${range.label}: prior window is the same length', () {
        final current = periodFor(range);
        final prior = statsPriorPeriod(range, current)!;
        expect(lengthOf(prior), equals(lengthOf(current)));
      });

      test('${range.label}: prior window ends the day before the current one',
          () {
        final current = periodFor(range);
        final prior = statsPriorPeriod(range, current)!;
        expect(prior.end, equals(TimeService.addDays(current.start, -1)));
      });

      test('${range.label}: no gap and no overlap between the two windows',
          () {
        final current = periodFor(range);
        final prior = statsPriorPeriod(range, current)!;
        // Exactly one day apart: the prior period's last day is immediately
        // followed by the current period's first.
        expect(TimeService.daysBetween(prior.end, current.start), equals(1));
        expect(prior.contains(current.start), isFalse);
        expect(current.contains(prior.end), isFalse);
      });
    }

    test('the literal windows, spelled out', () {
      // Week: 09-14..09-20 is preceded by 09-07..09-13.
      expect(
        statsPriorPeriod(StatsRange.week, periodFor(StatsRange.week))!.toString(),
        equals('2026-09-07..2026-09-13'),
      );
      // 30d: 08-16..09-14 is preceded by 07-17..08-15.
      expect(
        statsPriorPeriod(StatsRange.month, periodFor(StatsRange.month))!
            .toString(),
        equals('2026-07-17..2026-08-15'),
      );
      // 90d: 06-17..09-14 is preceded by 03-19..06-16.
      expect(
        statsPriorPeriod(StatsRange.quarter, periodFor(StatsRange.quarter))!
            .toString(),
        equals('2026-03-19..2026-06-16'),
      );
    });
  });

  group('journeyWeeks — the "Your journey" trail', () {
    // The real default (25/day, so 175 a week). `flatMinutes`' 30/day clears
    // it every day, which is a full four-stone cairn.
    const goal = FocusStats.defaultDailyGoalMinutes;

    List<JourneyWeek> weeksFor(
      StatsRange range,
      Map<String, int> minutesByDate, {
      int dailyGoalMinutes = goal,
    }) =>
        journeyWeeks(
          minutesByDate: minutesByDate,
          periodStart: periodFor(range).start,
          todayLocalDate: today,
          startOfWeek: time.startOfWeek,
          dailyGoalMinutes: dailyGoalMinutes,
        );

    /// Every day in the period with the same number of focus minutes, so the
    /// column count is about the calendar and nothing else.
    Map<String, int> flatMinutes(StatsRange range, {int minutes = 30}) {
      final period = periodFor(range);
      final start = range == StatsRange.allTime
          ? TimeService.addDays(today, -200)
          : period.start;
      return {
        for (var d = start;
            d.compareTo(today) <= 0;
            d = TimeService.addDays(d, 1))
          d: minutes,
      };
    }

    test('the Week range is exactly one column, and it is "Now"', () {
      final weeks = weeksFor(StatsRange.week, flatMinutes(StatsRange.week));
      expect(weeks, hasLength(1));
      expect(weeks.single.isNow, isTrue);
      // Nothing to taper against, so the lone glyph is drawn at full trail
      // size rather than at the bottom of the ramp.
      expect(weeks.single.scale, equals(journeyMaxScale));
      expect(weeks.single.opacity, equals(1.0));
    });

    test('30 days spans six calendar weeks', () {
      // 08-16 is a Sunday, so its week began 08-10; 08-10 to 09-14 is 5 weeks
      // of gap plus the current one.
      final weeks = weeksFor(StatsRange.month, flatMinutes(StatsRange.month));
      expect(weeks, hasLength(6));
      expect(weeks.first.weekStart, equals('2026-08-10'));
      expect(weeks.last.weekStart, equals('2026-09-14'));
    });

    test('90 days would span fourteen weeks and is capped at eight', () {
      final weeks =
          weeksFor(StatsRange.quarter, flatMinutes(StatsRange.quarter));
      expect(weeks, hasLength(journeyMaxWeeks));
      // Capped from the recent end: the last column is still this week.
      expect(weeks.last.weekStart, equals('2026-09-14'));
      expect(weeks.last.isNow, isTrue);
    });

    test('All time is capped at eight too, and anchors on the oldest data', () {
      final weeks =
          weeksFor(StatsRange.allTime, flatMinutes(StatsRange.allTime));
      expect(weeks, hasLength(journeyMaxWeeks));
      expect(weeks.last.weekStart, equals('2026-09-14'));
    });

    test('All time with a single day of data is a single column', () {
      final weeks = weeksFor(StatsRange.allTime, const {today: 45});
      expect(weeks, hasLength(1));
      expect(weeks.single.isNow, isTrue);
    });

    test('scale and opacity rise left to right, ending at full', () {
      final weeks = weeksFor(StatsRange.month, flatMinutes(StatsRange.month));
      for (var i = 1; i < weeks.length; i++) {
        expect(weeks[i].scale, greaterThan(weeks[i - 1].scale));
        expect(weeks[i].opacity, greaterThan(weeks[i - 1].opacity));
      }
      expect(weeks.first.scale, closeTo(journeyMinScale, 1e-9));
      expect(weeks.last.scale, closeTo(journeyMaxScale, 1e-9));
      expect(weeks.last.opacity, closeTo(1.0, 1e-9));
      // Only the last column is "Now".
      expect(weeks.where((w) => w.isNow), hasLength(1));
    });

    test('a week with no focus at all keeps its column, with no stones', () {
      // Only this week and the week before last have data; the week in
      // between is empty and must still hold its place, or the trail would
      // quietly pretend the gap never happened.
      final weeks = journeyWeeks(
        minutesByDate: const {
          '2026-08-31': 120, // two weeks back
          '2026-09-14': 90, // this week
        },
        periodStart: '2026-08-31',
        todayLocalDate: today,
        startOfWeek: time.startOfWeek,
        dailyGoalMinutes: goal,
      );
      expect(weeks, hasLength(3));
      expect(weeks[0].weekStart, equals('2026-08-31'));
      expect(weeks[1].weekStart, equals('2026-09-07'));
      expect(weeks[1].minutes, equals(0));
      expect(weeks[1].stones, equals(0));
      expect(weeks[2].stones, greaterThan(0));
    });

    group('stone counts are absolute, not relative to the trail', () {
      // A goal of 20 a day is 140 a week, so the quarter/half/three-quarter
      // marks land on whole stones and the bands are readable.
      const tidyGoal = 20;
      const weeklyGoal = tidyGoal * 7; // 140

      List<JourneyWeek> trailOf(Map<String, int> weekTotals) => journeyWeeks(
            // One day per week carries that week's whole total; the bucket
            // sums seven days either way.
            minutesByDate: weekTotals,
            periodStart: weekTotals.keys.reduce((a, b) => a.compareTo(b) <= 0 ? a : b),
            todayLocalDate: today,
            startOfWeek: time.startOfWeek,
            dailyGoalMinutes: tidyGoal,
          );

      test('a week that hits the goal every day is a full cairn', () {
        final weeks = trailOf(const {'2026-09-14': weeklyGoal});
        expect(weeks.single.stones, equals(4));
      });

      test('half the weekly goal scores fewer stones than the full goal', () {
        final half = trailOf(const {'2026-09-14': weeklyGoal ~/ 2}).single;
        final full = trailOf(const {'2026-09-14': weeklyGoal}).single;
        expect(half.stones, lessThan(full.stones));
        expect(half.stones, equals(2));
      });

      test('the bands step evenly from the goal', () {
        expect(trailOf(const {'2026-09-14': 35}).single.stones, equals(1));
        expect(trailOf(const {'2026-09-14': 70}).single.stones, equals(2));
        expect(trailOf(const {'2026-09-14': 105}).single.stones, equals(3));
        expect(trailOf(const {'2026-09-14': 140}).single.stones, equals(4));
      });

      test('a week with no focus at all is zero stones, not one', () {
        final weeks = trailOf(const {'2026-09-07': 60, '2026-09-14': 0});
        expect(weeks.last.minutes, equals(0));
        expect(weeks.last.stones, equals(0));
      });

      test('clearing the goal several times over still caps at four', () {
        expect(
          trailOf(const {'2026-09-14': weeklyGoal * 3}).single.stones,
          equals(4),
        );
      });

      test('a goal of zero is zero stones rather than a divide by zero', () {
        // `dailyGoalMinutes` is user-configurable, so the guard is load
        // bearing even though the default can never be zero.
        final weeks = journeyWeeks(
          minutesByDate: const {'2026-09-14': 300},
          periodStart: '2026-09-14',
          todayLocalDate: today,
          startOfWeek: time.startOfWeek,
          dailyGoalMinutes: 0,
        );
        expect(weeks.single.stones, equals(0));
      });

      test(
          'the same week scores the same in a weak trail and a strong one',
          () {
        // The regression this scoring exists for. 70 minutes is half the
        // weekly goal in both trails; under the old best-in-trail scoring it
        // would have been a full 4-stone cairn in the first (where it was the
        // best week) and 1 stone in the second.
        final weak = trailOf(const {
          '2026-09-07': 10,
          '2026-09-14': 70,
        });
        final strong = trailOf(const {
          '2026-09-07': 900,
          '2026-09-14': 70,
        });

        expect(weak.last.minutes, equals(strong.last.minutes));
        expect(weak.last.stones, equals(strong.last.stones));
        expect(weak.last.stones, equals(2));

        // And the genuinely quiet week is visibly quiet rather than tallest.
        expect(weak.first.stones, equals(1));
        expect(strong.first.stones, equals(4));
      });
    });

    test('a bounded range with no focus at all keeps its columns, all empty',
        () {
      final weeks = weeksFor(StatsRange.month, const {});
      expect(weeks, hasLength(6));
      expect(weeks.every((w) => w.stones == 0), isTrue);
      expect(weeks.last.isNow, isTrue);
    });

    test('All time with no focus at all falls back on the cap, not a crash',
        () {
      // Reachable: `activeDayCount` counts events of any type, so a user who
      // has only ever ticked off tasks gets past the screen's empty-state
      // gate with an empty `minutesByDate` and the all-time sentinel start.
      final weeks = weeksFor(StatsRange.allTime, const {});
      expect(weeks, hasLength(journeyMaxWeeks));
      expect(weeks.every((w) => w.stones == 0), isTrue);
      expect(weeks.last.weekStart, equals('2026-09-14'));
    });
  });

  group('strongestWeekdayLabel', () {
    test('picks the highest mean, not the highest total', () {
      // Monday totals more minutes but over more days; Friday's mean is
      // higher, and the tile is about the mean.
      const profile = WeekdayProfile([
        WeekdayBin(weekday: 1, activeDays: 4, totalMinutes: 200), // 50
        WeekdayBin(weekday: 2, activeDays: 0, totalMinutes: 0),
        WeekdayBin(weekday: 3, activeDays: 0, totalMinutes: 0),
        WeekdayBin(weekday: 4, activeDays: 0, totalMinutes: 0),
        WeekdayBin(weekday: 5, activeDays: 1, totalMinutes: 90), // 90
        WeekdayBin(weekday: 6, activeDays: 0, totalMinutes: 0),
        WeekdayBin(weekday: 7, activeDays: 0, totalMinutes: 0),
      ]);
      expect(strongestWeekdayLabel(profile), equals('Fri'));
    });

    test('every bin empty is an em dash, not Monday', () {
      const profile = WeekdayProfile([
        WeekdayBin(weekday: 1, activeDays: 0, totalMinutes: 0),
        WeekdayBin(weekday: 2, activeDays: 0, totalMinutes: 0),
        WeekdayBin(weekday: 3, activeDays: 0, totalMinutes: 0),
        WeekdayBin(weekday: 4, activeDays: 0, totalMinutes: 0),
        WeekdayBin(weekday: 5, activeDays: 0, totalMinutes: 0),
        WeekdayBin(weekday: 6, activeDays: 0, totalMinutes: 0),
        WeekdayBin(weekday: 7, activeDays: 0, totalMinutes: 0),
      ]);
      expect(strongestWeekdayLabel(profile), equals('—'));
    });

    test('an active day with zero minutes is still a defined mean of zero', () {
      const profile = WeekdayProfile([
        WeekdayBin(weekday: 1, activeDays: 2, totalMinutes: 0),
        WeekdayBin(weekday: 2, activeDays: 0, totalMinutes: 0),
        WeekdayBin(weekday: 3, activeDays: 0, totalMinutes: 0),
        WeekdayBin(weekday: 4, activeDays: 0, totalMinutes: 0),
        WeekdayBin(weekday: 5, activeDays: 0, totalMinutes: 0),
        WeekdayBin(weekday: 6, activeDays: 0, totalMinutes: 0),
        WeekdayBin(weekday: 7, activeDays: 0, totalMinutes: 0),
      ]);
      expect(strongestWeekdayLabel(profile), equals('Mon'));
    });
  });

  group('habitsKeptPerDay', () {
    HabitStatsBundle bundle({required int checkOffs, int habits = 2}) =>
        HabitStatsBundle(
          period: periodFor(StatsRange.month),
          completionRate: HabitCompletionRate.empty,
          weekdayProfile: const HabitWeekdayProfile([]),
          totalCheckOffs: checkOffs,
          activeHabitCount: habits,
          leaderboard: const [],
        );

    test('divides by the period length, to one decimal', () {
      expect(
        habitsKeptPerDay(
          range: StatsRange.month,
          period: periodFor(StatsRange.month),
          habitBundle: bundle(checkOffs: 72),
        ),
        equals('2.4'), // 72 / 30
      );
    });

    test('a week divides by seven', () {
      expect(
        habitsKeptPerDay(
          range: StatsRange.week,
          period: periodFor(StatsRange.week),
          habitBundle: bundle(checkOffs: 14),
        ),
        equals('2.0'),
      );
    });

    test('All time is an em dash — no honest denominator exists', () {
      expect(
        habitsKeptPerDay(
          range: StatsRange.allTime,
          period: periodFor(StatsRange.allTime),
          habitBundle: bundle(checkOffs: 500),
        ),
        equals('—'),
      );
    });

    test('no habits at all is an em dash, not 0.0', () {
      expect(
        habitsKeptPerDay(
          range: StatsRange.month,
          period: periodFor(StatsRange.month),
          habitBundle: bundle(checkOffs: 0, habits: 0),
        ),
        equals('—'),
      );
    });

    test('habits that exist but were never checked off is a real 0.0', () {
      expect(
        habitsKeptPerDay(
          range: StatsRange.month,
          period: periodFor(StatsRange.month),
          habitBundle: bundle(checkOffs: 0),
        ),
        equals('0.0'),
      );
    });

    test('a bundle that has not loaded yet is an em dash', () {
      expect(
        habitsKeptPerDay(
          range: StatsRange.month,
          period: periodFor(StatsRange.month),
          habitBundle: null,
        ),
        equals('—'),
      );
    });
  });
}
