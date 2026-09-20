import '../time/time_service.dart';

/// Task recurrence per SPEC.md §2.6.
///
/// Rules are stored in `tasks.recurrence_rule` as an RRULE subset, so they stay
/// readable in an export and can be widened later without a migration:
///
///   FREQ=DAILY;INTERVAL=1          every day
///   FREQ=DAILY;INTERVAL=3          every third day
///   FREQ=WEEKLY;BYDAY=MO,WE,FR     Mondays, Wednesdays and Fridays
///   FREQ=WEEKLY;INTERVAL=2;BYDAY=TU  every other Tuesday
///   FREQ=MONTHLY;BYMONTHDAY=1      the 1st of each month
///   FREQ=MONTHLY;BYDAY=2TU         the 2nd Tuesday of each month
///   FREQ=MONTHLY;BYDAY=-1FR        the last Friday of each month
///
/// All dates in and out are logical dates (YYYY-MM-DD) per SPEC.md §1.2, and
/// every calculation goes through [TimeService] so it stays DST-safe.
enum RecurrenceFreq { daily, weekly, monthly }

/// SPEC.md §2.6 — which anchor the next instance advances from.
enum RecurrenceMode {
  /// Anchored to the schedule. "Pay rent on the 1st" stays on the 1st no
  /// matter when you actually tick it off.
  onSchedule,

  /// Anchored to when you finished. "Water the plants every 3 days" means
  /// three days from the last watering, not from a calendar.
  afterCompletion,
}

class RecurrenceRule {
  const RecurrenceRule({
    required this.freq,
    this.interval = 1,
    this.byWeekday = const {},
    this.byMonthDay,
    this.nth,
    this.nthWeekday,
  });

  final RecurrenceFreq freq;

  /// Every N days / weeks / months. Always >= 1.
  final int interval;

  /// DateTime.monday (1) .. DateTime.sunday (7). Weekly rules only.
  final Set<int> byWeekday;

  /// 1..31. Monthly rules only. See [_clampToMonth] for short months.
  final int? byMonthDay;

  /// 1..5, or -1 for last. Monthly nth-weekday rules only.
  final int? nth;

  /// DateTime.monday .. DateTime.sunday, paired with [nth].
  final int? nthWeekday;

  static const _dayCodes = {
    'MO': DateTime.monday,
    'TU': DateTime.tuesday,
    'WE': DateTime.wednesday,
    'TH': DateTime.thursday,
    'FR': DateTime.friday,
    'SA': DateTime.saturday,
    'SU': DateTime.sunday,
  };
  static const _codeForDay = {
    DateTime.monday: 'MO',
    DateTime.tuesday: 'TU',
    DateTime.wednesday: 'WE',
    DateTime.thursday: 'TH',
    DateTime.friday: 'FR',
    DateTime.saturday: 'SA',
    DateTime.sunday: 'SU',
  };

  /// Parses a stored rule. Returns null on anything malformed rather than
  /// throwing — a corrupt rule should make a task non-recurring, not crash
  /// the list it appears in.
  static RecurrenceRule? parse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;

    final parts = <String, String>{};
    for (final chunk in raw.toUpperCase().split(';')) {
      final i = chunk.indexOf('=');
      if (i <= 0) return null;
      parts[chunk.substring(0, i).trim()] = chunk.substring(i + 1).trim();
    }

    final freq = switch (parts['FREQ']) {
      'DAILY' => RecurrenceFreq.daily,
      'WEEKLY' => RecurrenceFreq.weekly,
      'MONTHLY' => RecurrenceFreq.monthly,
      _ => null,
    };
    if (freq == null) return null;

    var interval = 1;
    if (parts.containsKey('INTERVAL')) {
      final n = int.tryParse(parts['INTERVAL']!);
      if (n == null || n < 1) return null;
      interval = n;
    }

    final byDayRaw = parts['BYDAY'];

    if (freq == RecurrenceFreq.weekly) {
      if (byDayRaw == null || byDayRaw.isEmpty) return null;
      final days = <int>{};
      for (final code in byDayRaw.split(',')) {
        final d = _dayCodes[code.trim()];
        if (d == null) return null;
        days.add(d);
      }
      return RecurrenceRule(
          freq: freq, interval: interval, byWeekday: days);
    }

    if (freq == RecurrenceFreq.monthly) {
      if (parts.containsKey('BYMONTHDAY')) {
        final d = int.tryParse(parts['BYMONTHDAY']!);
        if (d == null || d < 1 || d > 31) return null;
        return RecurrenceRule(
            freq: freq, interval: interval, byMonthDay: d);
      }
      if (byDayRaw != null && byDayRaw.length >= 3) {
        // e.g. "2TU", "-1FR"
        final code = byDayRaw.substring(byDayRaw.length - 2);
        final n = int.tryParse(byDayRaw.substring(0, byDayRaw.length - 2));
        final day = _dayCodes[code];
        if (n == null || day == null) return null;
        if (n != -1 && (n < 1 || n > 5)) return null;
        return RecurrenceRule(
            freq: freq, interval: interval, nth: n, nthWeekday: day);
      }
      return null;
    }

    return RecurrenceRule(freq: freq, interval: interval);
  }

  String serialize() {
    final b = StringBuffer();
    b.write('FREQ=${switch (freq) {
      RecurrenceFreq.daily => 'DAILY',
      RecurrenceFreq.weekly => 'WEEKLY',
      RecurrenceFreq.monthly => 'MONTHLY',
    }}');
    if (interval != 1) b.write(';INTERVAL=$interval');
    if (freq == RecurrenceFreq.weekly) {
      final ordered = byWeekday.toList()..sort();
      b.write(';BYDAY=${ordered.map((d) => _codeForDay[d]).join(',')}');
    }
    if (freq == RecurrenceFreq.monthly) {
      if (byMonthDay != null) {
        b.write(';BYMONTHDAY=$byMonthDay');
      } else if (nth != null && nthWeekday != null) {
        b.write(';BYDAY=$nth${_codeForDay[nthWeekday]}');
      }
    }
    return b.toString();
  }

  /// The first occurrence strictly after [from].
  ///
  /// [from] and the result are logical dates (YYYY-MM-DD).
  String nextAfter(String from) {
    return switch (freq) {
      RecurrenceFreq.daily => TimeService.addDays(from, interval),
      RecurrenceFreq.weekly => _nextWeekly(from),
      RecurrenceFreq.monthly => _nextMonthly(from),
    };
  }

  String _nextWeekly(String from) {
    final d = TimeService.parseLocalDate(from);
    // Recurrence weeks always start Monday, independent of the user's display
    // week-start setting. Otherwise changing that setting would silently
    // reschedule every existing task.
    final mondayOfFrom = TimeService.addDays(from, -(d.weekday - 1));

    for (var week = 0; week <= 520; week++) {
      final weekStart = TimeService.addDays(mondayOfFrom, week * interval * 7);
      for (var offset = 0; offset < 7; offset++) {
        final candidate = TimeService.addDays(weekStart, offset);
        final weekday = TimeService.parseLocalDate(candidate).weekday;
        if (byWeekday.contains(weekday) &&
            TimeService.daysBetween(from, candidate) > 0) {
          return candidate;
        }
      }
    }
    // Unreachable for any valid rule; ten years of weeks is a generous bound.
    return TimeService.addDays(from, 7);
  }

  String _nextMonthly(String from) {
    final d = TimeService.parseLocalDate(from);
    var year = d.year;
    var month = d.month;

    for (var step = 0; step <= 240; step++) {
      final candidate = byMonthDay != null
          ? _clampToMonth(year, month, byMonthDay!)
          : _nthWeekdayOf(year, month, nth!, nthWeekday!);

      if (candidate != null && TimeService.daysBetween(from, candidate) > 0) {
        return candidate;
      }

      // The anchor is the month of `from`, so an every-3-months rule counts
      // quarters from there rather than from an arbitrary epoch.
      month += interval;
      while (month > 12) {
        month -= 12;
        year += 1;
      }
    }
    return TimeService.addDays(from, 30);
  }

  /// Day-of-month rules in short months.
  ///
  /// RFC 5545 says BYMONTHDAY=31 simply does not occur in a 30-day month, so
  /// the month is skipped. That is wrong for a task app: someone who sets
  /// "pay rent on the 31st" expects February to fire on the 28th, not to
  /// vanish. So this CLAMPS to the last day of the month instead.
  static String _clampToMonth(int year, int month, int day) {
    final lastDay = DateTime.utc(year, month + 1, 0).day;
    final d = day > lastDay ? lastDay : day;
    return TimeService.formatIsoDate(year, month, d);
  }

  /// The [n]th [weekday] of a month; n == -1 means the last one.
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
    // A 5th Tuesday does not exist in every month. Skip that month.
    return null;
  }

  @override
  String toString() => serialize();

  @override
  bool operator ==(Object other) =>
      other is RecurrenceRule && other.serialize() == serialize();

  @override
  int get hashCode => serialize().hashCode;
}

/// The due date of the next instance after one is completed, per SPEC.md §2.6.
///
/// [scheduledDate] is the due date of the instance just completed.
/// [completedDate] is the logical date it was actually ticked off.
/// [todayLocalDate] is used only by [RecurrenceMode.onSchedule], to avoid
/// generating a backlog — see below.
///
/// The two modes differ only in which anchor they advance from:
///
///   onSchedule      -> advance from scheduledDate
///   afterCompletion -> advance from completedDate
///
/// On the backlog question: if you complete a monthly "1st of the month" task
/// six weeks late, advancing from the scheduled date lands on a due date
/// that is already in the past. Generating that instance, and the next, and
/// the next, buries the user in overdue copies of one task. So onSchedule
/// keeps advancing until it reaches a date that is not before today. The
/// series stays anchored to the 1st — which is what "does not shift the
/// series" means — without manufacturing a backlog.
String? nextOccurrence({
  required RecurrenceRule? rule,
  required RecurrenceMode mode,
  required String scheduledDate,
  required String completedDate,
  required String todayLocalDate,
}) {
  if (rule == null) return null;

  if (mode == RecurrenceMode.afterCompletion) {
    return rule.nextAfter(completedDate);
  }

  var next = rule.nextAfter(scheduledDate);
  var guard = 0;
  while (TimeService.daysBetween(todayLocalDate, next) < 0 && guard < 500) {
    next = rule.nextAfter(next);
    guard++;
  }
  return next;
}
