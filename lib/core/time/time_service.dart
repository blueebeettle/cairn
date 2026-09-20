// ignore_for_file: prefer_initializing_formals

/// Service implementing time semantics per SPEC.md §1.
///
/// Rules:
/// - All instants are UTC epoch milliseconds (INTEGER).
/// - local_date is computed once at write time as:
///     local_datetime := occurred_at in device timezone at write time
///     local_date     := (local_datetime - day_start_offset).date (YYYY-MM-DD)
/// - day_start_offset default: 240 minutes (04:00 AM).
/// - Also records tz_id and tz_offset_min.
///
/// ## Why the day shift is calendar arithmetic, not Duration arithmetic
///
/// `DateTime.subtract(Duration(...))` on a *local* DateTime shifts the absolute
/// instant and then re-renders it using the offset in effect at the NEW instant.
/// Across a DST transition that changes the wall-clock result by an hour, which
/// silently moves events onto the wrong logical day twice a year.
///
/// Concretely, in America/Edmonton (Alberta observes DST) with a 04:00 day start:
///
/// | local time             | correct    | Duration-based |
/// |------------------------|------------|----------------|
/// | 2026-03-08 04:30 MDT   | 2026-03-08 | 2026-03-07 ✗   |
/// | 2026-11-01 03:30 MST   | 2026-10-31 | 2026-11-01 ✗   |
///
/// So [computeLocalDate] reads the wall-clock fields and shifts the *calendar
/// date* instead. No instant arithmetic is involved, so DST cannot affect it.
///
/// ## Testability
///
/// [DateTime.toLocal] reads the ambient OS timezone, which makes DST behaviour
/// untestable on a machine in a zone that does not observe DST. The [localize],
/// [offsetMinutesAt] and [tzIdProvider] seams let a test inject a zone model.
/// Production code constructs `TimeService()` and gets device behaviour.
class TimeService {
  const TimeService({
    this.dayStartOffsetMinutes = 240,
    this.weekStart = DateTime.monday,
    DateTime Function(int utcMs)? localize,
    int Function(int utcMs)? offsetMinutesAt,
    String Function()? tzIdProvider,
    int Function()? nowProvider,
  })  : _localize = localize,
        _offsetMinutesAt = offsetMinutesAt,
        _tzIdProvider = tzIdProvider,
        _nowProvider = nowProvider;

  /// Default day start offset: 240 minutes (04:00 AM).
  final int dayStartOffsetMinutes;

  /// User setting for week start: default Monday (DateTime.monday = 1).
  final int weekStart;

  final DateTime Function(int utcMs)? _localize;
  final int Function(int utcMs)? _offsetMinutesAt;
  final String Function()? _tzIdProvider;
  final int Function()? _nowProvider;

  /// Returns current instant in UTC epoch milliseconds.
  int nowUtcMs() => _nowProvider != null ? _nowProvider() : DateTime.now().toUtc().millisecondsSinceEpoch;

  /// Converts a UTC epoch milliseconds timestamp to a DateTime whose calendar
  /// fields are the local wall clock at that instant.
  ///
  /// Only the y/M/d/H/m fields of the result are meaningful — do not perform
  /// Duration arithmetic on it.
  DateTime toLocal(int utcMs) {
    final fn = _localize;
    if (fn != null) return fn(utcMs);
    return DateTime.fromMillisecondsSinceEpoch(utcMs, isUtc: true).toLocal();
  }

  /// Converts a local or UTC DateTime to UTC epoch milliseconds.
  int toUtcMs(DateTime dateTime) => dateTime.toUtc().millisecondsSinceEpoch;

  /// Returns the timezone identifier recorded on events.
  ///
  /// NOTE: Dart's [DateTime.timeZoneName] is a platform-dependent abbreviation
  /// ("MDT", "IST") or a Windows display name ("India Standard Time") — it is
  /// NOT the IANA identifier SPEC.md §1.2 asks for. Nothing depends on it for
  /// correctness, because `local_date` is resolved at write time and never
  /// recomputed, but it is the field you will want when diagnosing a timezone
  /// bug months from now.
  ///
  /// To satisfy the spec, add `flutter_timezone` and pass its IANA id in via
  /// [tzIdProvider]. Until then this records the abbreviation.
  String currentTzId() => (_tzIdProvider ?? _deviceTzId)();

  static String _deviceTzId() => DateTime.now().timeZoneName;

  /// Returns the timezone offset in minutes at the given instant
  /// (defaults to now).
  int currentTzOffsetMin([int? atUtcMs]) {
    final fn = _offsetMinutesAt;
    if (fn != null) return fn(atUtcMs ?? nowUtcMs());
    if (atUtcMs == null) return DateTime.now().timeZoneOffset.inMinutes;
    return DateTime.fromMillisecondsSinceEpoch(atUtcMs, isUtc: true)
        .toLocal()
        .timeZoneOffset
        .inMinutes;
  }

  /// Computes the logical date (YYYY-MM-DD) for a UTC epoch millisecond
  /// timestamp, respecting [dayStartOffsetMinutes].
  ///
  /// With day_start_offset = 240 (04:00):
  /// - 03:30 on Sep 10 -> '2026-09-09'
  /// - 04:01 on Sep 10 -> '2026-09-10'
  ///
  /// DST-safe: reads wall-clock fields, shifts the calendar date. See the class
  /// doc for why Duration arithmetic is wrong here.
  String computeLocalDate(int utcMs, {int? offsetMinutes}) {
    final dayStart = offsetMinutes ?? dayStartOffsetMinutes;
    final local = toLocal(utcMs);
    final minutesIntoDay = local.hour * 60 + local.minute;
    final shiftDays = minutesIntoDay < dayStart ? -1 : 0;

    // DateTime.utc normalises out-of-range day values, so day 0 becomes the
    // last day of the previous month and month 0 the previous December.
    final shifted = DateTime.utc(local.year, local.month, local.day + shiftDays);
    return formatIsoDate(shifted.year, shifted.month, shifted.day);
  }

  /// Formats year, month, day into YYYY-MM-DD.
  static String formatIsoDate(int year, int month, int day) {
    final y = year.toString().padLeft(4, '0');
    final m = month.toString().padLeft(2, '0');
    final d = day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Parses a YYYY-MM-DD string into a **UTC** [DateTime] at midnight.
  ///
  /// UTC, not local, deliberately: a logical date is a naive calendar date, and
  /// parsing it as local makes the interval between two consecutive dates 23 or
  /// 25 hours across a DST transition. That breaks [daysBetween] and every
  /// streak walk built on it.
  static DateTime parseLocalDate(String localDate) {
    final parts = localDate.split('-');
    if (parts.length != 3) {
      throw FormatException('Invalid local_date format: $localDate');
    }
    return DateTime.utc(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  /// Returns today's logical date string for the current moment.
  String todayLocalDate() => computeLocalDate(nowUtcMs());

  /// Whole calendar days between two logical dates (date2 - date1).
  ///
  /// Exact across DST because both operands are UTC midnights.
  static int daysBetween(String localDate1, String localDate2) {
    return parseLocalDate(localDate2)
        .difference(parseLocalDate(localDate1))
        .inDays;
  }

  /// Returns the logical date [days] after [localDate] (negative walks back).
  ///
  /// This is what streak walks (SPEC.md §4.3) must use to step day by day.
  static String addDays(String localDate, int days) {
    final d = parseLocalDate(localDate);
    final shifted = DateTime.utc(d.year, d.month, d.day + days);
    return formatIsoDate(shifted.year, shifted.month, shifted.day);
  }

  /// The logical date on which the week containing [localDate] begins,
  /// per SPEC.md §1.3.
  String startOfWeek(String localDate) {
    final d = parseLocalDate(localDate);
    // DateTime.weekday: Monday = 1 ... Sunday = 7.
    final delta = (d.weekday - weekStart + 7) % 7;
    return addDays(localDate, -delta);
  }

  /// The seven logical dates of the week containing [localDate], in order.
  List<String> weekDates(String localDate) {
    final start = startOfWeek(localDate);
    return [for (var i = 0; i < 7; i++) addDays(start, i)];
  }

  /// Elapsed duration in seconds between [startedAtUtcMs] and [endedAtUtcMs],
  /// excluding paused time.
  ///
  /// Two distinct failure modes, deliberately not conflated:
  /// - [hasClockAnomaly] — the device clock moved backwards (SPEC.md §1.5).
  /// - [hasPausedUnderflow] — pause bookkeeping exceeded wall time, which is an
  ///   internal accounting bug, not a clock problem. Both clamp to 0, but they
  ///   need different investigations.
  static ({int elapsedSeconds, bool hasClockAnomaly, bool hasPausedUnderflow})
      computeElapsed({
    required int startedAtUtcMs,
    required int endedAtUtcMs,
    int pausedAccumulatedSeconds = 0,
    int? pausedAtUtcMs,
  }) {
    if (endedAtUtcMs < startedAtUtcMs) {
      return (
        elapsedSeconds: 0,
        hasClockAnomaly: true,
        hasPausedUnderflow: false
      );
    }

    var elapsedSeconds = (endedAtUtcMs - startedAtUtcMs) ~/ 1000;
    elapsedSeconds -= pausedAccumulatedSeconds;
    if (pausedAtUtcMs != null && endedAtUtcMs > pausedAtUtcMs) {
      elapsedSeconds -= (endedAtUtcMs - pausedAtUtcMs) ~/ 1000;
    }

    if (elapsedSeconds < 0) {
      return (
        elapsedSeconds: 0,
        hasClockAnomaly: false,
        hasPausedUnderflow: true
      );
    }

    return (
      elapsedSeconds: elapsedSeconds,
      hasClockAnomaly: false,
      hasPausedUnderflow: false
    );
  }
}
