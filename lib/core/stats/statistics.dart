/// The statistics engine — SPEC.md §4.2, §4.4–4.8 and §4.13.
///
/// Everything here is pure. No database, no Flutter, no clock: you hand it
/// records and it hands you numbers. That is deliberate — SPEC.md §7 requires
/// the stats engine to be testable exhaustively without a device, and a
/// calculation that can only be exercised through a database will not be.
///
/// ## The rule that governs this whole file
///
/// SPEC.md §4: *where a metric is undefined, display an em dash — never `0`,
/// never `0%`, never an imputed value. A zero that means "no data" is a lie the
/// user will act on.*
///
/// So every metric with a denominator returns `null` when that denominator is
/// zero. `null` means "cannot be computed"; `0` means "computed, and it is
/// zero". Those are different facts and the UI must render them differently.
/// Ten sessions all abandoned really is a 0% completion rate and should say so.
/// No sessions at all is an em dash.
///
/// Counts are not subject to this. Focus minutes and streak days of 0 are true
/// statements, and `FocusStats` in `stats_repository.dart` renders them as 0.
library;

import '../time/time_service.dart';

/// One completed or abandoned session, flattened out of the database.
///
/// The engine takes this rather than Drift's generated row class so the tests
/// can construct cases by hand without opening a database.
class SessionRecord {
  const SessionRecord({
    required this.id,
    required this.localDate,
    required this.startedAtUtcMs,
    required this.endedAtUtcMs,
    required this.actualDurationS,
    required this.outcome,
    required this.tzOffsetMin,
    this.interruptionsInternal = 0,
    this.interruptionsExternal = 0,
    this.focusRating,
    this.projectId,
  });

  final String id;

  /// The logical day the session STARTED on (SPEC.md §1.4). A session is never
  /// split across days, so this is also the day it is counted in.
  final String localDate;

  final int startedAtUtcMs;
  final int endedAtUtcMs;

  /// Minutes east of UTC where the session actually happened, captured at
  /// session start (SPEC.md §1.2). +330 for India, −360 for Alberta in summer.
  ///
  /// This is what makes "you focus best at 9am" survive a plane journey. Bin by
  /// the device's *current* zone instead and every session ever recorded in
  /// Ahmedabad jumps 11½ hours the moment the phone lands in Edmonton: a
  /// morning habit is redrawn as a late-night one, and nothing the user did
  /// changed. The offset belongs to the session, not to the reader.
  final int tzOffsetMin;

  /// Focused seconds, excluding paused time.
  final int actualDurationS;

  /// `completed` or `abandoned` — see `SessionOutcomes`.
  final String outcome;

  final int interruptionsInternal;
  final int interruptionsExternal;

  /// 1–5, or null when the user did not rate the session.
  final int? focusRating;

  /// Denormalised at session start, so reassigning a task later does not
  /// rewrite history (SPEC.md §2.3).
  final String? projectId;

  bool get isCompleted => outcome == 'completed';
  bool get isAbandoned => outcome == 'abandoned';
}

/// An inclusive range of logical dates.
///
/// A range rather than a set of dates: the queries behind these metrics can
/// then use `BETWEEN` on the indexed `local_date` column instead of an `IN`
/// clause with 365 bound variables. YYYY-MM-DD sorts lexicographically in the
/// same order it sorts chronologically, which is the whole reason the format
/// was chosen in §1.2.
class StatsPeriod {
  const StatsPeriod({required this.start, required this.end});

  final String start;
  final String end;

  /// Wide enough to contain every date the app can store.
  static const allTime = StatsPeriod(start: '0000-01-01', end: '9999-12-31');

  bool contains(String localDate) =>
      localDate.compareTo(start) >= 0 && localDate.compareTo(end) <= 0;

  static StatsPeriod day(String localDate) =>
      StatsPeriod(start: localDate, end: localDate);

  /// The [days] logical days ending on [endDate] inclusive, so
  /// `lastNDays('2026-09-15', 7)` runs 09-09 .. 09-15.
  static StatsPeriod lastNDays(String endDate, int days) => StatsPeriod(
        start: TimeService.addDays(endDate, -(days - 1)),
        end: endDate,
      );

  static StatsPeriod week(TimeService time, String localDate) {
    final start = time.startOfWeek(localDate);
    return StatsPeriod(start: start, end: TimeService.addDays(start, 6));
  }

  static StatsPeriod month(String localDate) {
    final d = TimeService.parseLocalDate(localDate);
    final lastDay = DateTime.utc(d.year, d.month + 1, 0).day;
    return StatsPeriod(
      start: TimeService.formatIsoDate(d.year, d.month, 1),
      end: TimeService.formatIsoDate(d.year, d.month, lastDay),
    );
  }

  /// Every date in the range, in order. Only safe on bounded periods — do not
  /// call it on [allTime].
  List<String> dates() {
    final out = <String>[];
    var cursor = start;
    var guard = 0;
    while (cursor.compareTo(end) <= 0 && guard++ < 4000) {
      out.add(cursor);
      cursor = TimeService.addDays(cursor, 1);
    }
    return out;
  }

  @override
  String toString() => '$start..$end';
}

// ───────────────────────────────────────────────────────────────────────────
// §4.1 Focus minutes — the denominator several metrics below share
// ───────────────────────────────────────────────────────────────────────────

/// SPEC.md §4.1 — focused minutes per logical day, from completed sessions.
///
/// Seconds are accumulated per day and divided once at the end. Rounding each
/// session and then adding would throw away up to 59 seconds per session, which
/// on a busy day is enough to lose a streak the user actually earned.
///
/// Abandoned sessions contribute zero, so they are dropped here rather than
/// filtered by every caller.
Map<String, int> focusMinutesByDate(Iterable<SessionRecord> sessions) {
  final seconds = <String, int>{};
  for (final s in sessions) {
    if (!s.isCompleted) continue;
    seconds[s.localDate] = (seconds[s.localDate] ?? 0) + s.actualDurationS;
  }
  return {
    for (final entry in seconds.entries) entry.key: entry.value ~/ 60,
  };
}

/// SPEC.md §4.1 over a whole collection, summed before conversion.
int focusMinutesTotal(Iterable<SessionRecord> sessions) {
  var seconds = 0;
  for (final s in sessions) {
    if (s.isCompleted) seconds += s.actualDurationS;
  }
  return seconds ~/ 60;
}

// ───────────────────────────────────────────────────────────────────────────
// §4.2 Session completion rate
// ───────────────────────────────────────────────────────────────────────────

/// SPEC.md §4.2 — `completed / (completed + abandoned)` over sessions STARTED
/// in the period.
///
/// "Started in P" needs no extra column: §1.4 fixes a session's `local_date` to
/// the day it started, so filtering on `local_date` already means "started in".
class CompletionRate {
  const CompletionRate({required this.completed, required this.abandoned});

  final int completed;
  final int abandoned;

  int get total => completed + abandoned;

  /// 0.0–1.0, or null when no session was started in the period.
  ///
  /// Note the case that is easy to get wrong: ten sessions, all abandoned, is
  /// a *defined* rate of 0.0 and must be shown as 0%. Only an empty period is
  /// an em dash.
  double? get rate => total == 0 ? null : completed / total;

  static const empty = CompletionRate(completed: 0, abandoned: 0);

  static CompletionRate of(Iterable<SessionRecord> sessions) {
    var c = 0;
    var a = 0;
    for (final s in sessions) {
      if (s.isCompleted) {
        c++;
      } else if (s.isAbandoned) {
        a++;
      }
    }
    return CompletionRate(completed: c, abandoned: a);
  }
}

// ───────────────────────────────────────────────────────────────────────────
// §4.4 Peak window
// ───────────────────────────────────────────────────────────────────────────

/// SPEC.md §4.4 — twenty-four bins by local hour, with sessions apportioned
/// across the bins they actually overlap.
class PeakWindow {
  const PeakWindow({
    required this.minutesByHour,
    required this.totalCompletedSessions,
  });

  /// 24 entries, index 0 = midnight hour. Fractional: a session rarely lands
  /// on an hour boundary.
  final List<double> minutesByHour;

  /// Completed sessions over ALL history, not just this period — that is what
  /// the display gate below is counted against.
  final int totalCompletedSessions;

  /// SPEC.md §4.4: *"a peak computed from four sessions is noise presented as
  /// insight."*
  static const minimumSessions = 10;

  bool get hasEnoughData => totalCompletedSessions >= minimumSessions;

  /// The busiest hour, or null when there is not enough history to say.
  ///
  /// A tie goes to the earlier hour — strictly greater, never greater-or-equal
  /// — so the answer does not depend on iteration order.
  int? get peakHour {
    if (!hasEnoughData) return null;
    var best = -1;
    var bestValue = 0.0;
    for (var h = 0; h < 24; h++) {
      if (minutesByHour[h] > bestValue) {
        bestValue = minutesByHour[h];
        best = h;
      }
    }
    return best < 0 ? null : best;
  }

  double get totalMinutes =>
      minutesByHour.fold(0.0, (sum, value) => sum + value);

  static PeakWindow of(
    Iterable<SessionRecord> sessionsInPeriod, {
    required int totalCompletedSessions,
  }) {
    final bins = List<double>.filled(24, 0.0);
    for (final s in sessionsInPeriod) {
      if (!s.isCompleted) continue;
      final contribution = apportionToHourBins(s);
      for (var h = 0; h < 24; h++) {
        bins[h] += contribution[h];
      }
    }
    return PeakWindow(
      minutesByHour: bins,
      totalCompletedSessions: totalCompletedSessions,
    );
  }

  /// Spreads one session's focus minutes across the local hours it overlapped.
  ///
  /// Two decisions worth stating, because both are invisible until they are
  /// wrong:
  ///
  /// **1. The bins hold focus minutes, not wall-clock minutes.** A session
  /// paused for half an hour occupies more clock than it contributes to §4.1.
  /// If the bins held wall-clock time, the peak-window chart would total more
  /// than the focus-minutes figure sitting next to it on the same screen, and
  /// one of the two would be wrong. So the overlap is scaled by
  /// `actual / span`; pause time is spread evenly across the span, which is an
  /// approximation, but a conservative one that keeps the two numbers agreeing.
  /// Summed over a period, the bins equal total focused seconds ÷ 60 exactly
  /// (§4.1 then floors that to whole minutes).
  ///
  /// **2. The hours are the session's own, not the reader's.** Binning runs off
  /// [SessionRecord.tzOffsetMin], captured where and when the session happened,
  /// never off the device's current zone.
  ///
  /// Users are expected to be in India or in Canada and to stay put — this is
  /// not about emigrating. It is about the device's idea of "local" being an
  /// unsafe basis for reading the past at all: a trip with the timezone
  /// changed, or a zone simply set wrong, would redraw every session ever
  /// recorded and then redraw it back afterwards. What the chart says about
  /// last March should not depend on where the phone is this morning.
  ///
  /// The cost, written down rather than rediscovered as a bug: looking the zone
  /// up per instant would bin a session that *spans* a DST change correctly,
  /// and this does not — minutes after the change land an hour off. It takes a
  /// session still running at 02:00 on one Sunday a year, so in practice close
  /// to never. But it is a real thing given up, not a free win.
  ///
  /// Arithmetic note: adding the offset to the UTC instant gives a "local
  /// epoch" on which hour boundaries are plain division, so no calendar object
  /// is constructed and no zone is consulted at read time.
  static List<double> apportionToHourBins(SessionRecord session) {
    final bins = List<double>.filled(24, 0.0);
    if (session.actualDurationS <= 0) return bins;

    final offsetMs = session.tzOffsetMin * 60000;
    final localStart = session.startedAtUtcMs + offsetMs;
    final localEnd = session.endedAtUtcMs + offsetMs;
    final focusMinutes = session.actualDurationS / 60.0;
    final spanMs = localEnd - localStart;

    if (spanMs <= 0) {
      // A zero or negative span means a clock anomaly (§1.5) or a manual entry
      // recorded as an instant. Attribute the whole session to the hour it
      // started in rather than dropping it.
      bins[_localHour(localStart)] += focusMinutes;
      return bins;
    }

    final scale = focusMinutes / (spanMs / 60000.0);

    var cursor = localStart;
    var guard = 0;
    while (cursor < localEnd && guard++ < 2000) {
      final hour = _localHour(cursor);
      final step = _msPerHour - _msIntoHour(cursor);
      final next = cursor + step;
      final chunkEnd = next < localEnd ? next : localEnd;
      bins[hour] += ((chunkEnd - cursor) / 60000.0) * scale;
      cursor = chunkEnd;
    }
    return bins;
  }

  static const _msPerHour = 3600000;

  /// Milliseconds elapsed within the current local hour.
  ///
  /// Dart's `%` returns a non-negative result for a positive divisor, so this
  /// is right for pre-1970 instants too — and for the half-hour offsets that
  /// make India interesting, where local hour boundaries never line up with UTC
  /// ones.
  static int _msIntoHour(int localMs) => localMs % _msPerHour;

  /// Hour of the local day, 0–23, from a local-epoch millisecond value.
  static int _localHour(int localMs) {
    final hours = (localMs - _msIntoHour(localMs)) ~/ _msPerHour;
    return hours % 24;
  }
}

// ───────────────────────────────────────────────────────────────────────────
// §4.5 Day-of-week profile
// ───────────────────────────────────────────────────────────────────────────

/// One weekday's bar in the §4.5 profile.
class WeekdayBin {
  const WeekdayBin({
    required this.weekday,
    required this.activeDays,
    required this.totalMinutes,
  });

  /// `DateTime.monday` (1) … `DateTime.sunday` (7).
  final int weekday;

  /// SPEC.md §4.5 requires this to be displayed on every bar. A mean of 90
  /// drawn from one Saturday is not the same claim as a mean of 90 drawn from
  /// thirty, and a bar that hides `n` makes them look identical.
  final int activeDays;

  final int totalMinutes;

  double? get meanMinutes =>
      activeDays == 0 ? null : totalMinutes / activeDays;
}

/// SPEC.md §4.5 — mean focus minutes per weekday.
///
/// The denominator is days that contain **at least one event of any type**, not
/// all days in the period. A Tuesday the user spent on a plane without opening
/// the app is not evidence that they focus badly on Tuesdays; averaging it in
/// as a zero would say exactly that. A day they *did* use the app but logged no
/// focus time is a real zero and does count.
///
/// [activeDates] must already be restricted to the period, and must come from
/// the events table rather than from sessions — that is what "any type" means.
class WeekdayProfile {
  const WeekdayProfile(this.bins);

  /// Seven entries, index 0 = Monday.
  final List<WeekdayBin> bins;

  WeekdayBin forWeekday(int weekday) => bins[weekday - 1];

  static WeekdayProfile of({
    required Iterable<String> activeDates,
    required Map<String, int> minutesByDate,
  }) {
    final counts = List<int>.filled(7, 0);
    final totals = List<int>.filled(7, 0);

    for (final date in activeDates) {
      final index = TimeService.parseLocalDate(date).weekday - 1;
      counts[index] += 1;
      totals[index] += minutesByDate[date] ?? 0;
    }

    return WeekdayProfile([
      for (var i = 0; i < 7; i++)
        WeekdayBin(
          weekday: i + 1,
          activeDays: counts[i],
          totalMinutes: totals[i],
        ),
    ]);
  }
}

// ───────────────────────────────────────────────────────────────────────────
// §4.6 Interruptions per focused hour
// ───────────────────────────────────────────────────────────────────────────

/// SPEC.md §4.6 — `(internal + external) / (focus minutes / 60)`.
///
/// Internal and external are reported separately as well as combined because,
/// as §4.6 says, they have different remedies: internal is a habit to train,
/// external is a boundary to set.
///
/// **Population:** numerator and denominator are both taken over *completed*
/// sessions. §4.1 already defines focus minutes as completed-only, so counting
/// interruptions from abandoned sessions on top of a completed-only denominator
/// would produce a ratio of two different populations — a user who abandons
/// often would see a rate they cannot act on. Interruptions recorded on
/// abandoned sessions are surfaced separately instead of being hidden.
class InterruptionRate {
  const InterruptionRate({
    required this.internal,
    required this.external,
    required this.focusMinutes,
    required this.abandonedInternal,
    required this.abandonedExternal,
  });

  final int internal;
  final int external;
  final int focusMinutes;

  /// Not folded into the rate — see the class doc.
  final int abandonedInternal;
  final int abandonedExternal;

  int get total => internal + external;

  double? _per(int count) =>
      focusMinutes == 0 ? null : count / (focusMinutes / 60.0);

  double? get perHourInternal => _per(internal);
  double? get perHourExternal => _per(external);
  double? get perHourTotal => _per(total);

  static const empty = InterruptionRate(
    internal: 0,
    external: 0,
    focusMinutes: 0,
    abandonedInternal: 0,
    abandonedExternal: 0,
  );

  static InterruptionRate of(Iterable<SessionRecord> sessions) {
    var internal = 0;
    var external = 0;
    var seconds = 0;
    var abInternal = 0;
    var abExternal = 0;

    for (final s in sessions) {
      if (s.isCompleted) {
        internal += s.interruptionsInternal;
        external += s.interruptionsExternal;
        seconds += s.actualDurationS;
      } else if (s.isAbandoned) {
        abInternal += s.interruptionsInternal;
        abExternal += s.interruptionsExternal;
      }
    }

    return InterruptionRate(
      internal: internal,
      external: external,
      // Sum seconds, divide once — §4.1's rule. Rounding each session first
      // would discard up to 59 seconds per session.
      focusMinutes: seconds ~/ 60,
      abandonedInternal: abInternal,
      abandonedExternal: abExternal,
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// §4.7 Mean focus rating
// ───────────────────────────────────────────────────────────────────────────

/// SPEC.md §4.7 — mean of `focus_rating` over completed sessions that have one.
///
/// *"Never impute a missing rating."* An unrated session is absent from both
/// the numerator and the denominator. Treating it as a 3 would drag every
/// user's mean toward the middle and make the metric useless exactly when it
/// has least data.
class FocusRatingStats {
  const FocusRatingStats({required this.n, required this.sum, required this.distribution});

  /// Rated completed sessions. SPEC.md §4.7 requires this to be displayed.
  final int n;
  final int sum;

  /// Counts for ratings 1–5; index 0 is rating 1.
  final List<int> distribution;

  double? get mean => n == 0 ? null : sum / n;

  static const empty =
      FocusRatingStats(n: 0, sum: 0, distribution: [0, 0, 0, 0, 0]);

  static FocusRatingStats of(Iterable<SessionRecord> sessions) {
    final dist = List<int>.filled(5, 0);
    var n = 0;
    var sum = 0;
    for (final s in sessions) {
      if (!s.isCompleted) continue;
      final r = s.focusRating;
      if (r == null || r < 1 || r > 5) continue;
      dist[r - 1] += 1;
      n += 1;
      sum += r;
    }
    return FocusRatingStats(n: n, sum: sum, distribution: dist);
  }
}

// ───────────────────────────────────────────────────────────────────────────
// §4.8 Time allocation
// ───────────────────────────────────────────────────────────────────────────

/// One project's share of focused time.
class AllocationSlice {
  const AllocationSlice({
    required this.projectId,
    required this.label,
    required this.minutes,
    required this.totalMinutes,
  });

  /// null means the session had no project — see [unassignedLabel].
  final String? projectId;
  final String label;
  final int minutes;
  final int totalMinutes;

  bool get isUnassigned => projectId == null;

  double? get share => totalMinutes == 0 ? null : minutes / totalMinutes;
}

/// SPEC.md §4.8 — focus minutes grouped by project.
///
/// *"Sessions with no project appear as 'Unassigned' and are always shown —
/// hiding them makes the totals lie."* The bug this guards against is a query
/// that groups by `project_id` and quietly loses every row where it is null;
/// the chart then shows 100% across three projects while the user's actual
/// week was half unassigned.
class TimeAllocation {
  const TimeAllocation({required this.slices, required this.totalMinutes});

  final List<AllocationSlice> slices;
  final int totalMinutes;

  static const unassignedLabel = 'Unassigned';

  /// False when nothing was completed in the period — render an em dash, not
  /// an empty pie.
  bool get isDefined => totalMinutes > 0;

  static const empty = TimeAllocation(slices: [], totalMinutes: 0);

  static TimeAllocation of(
    Iterable<SessionRecord> sessions, {
    required Map<String, String> projectNames,
  }) {
    final secondsByProject = <String?, int>{};
    for (final s in sessions) {
      if (!s.isCompleted) continue;
      secondsByProject[s.projectId] =
          (secondsByProject[s.projectId] ?? 0) + s.actualDurationS;
    }

    final minutesByProject = <String?, int>{};
    for (final entry in secondsByProject.entries) {
      final minutes = entry.value ~/ 60;
      if (minutes > 0) minutesByProject[entry.key] = minutes;
    }

    final total =
        minutesByProject.values.fold(0, (sum, value) => sum + value);

    final slices = <AllocationSlice>[];
    for (final entry in minutesByProject.entries) {
      final id = entry.key;
      slices.add(AllocationSlice(
        projectId: id,
        label: id == null
            ? unassignedLabel
            : (projectNames[id] ?? 'Unknown project'),
        minutes: entry.value,
        totalMinutes: total,
      ));
    }

    // Largest first. Ties put named projects ahead of Unassigned and then sort
    // alphabetically, so the order is stable between rebuilds rather than
    // following map iteration order.
    slices.sort((a, b) {
      final byMinutes = b.minutes.compareTo(a.minutes);
      if (byMinutes != 0) return byMinutes;
      if (a.isUnassigned != b.isUnassigned) return a.isUnassigned ? 1 : -1;
      return a.label.compareTo(b.label);
    });

    return TimeAllocation(slices: slices, totalMinutes: total);
  }
}

// ───────────────────────────────────────────────────────────────────────────
// §4.13 Activity heatmap
// ───────────────────────────────────────────────────────────────────────────

/// SPEC.md §4.13 — the level boundaries for the contribution heatmap.
///
/// The thresholds are percentiles of the user's **own** trailing 365 non-zero
/// days. *"Fixed thresholds make every user's heatmap look the same; relative
/// ones make it theirs."* Someone doing 20-minute sessions and someone doing
/// four-hour ones both get a heatmap that distinguishes their good days from
/// their ordinary ones.
///
/// **Four percentiles, four levels.** Each percentile is the *upper* bound of
/// its level, and the top level saturates — a day above the 90th percentile is
/// still level 4, because there is no level 5:
///
/// ```
///   level 0 :          minutes == 0
///   level 1 :      0 <  minutes <= p25
///   level 2 :    p25 <  minutes <= p50
///   level 3 :    p50 <  minutes <= p75
///   level 4 :    p75 <  minutes            (nominal ceiling p90, legend only)
/// ```
///
/// [level4Nominal] is therefore not used to assign a level. It is what the
/// legend shows as the top of the scale.
class HeatmapThresholds {
  const HeatmapThresholds({
    required this.level1Max,
    required this.level2Max,
    required this.level3Max,
    required this.level4Nominal,
    required this.provisional,
    required this.nonZeroDayCount,
  });

  final int level1Max;
  final int level2Max;
  final int level3Max;

  /// The 90th percentile. Shown in the legend; never used to pick a level.
  final int level4Nominal;

  /// True while the fixed fallback is in use. SPEC.md §4.13 requires the
  /// legend to say so — a scale the user's own history did not produce should
  /// not pretend otherwise.
  final bool provisional;

  final int nonZeroDayCount;

  /// Below this many non-zero days the percentiles are noise, so §4.13 falls
  /// back to fixed thresholds.
  static const minimumNonZeroDays = 14;

  static const fallback = HeatmapThresholds(
    level1Max: 25,
    level2Max: 50,
    level3Max: 100,
    level4Nominal: 180,
    provisional: true,
    nonZeroDayCount: 0,
  );

  int levelFor(int minutes) {
    if (minutes <= 0) return 0;
    if (minutes <= level1Max) return 1;
    if (minutes <= level2Max) return 2;
    if (minutes <= level3Max) return 3;
    return 4;
  }

  /// Nearest-rank percentile: with `n` values sorted ascending, the `p`th
  /// percentile is the value at 1-based rank `ceil(p × n / 100)`.
  ///
  /// Computed in integer arithmetic on purpose. `(p / 100 * n).ceil()` is one
  /// representation error away from stepping a whole rank — `0.9 * 20` landing
  /// on 18.000000000000004 would ceil to 19 — and a threshold that moves by a
  /// rank changes which days light up on the user's heatmap.
  static int nearestRankPercentile(List<int> sortedAscending, int p) {
    final n = sortedAscending.length;
    if (n == 0) return 0;
    final rank = (p * n + 99) ~/ 100; // ceil(p * n / 100)
    var index = rank - 1;
    if (index < 0) index = 0;
    if (index > n - 1) index = n - 1;
    return sortedAscending[index];
  }

  /// [dailyMinutes] is every day in the trailing window; zero days are dropped
  /// here rather than by the caller, since §4.13 defines the percentiles over
  /// non-zero days only.
  ///
  /// Despite the name, nothing below is minute-specific — it is "the p-th
  /// nearest-rank value of a list of per-day integers", full stop. That is
  /// what lets `core/stats/habit_statistics.dart` reuse this exact method for
  /// habit check-off counts instead of duplicating the percentile logic; it
  /// only needed a fallback scaled for its own metric, hence [fallback] being
  /// a parameter rather than always reading the minutes-scaled constant below.
  static HeatmapThresholds fromDailyMinutes(
    Iterable<int> dailyMinutes, {
    HeatmapThresholds fallback = HeatmapThresholds.fallback,
  }) {
    final values = dailyMinutes.where((m) => m > 0).toList()..sort();

    if (values.length < minimumNonZeroDays) {
      return HeatmapThresholds(
        level1Max: fallback.level1Max,
        level2Max: fallback.level2Max,
        level3Max: fallback.level3Max,
        level4Nominal: fallback.level4Nominal,
        provisional: true,
        nonZeroDayCount: values.length,
      );
    }

    return HeatmapThresholds(
      level1Max: nearestRankPercentile(values, 25),
      level2Max: nearestRankPercentile(values, 50),
      level3Max: nearestRankPercentile(values, 75),
      level4Nominal: nearestRankPercentile(values, 90),
      provisional: false,
      nonZeroDayCount: values.length,
    );
  }
}

/// One cell of the heatmap.
class HeatmapCell {
  const HeatmapCell({
    required this.date,
    required this.minutes,
    required this.level,
  });

  final String date;
  final int minutes;
  final int level;
}

/// SPEC.md §4.13 — a run of days with a level each.
///
/// Every date in the period gets a cell, including days with no data: a gap in
/// a heatmap is information, and an absent square would silently shift every
/// later square into the wrong column.
List<HeatmapCell> buildHeatmap({
  required StatsPeriod period,
  required Map<String, int> minutesByDate,
  required HeatmapThresholds thresholds,
}) {
  return [
    for (final date in period.dates())
      HeatmapCell(
        date: date,
        minutes: minutesByDate[date] ?? 0,
        level: thresholds.levelFor(minutesByDate[date] ?? 0),
      ),
  ];
}
