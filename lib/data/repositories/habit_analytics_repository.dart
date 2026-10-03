// ignore_for_file: prefer_initializing_formals

import '../../core/stats/habit_statistics.dart';
import '../../core/stats/statistics.dart' show StatsPeriod, HeatmapThresholds;
import '../../core/time/time_service.dart';
import '../database/app_database.dart';
import 'habits_repository.dart';
import 'settings_repository.dart';

/// The one place a [HabitSnapshot] becomes the engine's Drift-free
/// [HabitStatsInput].
///
/// Shared rather than private because the Today screen's momentum strip pools
/// its own per-day rates from the snapshots it already watches, and a second
/// copy of this conversion is how the strip and the Habits recap would come to
/// disagree about a day.
extension HabitSnapshotStatsInput on HabitSnapshot {
  HabitStatsInput toStatsInput() => HabitStatsInput(
        habitId: habit.id,
        title: habit.title,
        colorIndex: habit.colorIndex,
        iconName: habit.iconName,
        currentStreak: streaks.current,
        longestStreak: streaks.longest,
        outcomes: streaks.outcomes,
        entries: entries,
      );
}

/// Database wiring for the habit half of the Stats screen (SPEC.md §10.5).
/// Deliberately separate from `AnalyticsRepository`, as `StatsRepository` and
/// `AnalyticsRepository` are from each other.
///
/// All the pooling arithmetic lives in `core/stats/habit_statistics.dart` and
/// is tested without a database. This class loads snapshots by composing
/// `HabitsRepository`, flattens them into the engine's plain input type, and
/// hands the result over.
///
/// Reusing `HabitsRepository.loadActiveSnapshots()` rather than querying
/// `habit_entries` directly is deliberate: the Habits and detail screens
/// compute streaks from it too, so the Stats leaderboard's current/longest
/// streak can never disagree with a habit's own card.
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

  /// Cache key for the weekly threshold recomputation; see
  /// `AnalyticsRepository.thresholdsCacheKey` for why weekly. A distinct key
  /// (and settings row) from the focus heatmap's, since the two scales measure
  /// different things and must not overwrite each other.
  static const thresholdsCacheKey = 'habit_heatmap_thresholds_v1';

  /// Same window as the focus heatmap (§4.13): today and the 364 days before.
  static const heatmapWindowDays = 365;

  // ── Row fetching ─────────────────────────────────────────────────────────

  /// Every active habit's history, flattened into the engine's input type.
  /// Archived and deleted habits are left out, matching
  /// `habitSnapshotsProvider` on the Habits screen: a habit the user stopped is
  /// stopped everywhere, including in the pooled numbers and the heatmap.
  Future<List<HabitStatsInput>> _inputs() async {
    final snapshots = await _habits.loadActiveSnapshots();
    return [for (final snapshot in snapshots) snapshot.toStatsInput()];
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
  /// Always the live week, never the Stats screen's range picker; see
  /// [WeeklyRecap]'s doc for why.
  ///
  /// One [_inputs] call covers the lot: [buildWeeklyRecap] asks the same
  /// in-memory list about this week, last week and each of seven days, and
  /// since those functions are pure the extra windows cost arithmetic rather
  /// than queries (the same trick the Stats trend chip uses for its
  /// prior-period comparison).
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

  /// Thresholds for the habit heatmap's legend, recomputed at most once a week,
  /// with the same cadence and reasoning as
  /// `AnalyticsRepository.heatmapThresholds`. Non-provisional thresholds are
  /// cached for the rest of the week; provisional entries count as invalid so
  /// the user is promoted to the real scale mid-week as soon as they reach 14
  /// non-zero days.
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

  /// Returns null when the cache is absent, stale, malformed, or provisional: a
  /// hand-edited settings row costs one recomputation rather than a crash on
  /// the way into the Stats screen, and a provisional entry is invalid so it
  /// can promote mid-week.
  ///
  /// Duplicated from `AnalyticsRepository._readCachedThresholds` rather than
  /// shared, like the `_testSafeStream` copies in the provider files; change
  /// them together.
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
