import '../recurrence/recurrence.dart';
import '../time/time_service.dart';

/// Habit scheduling per SPEC.md §10.2.
///
/// Habits reuse the RRULE subset already defined for task recurrence
/// ([RecurrenceRule]), so a habit schedule and a task recurrence are the same
/// string in an export and the parser is shared. What differs is the question
/// being asked:
///
///   tasks   -> "when is the next one?"      (RecurrenceRule.nextAfter)
///   habits  -> "was THIS day one of them?"  (HabitSchedule.occursOn)
///
/// A streak needs the second question answerable for an arbitrary past date.
/// Deriving it from `nextAfter` would mean replaying the series from the start
/// on every lookup, so it is computed directly here instead.
///
/// Everything in and out is a logical date (YYYY-MM-DD) per SPEC.md §1.2, and
/// every calculation goes through [TimeService], so this is DST-safe: a habit
/// scheduled "every 3 days" stays on calendar days across a transition rather
/// than drifting by an hour each time.
///
/// This file deliberately does not modify `recurrence.dart`. The two features
/// are built in parallel, and re-entering a shared file to add a method is how
/// merge conflicts get resolved by deleting someone's work.
abstract final class HabitSchedule {
  /// The furthest back [previousScheduledDate] will look before giving up.
  ///
  /// A yearly-ish rule (monthly with interval 12) can leave a gap just over
  /// 365 days; 800 clears that with room and still terminates promptly on a
  /// rule that matches nothing.
  static const int _searchLimitDays = 800;

  /// Whether [localDate] is a day this habit is scheduled for.
  ///
  /// [anchorDate] is the habit's start date — normally the logical date it was
  /// created. Intervals count from it, so "every 3 days" means every third day
  /// *from when you started*, not from an arbitrary epoch. Two people starting
  /// the same habit on different days get different days, which is correct.
  ///
  /// A null [rule] means the habit has no schedule and is never due. A date
  /// before [anchorDate] is never scheduled: a habit cannot be missed on a day
  /// it did not yet exist, and counting those would show every new habit with
  /// an instantly broken streak.
  static bool occursOn({
    required RecurrenceRule? rule,
    required String anchorDate,
    required String localDate,
  }) {
    if (rule == null) return false;
    if (TimeService.daysBetween(anchorDate, localDate) < 0) return false;

    return switch (rule.freq) {
      RecurrenceFreq.daily => _occursDaily(rule, anchorDate, localDate),
      RecurrenceFreq.weekly => _occursWeekly(rule, anchorDate, localDate),
      RecurrenceFreq.monthly => _occursMonthly(rule, anchorDate, localDate),
    };
  }

  static bool _occursDaily(RecurrenceRule rule, String anchor, String date) {
    final gap = TimeService.daysBetween(anchor, date);
    return gap % rule.interval == 0;
  }

  static bool _occursWeekly(RecurrenceRule rule, String anchor, String date) {
    final weekday = TimeService.parseLocalDate(date).weekday;
    if (!rule.byWeekday.contains(weekday)) return false;
    if (rule.interval == 1) return true;

    // Weeks are counted Monday-to-Monday, independent of the user's display
    // week-start setting — exactly as recurrence.dart does it. Otherwise
    // changing "week starts on Sunday" in settings would silently reschedule
    // every existing habit and reset streaks that were never broken.
    final weeksApart =
        TimeService.daysBetween(_mondayOf(anchor), _mondayOf(date)) ~/ 7;
    return weeksApart >= 0 && weeksApart % rule.interval == 0;
  }

  static bool _occursMonthly(RecurrenceRule rule, String anchor, String date) {
    final a = TimeService.parseLocalDate(anchor);
    final d = TimeService.parseLocalDate(date);
    final monthsApart = (d.year - a.year) * 12 + (d.month - a.month);
    if (monthsApart < 0 || monthsApart % rule.interval != 0) return false;

    if (rule.byMonthDay != null) {
      return date == _clampToMonth(d.year, d.month, rule.byMonthDay!);
    }
    if (rule.nth != null && rule.nthWeekday != null) {
      return date == _nthWeekdayOf(d.year, d.month, rule.nth!, rule.nthWeekday!);
    }
    return false;
  }

  /// Every scheduled date in `[start, end]` inclusive, ascending.
  ///
  /// Dates before [anchorDate] are excluded. Returns an empty list when
  /// [end] is before [start] rather than throwing — an empty window is a
  /// normal thing for a UI to ask about.
  ///
  /// This is the form the streak walk wants. Calling [previousScheduledDate]
  /// repeatedly instead would turn a linear walk into a quadratic one.
  static List<String> scheduledBetween({
    required RecurrenceRule? rule,
    required String anchorDate,
    required String start,
    required String end,
  }) {
    if (rule == null) return const [];
    if (TimeService.daysBetween(start, end) < 0) return const [];

    final from =
        TimeService.daysBetween(anchorDate, start) < 0 ? anchorDate : start;
    if (TimeService.daysBetween(from, end) < 0) return const [];

    final out = <String>[];
    final span = TimeService.daysBetween(from, end);
    for (var i = 0; i <= span; i++) {
      final candidate = TimeService.addDays(from, i);
      if (occursOn(rule: rule, anchorDate: anchorDate, localDate: candidate)) {
        out.add(candidate);
      }
    }
    return out;
  }

  /// The latest scheduled date strictly before [localDate], or null if there
  /// is none at or after [anchorDate].
  static String? previousScheduledDate({
    required RecurrenceRule? rule,
    required String anchorDate,
    required String localDate,
  }) {
    if (rule == null) return null;
    for (var i = 1; i <= _searchLimitDays; i++) {
      final candidate = TimeService.addDays(localDate, -i);
      if (TimeService.daysBetween(anchorDate, candidate) < 0) return null;
      if (occursOn(rule: rule, anchorDate: anchorDate, localDate: candidate)) {
        return candidate;
      }
    }
    return null;
  }

  /// The earliest scheduled date strictly after [localDate], or null if the
  /// rule matches nothing within [_searchLimitDays].
  static String? nextScheduledDate({
    required RecurrenceRule? rule,
    required String anchorDate,
    required String localDate,
  }) {
    if (rule == null) return null;
    for (var i = 1; i <= _searchLimitDays; i++) {
      final candidate = TimeService.addDays(localDate, i);
      if (occursOn(rule: rule, anchorDate: anchorDate, localDate: candidate)) {
        return candidate;
      }
    }
    return null;
  }

  static String _mondayOf(String localDate) {
    final weekday = TimeService.parseLocalDate(localDate).weekday;
    return TimeService.addDays(localDate, -(weekday - 1));
  }

  /// Day-of-month rules in short months.
  ///
  /// Clamps rather than skipping, matching recurrence.dart: someone who sets a
  /// habit for the 31st expects February to land on the 28th, not to vanish
  /// for a month and take their streak with it.
  static String _clampToMonth(int year, int month, int day) {
    final lastDay = DateTime.utc(year, month + 1, 0).day;
    return TimeService.formatIsoDate(year, month, day > lastDay ? lastDay : day);
  }

  /// The [n]th [weekday] of a month; n == -1 means the last one.
  /// Returns null when the month has no such day (there is no 5th Tuesday in
  /// most months), which correctly makes that month unscheduled.
  static String? _nthWeekdayOf(int year, int month, int n, int weekday) {
    final lastDay = DateTime.utc(year, month + 1, 0).day;

    if (n == -1) {
      for (var day = lastDay; day >= 1; day--) {
        if (DateTime.utc(year, month, day).weekday == weekday) {
          return TimeService.formatIsoDate(year, month, day);
        }
      }
      return null;
    }

    var seen = 0;
    for (var day = 1; day <= lastDay; day++) {
      if (DateTime.utc(year, month, day).weekday == weekday) {
        seen++;
        if (seen == n) return TimeService.formatIsoDate(year, month, day);
      }
    }
    return null;
  }
}
