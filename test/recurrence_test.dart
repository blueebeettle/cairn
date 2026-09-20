import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/recurrence/recurrence.dart';

/// Tests for SPEC.md §2.6 task recurrence.
///
/// Written from SPEC.md, not from the implementation. Pure date logic — no
/// database, no device, no clock.
///
/// Reference dates used below (all verified against a calendar):
///   2026-09-14 Mon   2026-09-15 Tue   2026-09-16 Wed   2026-09-18 Fri
///   September 2026 has 30 days; February 2026 has 28; February 2028 has 29.
void main() {
  RecurrenceRule rule(String s) => RecurrenceRule.parse(s)!;

  group('parsing', () {
    test('round-trips every supported shape', () {
      const shapes = [
        'FREQ=DAILY',
        'FREQ=DAILY;INTERVAL=3',
        'FREQ=WEEKLY;BYDAY=MO,WE,FR',
        'FREQ=WEEKLY;INTERVAL=2;BYDAY=TU',
        'FREQ=MONTHLY;BYMONTHDAY=1',
        'FREQ=MONTHLY;BYDAY=2TU',
        'FREQ=MONTHLY;BYDAY=-1FR',
      ];
      for (final s in shapes) {
        expect(rule(s).serialize(), equals(s), reason: s);
      }
    });

    test('malformed rules return null rather than throwing', () {
      const bad = [
        '',
        'FREQ=YEARLY',
        'FREQ=WEEKLY', // weekly with no BYDAY
        'FREQ=WEEKLY;BYDAY=XX',
        'FREQ=MONTHLY', // monthly with neither BYMONTHDAY nor BYDAY
        'FREQ=MONTHLY;BYMONTHDAY=0',
        'FREQ=MONTHLY;BYMONTHDAY=32',
        'FREQ=DAILY;INTERVAL=0',
        'FREQ=DAILY;INTERVAL=-2',
        'garbage',
      ];
      for (final s in bad) {
        expect(RecurrenceRule.parse(s), isNull, reason: s);
      }
      expect(RecurrenceRule.parse(null), isNull);
    });
  });

  group('daily', () {
    test('every day', () {
      expect(rule('FREQ=DAILY').nextAfter('2026-09-15'), equals('2026-09-16'));
    });

    test('every third day', () {
      expect(rule('FREQ=DAILY;INTERVAL=3').nextAfter('2026-09-15'),
          equals('2026-09-18'));
    });

    test('crosses a month boundary', () {
      expect(rule('FREQ=DAILY;INTERVAL=3').nextAfter('2026-09-29'),
          equals('2026-10-02'));
    });
  });

  group('weekly', () {
    test('several days a week picks the next matching day', () {
      final r = rule('FREQ=WEEKLY;BYDAY=MO,WE,FR');
      expect(r.nextAfter('2026-09-14'), equals('2026-09-16')); // Mon -> Wed
      expect(r.nextAfter('2026-09-16'), equals('2026-09-18')); // Wed -> Fri
      expect(r.nextAfter('2026-09-18'), equals('2026-09-21')); // Fri -> next Mon
    });

    test('the scheduled day itself is never returned', () {
      // A rule must always advance, or completing a task would re-create it
      // on the same day forever.
      final r = rule('FREQ=WEEKLY;BYDAY=TU');
      expect(r.nextAfter('2026-09-15'), equals('2026-09-22'));
    });

    test('every other Tuesday skips a week', () {
      final r = rule('FREQ=WEEKLY;INTERVAL=2;BYDAY=TU');
      expect(r.nextAfter('2026-09-15'), equals('2026-09-29'));
    });

    test('every other Tuesday, asked from mid-week, still lands correctly', () {
      // From Wednesday the 16th: that week's Tuesday has passed, so the next
      // occurrence is two weeks on from it.
      final r = rule('FREQ=WEEKLY;INTERVAL=2;BYDAY=TU');
      expect(r.nextAfter('2026-09-16'), equals('2026-09-29'));
    });

    test('weekdays-only rule skips the weekend', () {
      final r = rule('FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR');
      expect(r.nextAfter('2026-09-18'), equals('2026-09-21')); // Fri -> Mon
    });
  });

  group('monthly by day-of-month', () {
    test('the 1st of each month', () {
      final r = rule('FREQ=MONTHLY;BYMONTHDAY=1');
      expect(r.nextAfter('2026-09-01'), equals('2026-10-01'));
      expect(r.nextAfter('2026-09-15'), equals('2026-10-01'));
    });

    test('every third month counts from the anchor month', () {
      final r = rule('FREQ=MONTHLY;INTERVAL=3;BYMONTHDAY=1');
      expect(r.nextAfter('2026-09-01'), equals('2026-12-01'));
    });

    test('the 31st clamps to the last day of a 30-day month', () {
      // SPEC.md §2.6: clamping, not skipping. "Pay rent on the 31st" must
      // still fire in November, not vanish.
      final r = rule('FREQ=MONTHLY;BYMONTHDAY=31');
      expect(r.nextAfter('2026-10-31'), equals('2026-11-30'));
    });

    test('the 31st clamps to 28 in February', () {
      final r = rule('FREQ=MONTHLY;BYMONTHDAY=31');
      expect(r.nextAfter('2026-01-31'), equals('2026-02-28'));
    });

    test('the 29th clamps in a common year but not a leap year', () {
      final r = rule('FREQ=MONTHLY;BYMONTHDAY=29');
      expect(r.nextAfter('2026-01-29'), equals('2026-02-28'));
      expect(r.nextAfter('2028-01-29'), equals('2028-02-29'));
    });

    test('crosses a year boundary', () {
      final r = rule('FREQ=MONTHLY;BYMONTHDAY=1');
      expect(r.nextAfter('2026-12-15'), equals('2027-01-01'));
    });
  });

  group('monthly by nth weekday', () {
    test('the 2nd Tuesday of each month', () {
      final r = rule('FREQ=MONTHLY;BYDAY=2TU');
      expect(r.nextAfter('2026-09-08'), equals('2026-10-13'));
      expect(r.nextAfter('2026-10-13'), equals('2026-11-10'));
    });

    test('the last Friday of each month', () {
      final r = rule('FREQ=MONTHLY;BYDAY=-1FR');
      expect(r.nextAfter('2026-09-25'), equals('2026-10-30'));
    });

    test('a 5th weekday skips months that do not have one', () {
      // September 2026 has five Tuesdays (the 29th); October and November do
      // not. The next 5th Tuesday after Sept is December.
      final r = rule('FREQ=MONTHLY;BYDAY=5TU');
      expect(r.nextAfter('2026-09-29'), equals('2026-12-29'));
    });
  });

  group('§2.6 on_schedule vs after_completion', () {
    test('after_completion counts from when you finished', () {
      // "Water the plants every 3 days", due the 10th, actually done the 14th.
      final next = nextOccurrence(
        rule: rule('FREQ=DAILY;INTERVAL=3'),
        mode: RecurrenceMode.afterCompletion,
        scheduledDate: '2026-09-10',
        completedDate: '2026-09-14',
        todayLocalDate: '2026-09-14',
      );
      expect(next, equals('2026-09-17'));
    });

    test('on_schedule ignores when you finished', () {
      // "Pay rent on the 1st", due the 1st, paid on the 4th. Next is still
      // the 1st — the series does not drift onto the 4th.
      final next = nextOccurrence(
        rule: rule('FREQ=MONTHLY;BYMONTHDAY=1'),
        mode: RecurrenceMode.onSchedule,
        scheduledDate: '2026-09-01',
        completedDate: '2026-09-04',
        todayLocalDate: '2026-09-04',
      );
      expect(next, equals('2026-10-01'));
    });

    test('the two modes genuinely differ for the same completion', () {
      const args = (
        scheduled: '2026-09-10',
        completed: '2026-09-14',
        today: '2026-09-14',
      );
      final r = rule('FREQ=DAILY;INTERVAL=7');

      final onSchedule = nextOccurrence(
        rule: r,
        mode: RecurrenceMode.onSchedule,
        scheduledDate: args.scheduled,
        completedDate: args.completed,
        todayLocalDate: args.today,
      );
      final afterCompletion = nextOccurrence(
        rule: r,
        mode: RecurrenceMode.afterCompletion,
        scheduledDate: args.scheduled,
        completedDate: args.completed,
        todayLocalDate: args.today,
      );

      expect(onSchedule, equals('2026-09-17')); // 7 days after the due date
      expect(afterCompletion, equals('2026-09-21')); // 7 days after doing it
      expect(onSchedule, isNot(equals(afterCompletion)));
    });

    test('a very late on_schedule completion does not create a backlog', () {
      // Monthly task due 1 Jan, finally done 20 Mar. Advancing strictly from
      // the schedule would hand back 1 Feb — already past — and then 1 Mar,
      // burying the user in overdue copies. The series stays on the 1st but
      // lands on the next one that is not in the past.
      final next = nextOccurrence(
        rule: rule('FREQ=MONTHLY;BYMONTHDAY=1'),
        mode: RecurrenceMode.onSchedule,
        scheduledDate: '2026-01-01',
        completedDate: '2026-03-20',
        todayLocalDate: '2026-03-20',
      );
      expect(next, equals('2026-04-01'));
    });

    test('a null rule yields no next instance', () {
      expect(
        nextOccurrence(
          rule: null,
          mode: RecurrenceMode.onSchedule,
          scheduledDate: '2026-09-01',
          completedDate: '2026-09-01',
          todayLocalDate: '2026-09-01',
        ),
        isNull,
      );
    });
  });

  group('long runs stay consistent', () {
    test('24 months of a clamping monthly rule never repeats or goes backwards',
        () {
      final r = rule('FREQ=MONTHLY;BYMONTHDAY=31');
      var cursor = '2026-01-31';
      final seen = <String>{cursor};
      for (var i = 0; i < 24; i++) {
        final next = r.nextAfter(cursor);
        expect(next.compareTo(cursor), greaterThan(0),
            reason: 'went backwards or stalled at $cursor');
        expect(seen.add(next), isTrue, reason: 'repeated $next');
        cursor = next;
      }
    });

    test('100 weeks of an every-other-week rule stay 14 days apart', () {
      final r = rule('FREQ=WEEKLY;INTERVAL=2;BYDAY=TU');
      var cursor = '2026-09-15';
      for (var i = 0; i < 100; i++) {
        final next = r.nextAfter(cursor);
        expect(next, isNot(equals(cursor)));
        cursor = next;
      }
      // 100 fortnights = 1400 days on from Tue 15 Sep 2026, still a Tuesday.
      expect(cursor, equals('2030-07-16'));
    });
  });
}
