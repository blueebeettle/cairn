// ignore_for_file: prefer_initializing_formals
import 'package:drift/drift.dart';

import '../../core/constants/event_types.dart';
import '../../core/stats/statistics.dart';
import '../../core/time/time_service.dart';
import '../database/app_database.dart';
import 'settings_repository.dart';

/// Everything the Stats screen needs for one period, loaded together.
///
/// One object rather than seven providers because the numbers have to agree
/// with each other: if the completion rate came from one snapshot of the
/// database and the peak window from another taken a moment later, a session
/// finishing in between would show up in one and not the other, and the screen
/// would quietly contradict itself.
class StatsBundle {
  const StatsBundle({
    required this.period,
    required this.completionRate,
    required this.peakWindow,
    required this.weekdayProfile,
    required this.interruptions,
    required this.focusRating,
    required this.timeAllocation,
    required this.minutesByDate,
    required this.totalFocusMinutes,
    required this.activeDayCount,
  });

  final StatsPeriod period;

  /// §4.2
  final CompletionRate completionRate;

  /// §4.4
  final PeakWindow peakWindow;

  /// §4.5
  final WeekdayProfile weekdayProfile;

  /// §4.6
  final InterruptionRate interruptions;

  /// §4.7
  final FocusRatingStats focusRating;

  /// §4.8
  final TimeAllocation timeAllocation;

  /// §4.1, per logical day inside the period.
  final Map<String, int> minutesByDate;

  final int totalFocusMinutes;

  /// Days in the period on which the app recorded anything at all. Worth
  /// showing beside the charts: four active days is a different claim from
  /// thirty, and §5 asks for `n` wherever a comparison is drawn.
  final int activeDayCount;

  bool get hasAnyData => activeDayCount > 0;
}

/// Database wiring for SPEC.md §4.2, §4.4–4.8 and §4.13.
///
/// Deliberately separate from `StatsRepository`, which serves the Today screen.
/// That one answers "how am I doing right now" and is watched continuously;
/// this one answers "what do my last thirty days look like" and runs when a
/// screen opens. Keeping them apart means the Today screen never pays for a
/// year-wide aggregate.
///
/// All the arithmetic lives in `core/stats/statistics.dart` and is tested
/// without a database. This class only fetches rows and hands them over.
///
/// The queries are written as literal SQL rather than through the query
/// builder. They are aggregate-shaped, the SQL reads more clearly than the
/// builder equivalent, and POLISH §8 asks for `EXPLAIN QUERY PLAN` on exactly
/// these statements — which is a great deal easier when the statement is
/// sitting right here in the source.
class AnalyticsRepository {
  AnalyticsRepository({
    required AppDatabase db,
    required TimeService timeService,
    required SettingsRepository settings,
  })  : _db = db,
        _time = timeService,
        _settings = settings;

  final AppDatabase _db;
  final TimeService _time;
  final SettingsRepository _settings;

  /// Cache key for §4.13's weekly threshold recomputation. Versioned, so a
  /// future change to the percentile method invalidates old caches instead of
  /// reading them back with the wrong meaning.
  static const thresholdsCacheKey = 'heatmap_thresholds_v1';

  /// §4.13 — "the trailing 365 days", counting today as one of them.
  static const heatmapWindowDays = 365;

  // ── Row fetching ─────────────────────────────────────────────────────────

  /// Sessions started inside the period.
  ///
  /// §1.4 fixes `local_date` to the day a session started, so filtering on it
  /// already means "started in P" — no second column and no UTC arithmetic.
  Future<List<SessionRecord>> sessionsIn(StatsPeriod period) async {
    final rows = await _db.customSelect(
      'SELECT id, local_date, started_at, ended_at, actual_duration_s, '
      'outcome, interruptions_internal, interruptions_external, '
      'focus_rating, project_id, tz_offset_min '
      'FROM focus_sessions '
      'WHERE local_date >= ? AND local_date <= ?',
      variables: [Variable<String>(period.start), Variable<String>(period.end)],
      readsFrom: {_db.focusSessions},
    ).get();

    return [
      for (final row in rows)
        SessionRecord(
          id: row.read<String>('id'),
          localDate: row.read<String>('local_date'),
          startedAtUtcMs: row.read<int>('started_at'),
          endedAtUtcMs: row.read<int>('ended_at'),
          actualDurationS: row.read<int>('actual_duration_s'),
          outcome: row.read<String>('outcome'),
          interruptionsInternal: row.read<int>('interruptions_internal'),
          interruptionsExternal: row.read<int>('interruptions_external'),
          focusRating: row.readNullable<int>('focus_rating'),
          projectId: row.readNullable<String>('project_id'),
          tzOffsetMin: row.read<int>('tz_offset_min'),
        ),
    ];
  }

  /// Logical days inside the period on which *any* event was recorded.
  ///
  /// §4.5 needs this rather than days-with-sessions: a day the user spent
  /// ticking off tasks without running a timer is a day they showed up, and it
  /// belongs in the denominator as a zero. A day the app never opened does not.
  ///
  /// Reads `events`, which is what "an event of any type" means, and uses the
  /// `events_local_date_idx` index from §2.1.
  Future<Set<String>> activeDatesIn(StatsPeriod period) async {
    final rows = await _db.customSelect(
      'SELECT DISTINCT local_date FROM events '
      'WHERE local_date >= ? AND local_date <= ?',
      variables: [Variable<String>(period.start), Variable<String>(period.end)],
      readsFrom: {_db.events},
    ).get();
    return {for (final row in rows) row.read<String>('local_date')};
  }

  /// §4.1 by day, aggregated in SQL.
  ///
  /// Used for the heatmap's 365-day window, where pulling a year of session
  /// rows into memory to add them up would be wasteful. Identical in meaning to
  /// `focusMinutesByDate` in `statistics.dart`: sum the seconds per day, divide
  /// once. If you change one, change the other.
  Future<Map<String, int>> focusMinutesByDateSql(StatsPeriod period) async {
    final rows = await _db.customSelect(
      'SELECT local_date, SUM(actual_duration_s) AS total_seconds '
      'FROM focus_sessions '
      'WHERE outcome = ? AND local_date >= ? AND local_date <= ? '
      'GROUP BY local_date',
      variables: [
        Variable<String>(SessionOutcomes.completed),
        Variable<String>(period.start),
        Variable<String>(period.end),
      ],
      readsFrom: {_db.focusSessions},
    ).get();

    return {
      for (final row in rows)
        row.read<String>('local_date'):
            (row.readNullable<int>('total_seconds') ?? 0) ~/ 60,
    };
  }

  /// Completed sessions over all history — the count §4.4 gates its display on.
  ///
  /// All history, not the period: the question "do we know this user well
  /// enough to name their peak hour" is about how much they have ever logged,
  /// not about how busy last week was.
  Future<int> totalCompletedSessions() async {
    final row = await _db.customSelect(
      'SELECT COUNT(*) AS session_count FROM focus_sessions WHERE outcome = ?',
      variables: [Variable<String>(SessionOutcomes.completed)],
      readsFrom: {_db.focusSessions},
    ).getSingle();
    return row.read<int>('session_count');
  }

  /// Project id → display name, for §4.8's labels.
  ///
  /// Archived projects are included. A session logged against a project the
  /// user later archived still happened, and dropping the name would relabel
  /// history as "Unknown project".
  Future<Map<String, String>> projectNames() async {
    final rows = await _db.customSelect(
      'SELECT id, name FROM projects WHERE deleted_at IS NULL',
      readsFrom: {_db.projects},
    ).get();
    return {
      for (final row in rows)
        row.read<String>('id'): row.read<String>('name'),
    };
  }

  /// §4.2 for one period on its own.
  ///
  /// The trend chip on the Stats hero needs the *previous* period's completion
  /// rate and nothing else. Building a whole [StatsBundle] for it would run
  /// four more queries and compute a peak window, a weekday profile and a time
  /// allocation that no one reads.
  Future<CompletionRate> completionRateIn(StatsPeriod period) async {
    return CompletionRate.of(await sessionsIn(period));
  }

  // ── Assembly ─────────────────────────────────────────────────────────────

  /// Everything for one period, from one consistent read.
  Future<StatsBundle> load(StatsPeriod period) async {
    final sessions = await sessionsIn(period);
    final activeDates = await activeDatesIn(period);
    final totalCompleted = await totalCompletedSessions();
    final names = await projectNames();
    final minutesByDate = focusMinutesByDate(sessions);

    return StatsBundle(
      period: period,
      completionRate: CompletionRate.of(sessions),
      peakWindow: PeakWindow.of(
        sessions,
        totalCompletedSessions: totalCompleted,
      ),
      weekdayProfile: WeekdayProfile.of(
        activeDates: activeDates,
        minutesByDate: minutesByDate,
      ),
      interruptions: InterruptionRate.of(sessions),
      focusRating: FocusRatingStats.of(sessions),
      timeAllocation: TimeAllocation.of(sessions, projectNames: names),
      minutesByDate: minutesByDate,
      totalFocusMinutes: focusMinutesTotal(sessions),
      activeDayCount: activeDates.length,
    );
  }

  /// [load], re-run whenever anything it reads changes.
  ///
  /// The `SELECT 1` is a change trigger, not a query: Drift re-runs a custom
  /// statement when any table in `readsFrom` is written, so this emits once on
  /// listen and again after every relevant write. `asyncMap` keeps the reloads
  /// serialised, so a burst of writes cannot stack up overlapping reads.
  Stream<StatsBundle> watch(StatsPeriod period) {
    return _db
        .customSelect(
          'SELECT 1 AS change_trigger',
          readsFrom: {_db.focusSessions, _db.events, _db.projects},
        )
        .watch()
        .asyncMap((_) => load(period));
  }

  // ── §4.13 heatmap ────────────────────────────────────────────────────────

  /// The window §4.13 computes its percentiles over: today and the 364 days
  /// before it.
  StatsPeriod heatmapWindow(String todayLocalDate) =>
      StatsPeriod.lastNDays(todayLocalDate, heatmapWindowDays);

  /// §4.13 thresholds, recomputed at most once a week.
  ///
  /// Weekly, as the spec says, for two reasons. It is a year-wide aggregate
  /// that has no business running on every rebuild (POLISH §8), and thresholds
  /// that moved every session would make yesterday's squares change colour
  /// overnight for no reason the user could see.
  ///
  /// The cache is keyed by the start of the current week, so it expires by
  /// being from a different week rather than by storing a timestamp and doing
  /// arithmetic on it. Once non-provisional thresholds exist, they are cached
  /// for the remainder of the week; provisional cache entries are treated as
  /// invalid so the user can promote to the real scale mid-week as soon as
  /// they reach 14 non-zero days.
  Future<HeatmapThresholds> heatmapThresholds({
    required String todayLocalDate,
    bool forceRecompute = false,
  }) async {
    final weekKey = _time.startOfWeek(todayLocalDate);

    if (!forceRecompute) {
      final cached = _readCachedThresholds(await _settings.get(thresholdsCacheKey), weekKey);
      if (cached != null) return cached;
    }

    final minutes = await focusMinutesByDateSql(heatmapWindow(todayLocalDate));
    final thresholds = HeatmapThresholds.fromDailyMinutes(minutes.values);

    await _settings.set(thresholdsCacheKey, {
      'week': weekKey,
      'l1': thresholds.level1Max,
      'l2': thresholds.level2Max,
      'l3': thresholds.level3Max,
      'l4': thresholds.level4Nominal,
      'provisional': thresholds.provisional,
      'n': thresholds.nonZeroDayCount,
    });

    return thresholds;
  }

  /// Returns null when the cache is absent, stale, malformed, or provisional.
  ///
  /// Malformed counts as absent on purpose: a half-written or hand-edited
  /// settings row should cost one recomputation, not throw on the way into the
  /// Stats screen. A provisional cache entry is also treated as invalid so the
  /// threshold computation can promote to the real scale as soon as the data
  /// supports it mid-week.
  static HeatmapThresholds? _readCachedThresholds(Object? cached, String weekKey) {
    if (cached is! Map) return null;
    if (cached['week'] != weekKey) return null;
    final l1 = cached['l1'];
    final l2 = cached['l2'];
    final l3 = cached['l3'];
    final l4 = cached['l4'];
    final n = cached['n'];
    if (l1 is! int || l2 is! int || l3 is! int || l4 is! int || n is! int) {
      return null;
    }
    final provisional = cached['provisional'] == true;
    if (provisional) return null;
    return HeatmapThresholds(
      level1Max: l1,
      level2Max: l2,
      level3Max: l3,
      level4Nominal: l4,
      provisional: false,
      nonZeroDayCount: n,
    );
  }

  /// One cell per day for the last [days] days, ending today.
  Future<List<HeatmapCell>> heatmap({
    required String todayLocalDate,
    int days = heatmapWindowDays,
  }) async {
    final thresholds = await heatmapThresholds(todayLocalDate: todayLocalDate);
    final period = StatsPeriod.lastNDays(todayLocalDate, days);
    final minutes = await focusMinutesByDateSql(period);
    return buildHeatmap(
      period: period,
      minutesByDate: minutes,
      thresholds: thresholds,
    );
  }

  /// [heatmap], refreshed when sessions change.
  ///
  /// Only `focus_sessions` is watched: the heatmap is a picture of focused
  /// time, so ticking off a task should not redraw it.
  Stream<List<HeatmapCell>> watchHeatmap({
    required String todayLocalDate,
    int days = heatmapWindowDays,
  }) {
    return _db
        .customSelect(
          'SELECT 1 AS change_trigger',
          readsFrom: {_db.focusSessions},
        )
        .watch()
        .asyncMap((_) => heatmap(todayLocalDate: todayLocalDate, days: days));
  }
}
