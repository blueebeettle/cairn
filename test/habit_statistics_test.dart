import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/habits/habit_streak.dart';
import 'package:habit_tracker/core/stats/habit_statistics.dart';
import 'package:habit_tracker/core/stats/statistics.dart';

/// SPEC.md §10.5 — cross-habit statistics for the Stats screen.
///
/// Pure, like `statistics_test.dart` and `habit_streak_test.dart`: no
/// database, no clock, just fixed fixtures with expected values computed
/// independently before the Dart was written.
///
/// Fixture dates 2026-09-01..05 are Tue, Wed, Thu, Fri, Sat.
void main() {
  const period = StatsPeriod(start: '2026-09-01', end: '2026-09-05');

  // "Read" (h1): done Tue, missed Wed, done Thu, excused rest Fri,
  // pending (today) Sat.
  final h1 = HabitStatsInput(
    habitId: 'h1',
    title: 'Read',
    colorIndex: 0,
    iconName: 'book',
    currentStreak: 5,
    longestStreak: 10,
    outcomes: const {
      '2026-09-01': HabitDayOutcome.done,
      '2026-09-02': HabitDayOutcome.missed,
      '2026-09-03': HabitDayOutcome.done,
      '2026-09-04': HabitDayOutcome.neutral,
      '2026-09-05': HabitDayOutcome.pending,
    },
    entries: const {
      '2026-09-01': HabitDayRecord(count: 1),
      '2026-09-02': HabitDayRecord(count: 0),
      '2026-09-03': HabitDayRecord(count: 1),
      '2026-09-04': HabitDayRecord(count: 0, skipped: true),
      '2026-09-05': HabitDayRecord(count: 0),
    },
  );

  // "Walk" (h2): done Tue, done Wed, missed Thu, future Fri; not yet
  // scheduled (no entry at all) on Sat.
  final h2 = HabitStatsInput(
    habitId: 'h2',
    title: 'Walk',
    colorIndex: 1,
    iconName: 'walk',
    currentStreak: 2,
    longestStreak: 2,
    outcomes: const {
      '2026-09-01': HabitDayOutcome.done,
      '2026-09-02': HabitDayOutcome.done,
      '2026-09-03': HabitDayOutcome.missed,
      '2026-09-04': HabitDayOutcome.future,
    },
    entries: const {
      '2026-09-01': HabitDayRecord(count: 2),
      '2026-09-02': HabitDayRecord(count: 1),
      '2026-09-03': HabitDayRecord(count: 0),
      '2026-09-04': HabitDayRecord(count: 0),
    },
  );

  final habits = [h1, h2];

  group('HabitCompletionRate — pooled across habits (§10.5)', () {
    test('neutral, pending and future days are excluded from both sides', () {
      final rate = HabitCompletionRate.of(habits, period);
      // Eligible: h1{Tue done, Wed missed, Thu done} + h2{Tue done, Wed
      // done, Thu missed} = 6. Done: h1{Tue, Thu} + h2{Tue, Wed} = 4.
      expect(rate.eligible, 6);
      expect(rate.done, 4);
      expect(rate.rate, closeTo(4 / 6, 1e-9));
    });

    test('a period with nothing eligible is null, never 0%', () {
      final rate = HabitCompletionRate.of(
        habits,
        const StatsPeriod(start: '2020-01-01', end: '2020-01-02'),
      );
      expect(rate.eligible, 0);
      expect(rate.rate, isNull);
    });

    test('empty is the zero-denominator constant', () {
      expect(HabitCompletionRate.empty.rate, isNull);
    });
  });

  group('HabitWeekdayProfile — pooled (§10.5)', () {
    test('each weekday pools only its own eligible days', () {
      final profile = HabitWeekdayProfile.of(habits, period);

      // Tuesday (2026-09-01): both done -> 2/2.
      final tue = profile.forWeekday(DateTime.tuesday);
      expect(tue.eligibleDays, 2);
      expect(tue.doneDays, 2);
      expect(tue.rate, 1.0);

      // Wednesday (09-02): h1 missed, h2 done -> 1/2.
      final wed = profile.forWeekday(DateTime.wednesday);
      expect(wed.eligibleDays, 2);
      expect(wed.doneDays, 1);
      expect(wed.rate, 0.5);

      // Thursday (09-03): h1 done, h2 missed -> 1/2.
      final thu = profile.forWeekday(DateTime.thursday);
      expect(thu.eligibleDays, 2);
      expect(thu.doneDays, 1);

      // Friday (09-04): h1 neutral, h2 future -> nothing eligible.
      final fri = profile.forWeekday(DateTime.friday);
      expect(fri.eligibleDays, 0);
      expect(fri.rate, isNull);

      // Monday never appears in either habit's history at all.
      final mon = profile.forWeekday(DateTime.monday);
      expect(mon.eligibleDays, 0);
      expect(mon.rate, isNull);
    });
  });

  group('habitCheckOffsTotal — §10.5 "total check-offs"', () {
    test('sums check_count, not days, across every habit in the period', () {
      // h1: 1 + 0 + 1 + 0 + 0 = 2. h2: 2 + 1 + 0 + 0 = 3. Total 5.
      expect(habitCheckOffsTotal(habits, period), 5);
    });

    test('a rest day with count 0 contributes nothing, not a phantom check-off', () {
      final onlyRestDay = HabitStatsInput(
        habitId: 'h3',
        title: 'Rest test',
        colorIndex: 0,
        iconName: 'check',
        currentStreak: 0,
        longestStreak: 0,
        outcomes: const {'2026-09-04': HabitDayOutcome.neutral},
        entries: const {'2026-09-04': HabitDayRecord(count: 0, skipped: true)},
      );
      expect(habitCheckOffsTotal([onlyRestDay], period), 0);
    });
  });

  group('habitLeaderboard — streak ranking', () {
    test('ranks by current streak, longest first', () {
      final board = habitLeaderboard(habits);
      expect(board.map((e) => e.habitId), ['h1', 'h2']);
      expect(board.first.currentStreak, 5);
      expect(board.first.longestStreak, 10);
    });

    test('ties break alphabetically by title, not input order', () {
      final a = HabitStatsInput(
        habitId: 'a',
        title: 'Zebra',
        colorIndex: 0,
        iconName: 'check',
        currentStreak: 4,
        longestStreak: 4,
        outcomes: const {},
        entries: const {},
      );
      final b = HabitStatsInput(
        habitId: 'b',
        title: 'Apple',
        colorIndex: 0,
        iconName: 'check',
        currentStreak: 4,
        longestStreak: 9,
        outcomes: const {},
        entries: const {},
      );
      // Input order deliberately has Zebra first; the tie-break must still
      // put Apple first.
      final board = habitLeaderboard([a, b]);
      expect(board.map((e) => e.title), ['Apple', 'Zebra']);
    });
  });

  group('buildHabitStatsBundle — one consistent read', () {
    test('assembles every piece from the same input list', () {
      final bundle = buildHabitStatsBundle(habits: habits, period: period);
      expect(bundle.activeHabitCount, 2);
      expect(bundle.hasAnyData, isTrue);
      expect(bundle.totalCheckOffs, 5);
      expect(bundle.completionRate.rate, closeTo(4 / 6, 1e-9));
      expect(bundle.leaderboard.first.habitId, 'h1');
    });

    test('zero habits means hasAnyData is false, not an em-dash-filled card', () {
      final bundle = buildHabitStatsBundle(habits: const [], period: period);
      expect(bundle.activeHabitCount, 0);
      expect(bundle.hasAnyData, isFalse);
      expect(bundle.completionRate.rate, isNull);
    });
  });

  group('habit activity heatmap (§4.13\'s method, reused for habit counts)', () {
    test('counts distinct habits done per day, not total check-offs', () {
      final counts = habitDoneCountsByDate(habits, period);
      // 09-01: both done -> 2. 09-02: only h2 done -> 1. 09-03: only h1
      // done -> 1. 09-04/05: neither done that day -> absent (0).
      expect(counts['2026-09-01'], 2);
      expect(counts['2026-09-02'], 1);
      expect(counts['2026-09-03'], 1);
      expect(counts.containsKey('2026-09-04'), isFalse);
      expect(counts.containsKey('2026-09-05'), isFalse);
    });

    test('cells cover every day in the period, gaps included', () {
      final counts = habitDoneCountsByDate(habits, period);
      final cells = buildHabitHeatmap(
        period: period,
        doneCountsByDate: counts,
        thresholds: habitHeatmapFallbackThresholds, // 1/2/3/5
      );
      expect(cells.length, 5);
      expect(cells[0].date, '2026-09-01');
      expect(cells[0].doneCount, 2);
      expect(cells[0].level, 2); // 2 <= level2Max(2)
      expect(cells[1].doneCount, 1);
      expect(cells[1].level, 1); // 1 <= level1Max(1)
      expect(cells[3].doneCount, 0);
      expect(cells[3].level, 0);
    });

    test(
        'the habit fallback saturates around a handful of habits, not 180 '
        'like the focus-minutes fallback', () {
      final thresholds = HeatmapThresholds.fromDailyMinutes(
        const [], // fewer than 14 non-zero days -> fallback path
        fallback: habitHeatmapFallbackThresholds,
      );
      expect(thresholds.provisional, isTrue);
      expect(thresholds.level4Nominal, 5);
      expect(thresholds.level1Max, 1);
    });

    test('omitting fallback keeps the original minutes-scaled default', () {
      // HeatmapThresholds has no `==` override, so compare fields rather
      // than the instance -- this call builds a fresh object even when its
      // values match the constant.
      final thresholds = HeatmapThresholds.fromDailyMinutes(const []);
      expect(thresholds.level1Max, HeatmapThresholds.fallback.level1Max);
      expect(thresholds.level2Max, HeatmapThresholds.fallback.level2Max);
      expect(thresholds.level3Max, HeatmapThresholds.fallback.level3Max);
      expect(thresholds.level4Nominal, HeatmapThresholds.fallback.level4Nominal);
      expect(thresholds.provisional, isTrue);
    });
  });

  group('habitFreezeCountIn', () {
    test('counts neutral days across every habit inside the period', () {
      // h1 has one excused rest, on Fri 09-04. h2 has none.
      expect(habitFreezeCountIn([h1, h2], period), equals(1));
    });

    test('a day outside the period is not counted', () {
      const before = StatsPeriod(start: '2026-09-01', end: '2026-09-03');
      expect(habitFreezeCountIn([h1, h2], before), equals(0));
    });

    test('pools across habits rather than stopping at the first', () {
      final other = HabitStatsInput(
        habitId: 'h3',
        title: 'Stretch',
        colorIndex: 2,
        iconName: 'stretch',
        currentStreak: 0,
        longestStreak: 0,
        outcomes: const {
          '2026-09-02': HabitDayOutcome.neutral,
          '2026-09-04': HabitDayOutcome.neutral,
        },
        entries: const {},
      );
      expect(habitFreezeCountIn([h1, h2, other], period), equals(3));
    });

    test('done, missed and pending days are not freezes', () {
      expect(habitFreezeCountIn([h2], period), equals(0));
    });

    test('no habits is zero, not an error', () {
      expect(habitFreezeCountIn(const [], period), equals(0));
    });
  });

  group('buildWeeklyRecap', () {
    // The fixture week: Mon 2026-08-31 .. Sun 2026-09-06, with "today" on
    // Thu 2026-09-03 so Fri/Sat/Sun are still to come.
    const weekStart = '2026-08-31';
    const today = '2026-09-03';

    WeeklyRecap recapOf(List<HabitStatsInput> habits) => buildWeeklyRecap(
          habits: habits,
          todayLocalDate: today,
          weekStartLocalDate: weekStart,
        );

    test('spans Monday to Sunday', () {
      final recap = recapOf([h1, h2]);
      expect(recap.weekStart, equals('2026-08-31'));
      expect(recap.weekEnd, equals('2026-09-06'));
      expect(recap.days, hasLength(7));
      expect(recap.days.first.date, equals('2026-08-31'));
      expect(recap.days.last.date, equals('2026-09-06'));
    });

    test('marks today, and everything after it as still to come', () {
      final recap = recapOf([h1, h2]);
      final todayDays = recap.days.where((d) => d.isToday).toList();
      expect(todayDays, hasLength(1));
      expect(todayDays.single.date, equals(today));

      // Mon-Wed happened, Thu is today, Fri-Sun are future.
      expect(recap.days.map((d) => d.isFuture).toList(),
          equals([false, false, false, false, true, true, true]));
    });

    test('a future day carries no rate, so it cannot read as a miss', () {
      final recap = recapOf([h1, h2]);
      for (final day in recap.days.where((d) => d.isFuture)) {
        expect(day.rate, isNull, reason: '${day.date} has not happened');
      }
    });

    test('per-day rates are pooled across habits', () {
      final recap = recapOf([h1, h2]);
      // Tue 09-01: h1 done, h2 done -> 2/2. Wed 09-02: h1 missed, h2 done
      // -> 1/2. Thu 09-03: h1 done, h2 missed -> 1/2.
      expect(recap.days[1].rate, equals(1.0));
      expect(recap.days[2].rate, closeTo(0.5, 1e-9));
      expect(recap.days[3].rate, closeTo(0.5, 1e-9));
      // Mon 08-31 has nothing scheduled at all.
      expect(recap.days[0].rate, isNull);
    });

    test('the weekly rate excludes excused and pending days', () {
      final recap = recapOf([h1, h2]);
      // Scorable this week: 09-01 (done, done), 09-02 (missed, done),
      // 09-03 (done, missed) = 4 done of 6. 09-04's neutral and future, and
      // 09-05's pending, are all excluded.
      expect(recap.completionRate, closeTo(4 / 6, 1e-9));
    });

    test('a first-ever week has no prior rate to compare against', () {
      final recap = recapOf([h1, h2]);
      expect(recap.priorCompletionRate, isNull);
      expect(recap.rateDelta, isNull,
          reason: 'no baseline should be invented from an absent week');
    });

    test('a week with history reports a real delta', () {
      final withHistory = HabitStatsInput(
        habitId: 'h4',
        title: 'Journal',
        colorIndex: 0,
        iconName: 'book',
        currentStreak: 3,
        longestStreak: 9,
        outcomes: const {
          // Last week (08-24..08-30): 1 of 2.
          '2026-08-24': HabitDayOutcome.done,
          '2026-08-25': HabitDayOutcome.missed,
          // This week: 2 of 2.
          '2026-09-01': HabitDayOutcome.done,
          '2026-09-02': HabitDayOutcome.done,
        },
        entries: const {},
      );
      final recap = recapOf([withHistory]);
      expect(recap.priorCompletionRate, closeTo(0.5, 1e-9));
      expect(recap.completionRate, equals(1.0));
      expect(recap.rateDelta, closeTo(0.5, 1e-9));
    });

    test('best streak is the highest current streak, not re-sliced to the week',
        () {
      // h1's current streak is 5 and h2's is 2, both whole-history numbers
      // that a seven-day window could not produce on its own.
      expect(recapOf([h1, h2]).bestStreak, equals(5));
    });

    test('habits kept sums check-offs inside the week only', () {
      final recap = recapOf([h1, h2]);
      // 09-01: 1 + 2, 09-02: 0 + 1, 09-03: 1 + 0, 09-04..05: 0.
      expect(recap.habitsKept, equals(5));
    });

    test('freezes used is week-scoped, not month-scoped', () {
      expect(recapOf([h1, h2]).freezesUsed, equals(1)); // h1's 09-04 rest
    });

    test('no habits has no data, so the card can gate on it', () {
      final recap = recapOf(const []);
      expect(recap.hasAnyData, isFalse);
      expect(recap.activeHabitCount, equals(0));
      expect(recap.completionRate, isNull);
      expect(recap.bestStreak, equals(0));
      expect(recap.days, hasLength(7));
    });
  });
}
