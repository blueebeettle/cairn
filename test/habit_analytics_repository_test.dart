import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/stats/statistics.dart';
import 'package:habit_tracker/core/time/time_service.dart';
import 'package:habit_tracker/data/database/app_database.dart';
import 'package:habit_tracker/data/repositories/events_repository.dart';
import 'package:habit_tracker/data/repositories/habit_analytics_repository.dart';
import 'package:habit_tracker/data/repositories/habits_repository.dart';
import 'package:habit_tracker/data/repositories/settings_repository.dart';
import 'package:habit_tracker/features/today/presentation/widgets/momentum_week_strip.dart';

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
  late SettingsRepository settings;
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
    settings = SettingsRepository(db: db);
    analytics = HabitAnalyticsRepository(
      db: db,
      timeService: time,
      settings: settings,
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

  // The reported bug, end to end: real habits, real check-off, real database.
  // Both charts that draw today's fill — the Habits screen's recap bars and the
  // Today screen's momentum strip — must show a genuine fraction, and the same
  // one, rather than leaping to full the moment one habit is ticked.
  group("today's fill — 4 habits scheduled, 1 checked off", () {
    // Sun 2026-09-06: week starts Mon 08-31, so today is the last column.
    const today = '2026-09-06';

    Future<void> fourDailyHabitsOneDone() async {
      nowMs = _at('2026-08-31');
      final ids = <String>[];
      for (final title in ['Read', 'Walk', 'Stretch', 'Journal']) {
        ids.add(await habits.createHabit(
            title: title, scheduleRule: 'FREQ=DAILY'));
      }
      nowMs = _at(today);
      await habits.check(ids.first, localDate: today);
    }

    test('the weekly recap draws today at 0.25', () async {
      await fourDailyHabitsOneDone();

      final recap = await analytics.loadWeeklyRecap();
      final todayBar = recap.days.singleWhere((d) => d.isToday);

      expect(todayBar.date, today);
      expect(todayBar.rate, 0.25);
    });

    test('the momentum strip draws today at 0.25', () async {
      await fourDailyHabitsOneDone();

      final days = MomentumWeekStrip.daysFor(
        weekOf: today,
        todayLocalDate: today,
        snapshots: await habits.loadActiveSnapshots(),
        weekStart: DateTime.monday,
      );
      final todayPip = days.singleWhere((d) => d.isToday);

      expect(todayPip.localDate, today);
      expect(todayPip.rate, 0.25);
    });

    test('the two charts agree on every day of the week', () async {
      await fourDailyHabitsOneDone();

      final recap = await analytics.loadWeeklyRecap();
      final days = MomentumWeekStrip.daysFor(
        weekOf: today,
        todayLocalDate: today,
        snapshots: await habits.loadActiveSnapshots(),
        weekStart: DateTime.monday,
      );

      expect(
        [for (final d in days) d.rate],
        [for (final d in recap.days) d.rate],
      );
    });

    test('settled days are unchanged: an untouched past day is a real 0.0',
        () async {
      await fourDailyHabitsOneDone();

      final recap = await analytics.loadWeeklyRecap();
      // Mon 08-31 .. Sat 09-05: four habits scheduled, none ever checked.
      final monday = recap.days.first;
      expect(monday.date, '2026-08-31');
      expect(monday.rate, 0.0);
    });

    test('checking off every habit takes today to exactly 1.0', () async {
      await fourDailyHabitsOneDone();
      final all = await habits.loadActiveSnapshots();
      for (final s in all.skip(1)) {
        await habits.check(s.habit.id, localDate: today);
      }

      final recap = await analytics.loadWeeklyRecap();
      expect(recap.days.singleWhere((d) => d.isToday).rate, 1.0);
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

  group('heatmapThresholds() — provisional cache promotion and mid-week crossing', () {
    test(
      'provisional cache is not served as-is, promotes mid-week upon 14 non-zero days, and caches non-provisional',
      () async {
        // Anchor on 2026-08-01 so check-offs across August are valid scheduled dates
        nowMs = _at('2026-08-01');
        final habitId = await habits.createHabit(
          title: 'Exercise',
          scheduleRule: 'FREQ=DAILY',
        );

        // 1. Initial 5 distinct days of check-offs (< 14 minimumNonZeroDays)
        for (var d = 1; d <= 5; d++) {
          final date = '2026-08-0$d';
          nowMs = _at(date);
          await habits.check(habitId, localDate: date);
        }
        nowMs = _at('2026-09-06');

        final t1 = await analytics.heatmapThresholds(todayLocalDate: '2026-09-06');
        expect(t1.provisional, isTrue);
        expect(t1.nonZeroDayCount, 5);

        // Verify cache in settings store was written with provisional: true
        final cached1 = await settings.get(HabitAnalyticsRepository.thresholdsCacheKey) as Map?;
        expect(cached1, isNotNull);
        expect(cached1!['provisional'], isTrue);

        // 2. Next read within the same week: recomputes, still provisional
        final t2 = await analytics.heatmapThresholds(todayLocalDate: '2026-09-06');
        expect(t2.provisional, isTrue);
        expect(t2.nonZeroDayCount, 5);

        // 3. Add check-offs across 10 more distinct days so count reaches 15 (>= 14) mid-week
        for (var d = 10; d < 20; d++) {
          final date = '2026-08-$d';
          nowMs = _at(date);
          await habits.check(habitId, localDate: date);
        }
        nowMs = _at('2026-09-06');

        // Next read in the SAME week immediately promotes to non-provisional
        final t3 = await analytics.heatmapThresholds(todayLocalDate: '2026-09-06');
        expect(t3.provisional, isFalse);
        expect(t3.nonZeroDayCount, 15);

        // Cache now stores provisional == false
        final cached2 = await settings.get(HabitAnalyticsRepository.thresholdsCacheKey) as Map?;
        expect(cached2, isNotNull);
        expect(cached2!['provisional'], isFalse);

        // 4. Once non-provisional, subsequent reads in the same week return the cached value
        // Mutate underlying data by adding another check-off on a new date
        const dateExtra = '2026-08-25';
        nowMs = _at(dateExtra);
        await habits.check(habitId, localDate: dateExtra);
        nowMs = _at('2026-09-06');

        final t4 = await analytics.heatmapThresholds(todayLocalDate: '2026-09-06');
        // Returned value is still the cached one (15 nonZeroDayCount, not 16)
        expect(t4.provisional, isFalse);
        expect(t4.nonZeroDayCount, 15);
        expect(t4.level1Max, t3.level1Max);
        expect(t4.level2Max, t3.level2Max);

        // 5. forceRecompute: true bypasses cache and reflects the new data
        final t5 = await analytics.heatmapThresholds(
          todayLocalDate: '2026-09-06',
          forceRecompute: true,
        );
        expect(t5.provisional, isFalse);
        expect(t5.nonZeroDayCount, 16);
      },
    );

    test('forceRecompute: true bypasses provisional cache as well', () async {
      nowMs = _at('2026-08-01');
      final habitId = await habits.createHabit(
        title: 'Exercise',
        scheduleRule: 'FREQ=DAILY',
      );
      await habits.check(habitId, localDate: '2026-08-01');
      nowMs = _at('2026-09-06');

      final t1 = await analytics.heatmapThresholds(
        todayLocalDate: '2026-09-06',
        forceRecompute: true,
      );
      expect(t1.provisional, isTrue);
      expect(t1.nonZeroDayCount, 1);
    });
  });
}
