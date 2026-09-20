import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/habits/habit_schedule.dart';
import 'package:habit_tracker/core/habits/habit_streak.dart';
import 'package:habit_tracker/core/recurrence/recurrence.dart';

/// SPEC.md §10.3 — streaks, and §10.5 — habit statistics.
///
/// Expected values were computed independently before the Dart was written.
void main() {
  RecurrenceRule rule(String raw) => RecurrenceRule.parse(raw)!;
  final daily = rule('FREQ=DAILY;INTERVAL=1');
  final mwf = rule('FREQ=WEEKLY;BYDAY=MO,WE,FR');

  List<String> sched(RecurrenceRule r, String anchor, String end) =>
      HabitSchedule.scheduledBetween(
          rule: r, anchorDate: anchor, start: anchor, end: end);

  Map<String, HabitDayRecord> allDone(List<String> dates, {int count = 1}) => {
        for (final d in dates) d: HabitDayRecord(count: count),
      };

  HabitStreakResult streaks({
    required List<String> scheduled,
    required Map<String, HabitDayRecord> entries,
    required String today,
    int target = 1,
    int allowance = 0,
  }) =>
      HabitStats.computeStreaks(
        scheduledDates: scheduled,
        entries: entries,
        targetCount: target,
        todayLocalDate: today,
        skipAllowancePerMonth: allowance,
      );

  group('a day the habit is not scheduled for cannot break it', () {
    test('Mon/Wed/Fri survives every Tuesday, Thursday and weekend', () {
      final dates = sched(mwf, '2026-08-31', '2026-09-18');
      final result = streaks(
        scheduled: dates,
        entries: allDone(dates),
        today: '2026-09-18',
      );
      expect(dates.length, 9);
      expect(result.current, 9);
      expect(result.longest, 9);
    });

    test('the same record read as a DAILY habit is almost entirely broken',
        () {
      // The inverse proves the streak is driven by the schedule, not the data.
      // Those untouched weekends are invisible to Mon/Wed/Fri and are misses
      // to a daily habit.
      final mwfDates = sched(mwf, '2026-08-31', '2026-09-18');
      final dailyDates = sched(daily, '2026-08-31', '2026-09-18');
      final result = streaks(
        scheduled: dailyDates,
        entries: allDone(mwfDates),
        today: '2026-09-18',
      );
      expect(result.current, 1, reason: 'only today itself');
    });
  });

  group('today never breaks a streak', () {
    // The classic habit-app bug: open the app at breakfast, see 0, stop
    // trusting the number, stop opening the app.
    final dates = sched(daily, '2026-09-10', '2026-09-18');

    test('today done counts today', () {
      final result =
          streaks(scheduled: dates, entries: allDone(dates), today: '2026-09-18');
      expect(result.current, 9);
    });

    test('today untouched leaves yesterday\'s streak standing', () {
      final entries = allDone(dates)..remove('2026-09-18');
      final result =
          streaks(scheduled: dates, entries: entries, today: '2026-09-18');
      expect(result.current, 8);
    });

    test('today partially done is pending, not a failure', () {
      final entries = allDone(dates, count: 8);
      entries['2026-09-18'] = const HabitDayRecord(count: 5);
      final result = streaks(
        scheduled: dates,
        entries: entries,
        today: '2026-09-18',
        target: 8,
      );
      expect(result.current, 8, reason: '5 of 8 glasses at noon is not a miss');
    });

    test('today skipped inside the allowance preserves the number', () {
      // A protected rest day counts the same as a done day toward the
      // streak — using one costs nothing, the same way a Duolingo freeze
      // does not touch the number.
      final entries = allDone(dates);
      entries['2026-09-18'] = const HabitDayRecord(count: 0, skipped: true);
      final result = streaks(
        scheduled: dates,
        entries: entries,
        today: '2026-09-18',
        allowance: 1,
      );
      expect(result.current, 9, reason: 'all 9 days, one of them protected');
    });
  });

  group('rest days are excused only within the monthly allowance', () {
    final dates = sched(daily, '2026-09-01', '2026-09-18');
    Map<String, HabitDayRecord> withSkips() {
      final e = allDone(dates);
      for (final d in ['2026-09-05', '2026-09-10', '2026-09-15']) {
        e[d] = const HabitDayRecord(count: 0, skipped: true);
      }
      return e;
    }

    test('the first two skips are excused, the third is a miss', () {
      final outcomes = HabitStats.resolveOutcomes(
        scheduledDates: dates,
        entries: withSkips(),
        targetCount: 1,
        todayLocalDate: '2026-09-18',
        skipAllowancePerMonth: 2,
      );
      expect(outcomes['2026-09-05'], HabitDayOutcome.neutral);
      expect(outcomes['2026-09-10'], HabitDayOutcome.neutral);
      expect(outcomes['2026-09-15'], HabitDayOutcome.missed);
    });

    test('the streak resumes after the unexcused skip', () {
      final result = streaks(
          scheduled: dates,
          entries: withSkips(),
          today: '2026-09-18',
          allowance: 2);
      expect(result.current, 3, reason: '16th, 17th, 18th');
    });

    test('a wider allowance excuses all three, and costs nothing', () {
      final result = streaks(
          scheduled: dates,
          entries: withSkips(),
          today: '2026-09-18',
          allowance: 3);
      expect(result.current, 18,
          reason: 'all 18 days — protected rest days count the same as done');
    });

    test('no allowance makes every skip a miss', () {
      final result = streaks(
          scheduled: dates,
          entries: withSkips(),
          today: '2026-09-18',
          allowance: 0);
      expect(result.current, 3);
    });

    test('excusedSkipsInMonth reports what has been spent', () {
      final outcomes = HabitStats.resolveOutcomes(
        scheduledDates: dates,
        entries: withSkips(),
        targetCount: 1,
        todayLocalDate: '2026-09-18',
        skipAllowancePerMonth: 2,
      );
      expect(
        HabitStats.excusedSkipsInMonth(
            scheduledDates: dates, outcomes: outcomes, yearMonth: '2026-09'),
        2,
      );
    });
  });

  group('a past day below target is a miss', () {
    test('5 of 8 glasses yesterday breaks it', () {
      final dates = sched(daily, '2026-09-01', '2026-09-18');
      final entries = allDone(dates, count: 8);
      entries['2026-09-16'] = const HabitDayRecord(count: 5);
      final result = streaks(
          scheduled: dates, entries: entries, today: '2026-09-18', target: 8);
      expect(result.current, 2, reason: 'the 17th and the 18th');
    });
  });

  group('longest streak', () {
    test('finds the best run, not the most recent one', () {
      final dates = sched(daily, '2026-08-01', '2026-09-18');
      final entries = allDone(dates)
        ..remove('2026-08-20')
        ..remove('2026-09-02');
      final result =
          streaks(scheduled: dates, entries: entries, today: '2026-09-18');
      expect(result.longest, 19, reason: '08-01 through 08-19');
      expect(result.current, 16, reason: '09-03 through 09-18');
    });
  });

  group('completion rate returns null rather than a misleading zero', () {
    test('no scheduled day in the window', () {
      final dates = HabitSchedule.scheduledBetween(
          rule: mwf,
          anchorDate: '2026-09-01',
          start: '2026-09-19', // Saturday
          end: '2026-09-20'); // Sunday
      final outcomes = HabitStats.resolveOutcomes(
        scheduledDates: dates,
        entries: const {},
        targetCount: 1,
        todayLocalDate: '2026-09-20',
        skipAllowancePerMonth: 0,
      );
      expect(
        HabitStats.completionRate(scheduledDates: dates, outcomes: outcomes),
        isNull,
        reason: 'nothing was asked of them, so there is no rate',
      );
    });

    test('a window entirely before the habit existed', () {
      final dates = HabitSchedule.scheduledBetween(
          rule: daily,
          anchorDate: '2026-09-01',
          start: '2026-08-01',
          end: '2026-08-20');
      expect(dates, isEmpty);
      expect(
        HabitStats.completionRate(scheduledDates: dates, outcomes: const {}),
        isNull,
      );
    });

    test('every scheduled day in the window was excused', () {
      final saturdays = HabitSchedule.scheduledBetween(
          rule: rule('FREQ=WEEKLY;BYDAY=SA'),
          anchorDate: '2026-09-01',
          start: '2026-09-14',
          end: '2026-09-20');
      expect(saturdays, ['2026-09-19']);
      final outcomes = HabitStats.resolveOutcomes(
        scheduledDates: saturdays,
        entries: const {
          '2026-09-19': HabitDayRecord(count: 0, skipped: true),
        },
        targetCount: 1,
        todayLocalDate: '2026-09-30',
        skipAllowancePerMonth: 2,
      );
      expect(
        HabitStats.completionRate(
            scheduledDates: saturdays, outcomes: outcomes),
        isNull,
      );
    });

    test('scheduled days with nothing recorded are 0%, NOT null', () {
      // The distinction that matters: these days were asked for and missed.
      final dates = HabitSchedule.scheduledBetween(
          rule: daily,
          anchorDate: '2026-09-01',
          start: '2026-10-01',
          end: '2026-10-05');
      expect(dates.length, 5);
      final outcomes = HabitStats.resolveOutcomes(
        scheduledDates: dates,
        entries: const {},
        targetCount: 1,
        todayLocalDate: '2026-10-20',
        skipAllowancePerMonth: 0,
      );
      expect(
        HabitStats.completionRate(scheduledDates: dates, outcomes: outcomes),
        0.0,
      );
    });

    test('excused days leave the denominator', () {
      final dates = sched(daily, '2026-09-01', '2026-09-10');
      final entries = allDone(dates)
        ..['2026-09-03'] = const HabitDayRecord(count: 0, skipped: true)
        ..remove('2026-09-07');
      final outcomes = HabitStats.resolveOutcomes(
        scheduledDates: dates,
        entries: entries,
        targetCount: 1,
        todayLocalDate: '2026-09-10',
        skipAllowancePerMonth: 2,
      );
      final rate =
          HabitStats.completionRate(scheduledDates: dates, outcomes: outcomes);
      expect(rate, closeTo(8 / 9, 1e-9),
          reason: '10 scheduled, 1 excused, 1 missed');
    });
  });

  group('weekday profile', () {
    test('a weekday the habit never runs on has no rate', () {
      final dates = sched(mwf, '2026-08-31', '2026-09-18');
      final outcomes = HabitStats.resolveOutcomes(
        scheduledDates: dates,
        entries: allDone(dates),
        targetCount: 1,
        todayLocalDate: '2026-09-18',
        skipAllowancePerMonth: 0,
      );
      final profile = HabitStats.weekdayProfile(
          scheduledDates: dates, outcomes: outcomes);
      expect(profile[DateTime.monday], 1.0);
      expect(profile[DateTime.wednesday], 1.0);
      expect(profile[DateTime.friday], 1.0);
      expect(profile[DateTime.sunday], isNull,
          reason: 'Sunday 0% would invent a failure that never happened');
      expect(profile[DateTime.tuesday], isNull);
    });
  });

  group('a scheduled day in the future is not a miss', () {
    // The month grid on the detail screen asks for the whole current month,
    // which runs past today. Without a `future` outcome, tomorrow reads as a
    // miss and one glance at the calendar zeroes a live streak.
    test('tomorrow resolves to future, not missed', () {
      final dates = HabitSchedule.scheduledBetween(
        rule: daily,
        anchorDate: '2026-09-10',
        start: '2026-09-10',
        end: '2026-09-30', // past today
      );
      final done = sched(daily, '2026-09-10', '2026-09-18');
      final outcomes = HabitStats.resolveOutcomes(
        scheduledDates: dates,
        entries: allDone(done),
        targetCount: 1,
        todayLocalDate: '2026-09-18',
        skipAllowancePerMonth: 0,
      );
      expect(outcomes['2026-09-19'], HabitDayOutcome.future);
      expect(outcomes['2026-09-30'], HabitDayOutcome.future);
      expect(outcomes['2026-09-18'], HabitDayOutcome.done);
      expect(outcomes['2026-09-17'], HabitDayOutcome.done);
    });

    test('future days do not break the current streak', () {
      final dates = HabitSchedule.scheduledBetween(
        rule: daily,
        anchorDate: '2026-09-10',
        start: '2026-09-10',
        end: '2026-09-30',
      );
      final result = streaks(
        scheduled: dates,
        entries: allDone(sched(daily, '2026-09-10', '2026-09-18')),
        today: '2026-09-18',
      );
      expect(result.current, 9);
      expect(result.longest, 9);
    });

    test('future days are excluded from the completion rate', () {
      final dates = HabitSchedule.scheduledBetween(
        rule: daily,
        anchorDate: '2026-09-10',
        start: '2026-09-10',
        end: '2026-09-30',
      );
      final outcomes = HabitStats.resolveOutcomes(
        scheduledDates: dates,
        entries: allDone(sched(daily, '2026-09-10', '2026-09-18')),
        targetCount: 1,
        todayLocalDate: '2026-09-18',
        skipAllowancePerMonth: 0,
      );
      expect(
        HabitStats.completionRate(scheduledDates: dates, outcomes: outcomes),
        1.0,
        reason: '9 of 9 elapsed days, with 12 future days ignored',
      );
    });
  });

  group('totals', () {
    test('counts every check-off, not every day', () {
      expect(
        HabitStats.totalCheckOffs(const {
          '2026-09-01': HabitDayRecord(count: 8),
          '2026-09-02': HabitDayRecord(count: 3),
          '2026-09-03': HabitDayRecord(count: 0, skipped: true),
        }),
        11,
      );
    });
  });
}
