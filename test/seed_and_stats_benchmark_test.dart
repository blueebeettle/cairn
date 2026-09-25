// ignore_for_file: avoid_print
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/stats/statistics.dart';
import 'package:habit_tracker/core/time/time_service.dart';
import 'package:habit_tracker/data/database/app_database.dart';
import 'package:habit_tracker/data/dev/seed_data.dart';
import 'package:habit_tracker/data/providers/analytics_providers.dart';
import 'package:habit_tracker/data/repositories/analytics_repository.dart';
import 'package:habit_tracker/data/repositories/events_repository.dart';
import 'package:habit_tracker/data/repositories/habits_repository.dart';
import 'package:habit_tracker/data/repositories/habit_analytics_repository.dart';
import 'package:habit_tracker/data/repositories/settings_repository.dart';
import 'package:habit_tracker/data/repositories/stats_repository.dart';
import 'package:habit_tracker/data/repositories/tasks_repository.dart';

void main() {
  test('POLISH §8 — Seed 2 Years, Measure Stats Queries & Range Lags', () async {
    final db = AppDatabase(NativeDatabase.memory());
    const timeService = TimeService(dayStartOffsetMinutes: 240);
    final settingsRepo = SettingsRepository(db: db);
    final eventsRepo = EventsRepository(db: db, timeService: timeService);
    final analyticsRepo = AnalyticsRepository(
      db: db,
      timeService: timeService,
      settings: settingsRepo,
    );
    final habitsRepo = HabitsRepository(
      db: db,
      eventsRepository: eventsRepo,
      timeService: timeService,
      deviceId: 'bench-device-1',
    );
    final statsRepo = StatsRepository(db: db, timeService: timeService);
    final tasksRepo = TasksRepository(
      db: db,
      eventsRepository: eventsRepo,
      timeService: timeService,
      deviceId: 'bench-device-1',
    );
    final habitAnalyticsRepo = HabitAnalyticsRepository(
      db: db,
      timeService: timeService,
      settings: settingsRepo,
      habitsRepository: habitsRepo,
    );
    final seeder = SeedData(
      db: db,
      timeService: timeService,
      deviceId: 'bench-device-1',
    );

    print('\n==================== POLISH §8 PERFORMANCE PASS ====================');

    // 1. Seed 2 years of data
    print('1. Seeding 2 years (730 days, 1000 tasks)...');
    final seedSw = Stopwatch()..start();
    var lastProgress = 0.0;
    final report = await seeder.generate(
      days: 730,
      taskCount: 1000,
      onProgress: (p) {
        if (p - lastProgress >= 0.25 || p == 1.0) {
          lastProgress = p;
          print('   Progress: ${(p * 100).toStringAsFixed(0)}%');
        }
      },
    );
    seedSw.stop();

    print('   Seeding completed in ${report.elapsedMs}ms (${(report.elapsedMs / 1000).toStringAsFixed(2)}s)');
    print('   Report: $report');

    // Row counts
    final eventCount = (await db.select(db.events).get()).length;
    final sessionCount = (await db.select(db.focusSessions).get()).length;
    final taskCount = (await db.select(db.tasks).get()).length;
    final projectCount = (await db.select(db.projects).get()).length;
    final habitCount = (await db.select(db.habits).get()).length;
    final habitEntryCount = (await db.select(db.habitEntries).get()).length;
    print('   Actual DB counts: $eventCount events, $sessionCount focus_sessions, $taskCount tasks, $projectCount projects, $habitCount habits, $habitEntryCount habit_entries');

    expect(report.habits, equals(6));
    expect(report.habitEntries, greaterThan(2000));
    expect(habitCount, equals(6));
    expect(habitEntryCount, greaterThan(2000));

    // 2. Measure Stats queries for each range
    final today = timeService.todayLocalDate();

    final ranges = [
      (StatsRange.week, StatsPeriod.week(timeService, today)),
      (StatsRange.month, StatsPeriod.lastNDays(today, 30)),
      (StatsRange.quarter, StatsPeriod.lastNDays(today, 90)),
      (StatsRange.allTime, StatsPeriod.allTime),
    ];

    print('\n2. Stats Screen Query Durations:');
    for (final (range, period) in ranges) {
      final sw = Stopwatch()..start();
      final bundle = await analyticsRepo.load(period);
      sw.stop();
      print('   • Range ${range.label.padRight(14)} (${period.start}..${period.end}): '
          '${sw.elapsedMicroseconds / 1000.0}ms '
          '(totalFocus: ${bundle.totalFocusMinutes}m, sessions: ${bundle.peakWindow.totalCompletedSessions}, activeDays: ${bundle.activeDayCount})');
    }

    // 3. Heatmap query duration (trailing 365 days)
    final heatmapSw = Stopwatch()..start();
    final heatmapCells = await analyticsRepo.heatmap(todayLocalDate: today);
    heatmapSw.stop();
    print('\n3. Focus Heatmap 365-day query: ${heatmapSw.elapsedMicroseconds / 1000.0}ms (${heatmapCells.length} cells)');

    final thresholdsSw = Stopwatch()..start();
    final thresholds = await analyticsRepo.heatmapThresholds(todayLocalDate: today);
    thresholdsSw.stop();
    print('   Focus Heatmap thresholds calculation: ${thresholdsSw.elapsedMicroseconds / 1000.0}ms (provisional: ${thresholds.provisional}, days: ${thresholds.nonZeroDayCount})');

    // 4. Habit Stats & Heatmap queries
    print('\n4. Habit Stats & Heatmap Query Durations:');
    final habitStatsSw = Stopwatch()..start();
    final habitBundle = await habitAnalyticsRepo.load(StatsPeriod.lastNDays(today, 30));
    habitStatsSw.stop();
    print('   • Habit stats 30-day query: ${habitStatsSw.elapsedMicroseconds / 1000.0}ms '
        '(activeHabits: ${habitBundle.activeHabitCount}, totalCheckOffs: ${habitBundle.totalCheckOffs}, completionRate: ${(habitBundle.completionRate.rate != null ? (habitBundle.completionRate.rate! * 100).toStringAsFixed(1) : 0)}%)');

    final habitHeatmapSw = Stopwatch()..start();
    final habitHeatmapCells = await habitAnalyticsRepo.heatmap(todayLocalDate: today);
    habitHeatmapSw.stop();
    print('   • Habit Heatmap 365-day query: ${habitHeatmapSw.elapsedMicroseconds / 1000.0}ms (${habitHeatmapCells.length} cells)');

    final habitThresholdsSw = Stopwatch()..start();
    final habitThresholds = await habitAnalyticsRepo.heatmapThresholds(todayLocalDate: today);
    habitThresholdsSw.stop();
    print('   • Habit Heatmap thresholds calculation: ${habitThresholdsSw.elapsedMicroseconds / 1000.0}ms (provisional: ${habitThresholds.provisional}, days: ${habitThresholds.nonZeroDayCount})');

    // 4b. Measure windowed Stats & Tasks query performance
    print('\n4b. Windowed Stats & Tasks Query Durations:');
    final last7DaysSw = Stopwatch()..start();
    final last7Days = await statsRepo.watchLast7DaysSummary().first;
    last7DaysSw.stop();
    print('   • StatsRepository.watchLast7DaysSummary (7 days windowed): ${last7DaysSw.elapsedMicroseconds / 1000.0}ms (${last7Days.length} days)');

    final throughputSw = Stopwatch()..start();
    final throughput = await statsRepo.getThroughput(
      localDates: {for (var i = 0; i < 7; i++) TimeService.addDays(today, -i)},
    );
    throughputSw.stop();
    print('   • StatsRepository.getThroughput (SQL date filtered): ${throughputSw.elapsedMicroseconds / 1000.0}ms (created: ${throughput.created}, completed: ${throughput.completed})');

    final todayTasksSw = Stopwatch()..start();
    final todayTasks = await tasksRepo.watchTodayTasks(today).first;
    todayTasksSw.stop();
    print('   • TasksRepository.watchTodayTasks (indexed & scoped): ${todayTasksSw.elapsedMicroseconds / 1000.0}ms (${todayTasks.length} tasks)');

    final upcomingTasksSw = Stopwatch()..start();
    final upcomingTasks = await tasksRepo.watchUpcomingTasks(today).first;
    upcomingTasksSw.stop();
    print('   • TasksRepository.watchUpcomingTasks (indexed & scoped): ${upcomingTasksSw.elapsedMicroseconds / 1000.0}ms (${upcomingTasks.length} tasks)');

    final inboxTasksSw = Stopwatch()..start();
    final inboxTasks = await tasksRepo.watchInboxTasks().first;
    inboxTasksSw.stop();
    print('   • TasksRepository.watchInboxTasks (indexed & scoped): ${inboxTasksSw.elapsedMicroseconds / 1000.0}ms (${inboxTasks.length} tasks)');

    final archivedTasksSw = Stopwatch()..start();
    final archivedTasks = await tasksRepo.watchArchivedTasks().first;
    archivedTasksSw.stop();
    print('   • TasksRepository.watchArchivedTasks (indexed & scoped): ${archivedTasksSw.elapsedMicroseconds / 1000.0}ms (${archivedTasks.length} tasks)');

    // 5. Wipe duration
    print('\n5. Database wipe...');
    final wipeSw = Stopwatch()..start();
    await seeder.wipe();
    wipeSw.stop();
    print('   Wiped in ${wipeSw.elapsedMilliseconds}ms');

    // Verify empty state counts
    final eventsAfter = (await db.select(db.events).get()).length;
    final sessionsAfter = (await db.select(db.focusSessions).get()).length;
    final tasksAfter = (await db.select(db.tasks).get()).length;
    final habitsAfter = (await db.select(db.habits).get()).length;
    final habitEntriesAfter = (await db.select(db.habitEntries).get()).length;
    print('   Counts after wipe: $eventsAfter events, $sessionsAfter sessions, $tasksAfter tasks, $habitsAfter habits, $habitEntriesAfter habit_entries');

    expect(eventsAfter, equals(0));
    expect(sessionsAfter, equals(0));
    expect(tasksAfter, equals(0));
    expect(habitsAfter, equals(0));
    expect(habitEntriesAfter, equals(0));

    print('======================================================================\n');

    await db.close();
  });
}
