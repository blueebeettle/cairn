import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/data/database/app_database.dart';
import 'package:habit_tracker/data/repositories/settings_repository.dart';
import 'package:habit_tracker/main.dart';

void main() {
  test('Startup parallelization: runStartupBootstrap runs independent steps concurrently', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final settingsRepo = SettingsRepository(db: db);

    const stepDelay = Duration(milliseconds: 100);
    DateTime? homeWidgetStarted;
    DateTime? homeWidgetFinished;
    DateTime? timezoneStarted;
    DateTime? timezoneFinished;

    // Pre-warm the database schema so we isolate and measure the concurrency
    // of the bootstrap steps rather than one-time SQLite table creation overhead.
    await db.customSelect('SELECT 1').get();

    final stopwatch = Stopwatch()..start();
    final result = await runStartupBootstrap(
      settingsRepo: settingsRepo,
      registerHomeWidgetCallback: () async {
        homeWidgetStarted = DateTime.now();
        await Future.delayed(stepDelay);
        homeWidgetFinished = DateTime.now();
      },
      resolveTimezone: () async {
        timezoneStarted = DateTime.now();
        await Future.delayed(stepDelay);
        timezoneFinished = DateTime.now();
        return 'America/Edmonton';
      },
    );
    stopwatch.stop();

    // 1. Verify typed return values are correctly populated from bootstrap steps
    expect(result.tzId, equals('America/Edmonton'));
    expect(result.deviceId, isNotEmpty);
    expect(result.dayStartOffset, equals(240));

    // 2. Structural concurrency check: both async steps must be in-flight concurrently
    // (i.e. the second step starts before the first step finishes, and vice-versa)
    expect(homeWidgetStarted, isNotNull);
    expect(homeWidgetFinished, isNotNull);
    expect(timezoneStarted, isNotNull);
    expect(timezoneFinished, isNotNull);

    expect(
      timezoneStarted!.isBefore(homeWidgetFinished!),
      isTrue,
      reason: 'resolveTimezone must start before registerHomeWidgetCallback completes (concurrent overlap)',
    );
    expect(
      homeWidgetStarted!.isBefore(timezoneFinished!),
      isTrue,
      reason: 'registerHomeWidgetCallback must start before resolveTimezone completes (concurrent overlap)',
    );

    // 3. Wall-clock timing check:
    // If run sequentially, two 100ms steps would take at least 200ms (+ DB queries).
    // When running concurrently via Future.wait, elapsed time should be well under
    // 75% of the sequential sum (200ms * 0.75 = 150ms).
    final sequentialSumMs = stepDelay.inMilliseconds * 2;
    expect(
      stopwatch.elapsedMilliseconds,
      lessThan((sequentialSumMs * 0.75).round()),
      reason: 'Elapsed time (${stopwatch.elapsedMilliseconds}ms) should be noticeably less '
          'than 75% of sequential sum (${sequentialSumMs}ms)',
    );

    await db.close();
  });
}

