import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/time/time_service.dart';

void main() {
  group('TimeService - SPEC.md §1 Time Semantics', () {
    const timeService = TimeService(dayStartOffsetMinutes: 240); // 04:00 AM

    test('formatIsoDate formats correctly with zero padding', () {
      expect(TimeService.formatIsoDate(2026, 9, 9), equals('2026-09-09'));
      expect(TimeService.formatIsoDate(2026, 1, 5), equals('2026-01-05'));
    });

    test('parseLocalDate parses YYYY-MM-DD correctly', () {
      final dt = TimeService.parseLocalDate('2026-09-09');
      expect(dt.year, equals(2026));
      expect(dt.month, equals(9));
      expect(dt.day, equals(9));
    });

    test('daysBetween computes difference between logical dates', () {
      expect(TimeService.daysBetween('2026-09-01', '2026-09-09'), equals(8));
      expect(TimeService.daysBetween('2026-09-09', '2026-09-09'), equals(0));
    });

    test('Logical day: 03:30 AM with 04:00 offset belongs to previous day (§1.2)', () {
      // Create a local DateTime at 03:30 on Sep 10, 2026
      final localDt = DateTime(2026, 9, 10, 3, 30);
      final utcMs = localDt.toUtc().millisecondsSinceEpoch;

      final logicalDate = timeService.computeLocalDate(utcMs);

      // Since 03:30 is before 04:00 (day_start_offset 240 min),
      // it counts towards the PREVIOUS day: 2026-09-09!
      expect(logicalDate, equals('2026-09-09'));
    });

    test('Logical day: 04:05 AM with 04:00 offset belongs to current day (§1.2)', () {
      // Create a local DateTime at 04:05 on Sep 10, 2026
      final localDt = DateTime(2026, 9, 10, 4, 5);
      final utcMs = localDt.toUtc().millisecondsSinceEpoch;

      final logicalDate = timeService.computeLocalDate(utcMs);

      // Since 04:05 is after 04:00 (day_start_offset 240 min),
      // it counts towards the current day: 2026-09-10!
      expect(logicalDate, equals('2026-09-10'));
    });

    test('Clock skew: now < started_at clamps to 0 and flags anomaly (§1.5)', () {
      const startedAt = 1000000;
      const endedAt = 900000; // Device clock moved backwards

      final result = TimeService.computeElapsed(
        startedAtUtcMs: startedAt,
        endedAtUtcMs: endedAt,
      );

      expect(result.elapsedSeconds, equals(0));
      expect(result.hasClockAnomaly, isTrue);
    });

    test('Elapsed duration excludes paused accumulated seconds', () {
      const startedAt = 1000000; // ms
      const endedAt = 1060000; // +60 seconds
      const pausedSeconds = 15;

      final result = TimeService.computeElapsed(
        startedAtUtcMs: startedAt,
        endedAtUtcMs: endedAt,
        pausedAccumulatedSeconds: pausedSeconds,
      );

      expect(result.elapsedSeconds, equals(45));
      expect(result.hasClockAnomaly, isFalse);
    });
  });
}
