import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/constants/event_types.dart';
import 'package:habit_tracker/core/stats/statistics.dart';
import 'package:habit_tracker/core/time/time_service.dart';
import 'package:habit_tracker/data/database/app_database.dart';
import 'package:habit_tracker/data/repositories/analytics_repository.dart';
import 'package:habit_tracker/data/repositories/settings_repository.dart';

void main() {
  late AppDatabase db;
  late TimeService time;
  late SettingsRepository settings;
  late AnalyticsRepository analytics;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    time = const TimeService(dayStartOffsetMinutes: 0);
    settings = SettingsRepository(db: db);
    analytics = AnalyticsRepository(
      db: db,
      timeService: time,
      settings: settings,
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> insertSession({
    required String id,
    required String localDate,
    int minutes = 25,
  }) async {
    await db.into(db.focusSessions).insert(
      FocusSessionsCompanion.insert(
        id: id,
        mode: 'pomodoro',
        outcome: SessionOutcomes.completed,
        plannedDurationS: Value(minutes * 60),
        actualDurationS: Value(minutes * 60),
        startedAt: 1000,
        endedAt: 1000 + minutes * 60 * 1000,
        localDate: localDate,
        tzOffsetMin: 0,
        updatedAt: 1000,
        deviceId: 'test-device',
      ),
    );
  }

  group('heatmapThresholds() — provisional cache promotion and mid-week crossing', () {
    test(
      'provisional cache is not served as-is, promotes mid-week upon 14 non-zero days, and caches non-provisional',
      () async {
        const today = '2026-09-10'; // Thursday (week started 2026-09-07)

        // 1. Initial 5 distinct days of focus sessions (< 14 minimumNonZeroDays)
        for (var i = 1; i <= 5; i++) {
          await insertSession(
            id: 'session-$i',
            localDate: '2026-09-0$i',
            minutes: 25,
          );
        }

        final t1 = await analytics.heatmapThresholds(todayLocalDate: today);
        expect(t1.provisional, isTrue);
        expect(t1.nonZeroDayCount, 5);
        expect(t1.level1Max, HeatmapThresholds.fallback.level1Max);

        // Verify cache in settings store was written with provisional: true
        final cached1 = await settings.get(AnalyticsRepository.thresholdsCacheKey) as Map?;
        expect(cached1, isNotNull);
        expect(cached1!['provisional'], isTrue);

        // 2. Next read within the same week: recomputes, still provisional
        final t2 = await analytics.heatmapThresholds(todayLocalDate: today);
        expect(t2.provisional, isTrue);
        expect(t2.nonZeroDayCount, 5);

        // 3. User logs focus sessions across 10 more distinct days (total 15 non-zero days >= 14)
        for (var i = 11; i <= 20; i++) {
          await insertSession(
            id: 'session-$i',
            localDate: '2026-08-$i',
            minutes: 30,
          );
        }

        // Next read in the SAME week immediately promotes to non-provisional
        final t3 = await analytics.heatmapThresholds(todayLocalDate: today);
        expect(t3.provisional, isFalse);
        expect(t3.nonZeroDayCount, 15);

        // Cache now stores provisional == false
        final cached2 = await settings.get(AnalyticsRepository.thresholdsCacheKey) as Map?;
        expect(cached2, isNotNull);
        expect(cached2!['provisional'], isFalse);

        // 4. Once non-provisional, subsequent reads in the same week return the cached value
        // Mutate underlying data by adding another day's session
        await insertSession(
          id: 'session-extra',
          localDate: '2026-08-25',
          minutes: 60,
        );

        final t4 = await analytics.heatmapThresholds(todayLocalDate: today);
        // Returned value is still the cached one (15 nonZeroDayCount, not 16)
        expect(t4.provisional, isFalse);
        expect(t4.nonZeroDayCount, 15);
        expect(t4.level1Max, t3.level1Max);
        expect(t4.level2Max, t3.level2Max);

        // 5. forceRecompute: true bypasses cache and reflects the new data
        final t5 = await analytics.heatmapThresholds(
          todayLocalDate: today,
          forceRecompute: true,
        );
        expect(t5.provisional, isFalse);
        expect(t5.nonZeroDayCount, 16);
      },
    );

    test('forceRecompute: true bypasses provisional cache as well', () async {
      const today = '2026-09-10';
      await insertSession(id: 'session-1', localDate: '2026-09-01', minutes: 25);

      final t1 = await analytics.heatmapThresholds(
        todayLocalDate: today,
        forceRecompute: true,
      );
      expect(t1.provisional, isTrue);
      expect(t1.nonZeroDayCount, 1);
    });

    test('cached entry with stale week key is treated as invalid and recomputed', () async {
      const today = '2026-09-10'; // Week of 2026-09-07
      await insertSession(id: 's-1', localDate: '2026-09-01', minutes: 25);

      // Write stale week cache
      await settings.set(AnalyticsRepository.thresholdsCacheKey, {
        'week': '2026-08-31',
        'l1': 10,
        'l2': 20,
        'l3': 30,
        'l4': 40,
        'provisional': false,
        'n': 14,
      });

      final t = await analytics.heatmapThresholds(todayLocalDate: today);
      // Because week was stale, it recomputed based on current data (1 day -> provisional)
      expect(t.provisional, isTrue);
      expect(t.nonZeroDayCount, 1);
    });

    test('cached entry with malformed fields is treated as invalid and recomputed', () async {
      const today = '2026-09-10';
      await insertSession(id: 's-1', localDate: '2026-09-01', minutes: 25);

      // Write malformed cache (l1 is string instead of int)
      await settings.set(AnalyticsRepository.thresholdsCacheKey, {
        'week': '2026-09-07',
        'l1': 'not-an-int',
        'l2': 20,
        'l3': 30,
        'l4': 40,
        'provisional': false,
        'n': 14,
      });

      final t = await analytics.heatmapThresholds(todayLocalDate: today);
      expect(t.provisional, isTrue);
      expect(t.nonZeroDayCount, 1);
    });
  });
}
