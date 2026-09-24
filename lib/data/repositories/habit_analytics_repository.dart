// ignore_for_file: prefer_initializing_formals

import '../../core/stats/habit_statistics.dart';
import '../../core/stats/statistics.dart' show StatsPeriod, HeatmapThresholds;
import '../../core/time/time_service.dart';
import '../database/app_database.dart';
import 'habits_repository.dart';
import 'settings_repository.dart';

/// Database wiring for the habit half of the Stats screen (SPEC.md §10.5).
///
/// Deliberately separate from `AnalyticsRepository`, for the same reason
/// `StatsRepository` and `AnalyticsRepository` are already separate from each
/// other: two features that can be built and touched independently should
/// not share a file just because they both answer "how am I doing".
///
/// All the pooling arithmetic lives in `core/stats/habit_statistics.dart` and
/// is tested without a database. This class only loads snapshots — by
/// composing `HabitsRepository`, which already knows how to build one habit's
/// full history and streaks — flattens them into the engine's plain input
/// type, and hands the result over.
///
/// Reusing `HabitsRepository.loadActiveSnapshots()` rather than querying
/// `habit_entries` directly here is deliberate: that method is also what the
/// Habits screen and the detail screen use to compute streaks, so the
/// current/longest streak numbers on the Stats leaderboard can never disagree
/// with the number on a habit's own card.
class HabitAnalyticsRepository {
  HabitAnalyticsRepository({
    required AppDatabase db,
    required TimeService timeService,
    required SettingsRepository settings,
    required HabitsRepository habitsRepository,
  })  : _db = db,
        _time = timeService,
        _settings = settings,
        _habits = habitsRepository;

  final AppDatabase _db;
  final TimeService _time;
  final SettingsRepository _settings;
  final HabitsRepository _habits;

  /// Cache key for the weekly threshold recomputation — see
  /// `AnalyticsRepository.thresholdsCacheKey` for why weekly. A distinct key
  /// (and a distinct settings row) from the focus heatmap's, since the two
  /// scales measure different things and must not overwrite each other.
  static const thresholdsCacheKey = 'habit_heatmap_thresholds_v1';

  /// Same window as the focus heatmap (§4.13): today and the 364 days before.
  static const heatmapWindowDays = 365;

  // ── Row fetching ─────────────────────────────────────────────────────────

  /// Every active habit's history, flattened into the engine's input type.
  ///
  /// Archived and deleted habits are left out, matching what
  /// `habitSnapshotsProvider` already shows on the Habits screen — a habit
  /// the user stopped is stopped everywhere at once, including in its own
  /// contribution to the pooled numbers and the heatmap.
  Future<List<HabitStatsInput>> _inputs() async {
    final snapshots = await _habits.loadActiveSnapshots();
    return [
      for (final snapshot in snapshots)
        HabitStatsInput(
          habitId: snapshot.habit.id,
          title: snapshot.habit.title,
          colorIndex: snapshot.habit.colorIndex,
          iconName: snapshot.habit.iconName,
          currentStreak: snapshot.streaks.current,
          longestStreak: snapshot.streaks.longest,
          outcomes: snapshot.streaks.outcomes,
          entries: snapshot.entries,
        ),
    ];
  }

  // ── Assembly ─────────────────────────────────────────────────────────────

  Future<HabitStatsBundle> load(StatsPeriod period) async {
    final inputs = await _inputs();
    return buildHabitStatsBundle(habits: inputs, period: period);
  }

  /// [load], re-run whenever a habit or an entry changes.
  Stream<HabitStatsBundle> watch(StatsPeriod period) {
    return _db
        .customSelect(
          'SELECT 1 AS change_trigger',
          readsFrom: {_db.habits, _db.habitEntries},
        )
        .watch()
        .asyncMap((_) => load(period));
  }

  // ── Weekly recap ────────────────────────────────────────────────────

  /// The Habits screen's "This week" card, for the current calendar week.
  ///
  /// Always the live week, never [StatsPeriod] from the Stats screen's range
  /// picker — see [WeeklyRecap]'s doc for why a card headed "This week" must
  /// not follow that selection.
  ///
  /// One [_inputs] call covers the lot. [buildWeeklyRecap] asks the same
  /// in-memory list about this week, last week and each of seven days, and
  /// since those functions are pure the extra windows cost arithmetic rather
  /// than queries — the same trick the Stats trend chip uses to price its
  /// prior-period comparison at zero.
  Future<WeeklyRecap> loadWeeklyRecap() async {
    final inputs = await _inputs();
    final today = _time.todayLocalDate();
    return buildWeeklyRecap(
      habits: inputs,
      todayLocalDate: today,
      weekStartLocalDate: _time.startOfWeek(today),
    );
  }

  /// [loadWeeklyRecap], re-run whenever a habit or an entry changes — so a
  /// check-off on the Habits screen moves the card underneath it.
  Stream<WeeklyRecap> watchWeeklyRecap() {
    return _db
        .customSelect(
          'SELECT 1 AS change_trigger',
          readsFrom: {_db.habits, _db.habitEntries},
        )
        .watch()
        .asyncMap((_) => loadWeeklyRecap());
  }

  // ── Activity heatmap ─────────────────────────────────────────────────────

  StatsPeriod heatmapWindow(String todayLocalDate) =>
      StatsPeriod.lastNDays(todayLocalDate, heatmapWindowDays);

  /// Thresholds for the habit heatmap's legend, recomputed at most once a
  /// week — same cadence and the same reasoning as
  /// `AnalyticsRepository.heatmapThresholds`.
  Future<HeatmapThresholds> heatmapThresholds({
    required String todayLocalDate,
    bool forceRecompute = false,
  }) async {
    final weekKey = _time.startOfWeek(todayLocalDate);

    if (!forceRecompute) {
      final cached =
          _readCachedThresholds(await _settings.get(thresholdsCacheKey), weekKey);
      if (cached != null) return cached;
    }

    final inputs = await _inputs();
    final counts = habitDoneCountsByDate(inputs, heatmapWindow(todayLocalDate));
    final thresholds = HeatmapThresholds.fromDailyMinutes(
      counts.values,
      fallback: habitHeatmapFallbackThresholds,
    );

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

  /// Returns null when the cache is absent, stale, or malformed — a
  /// malformed or hand-edited settings row costs one recomputation rather
  /// than a crash on the way into the Stats screen.
  ///
  /// Duplicated from `AnalyticsRepository._readCachedThresholds` rather than
  /// shared: same reasoning as the `_testSafeStream` duplication in the
  /// provider files — two independent features should not be made to share a
  /// file just because they happen to need the same six lines.
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
    return HeatmapThresholds(
      level1Max: l1,
      level2Max: l2,
      level3Max: l3,
      level4Nominal: l4,
      provisional: cached['provisional'] == true,
      nonZeroDayCount: n,
    );
  }

  /// One cell per day for the last [days] days, ending today.
  Future<List<HabitHeatmapCell>> heatmap({
    required String todayLocalDate,
    int days = heatmapWindowDays,
  }) async {
    final thresholds = await heatmapThresholds(todayLocalDate: todayLocalDate);
    final period = StatsPeriod.lastNDays(todayLocalDate, days);
    final inputs = await _inputs();
    final counts = habitDoneCountsByDate(inputs, period);
    return buildHabitHeatmap(
      period: period,
      doneCountsByDate: counts,
      thresholds: thresholds,
    );
  }

  /// [heatmap], refreshed when a habit or an entry changes.
  Stream<List<HabitHeatmapCell>> watchHeatmap({
    required String todayLocalDate,
    int days = heatmapWindowDays,
  }) {
    return _db
        .customSelect(
          'SELECT 1 AS change_trigger',
          readsFrom: {_db.habits, _db.habitEntries},
        )
        .watch()
        .asyncMap((_) => heatmap(todayLocalDate: todayLocalDate, days: days));
  }
}
