import '../recurrence/recurrence.dart';
import '../time/time_service.dart';

/// Habit scheduling per SPEC.md §10.2.
///
/// Habits reuse the task-recurrence RRULE subset ([RecurrenceRule]), so a habit
/// schedule is the same string in an export and the parser is shared. The
/// question being asked differs:
///
///   tasks   -> "when is the next one?"      (RecurrenceRule.nextAfter)
///   habits  -> "was THIS day one of them?"  (HabitSchedule.occursOn)
///
/// A streak needs the second answerable for any past date. Deriving it from
/// `nextAfter` would replay the series from the start on every lookup.
///
/// Dates in and out are logical dates (YYYY-MM-DD, SPEC.md §1.2) and all date
/// math goes through [TimeService], so it is DST-safe: "every 3 days" stays on
/// calendar days across a transition instead of drifting by an hour.
abstract final class HabitSchedule {
  /// How far [previousScheduledDate] and [nextScheduledDate] look before giving
  /// up. A monthly rule with interval 12 can leave a gap just over 365 days; 800
  /// clears that and still ends promptly on a rule that matches nothing.
  static const int _searchLimitDays = 800;

  /// Whether [localDate] is a day this habit is scheduled for.
  ///
  /// [anchorDate] is the habit's start date, normally the logical date it was
  /// created. Intervals count from it: "every 3 days" means every third day from
  /// when you started, not from an arbitrary epoch.
  ///
  /// A null [rule] means no schedule, so never due. A date before [anchorDate]
  /// is never scheduled: a habit can't be missed before it existed, and counting
  /// those days would give every new habit an instantly broken streak.
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

    // Weeks are counted Monday-to-Monday, independent of the display week-start
    // setting, as in recurrence.dart. Otherwise changing that setting would
    // reschedule every habit and reset streaks that were never broken.
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

  /// Every scheduled date in `[start, end]` inclusive, ascending. Dates before
  /// [anchorDate] are excluded, and an empty or inverted window returns an empty
  /// list rather than throwing.
  ///
  /// This is the form the streak walk wants: calling [previousScheduledDate]
  /// repeatedly would make it quadratic.
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

  /// Day-of-month rules in short months. Clamps rather than skipping, matching
  /// recurrence.dart: a habit set for the 31st lands on the 28th in February
  /// instead of vanishing for a month and taking the streak with it.
  static String _clampToMonth(int year, int month, int day) {
    final lastDay = DateTime.utc(year, month + 1, 0).day;
    return TimeService.formatIsoDate(year, month, day > lastDay ? lastDay : day);
  }

  /// The [n]th [weekday] of a month; n == -1 means the last one. Null when the
  /// month has no such day (most months have no 5th Tuesday), which leaves that
  /// month unscheduled.
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
