// ignore_for_file: avoid_print
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/stats/statistics.dart';
import 'package:habit_tracker/core/time/time_service.dart';
import 'package:habit_tracker/data/database/app_database.dart';
import 'package:habit_tracker/data/dev/seed_data.dart';
import 'package:habit_tracker/data/providers/analytics_providers.dart';
import 'package:habit_tracker/data/repositories/analytics_repository.dart';
import 'package:habit_tracker/data/repositories/settings_repository.dart';

void main() {
  test('POLISH §8 — Seed 2 Years, Measure Stats Queries & Range Lags', () async {
    final db = AppDatabase(NativeDatabase.memory());
    const timeService = TimeService(dayStartOffsetMinutes: 240);
    final settingsRepo = SettingsRepository(db: db);
    final analyticsRepo = AnalyticsRepository(
      db: db,
      timeService: timeService,
      settings: settingsRepo,
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
    print('   Actual DB counts: $eventCount events, $sessionCount focus_sessions, $taskCount tasks, $projectCount projects');

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
    print('\n3. Heatmap 365-day query: ${heatmapSw.elapsedMicroseconds / 1000.0}ms (${heatmapCells.length} cells)');

    final thresholdsSw = Stopwatch()..start();
    final thresholds = await analyticsRepo.heatmapThresholds(todayLocalDate: today);
    thresholdsSw.stop();
    print('   Heatmap thresholds calculation: ${thresholdsSw.elapsedMicroseconds / 1000.0}ms (provisional: ${thresholds.provisional}, days: ${thresholds.nonZeroDayCount})');

    // 4. Wipe duration
    print('\n4. Database wipe...');
    final wipeSw = Stopwatch()..start();
    await seeder.wipe();
    wipeSw.stop();
    print('   Wiped in ${wipeSw.elapsedMilliseconds}ms');

    // Verify empty state counts
    final eventsAfter = (await db.select(db.events).get()).length;
    final sessionsAfter = (await db.select(db.focusSessions).get()).length;
    final tasksAfter = (await db.select(db.tasks).get()).length;
    print('   Counts after wipe: $eventsAfter events, $sessionsAfter sessions, $tasksAfter tasks');

    print('======================================================================\n');

    await db.close();
  });
}
