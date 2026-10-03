import '../time/time_service.dart';

/// Habit streaks and habit statistics per SPEC.md §10.3 and §10.5.
///
/// Pure functions over a resolved set of days: no database, no clock, no
/// Riverpod. Every input is passed in, so each rule is testable against a fixed
/// date.
///
/// The governing rule from `statistics.dart` carries over: a rate with a zero
/// denominator returns **null**, which the UI renders as an em dash, never 0.0.
/// "You have done none of them" and "none were asked of you" are different
/// sentences and must not share a number.

/// One day's raw record for a habit, as stored in `habit_entries`.
class HabitDayRecord {
  const HabitDayRecord({required this.count, this.skipped = false});

  /// How many times the habit was checked off that logical day.
  final int count;

  /// Whether the user explicitly froze the day.
  final bool skipped;
}

/// What a scheduled day resolved to once the skip allowance was applied.
enum HabitDayOutcome {
  /// Target met. Extends the streak.
  done,

  /// A freeze the user applied by hand, within the monthly allowance (nothing
  /// applies one automatically).
  ///
  /// Counts toward the STREAK exactly like [done], so using a freeze never costs
  /// the number. Excluded from RATES, which answer "how often did you actually
  /// do it": a protected day you did not do is not reported as done there.
  neutral,

  /// Scheduled and not met, on a day that is over. Breaks the streak.
  missed,

  /// Today, scheduled, not yet met. Breaks nothing: the day is not over.
  pending,

  /// Scheduled, but after today. Breaks nothing and counts for nothing.
  ///
  /// Reachable whenever a caller asks for a window that runs past today, as the
  /// detail screen's month grid does for the rest of the month. Without this,
  /// tomorrow reads as a miss and one glance at the calendar zeroes a live
  /// streak.
  future,
}

/// The result of resolving a habit's history.
class HabitStreakResult {
  const HabitStreakResult({
    required this.current,
    required this.longest,
    required this.outcomes,
  });

  /// Consecutive scheduled days met, counting back from today.
  final int current;

  /// The best run of scheduled days ever met.
  final int longest;

  /// Per-scheduled-date outcome, ascending by date. Drives the day grid.
  final Map<String, HabitDayOutcome> outcomes;
}

abstract final class HabitStats {
  /// Resolves every scheduled day to an outcome, applying the monthly skip
  /// allowance.
  ///
  /// [scheduledDates] must be ascending and already filtered to days this habit
  /// is scheduled for (see `HabitSchedule.scheduledBetween`). Unscheduled days
  /// are not "missed", they are invisible; passing them in is what makes a
  /// Mon/Wed/Fri habit look broken every Tuesday.
  ///
  /// [skipAllowancePerMonth] is how many freezes a calendar month excuses. Skips
  /// are ranked by date, so the first N in a month are excused and any beyond
  /// that count as misses. The bound is the point: unlimited freezes would let
  /// someone hold a 200-day streak while doing nothing.
  static Map<String, HabitDayOutcome> resolveOutcomes({
    required List<String> scheduledDates,
    required Map<String, HabitDayRecord> entries,
    required int targetCount,
    required String todayLocalDate,
    required int skipAllowancePerMonth,
  }) {
    final target = targetCount < 1 ? 1 : targetCount;

    // Rank skips within their calendar month, in date order. Only skips on
    // scheduled days consume allowance: a freeze on a day you were never due
    // spends nothing.
    final excused = <String>{};
    final usedPerMonth = <String, int>{};
    for (final date in scheduledDates) {
      final record = entries[date];
      if (record == null || !record.skipped) continue;
      final month = date.substring(0, 7); // YYYY-MM
      final used = usedPerMonth[month] ?? 0;
      if (used < skipAllowancePerMonth) {
        excused.add(date);
        usedPerMonth[month] = used + 1;
      }
    }

    final outcomes = <String, HabitDayOutcome>{};
    for (final date in scheduledDates) {
      final record = entries[date];
      final dayOffset = TimeService.daysBetween(todayLocalDate, date);
      final isToday = dayOffset == 0;

      if (dayOffset > 0) {
        outcomes[date] = HabitDayOutcome.future;
      } else if (excused.contains(date)) {
        outcomes[date] = HabitDayOutcome.neutral;
      } else if (record != null && record.count >= target) {
        outcomes[date] = HabitDayOutcome.done;
      } else if (isToday) {
        // Not met yet, but the day is not over: a partial count today (5 of 8
        // glasses) is pending, not a failure.
        outcomes[date] = HabitDayOutcome.pending;
      } else {
        outcomes[date] = HabitDayOutcome.missed;
      }
    }
    return outcomes;
  }

  /// Current and longest streak over [scheduledDates].
  ///
  /// The single most important rule here: **today never breaks a streak.** If
  /// today is scheduled and not yet done, the walk steps past it to yesterday.
  /// Getting this wrong is the classic habit-app bug: you open the app over
  /// breakfast, it says 0, and you stop trusting the number.
  static HabitStreakResult computeStreaks({
    required List<String> scheduledDates,
    required Map<String, HabitDayRecord> entries,
    required int targetCount,
    required String todayLocalDate,
    required int skipAllowancePerMonth,
  }) {
    final outcomes = resolveOutcomes(
      scheduledDates: scheduledDates,
      entries: entries,
      targetCount: targetCount,
      todayLocalDate: todayLocalDate,
      skipAllowancePerMonth: skipAllowancePerMonth,
    );

    // `neutral` counts the same as `done` here: a freeze costs nothing off the
    // number, which is what "protects your streak" means to a user. `pending`
    // and `future` are unresolved, not protected: they are stepped over without
    // adding or resetting.
    var current = 0;
    for (var i = scheduledDates.length - 1; i >= 0; i--) {
      final outcome = outcomes[scheduledDates[i]];
      if (outcome == HabitDayOutcome.done || outcome == HabitDayOutcome.neutral) {
        current++;
      } else if (outcome == HabitDayOutcome.pending ||
          outcome == HabitDayOutcome.future) {
        continue;
      } else {
        break;
      }
    }

    var longest = 0;
    var run = 0;
    for (final date in scheduledDates) {
      final outcome = outcomes[date];
      if (outcome == HabitDayOutcome.done || outcome == HabitDayOutcome.neutral) {
        run++;
        if (run > longest) longest = run;
      } else if (outcome == HabitDayOutcome.pending ||
          outcome == HabitDayOutcome.future) {
        continue;
      } else {
        run = 0;
      }
    }

    return HabitStreakResult(
      current: current,
      longest: longest,
      outcomes: outcomes,
    );
  }

  /// Share of scheduled days in a window that were met.
  ///
  /// Frozen days and today-if-pending leave the denominator rather than counting
  /// as failures. Returns null when nothing remains to divide by (a Mon/Wed/Fri
  /// habit asked about a weekend, or a window before the habit existed); render
  /// that as an em dash.
  static double? completionRate({
    required List<String> scheduledDates,
    required Map<String, HabitDayOutcome> outcomes,
  }) {
    var denominator = 0;
    var done = 0;
    for (final date in scheduledDates) {
      final outcome = outcomes[date];
      if (outcome == HabitDayOutcome.neutral ||
          outcome == HabitDayOutcome.pending ||
          outcome == HabitDayOutcome.future) {
        continue;
      }
      denominator++;
      if (outcome == HabitDayOutcome.done) done++;
    }
    if (denominator == 0) return null;
    return done / denominator;
  }

  /// Completion rate per weekday, indexed 1 = Monday .. 7 = Sunday.
  ///
  /// A weekday with no scheduled days maps to null rather than 0.0: for a
  /// Mon/Wed/Fri habit, Sunday has no rate, and "Sunday 0%" would invent a
  /// failure that never happened.
  static Map<int, double?> weekdayProfile({
    required List<String> scheduledDates,
    required Map<String, HabitDayOutcome> outcomes,
  }) {
    final done = <int, int>{};
    final total = <int, int>{};
    for (final date in scheduledDates) {
      final outcome = outcomes[date];
      if (outcome == HabitDayOutcome.neutral ||
          outcome == HabitDayOutcome.pending ||
          outcome == HabitDayOutcome.future) {
        continue;
      }
      final weekday = TimeService.parseLocalDate(date).weekday;
      total[weekday] = (total[weekday] ?? 0) + 1;
      if (outcome == HabitDayOutcome.done) {
        done[weekday] = (done[weekday] ?? 0) + 1;
      }
    }
    return {
      for (var w = 1; w <= 7; w++)
        w: (total[w] ?? 0) == 0 ? null : (done[w] ?? 0) / total[w]!,
    };
  }

  /// How many freezes have been applied in [yearMonth] (`YYYY-MM`). The UI needs
  /// this to say "2 of 2 freezes used this month" *before* the last one is
  /// spent, rather than reporting a broken streak after.
  static int excusedSkipsInMonth({
    required List<String> scheduledDates,
    required Map<String, HabitDayOutcome> outcomes,
    required String yearMonth,
  }) {
    var count = 0;
    for (final date in scheduledDates) {
      if (!date.startsWith(yearMonth)) continue;
      if (outcomes[date] == HabitDayOutcome.neutral) count++;
    }
    return count;
  }

  /// Total check-offs recorded, across every entry.
  static int totalCheckOffs(Map<String, HabitDayRecord> entries) {
    var sum = 0;
    for (final record in entries.values) {
      sum += record.count;
    }
    return sum;
  }
}
