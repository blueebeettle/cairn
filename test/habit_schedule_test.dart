import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/habits/habit_schedule.dart';
import 'package:habit_tracker/core/recurrence/recurrence.dart';

/// SPEC.md §10.2 — habit schedule matching.
///
/// Every expected value here was computed independently before the Dart was
/// written, so these assert real answers rather than whatever the
/// implementation happens to return.
void main() {
  RecurrenceRule rule(String raw) => RecurrenceRule.parse(raw)!;

  group('occursOn - daily', () {
    const anchor = '2026-09-01';
    final everyThird = rule('FREQ=DAILY;INTERVAL=3');

    test('matches every third day counting from the anchor', () {
      final hits = HabitSchedule.scheduledBetween(
        rule: everyThird,
        anchorDate: anchor,
        start: '2026-09-01',
        end: '2026-09-22',
      );
      expect(hits, [
        '2026-09-01',
        '2026-09-04',
        '2026-09-07',
        '2026-09-10',
        '2026-09-13',
        '2026-09-16',
        '2026-09-19',
        '2026-09-22',
      ]);
    });

    test('keeps its stride across a month boundary', () {
      final hits = HabitSchedule.scheduledBetween(
        rule: everyThird,
        anchorDate: anchor,
        start: '2026-09-25',
        end: '2026-10-07',
      );
      expect(hits, [
        '2026-09-25',
        '2026-09-28',
        '2026-10-01',
        '2026-10-04',
        '2026-10-07',
      ]);
    });

    test('is never scheduled before the anchor', () {
      expect(
        HabitSchedule.occursOn(
          rule: everyThird,
          anchorDate: anchor,
          localDate: '2026-08-29',
        ),
        isFalse,
        reason: 'a habit cannot be missed on a day it did not exist',
      );
    });

    test('off-stride days do not match', () {
      expect(
        HabitSchedule.occursOn(
            rule: everyThird, anchorDate: anchor, localDate: '2026-09-04'),
        isTrue,
      );
      expect(
        HabitSchedule.occursOn(
            rule: everyThird, anchorDate: anchor, localDate: '2026-09-05'),
        isFalse,
      );
    });
  });

  group('occursOn - weekly', () {
    test('Mon/Wed/Fri hits exactly those weekdays', () {
      final hits = HabitSchedule.scheduledBetween(
        rule: rule('FREQ=WEEKLY;BYDAY=MO,WE,FR'),
        anchorDate: '2026-08-31',
        start: '2026-08-31',
        end: '2026-09-18',
      );
      expect(hits.length, 9);
      expect(hits.first, '2026-08-31');
      expect(hits.last, '2026-09-18');
      expect(hits.contains('2026-09-01'), isFalse, reason: 'that is a Tuesday');
    });

    test('every other Tuesday leaves 14-day gaps', () {
      final hits = HabitSchedule.scheduledBetween(
        rule: rule('FREQ=WEEKLY;INTERVAL=2;BYDAY=TU'),
        anchorDate: '2026-09-01',
        start: '2026-09-01',
        end: '2026-11-01',
      );
      expect(hits, [
        '2026-09-01',
        '2026-09-15',
        '2026-09-29',
        '2026-10-13',
        '2026-10-27',
      ]);
    });
  });

  group('occursOn - monthly', () {
    test('the 31st clamps into short months instead of vanishing', () {
      final hits = HabitSchedule.scheduledBetween(
        rule: rule('FREQ=MONTHLY;BYMONTHDAY=31'),
        anchorDate: '2026-01-31',
        start: '2026-01-01',
        end: '2026-12-31',
      );
      expect(hits.length, 12, reason: 'every month must be represented');
      expect(hits[1], '2026-02-28');
      expect(hits[3], '2026-04-30');
      expect(hits.last, '2026-12-31');
    });

    test('the 31st lands on the 29th in a leap February', () {
      final hits = HabitSchedule.scheduledBetween(
        rule: rule('FREQ=MONTHLY;BYMONTHDAY=31'),
        anchorDate: '2028-01-31',
        start: '2028-02-01',
        end: '2028-02-29',
      );
      expect(hits, ['2028-02-29']);
    });

    test('nth weekday skips months that have no such day', () {
      final hits = HabitSchedule.scheduledBetween(
        rule: rule('FREQ=MONTHLY;BYDAY=5TU'),
        anchorDate: '2026-01-01',
        start: '2026-01-01',
        end: '2026-12-31',
      );
      expect(hits.length, lessThan(12),
          reason: 'not every month has a 5th Tuesday');
      for (final date in hits) {
        expect(DateTime.parse(date).weekday, DateTime.tuesday);
      }
    });
  });

  group('navigation helpers', () {
    final mwf = rule('FREQ=WEEKLY;BYDAY=MO,WE,FR');

    test('previousScheduledDate steps over unscheduled days', () {
      expect(
        HabitSchedule.previousScheduledDate(
          rule: mwf,
          anchorDate: '2026-08-31',
          localDate: '2026-09-14', // a Monday
        ),
        '2026-09-11', // the Friday before
      );
    });

    test('previousScheduledDate stops at the anchor', () {
      expect(
        HabitSchedule.previousScheduledDate(
          rule: mwf,
          anchorDate: '2026-09-14',
          localDate: '2026-09-14',
        ),
        isNull,
      );
    });

    test('nextScheduledDate finds the following occurrence', () {
      expect(
        HabitSchedule.nextScheduledDate(
          rule: mwf,
          anchorDate: '2026-08-31',
          localDate: '2026-09-18', // a Friday
        ),
        '2026-09-21', // the following Monday
      );
    });
  });

  group('degenerate input', () {
    test('a null rule is never scheduled and yields no dates', () {
      expect(
        HabitSchedule.occursOn(
            rule: null, anchorDate: '2026-09-01', localDate: '2026-09-01'),
        isFalse,
      );
      expect(
        HabitSchedule.scheduledBetween(
            rule: null,
            anchorDate: '2026-09-01',
            start: '2026-09-01',
            end: '2026-09-30'),
        isEmpty,
      );
    });

    test('an inverted window returns empty rather than throwing', () {
      expect(
        HabitSchedule.scheduledBetween(
          rule: rule('FREQ=DAILY;INTERVAL=1'),
          anchorDate: '2026-09-01',
          start: '2026-09-30',
          end: '2026-09-01',
        ),
        isEmpty,
      );
    });
  });
}
