import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/stats/statistics.dart';
import 'package:habit_tracker/core/time/time_service.dart';
import 'package:habit_tracker/data/database/app_database.dart';
import 'package:habit_tracker/data/repositories/events_repository.dart';
import 'package:habit_tracker/data/repositories/habit_analytics_repository.dart';
import 'package:habit_tracker/data/repositories/habits_repository.dart';
import 'package:habit_tracker/data/repositories/settings_repository.dart';

/// Wiring test for `HabitAnalyticsRepository` (SPEC.md §10.5) — the real
/// database and the real `HabitsRepository` underneath it, so a mistake in
/// how `HabitStatsInput` is assembled from a `HabitSnapshot` would show up
/// here even though it can't in `habit_statistics_test.dart`'s pure fixtures.
///
/// The arithmetic itself is exhaustively covered there; this file only checks
/// that the numbers reaching the Stats screen actually match what two real
/// habits, checked off through the real repository, produce.
int _at(String date, [int hour = 12]) {
  final d = TimeService.parseLocalDate(date);
  return DateTime.utc(d.year, d.month, d.day, hour).millisecondsSinceEpoch;
}

void main() {
  late AppDatabase db;
  late TimeService time;
  late HabitsRepository habits;
  late HabitAnalyticsRepository analytics;
  int nowMs = _at('2026-09-06');

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    time = TimeService(
      localize: (ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
      offsetMinutesAt: (_) => 0,
      tzIdProvider: () => 'UTC',
      nowProvider: () => nowMs,
    );
    final events =
        EventsRepository(db: db, timeService: time, deviceId: 'test-device');
    habits = HabitsRepository(
      db: db,
      eventsRepository: events,
      timeService: time,
      deviceId: 'test-device',
    );
    analytics = HabitAnalyticsRepository(
      db: db,
      timeService: time,
      settings: SettingsRepository(db: db),
      habitsRepository: habits,
    );
  });

  tearDown(() async {
    await db.close();
  });

  const period = StatsPeriod(start: '2026-09-01', end: '2026-09-05');

  Future<void> seedTwoHabits() async {
    // Anchor both on 09-01 by creating them while "now" is that day.
    nowMs = _at('2026-09-01');
    final readId =
        await habits.createHabit(title: 'Read', scheduleRule: 'FREQ=DAILY');
    final walkId =
        await habits.createHabit(title: 'Walk', scheduleRule: 'FREQ=DAILY');

    // Read: done every day except 09-03.
    for (final date in ['2026-09-01', '2026-09-02', '2026-09-04', '2026-09-05']) {
      nowMs = _at(date);
      await habits.check(readId, localDate: date);
    }
    // Walk: done on alternating days only.
    for (final date in ['2026-09-01', '2026-09-03', '2026-09-05']) {
      nowMs = _at(date);
      await habits.check(walkId, localDate: date);
    }

    // "Today" is the 6th — every day above is safely in the past, so none
    // of them can read as `pending` and confuse the arithmetic below.
    nowMs = _at('2026-09-06');
  }

  group('load() — pooled numbers match two real, checked-off habits', () {
    test('completion rate, check-offs, active count and leaderboard', () async {
      await seedTwoHabits();

      final bundle = await analytics.load(period);

      expect(bundle.activeHabitCount, 2);
      // Read: 4 done / 5 scheduled. Walk: 3 done / 5 scheduled. Pooled:
      // 7 done / 10 eligible.
      expect(bundle.completionRate.eligible, 10);
      expect(bundle.completionRate.done, 7);
      expect(bundle.completionRate.rate, closeTo(0.7, 1e-9));

      // Read: 4 check-offs. Walk: 3 check-offs. Total 7.
      expect(bundle.totalCheckOffs, 7);

      // Read finished 09-04 and 09-05 (streak 2); Walk's last day, 09-05,
      // was preceded by a miss on 09-04 (streak 1) -- Read ranks first.
      expect(bundle.leaderboard.map((e) => e.title), ['Read', 'Walk']);
      expect(bundle.leaderboard.first.currentStreak, 2);
      expect(bundle.leaderboard.last.currentStreak, 1);
    });

    test('archiving a habit removes it from the pooled numbers', () async {
      await seedTwoHabits();
      final active = await habits.watchActiveHabits().first;
      final walk = active.firstWhere((h) => h.title == 'Walk');
      await habits.archiveHabit(walk.id);

      final bundle = await analytics.load(period);
      expect(bundle.activeHabitCount, 1);
      expect(bundle.leaderboard.single.title, 'Read');
      // Only Read's 4/5 remains.
      expect(bundle.completionRate.eligible, 5);
      expect(bundle.completionRate.done, 4);
    });
  });

  group('heatmap() — distinct habits done per day', () {
    test('cells for the seeded days carry the right done-count and level',
        () async {
      await seedTwoHabits();

      final cells = await analytics.heatmap(todayLocalDate: '2026-09-06');
      final sep01 = cells.firstWhere((c) => c.date == '2026-09-01');
      final sep02 = cells.firstWhere((c) => c.date == '2026-09-02');

      // 09-01: both habits done -> 2.
      expect(sep01.doneCount, 2);
      // 09-02: only Read done -> 1.
      expect(sep02.doneCount, 1);

      final thresholds =
          await analytics.heatmapThresholds(todayLocalDate: '2026-09-06');
      // Fewer than 14 non-zero days of history -> the habit-scaled fallback,
      // not the focus-minutes one.
      expect(thresholds.provisional, isTrue);
      expect(thresholds.level4Nominal, 5);
    });
  });
}
