import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/time/time_service.dart';
import 'package:habit_tracker/features/tasks/domain/task_parser.dart';

void main() {
  late TimeService timeService;
  late TaskParser parser;

  setUp(() {
    // Inject deterministic fixed time for testing
    timeService = TimeService(
      dayStartOffsetMinutes: 240, // 04:00 AM
      localize: (utcMs) => DateTime.fromMillisecondsSinceEpoch(utcMs, isUtc: true),
      offsetMinutesAt: (_) => 0,
      tzIdProvider: () => 'UTC',
      nowProvider: () => DateTime.utc(2026, 9, 13, 12, 0).millisecondsSinceEpoch,
    );
    parser = TaskParser(timeService: timeService);
  });

  group('TaskParser — SPEC.md §2.4 Natural Language Quick Capture', () {
    test('parses full sample: "submit report fri 5pm !p1 #work"', () {
      final result = parser.parse('submit report fri 5pm !p1 #work');

      expect(result.title, equals('submit report'));
      expect(result.priority, equals(1));
      expect(result.tags, equals(['work']));
      expect(result.dueIsAllDay, isFalse);
      expect(result.dueAtUtcMs, isNotNull);

      // In 2026-09-13 (Sunday), next Friday is 2026-09-18 at 17:00 (5pm)
      final dueDt = DateTime.fromMillisecondsSinceEpoch(result.dueAtUtcMs!, isUtc: true);
      expect(dueDt.year, equals(2026));
      expect(dueDt.month, equals(9));
      expect(dueDt.day, equals(18));
      expect(dueDt.hour, equals(17));
      expect(dueDt.minute, equals(0));
    });

    test('parses priority tokens !p1 through !p4 with case insensitivity', () {
      expect(parser.parse('Task one !p1').priority, equals(1));
      expect(parser.parse('Task two !P2').priority, equals(2));
      expect(parser.parse('Task three !p3').priority, equals(3));
      expect(parser.parse('Task four !P4').priority, equals(4));
      // Default priority is 4
      expect(parser.parse('Plain task without priority').priority, equals(4));
    });

    test('parses multiple tags anywhere in input', () {
      final result = parser.parse('buy milk #groceries #errands !p3');
      expect(result.title, equals('buy milk'));
      expect(result.tags, equals(['groceries', 'errands']));
      expect(result.priority, equals(3));
    });

    test('parses pomodoro estimate: ~2p or 3p', () {
      final r1 = parser.parse('write chapter ~2p');
      expect(r1.title, equals('write chapter'));
      expect(r1.estimatePomodoros, equals(2));

      final r2 = parser.parse('debug memory leak 4p !p1');
      expect(r2.title, equals('debug memory leak'));
      expect(r2.estimatePomodoros, equals(4));
      expect(r2.priority, equals(1));
    });

    test('parses "today" as all-day due date', () {
      final result = parser.parse('call accountant today');
      expect(result.title, equals('call accountant'));
      expect(result.dueIsAllDay, isTrue);
      expect(result.dueAtUtcMs, isNotNull);

      final dt = DateTime.fromMillisecondsSinceEpoch(result.dueAtUtcMs!, isUtc: true);
      expect(dt.year, equals(2026));
      expect(dt.month, equals(9));
      expect(dt.day, equals(13));
    });

    test('parses "tomorrow" as all-day due date', () {
      final result = parser.parse('review pull request tomorrow !p2');
      expect(result.title, equals('review pull request'));
      expect(result.dueIsAllDay, isTrue);
      expect(result.priority, equals(2));

      final dt = DateTime.fromMillisecondsSinceEpoch(result.dueAtUtcMs!, isUtc: true);
      expect(dt.year, equals(2026));
      expect(dt.month, equals(9));
      expect(dt.day, equals(14)); // 2026-09-14
    });

    test('parses weekday with specific time: "wed 9:30am"', () {
      final result = parser.parse('team standup wed 9:30am');
      expect(result.title, equals('team standup'));
      expect(result.dueIsAllDay, isFalse);

      final dt = DateTime.fromMillisecondsSinceEpoch(result.dueAtUtcMs!, isUtc: true);
      expect(dt.year, equals(2026));
      expect(dt.month, equals(9));
      expect(dt.day, equals(16)); // Wednesday is Sep 16
      expect(dt.hour, equals(9));
      expect(dt.minute, equals(30));
    });

    test('parses 24-hour time and keywords "noon" and "midnight"', () {
      final r1 = parser.parse('deploy hotfix today 14:45');
      final dt1 = DateTime.fromMillisecondsSinceEpoch(r1.dueAtUtcMs!, isUtc: true);
      expect(dt1.hour, equals(14));
      expect(dt1.minute, equals(45));

      final r2 = parser.parse('lunch sync tomorrow noon');
      final dt2 = DateTime.fromMillisecondsSinceEpoch(r2.dueAtUtcMs!, isUtc: true);
      expect(dt2.hour, equals(12));
      expect(dt2.minute, equals(0));

      final r3 = parser.parse('backup run tomorrow midnight');
      final dt3 = DateTime.fromMillisecondsSinceEpoch(r3.dueAtUtcMs!, isUtc: true);
      expect(dt3.hour, equals(0));
      expect(dt3.minute, equals(0));
    });

    test('parses explicit month and day: "sep 25 3pm"', () {
      final result = parser.parse('dentist appointment sep 25 3pm');
      expect(result.title, equals('dentist appointment'));
      expect(result.dueIsAllDay, isFalse);

      final dt = DateTime.fromMillisecondsSinceEpoch(result.dueAtUtcMs!, isUtc: true);
      expect(dt.year, equals(2026));
      expect(dt.month, equals(9));
      expect(dt.day, equals(25));
      expect(dt.hour, equals(15));
      expect(dt.minute, equals(0));
    });

    // "Today" in this suite is 2026-09-13.
    group('month/day year rollover', () {
      DateTime dueOf(String input) => DateTime.fromMillisecondsSinceEpoch(
            parser.parse(input).dueAtUtcMs!,
            isUtc: true,
          );

      test('a date still ahead this year stays in this year', () {
        final dt = dueOf('file the return dec 1');
        expect(dt.year, equals(2026));
        expect(dt.month, equals(12));
        expect(dt.day, equals(1));
      });

      test('a date already gone by rolls into next year', () {
        // January is nine months behind "today"; naming it means next
        // January, the same way naming a weekday means next week.
        final dt = dueOf('renew the licence jan 5');
        expect(dt.year, equals(2027));
        expect(dt.month, equals(1));
        expect(dt.day, equals(5));
      });

      test('today itself is today, not a year away', () {
        final dt = dueOf('call the bank sep 13');
        expect(dt.year, equals(2026));
        expect(dt.month, equals(9));
        expect(dt.day, equals(13));
      });

      test('yesterday rolls forward a year rather than landing in the past',
          () {
        final dt = dueOf('post the form sep 12');
        expect(dt.year, equals(2027));
        expect(dt.month, equals(9));
        expect(dt.day, equals(12));
      });

      test('tomorrow stays put', () {
        final dt = dueOf('collect the parcel sep 14');
        expect(dt.year, equals(2026));
        expect(dt.month, equals(9));
        expect(dt.day, equals(14));
      });

      test('a resolved month/day date is never in the past', () {
        const today = '2026-09-13';
        for (final month in [
          'jan', 'feb', 'mar', 'apr', 'may', 'jun',
          'jul', 'aug', 'sep', 'oct', 'nov', 'dec',
        ]) {
          final dt = dueOf('thing $month 15');
          final iso = TimeService.formatIsoDate(dt.year, dt.month, dt.day);
          expect(iso.compareTo(today) >= 0, isTrue,
              reason: '$month 15 resolved to $iso, which is behind today');
        }
      });

      test('feb 29 in a non-leap year behaves as it did before the rollover',
          () {
        // 2027 is not a leap year and 2028 is. Whatever `formatIsoDate` and
        // the day-validation already did with an impossible date, the
        // rollover must not make it worse — this pins the current behaviour
        // so a future change to it is a deliberate one.
        final result = parser.parse('leap day feb 29');
        expect(result.dueAtUtcMs, isNotNull);
        final dt = DateTime.fromMillisecondsSinceEpoch(
          result.dueAtUtcMs!,
          isUtc: true,
        );
        // Feb 2027 has 28 days, so Dart normalises 02-29 to 03-01. The point
        // is that it resolves forward of today and does not throw.
        expect(dt.isAfter(DateTime.utc(2026, 9, 13)), isTrue);
      });
    });

    test('ambiguity rule: keeps unparseable text in title rather than guessing', () {
      // "read Friday Night Lights" should NOT strip Friday
      final result = parser.parse('read friday night lights !p3');
      expect(result.title, equals('read friday night lights'));
      expect(result.priority, equals(3));
      // No due date should be attached because "friday night lights" was not a valid trailing date/time
      expect(result.dueAtUtcMs, isNull);
    });

    test('handles empty or whitespace-only input gracefully', () {
      final result = parser.parse('   ');
      expect(result.title, isEmpty);
      expect(result.dueAtUtcMs, isNull);
      expect(result.tags, isEmpty);
    });
  });
}
