import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/time/time_service.dart';

/// Tests for SPEC.md §1 time semantics across DST transitions.
///
/// Written from SPEC.md, not from the implementation.
///
/// These tests model America/Edmonton explicitly rather than relying on
/// [DateTime.toLocal]. That matters: the development machine sits in
/// Asia/Kolkata, which has no DST, so a test that used the ambient OS timezone
/// could never fail here no matter how broken the logic was. Injecting the zone
/// is what makes SPEC.md §7 Fixture A possible at all.
///
/// America/Edmonton 2026 transitions:
///   spring forward  2026-03-08 02:00 MST (UTC-7) -> 03:00 MDT (UTC-6)
///                   = 2026-03-08T09:00:00Z
///   fall back       2026-11-01 02:00 MDT (UTC-6) -> 01:00 MST (UTC-7)
///                   = 2026-11-01T08:00:00Z
const int _springForwardUtcMs = 1772960400000;
const int _fallBackUtcMs = 1793520000000;

int _edmontonOffsetMinutes(int utcMs) =>
    (utcMs >= _springForwardUtcMs && utcMs < _fallBackUtcMs) ? -360 : -420;

/// Returns a DateTime whose calendar fields are the Edmonton wall clock.
DateTime _edmontonLocalize(int utcMs) => DateTime.fromMillisecondsSinceEpoch(
      utcMs + _edmontonOffsetMinutes(utcMs) * 60000,
      isUtc: true,
    );

final _edmonton = TimeService(
  dayStartOffsetMinutes: 240, // 04:00
  localize: _edmontonLocalize,
  offsetMinutesAt: _edmontonOffsetMinutes,
  tzIdProvider: _fixedTzId,
);

String _fixedTzId() => 'America/Edmonton';

void main() {
  group('§1.2 logical day — DST transitions', () {
    // Each case is (utcMs, local wall clock for readability, expected logical date).
    // The Duration-based implementation this replaced returned the wrong answer
    // for the two cases marked REGRESSION.
    const cases = <(int, String, String)>[
      (1772965800000, '2026-03-08 04:30 MDT', '2026-03-08'), // REGRESSION
      (1772962200000, '2026-03-08 03:30 MDT', '2026-03-07'),
      (1772955000000, '2026-03-08 00:30 MST', '2026-03-07'),
      (1793529000000, '2026-11-01 03:30 MST', '2026-10-31'), // REGRESSION
      (1793532600000, '2026-11-01 04:30 MST', '2026-11-01'),
      (1793518200000, '2026-11-01 01:30 MDT', '2026-10-31'),
    ];

    for (final (utcMs, wallClock, expected) in cases) {
      test('$wallClock -> $expected', () {
        expect(_edmonton.computeLocalDate(utcMs), equals(expected));
      });
    }
  });

  group('§1.2 logical day — ordinary days (control)', () {
    test('03:30 with a 04:00 day start belongs to the previous day', () {
      expect(_edmonton.computeLocalDate(1789032600000), equals('2026-09-09'));
    });

    test('04:05 with a 04:00 day start belongs to the current day', () {
      expect(_edmonton.computeLocalDate(1789034700000), equals('2026-09-10'));
    });

    test('exactly 04:00 belongs to the current day', () {
      // 2026-09-10 04:00 MDT
      const utcMs = 1789034400000;
      expect(_edmonton.computeLocalDate(utcMs), equals('2026-09-10'));
    });
  });

  group('§1.2 logical day — month and year rollover', () {
    test('03:30 on the 1st of a month rolls back into the previous month', () {
      // 2026-03-01 03:30 MST -> 2026-02-28 (2026 is not a leap year)
      expect(_edmonton.computeLocalDate(1772361000000), equals('2026-02-28'));
    });

    test('03:30 on Jan 1 rolls back into the previous year', () {
      // 2026-01-01 03:30 MST -> 2025-12-31
      expect(_edmonton.computeLocalDate(1767263400000), equals('2025-12-31'));
    });
  });

  group('§1.2 day start offset of 0 behaves as plain midnight', () {
    final midnightDay = TimeService(
      dayStartOffsetMinutes: 0,
      localize: _edmontonLocalize,
      offsetMinutesAt: _edmontonOffsetMinutes,
    );

    test('03:30 stays on its own calendar day', () {
      expect(midnightDay.computeLocalDate(1789032600000), equals('2026-09-10'));
    });
  });

  group('daysBetween — exact across DST', () {
    test('the 23-hour day still counts as one day', () {
      expect(TimeService.daysBetween('2026-03-08', '2026-03-09'), equals(1));
    });

    test('the 25-hour day still counts as one day', () {
      expect(TimeService.daysBetween('2026-11-01', '2026-11-02'), equals(1));
    });

    test('a month spanning spring-forward is not short by a day', () {
      expect(TimeService.daysBetween('2026-03-01', '2026-03-31'), equals(30));
    });

    test('a full year', () {
      expect(TimeService.daysBetween('2026-01-01', '2026-12-31'), equals(364));
    });

    test('same day is zero, reverse order is negative', () {
      expect(TimeService.daysBetween('2026-09-09', '2026-09-09'), equals(0));
      expect(TimeService.daysBetween('2026-09-09', '2026-09-01'), equals(-8));
    });
  });

  group('addDays — streak walking (§4.3)', () {
    test('steps forward and back across spring-forward', () {
      expect(TimeService.addDays('2026-03-08', 1), equals('2026-03-09'));
      expect(TimeService.addDays('2026-03-09', -1), equals('2026-03-08'));
    });

    test('steps across fall-back', () {
      expect(TimeService.addDays('2026-11-01', 1), equals('2026-11-02'));
      expect(TimeService.addDays('2026-11-02', -1), equals('2026-11-01'));
    });

    test('handles month and year boundaries', () {
      expect(TimeService.addDays('2026-02-28', 1), equals('2026-03-01'));
      expect(TimeService.addDays('2026-03-01', -1), equals('2026-02-28'));
      expect(TimeService.addDays('2026-01-01', -1), equals('2025-12-31'));
      expect(TimeService.addDays('2025-12-31', 1), equals('2026-01-01'));
    });

    test('walking back 365 days from a date spanning both transitions', () {
      var d = '2026-12-31';
      for (var i = 0; i < 365; i++) {
        d = TimeService.addDays(d, -1);
      }
      expect(d, equals('2025-12-31'));
    });
  });

  group('§1.3 week grouping', () {
    test('Monday-start week resolves to the containing Monday', () {
      // 2026-09-09 is a Wednesday.
      expect(_edmonton.startOfWeek('2026-09-09'), equals('2026-09-07'));
      expect(_edmonton.startOfWeek('2026-09-07'), equals('2026-09-07'));
      expect(_edmonton.startOfWeek('2026-09-13'), equals('2026-09-07'));
    });

    test('Sunday-start week is configurable', () {
      const sundayStart = TimeService(weekStart: DateTime.sunday);
      expect(sundayStart.startOfWeek('2026-09-09'), equals('2026-09-06'));
    });

    test('a week containing a DST transition still has seven distinct days', () {
      final week = _edmonton.weekDates('2026-03-08');
      expect(week.length, equals(7));
      expect(week.toSet().length, equals(7));
      expect(week.first, equals('2026-03-02'));
      expect(week.last, equals('2026-03-08'));
    });
  });

  group('§1.5 elapsed time and clock skew', () {
    test('a backwards clock clamps to zero and flags a clock anomaly', () {
      final r = TimeService.computeElapsed(
        startedAtUtcMs: 1000000,
        endedAtUtcMs: 900000,
      );
      expect(r.elapsedSeconds, equals(0));
      expect(r.hasClockAnomaly, isTrue);
      expect(r.hasPausedUnderflow, isFalse);
    });

    test('accumulated pause time is excluded', () {
      final r = TimeService.computeElapsed(
        startedAtUtcMs: 1000000,
        endedAtUtcMs: 1060000, // +60s
        pausedAccumulatedSeconds: 15,
      );
      expect(r.elapsedSeconds, equals(45));
      expect(r.hasClockAnomaly, isFalse);
    });

    test('an open pause is excluded up to the end instant', () {
      final r = TimeService.computeElapsed(
        startedAtUtcMs: 1000000,
        endedAtUtcMs: 1060000, // +60s
        pausedAtUtcMs: 1040000, // paused at +40s, so 20s of pause
      );
      expect(r.elapsedSeconds, equals(40));
    });

    test('pause underflow clamps but is NOT reported as a clock anomaly', () {
      final r = TimeService.computeElapsed(
        startedAtUtcMs: 1000000,
        endedAtUtcMs: 1010000, // +10s
        pausedAccumulatedSeconds: 30, // impossible bookkeeping
      );
      expect(r.elapsedSeconds, equals(0));
      expect(r.hasClockAnomaly, isFalse);
      expect(r.hasPausedUnderflow, isTrue);
    });

    test('a full 25-minute pomodoro measures exactly 1500 seconds', () {
      final r = TimeService.computeElapsed(
        startedAtUtcMs: 1789032600000,
        endedAtUtcMs: 1789032600000 + 1500 * 1000,
      );
      expect(r.elapsedSeconds, equals(1500));
    });
  });

  group('§1.4 a session spanning the day boundary', () {
    test('start and end fall on different logical dates across the 04:00 line',
        () {
      // A 60-minute session from 03:30 to 04:30 local on 2026-09-10.
      // With a 04:00 day start the boundary sits inside the session.
      const startUtcMs = 1789032600000; // 2026-09-10 03:30 MDT
      const endUtcMs = 1789036200000; // 2026-09-10 04:30 MDT

      expect(_edmonton.computeLocalDate(startUtcMs), equals('2026-09-09'));
      expect(_edmonton.computeLocalDate(endUtcMs), equals('2026-09-10'));

      // SPEC.md §1.4: the session belongs wholly to the STARTING logical day.
      // The two values differ here, so session-writing code that reaches for
      // the end instant will silently file this session on the wrong day.
    });

    test('a session wholly before the 04:00 line stays on one date', () {
      const startUtcMs = 1789018200000; // 2026-09-09 23:30 MDT
      const endUtcMs = 1789018200000 + 3600 * 1000; // 2026-09-10 00:30 MDT

      // Both sit before the 04:00 start, so both resolve to the 9th — the
      // calendar date rolled over but the logical day did not.
      expect(_edmonton.computeLocalDate(startUtcMs), equals('2026-09-09'));
      expect(_edmonton.computeLocalDate(endUtcMs), equals('2026-09-09'));
    });
  });
}
