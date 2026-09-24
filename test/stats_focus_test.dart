import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/time/time_service.dart';
import 'package:habit_tracker/data/repositories/stats_repository.dart';

/// Tests for SPEC.md §4.1 (focus minutes) and §4.3 (streaks).
///
/// Written from SPEC.md, not from the implementation. The computation is pure,
/// so none of this needs a database or a device.
///
/// Maps are {logical date: total completed focus SECONDS}.
void main() {
  const goal = 25; // SPEC.md §4.3 default daily goal, in minutes

  int mins(int m) => m * 60;

  group('§4.1 focus minutes', () {
    test('sums seconds before converting, not after', () {
      // Three sessions of 50 seconds each on one day. Converting per session
      // would floor each to 0 minutes and report 0. Summing first gives 150s.
      final byDate = {'2026-09-10': 50 + 50 + 50};
      expect(StatsRepository.focusMinutesOn(byDate, '2026-09-10'), equals(2));
    });

    test('a day with no sessions is zero, not an error', () {
      expect(StatsRepository.focusMinutesOn({}, '2026-09-10'), equals(0));
    });

    test('a full pomodoro reads as exactly 25 minutes', () {
      expect(
        StatsRepository.focusMinutesOn({'2026-09-10': 1500}, '2026-09-10'),
        equals(25),
      );
    });
  });

  group('§4.3 current streak', () {
    test('today not yet met does NOT break the streak', () {
      // The critical rule. Yesterday and the day before were met; today has
      // only 10 minutes so far. The streak must still read 2, not 0.
      final byDate = {
        '2026-09-08': mins(30),
        '2026-09-09': mins(40),
        '2026-09-10': mins(10), // today, in progress
      };
      expect(
        StatsRepository.currentStreak(byDate, '2026-09-10', goal),
        equals(2),
      );
    });

    test('today met counts toward the streak', () {
      final byDate = {
        '2026-09-08': mins(30),
        '2026-09-09': mins(40),
        '2026-09-10': mins(25),
      };
      expect(
        StatsRepository.currentStreak(byDate, '2026-09-10', goal),
        equals(3),
      );
    });

    test('exactly the goal counts as met', () {
      expect(
        StatsRepository.currentStreak({'2026-09-10': mins(25)}, '2026-09-10', goal),
        equals(1),
      );
    });

    test('one minute short does not count', () {
      expect(
        StatsRepository.currentStreak({'2026-09-10': mins(24)}, '2026-09-10', goal),
        equals(0),
      );
    });

    test('a gap ends the streak', () {
      final byDate = {
        '2026-09-06': mins(30),
        '2026-09-07': mins(30),
        // 2026-09-08 missed
        '2026-09-09': mins(30),
      };
      expect(
        StatsRepository.currentStreak(byDate, '2026-09-09', goal),
        equals(1),
      );
    });

    test('no history at all is zero', () {
      expect(StatsRepository.currentStreak({}, '2026-09-10', goal), equals(0));
    });

    test('yesterday missed and today not yet met is zero', () {
      final byDate = {'2026-09-08': mins(30), '2026-09-10': mins(5)};
      expect(
        StatsRepository.currentStreak(byDate, '2026-09-10', goal),
        equals(0),
      );
    });

    test('walks correctly across a month boundary', () {
      final byDate = {
        '2026-02-27': mins(30),
        '2026-02-28': mins(30),
        '2026-03-01': mins(30),
      };
      expect(
        StatsRepository.currentStreak(byDate, '2026-03-01', goal),
        equals(3),
      );
    });

    test('walks correctly across a year boundary', () {
      final byDate = {
        '2025-12-30': mins(30),
        '2025-12-31': mins(30),
        '2026-01-01': mins(30),
      };
      expect(
        StatsRepository.currentStreak(byDate, '2026-01-01', goal),
        equals(3),
      );
    });

    test('walks correctly across the spring-forward DST day', () {
      // 2026-03-08 is a 23-hour day in America/Edmonton. Date stepping must
      // not stall or skip there.
      final byDate = {
        '2026-03-07': mins(30),
        '2026-03-08': mins(30),
        '2026-03-09': mins(30),
      };
      expect(
        StatsRepository.currentStreak(byDate, '2026-03-09', goal),
        equals(3),
      );
    });
  });

  group('§4.3 longest streak', () {
    test('finds the longest run, not the most recent', () {
      final byDate = {
        '2026-09-01': mins(30),
        '2026-09-02': mins(30),
        '2026-09-03': mins(30),
        '2026-09-04': mins(30),
        // gap
        '2026-09-08': mins(30),
        '2026-09-09': mins(30),
      };
      expect(StatsRepository.longestStreak(byDate, goal), equals(4));
    });

    test('ignores days below the goal when measuring a run', () {
      final byDate = {
        '2026-09-01': mins(30),
        '2026-09-02': mins(5), // breaks the run
        '2026-09-03': mins(30),
        '2026-09-04': mins(30),
      };
      expect(StatsRepository.longestStreak(byDate, goal), equals(2));
    });

    test('a single met day is a streak of one', () {
      expect(
        StatsRepository.longestStreak({'2026-09-01': mins(30)}, goal),
        equals(1),
      );
    });

    test('no met days is zero', () {
      expect(
        StatsRepository.longestStreak({'2026-09-01': mins(5)}, goal),
        equals(0),
      );
    });

    test('empty history is zero', () {
      expect(StatsRepository.longestStreak({}, goal), equals(0));
    });

    test('a run spanning a month boundary is counted as consecutive', () {
      final byDate = {
        '2026-02-27': mins(30),
        '2026-02-28': mins(30),
        '2026-03-01': mins(30),
        '2026-03-02': mins(30),
      };
      expect(StatsRepository.longestStreak(byDate, goal), equals(4));
    });

    test('unsorted input still measures runs correctly', () {
      final byDate = {
        '2026-09-03': mins(30),
        '2026-09-01': mins(30),
        '2026-09-02': mins(30),
      };
      expect(StatsRepository.longestStreak(byDate, goal), equals(3));
    });
  });

  group('milestone dates — the heatmap ring overlay', () {
    /// [days] consecutive met days starting at [start].
    Map<String, int> run(String start, int days, {int minutes = 30}) => {
          for (var i = 0; i < days; i++)
            TimeService.addDays(start, i): mins(minutes),
        };

    test('no data marks nothing', () {
      expect(StatsRepository.milestoneDates({}, goal), isEmpty);
    });

    test('a streak that never reaches seven marks nothing', () {
      final byDate = run('2026-09-01', 6);
      expect(StatsRepository.milestoneDates(byDate, goal), isEmpty);
    });

    test('a run of exactly seven marks its seventh day and nothing else', () {
      final byDate = run('2026-09-01', 7);
      expect(
        StatsRepository.milestoneDates(byDate, goal),
        equals({'2026-09-07'}),
      );
    });

    test('a long run marks 7, 14 and 30 — and only those days', () {
      final byDate = run('2026-09-01', 45);
      expect(
        StatsRepository.milestoneDates(byDate, goal),
        equals({
          '2026-09-07', // day 7
          '2026-09-14', // day 14
          '2026-09-30', // day 30
        }),
      );
    });

    test('days between thresholds are not marked', () {
      final marked = StatsRepository.milestoneDates(run('2026-09-01', 45), goal);
      expect(marked.contains('2026-09-08'), isFalse); // day 8
      expect(marked.contains('2026-09-15'), isFalse); // day 15
      expect(marked.contains('2026-10-01'), isFalse); // day 31
    });

    test('a broken streak restarts the count, so the second run re-earns 7',
        () {
      // Seven days, a gap, then seven more. Both sevenths are milestones —
      // the second run genuinely reached seven from zero.
      final byDate = {
        ...run('2026-09-01', 7), // 09-01..09-07
        ...run('2026-09-10', 7), // 09-10..09-16
      };
      expect(
        StatsRepository.milestoneDates(byDate, goal),
        equals({'2026-09-07', '2026-09-16'}),
      );
    });

    test('a day under the goal breaks the run even with data on it', () {
      final byDate = {
        ...run('2026-09-01', 6),
        '2026-09-07': mins(10), // short of the goal — breaks it
        ...run('2026-09-08', 7),
      };
      // The first stretch never reached 7; the second did, on 09-14.
      expect(
        StatsRepository.milestoneDates(byDate, goal),
        equals({'2026-09-14'}),
      );
    });

    test('hundreds keep repeating past the fixed early thresholds', () {
      final byDate = run('2026-01-01', 210);
      final marked = StatsRepository.milestoneDates(byDate, goal);
      expect(marked, contains(TimeService.addDays('2026-01-01', 99))); // 100
      expect(marked, contains(TimeService.addDays('2026-01-01', 199))); // 200
      expect(marked.contains(TimeService.addDays('2026-01-01', 149)), isFalse);
    });

    test('unsorted input is walked in date order, not insertion order', () {
      final ordered = run('2026-09-01', 14);
      final shuffled = Map<String, int>.fromEntries(
        ordered.entries.toList().reversed,
      );
      expect(
        StatsRepository.milestoneDates(shuffled, goal),
        equals(StatsRepository.milestoneDates(ordered, goal)),
      );
    });

    test(
        'a window opening mid-streak restarts the count — the documented limit',
        () {
      // The accepted limitation from `milestoneDates`' doc comment. The real
      // streak here is 100 days long, but the caller only handed over its
      // last 20 days, so day 7 of the *visible* stretch is marked even though
      // the user crossed 7 eighty days earlier.
      //
      // Production is not exposed to this: `watchMilestoneDates` reads all
      // history, never a window. The test pins the behaviour so a future
      // caller that does pass a window knows what it gets.
      final windowed = run('2026-09-01', 20);
      expect(
        StatsRepository.milestoneDates(windowed, goal),
        equals({'2026-09-07', '2026-09-14'}),
      );
    });

    test('all history sees the same streak correctly', () {
      // The same 100-day run, handed over in full: 7, 14, 30, 60 and 100 are
      // marked at their true positions.
      final full = run('2026-06-01', 100);
      final marked = StatsRepository.milestoneDates(full, goal);
      expect(marked, hasLength(5));
      for (final threshold in [7, 14, 30, 60, 100]) {
        expect(
          marked,
          contains(TimeService.addDays('2026-06-01', threshold - 1)),
          reason: 'day $threshold should be marked',
        );
      }
    });
  });
}
