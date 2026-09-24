import 'package:flutter/material.dart';

import '../../../core/habits/habit_streak.dart';
import '../../../core/habits/milestone_thresholds.dart';
import '../../../core/recurrence/recurrence.dart';
import '../../../core/time/time_service.dart';
import '../../../data/repositories/habits_repository.dart';
import '../../../theme/app_theme.dart';

/// Presentation helpers for habits: icons, colours, and schedules in words.
///
/// Nothing here computes a streak. Streaks come from `HabitSnapshot.streaks`
/// and only from there — two places computing the same number is how a
/// screen and a stat end up disagreeing.

// ─────────────────────────────────────────────────────────────────────────────
// Icons
// ─────────────────────────────────────────────────────────────────────────────

/// The one place a stored `icon_name` becomes an [IconData].
///
/// `habits.icon_name` stores these KEYS, never a code point: Flutter's code
/// points are not stable across SDK versions, and a backup restored after an
/// upgrade would otherwise come back as a grid of random glyphs (SPEC §10.1).
///
/// Keys are append-only. Renaming or removing one orphans every habit that
/// stored it; an unknown key falls back to [fallback] rather than crashing.
abstract final class HabitIcons {
  static const String fallback = 'check';

  static const Map<String, IconData> byName = {
    'check': Icons.check_circle_outline_rounded,
    'water': Icons.water_drop_outlined,
    'book': Icons.menu_book_rounded,
    'run': Icons.directions_run_rounded,
    'walk': Icons.directions_walk_rounded,
    'fitness': Icons.fitness_center_rounded,
    'meditate': Icons.self_improvement_rounded,
    'sleep': Icons.bedtime_outlined,
    'food': Icons.restaurant_rounded,
    'no_sugar': Icons.no_food_outlined,
    'write': Icons.edit_note_rounded,
    'music': Icons.music_note_rounded,
    'language': Icons.translate_rounded,
    'code': Icons.code_rounded,
    'pill': Icons.medication_outlined,
    'plant': Icons.eco_outlined,
    'clean': Icons.cleaning_services_outlined,
    'money': Icons.savings_outlined,
    'phone_off': Icons.phonelink_erase_rounded,
    'call': Icons.call_outlined,
  };

  static IconData of(String? name) => byName[name] ?? byName[fallback]!;

  /// A readable name for screen readers: 'no_sugar' -> 'no sugar'.
  static String label(String name) => name.replaceAll('_', ' ');
}

// ─────────────────────────────────────────────────────────────────────────────
// Colours
// ─────────────────────────────────────────────────────────────────────────────

/// `habits.color_index` indexes the theme's categorical series.
///
/// SPEC.md forbids inventing colours; `AppTokens.series` is already contrast-
/// checked in both themes, so the habit palette IS that list. An out-of-range
/// index wraps rather than throwing — a restored backup from a build with a
/// longer palette must still render.
abstract final class HabitColors {
  static int get count => AppTokens.light.series.length;

  static Color of(BuildContext context, int index) {
    final series = context.tokens.series;
    return series[index.abs() % series.length];
  }

  static const List<String> names = [
    'purple',
    'blue',
    'teal',
    'amber',
    'rose',
    'olive',
  ];

  static String label(int index) => names[index.abs() % names.length];
}

// ─────────────────────────────────────────────────────────────────────────────
// Dates in words
// ─────────────────────────────────────────────────────────────────────────────

abstract final class HabitDates {
  static const weekdayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const weekdayLetter = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  /// 'Monday 14 September' — the form screen readers get for a day cell.
  static String spoken(String localDate) {
    final d = TimeService.parseLocalDate(localDate);
    return '${weekdayNames[d.weekday - 1]} ${d.day} ${monthNames[d.month - 1]}';
  }

  /// 'Mon 14 Sep'.
  static String short(String localDate) {
    final d = TimeService.parseLocalDate(localDate);
    return '${weekdayShort[d.weekday - 1]} ${d.day} '
        '${monthNames[d.month - 1].substring(0, 3)}';
  }

  /// 'September 2026'.
  static String monthTitle(int year, int month) =>
      '${monthNames[month - 1]} $year';

  /// 1 -> '1st', 22 -> '22nd', 13 -> '13th'.
  static String ordinal(int n) {
    if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
    return switch (n % 10) {
      1 => '${n}st',
      2 => '${n}nd',
      3 => '${n}rd',
      _ => '${n}th',
    };
  }

  /// "Next: Wednesday" for a habit not due today.
  ///
  /// Within the coming week the weekday is unambiguous; further out it needs
  /// a date, or "Next: Monday" on a monthly habit reads as this Monday.
  static String nextLabel(String? nextDate, String today) {
    if (nextDate == null) return 'Not scheduled';
    final gap = TimeService.daysBetween(today, nextDate);
    final d = TimeService.parseLocalDate(nextDate);
    if (gap >= 1 && gap < 7) return 'Next: ${weekdayNames[d.weekday - 1]}';
    return 'Next: ${d.day} ${monthNames[d.month - 1].substring(0, 3)}';
  }

  /// "Freeze used yesterday — streak safe".
  ///
  /// Deliberately not phrased as a miss: the rest day was inside the monthly
  /// allowance, the streak is intact, and a row that looks like a failure is
  /// the thing the allowance exists to prevent.
  static String freezeUsedLabel(String localDate, String today) {
    final gap = TimeService.daysBetween(localDate, today);
    final d = TimeService.parseLocalDate(localDate);
    final when = switch (gap) {
      <= 0 => 'today',
      1 => 'yesterday',
      < 7 => 'on ${weekdayNames[d.weekday - 1]}',
      _ => 'on ${d.day} ${monthNames[d.month - 1].substring(0, 3)}',
    };
    return 'Freeze used $when — streak safe';
  }

  /// '9:00 AM' from minutes past midnight.
  static String timeOfDay(int minutes) {
    final h = minutes ~/ 60;
    final m = (minutes % 60).toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$h12:$m $period';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Schedules in words
// ─────────────────────────────────────────────────────────────────────────────

/// Turns a stored RRULE into the words a person would use.
///
/// The user never sees `FREQ=WEEKLY;BYDAY=MO,WE,FR`. Every rule the §2.6
/// grammar can express gets a sentence here, including the ones the create
/// sheet cannot build (every-other-week, nth weekday), because a habit
/// restored from a backup or written by a later build must still read well.
abstract final class HabitScheduleText {
  static String describe(String? raw) {
    final rule = RecurrenceRule.parse(raw);
    if (rule == null) return 'No schedule';
    return describeRule(rule);
  }

  static String describeRule(RecurrenceRule rule) {
    switch (rule.freq) {
      case RecurrenceFreq.daily:
        return rule.interval == 1 ? 'Every day' : 'Every ${rule.interval} days';
      case RecurrenceFreq.weekly:
        final days = rule.byWeekday.toList()..sort();
        final String dayText;
        if (days.length == 7) {
          dayText = 'every day';
        } else if (_sameSet(days, const [1, 2, 3, 4, 5])) {
          dayText = 'weekdays';
        } else if (_sameSet(days, const [6, 7])) {
          dayText = 'weekends';
        } else {
          dayText = days.map((d) => HabitDates.weekdayShort[d - 1]).join(', ');
        }
        if (rule.interval == 1) {
          if (days.length == 7) return 'Every day';
          if (dayText == 'weekdays') return 'Weekdays';
          if (dayText == 'weekends') return 'Weekends';
          return dayText;
        }
        final every =
            rule.interval == 2 ? 'Every other week' : 'Every ${rule.interval} weeks';
        return '$every on $dayText';
      case RecurrenceFreq.monthly:
        final String day;
        if (rule.byMonthDay != null) {
          day = '${HabitDates.ordinal(rule.byMonthDay!)} of the month';
        } else if (rule.nth != null && rule.nthWeekday != null) {
          final which = rule.nth == -1 ? 'Last' : HabitDates.ordinal(rule.nth!);
          day =
              '$which ${HabitDates.weekdayNames[rule.nthWeekday! - 1]} of the month';
        } else {
          day = 'Monthly';
        }
        if (rule.interval == 1) return day;
        return '$day, every ${rule.interval} months';
    }
  }

  static bool _sameSet(List<int> a, List<int> b) =>
      a.length == b.length && a.toSet().containsAll(b);
}

// ─────────────────────────────────────────────────────────────────────────────
// Outcomes in words
// ─────────────────────────────────────────────────────────────────────────────

/// How a day reads to a screen reader: "Monday 14 September, done".
abstract final class HabitOutcomeText {
  static String of(HabitDayOutcome? outcome) => switch (outcome) {
        HabitDayOutcome.done => 'done',
        HabitDayOutcome.missed => 'missed',
        HabitDayOutcome.neutral => 'rest day',
        HabitDayOutcome.pending => 'not done yet',
        HabitDayOutcome.future => 'upcoming',
        null => 'not scheduled',
      };

  static String cell(String localDate, HabitDayOutcome? outcome) =>
      '${HabitDates.spoken(localDate)}, ${of(outcome)}';
}

// ─────────────────────────────────────────────────────────────────────────────
// Read-only views over a snapshot
// ─────────────────────────────────────────────────────────────────────────────

/// Derived views the screens need, read off an existing snapshot.
///
/// Every value here is a *lookup* into `snapshot.streaks.outcomes` or a call
/// into `HabitStats` — the same engine the snapshot used. None of it walks a
/// streak, so it cannot drift from the number in the header.
extension HabitSnapshotViews on HabitSnapshot {
  /// The last [n] scheduled days up to and including today, oldest first.
  ///
  /// Scheduled days only. A habit created today has exactly one, so a new
  /// habit never shows a week of missed dots it could not have done.
  List<String> lastScheduledDays([int n = 7]) {
    final start = scheduledDates.length > n ? scheduledDates.length - n : 0;
    return scheduledDates.sublist(start);
  }

  HabitDayOutcome? outcomeOn(String localDate) => streaks.outcomes[localDate];

  /// Rest days already excused in [yearMonth] (`YYYY-MM`).
  int excusedInMonth(String yearMonth) => HabitStats.excusedSkipsInMonth(
        scheduledDates: scheduledDates,
        outcomes: streaks.outcomes,
        yearMonth: yearMonth,
      );

  /// The weekday (1 = Monday) with the best completion rate, skipping any
  /// weekday whose rate is null. Null when no weekday has a rate at all.
  ({int weekday, double rate})? get bestWeekday {
    final profile = HabitStats.weekdayProfile(
      scheduledDates: scheduledDates,
      outcomes: streaks.outcomes,
    );
    ({int weekday, double rate})? best;
    for (var w = 1; w <= 7; w++) {
      final rate = profile[w];
      if (rate == null) continue;
      if (best == null || rate > best.rate) best = (weekday: w, rate: rate);
    }
    return best;
  }

  int get totalCheckOffs => HabitStats.totalCheckOffs(entries);

  bool get isRestingToday => todayOutcome == HabitDayOutcome.neutral;

  /// The streak figure when today lands exactly on a milestone, else null.
  ///
  /// Exact per [MilestoneThresholds.reached] — day 31 of a 30-day streak is
  /// not a milestone, so the card glows for one day rather than for a month.
  int? get milestoneToday =>
      MilestoneThresholds.reached(streaks.current) ? streaks.current : null;

  /// The most recent *settled* scheduled day, when it resolved to an excused
  /// rest day rather than a miss.
  ///
  /// Today is skipped: an unchecked habit resolves to `missed` all day, so
  /// reading today would hide yesterday's freeze behind a miss that has not
  /// happened yet. A rest day marked for today needs no forgiveness line
  /// either — the list already files it under "done today".
  ///
  /// Only the latest settled day counts: a freeze three weeks back is
  /// history, and labelling the row for it reads as though the streak were
  /// still in doubt.
  String? get freezeUsedOn {
    for (final date in scheduledDates.reversed) {
      if (date == todayLocalDate) continue;
      final outcome = streaks.outcomes[date];
      if (outcome == null) continue;
      return outcome == HabitDayOutcome.neutral ? date : null;
    }
    return null;
  }
}

/// '82%', or an em dash when the rate is undefined. Never '0%' for null.
String formatHabitRate(double? rate) =>
    rate == null ? '—' : '${(rate * 100).round()}%';
