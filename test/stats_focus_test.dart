import 'package:flutter_test/flutter_test.dart';
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
}
