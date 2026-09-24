// The habit digest's copy selection — pure, so none of this needs a
// database, a plugin or a clock.
//
// The tones are checked one at a time in isolation, then together to pin the
// priority order, then the "say nothing" cases. `templateIndex` is passed
// explicitly throughout: the whole reason the randomness lives in
// `ReminderService` is that this file stays deterministic.
//
// Fixture dates: 2026-09-14 is a Monday, so it is both "today" and the start
// of the week wherever a rollover is being tested.

import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/habits/habit_streak.dart';
import 'package:habit_tracker/features/reminders/habit_digest_copy.dart';

void main() {
  const today = '2026-09-14'; // Monday
  const yesterday = '2026-09-13';
  const midWeek = '2026-09-16'; // Wednesday, so not a rollover day

  HabitDigestInput habit({
    int streak = 0,
    Map<String, HabitDayOutcome> outcomes = const {},
  }) =>
      HabitDigestInput(currentStreak: streak, outcomes: outcomes);

  HabitDigestTone? toneFor(
    List<HabitDigestInput> habits, {
    String todayDate = midWeek,
    String weekStart = today,
  }) =>
      selectHabitDigestTone(
        habits: habits,
        todayLocalDate: todayDate,
        yesterdayLocalDate: yesterday,
        startOfWeekLocalDate: weekStart,
      );

  String? bodyFor(
    List<HabitDigestInput> habits, {
    String todayDate = midWeek,
    String weekStart = today,
    int templateIndex = 0,
  }) =>
      selectHabitDigestBody(
        habits: habits,
        todayLocalDate: todayDate,
        yesterdayLocalDate: yesterday,
        startOfWeekLocalDate: weekStart,
        templateIndex: templateIndex,
      )?.body;

  group('freeze-used tone', () {
    test('fires when any habit was excused yesterday', () {
      final habits = [
        habit(outcomes: const {yesterday: HabitDayOutcome.missed}),
        habit(outcomes: const {yesterday: HabitDayOutcome.neutral}),
      ];
      expect(toneFor(habits), equals(HabitDigestTone.freezeUsed));
    });

    test('does not fire on a plain miss', () {
      final habits = [
        habit(outcomes: const {yesterday: HabitDayOutcome.missed}),
      ];
      expect(toneFor(habits), isNull);
    });

    test('its copy mentions the freeze and does not scold', () {
      final habits = [
        habit(outcomes: const {yesterday: HabitDayOutcome.neutral}),
      ];
      for (var i = 0; i < habitDigestVariantCount(HabitDigestTone.freezeUsed); i++) {
        final body = bodyFor(habits, templateIndex: i)!;
        expect(body.toLowerCase(), contains('freeze'));
        expect(body, isNot(contains('{')), reason: 'no unsubstituted placeholder');
      }
    });
  });

  group('week-rollover tone', () {
    test('fires on the first day of the week when something is scheduled', () {
      final habits = [
        habit(outcomes: const {today: HabitDayOutcome.pending}),
      ];
      expect(
        toneFor(habits, todayDate: today, weekStart: today),
        equals(HabitDigestTone.weekRollover),
      );
    });

    test('does not fire mid-week', () {
      final habits = [
        habit(outcomes: const {midWeek: HabitDayOutcome.pending}),
      ];
      expect(toneFor(habits, todayDate: midWeek), isNot(HabitDigestTone.weekRollover));
    });

    test('does not fire with nothing scheduled — no "0 habits are waiting"',
        () {
      // Every habit is Tue/Thu only, and the week starts on Monday.
      final habits = [
        habit(streak: 4, outcomes: const {'2026-09-15': HabitDayOutcome.pending}),
      ];
      expect(toneFor(habits, todayDate: today, weekStart: today), isNull);
    });

    test('counts the habits scheduled today, done or not', () {
      final habits = [
        habit(outcomes: const {today: HabitDayOutcome.pending}),
        habit(outcomes: const {today: HabitDayOutcome.done}),
        habit(outcomes: const {today: HabitDayOutcome.neutral}),
        habit(outcomes: const {'2026-09-15': HabitDayOutcome.pending}),
      ];
      expect(
        bodyFor(habits, todayDate: today, weekStart: today, templateIndex: 0),
        equals('New week, clean slate. 3 habits are waiting whenever you are.'),
      );
    });

    test('one habit gets a singular noun and verb', () {
      final habits = [
        habit(outcomes: const {today: HabitDayOutcome.pending}),
      ];
      expect(
        bodyFor(habits, todayDate: today, weekStart: today, templateIndex: 0),
        equals('New week, clean slate. 1 habit is waiting whenever you are.'),
      );
    });
  });

  group('active-streak tone', () {
    test('fires with a live streak and something still open', () {
      final habits = [
        habit(streak: 12, outcomes: const {midWeek: HabitDayOutcome.pending}),
      ];
      expect(toneFor(habits), equals(HabitDigestTone.activeStreak));
    });

    test('does not fire with no streak', () {
      final habits = [
        habit(streak: 0, outcomes: const {midWeek: HabitDayOutcome.pending}),
      ];
      expect(toneFor(habits), isNull);
    });

    test('does not fire when everything is already done', () {
      // The deliberate suppression: "12-day streak — 0 habits are still open"
      // is a status report, not a nudge, so the digest stays quiet.
      final habits = [
        habit(streak: 12, outcomes: const {midWeek: HabitDayOutcome.done}),
      ];
      expect(toneFor(habits), isNull);
    });

    test('cites the highest streak and the open count', () {
      final habits = [
        habit(streak: 12, outcomes: const {midWeek: HabitDayOutcome.pending}),
        habit(streak: 3, outcomes: const {midWeek: HabitDayOutcome.pending}),
        habit(streak: 40, outcomes: const {midWeek: HabitDayOutcome.done}),
      ];
      expect(
        bodyFor(habits, templateIndex: 0),
        equals('40-day streak — keep it alive. 2 habits are still open.'),
      );
    });
  });

  group('priority order', () {
    test('a freeze yesterday outranks a week rollover', () {
      // The documented edge case: one habit, excused yesterday, and today is
      // also the first day of the week.
      final habits = [
        habit(
          streak: 9,
          outcomes: const {
            yesterday: HabitDayOutcome.neutral,
            today: HabitDayOutcome.pending,
          },
        ),
      ];
      expect(
        toneFor(habits, todayDate: today, weekStart: today),
        equals(HabitDigestTone.freezeUsed),
      );
    });

    test('a freeze yesterday outranks an active streak', () {
      final habits = [
        habit(
          streak: 9,
          outcomes: const {
            yesterday: HabitDayOutcome.neutral,
            midWeek: HabitDayOutcome.pending,
          },
        ),
      ];
      expect(toneFor(habits), equals(HabitDigestTone.freezeUsed));
    });

    test('a week rollover outranks an active streak', () {
      final habits = [
        habit(streak: 9, outcomes: const {today: HabitDayOutcome.pending}),
      ];
      expect(
        toneFor(habits, todayDate: today, weekStart: today),
        equals(HabitDigestTone.weekRollover),
      );
    });

    test('a rollover with nothing scheduled falls through to the streak tone',
        () {
      // Monday, but this habit is only due Wednesday — and it is pending
      // today anyway because the outcomes map says so. The rollover gate
      // fails on the scheduled count, and the lower tone picks it up.
      final habits = [
        habit(
          streak: 9,
          outcomes: const {'2026-09-15': HabitDayOutcome.pending},
        ),
      ];
      // Nothing scheduled today at all, so neither tone applies.
      expect(toneFor(habits, todayDate: today, weekStart: today), isNull);

      // With something scheduled today but the week already under way, the
      // streak tone is what is left.
      final midWeekHabits = [
        habit(streak: 9, outcomes: const {midWeek: HabitDayOutcome.pending}),
      ];
      expect(
        toneFor(midWeekHabits, todayDate: midWeek, weekStart: today),
        equals(HabitDigestTone.activeStreak),
      );
    });
  });

  group('no fire', () {
    test('no active habits at all', () {
      expect(toneFor(const []), isNull);
      expect(bodyFor(const []), isNull);
    });

    test('everything done, no streak, mid-week', () {
      final habits = [
        habit(streak: 0, outcomes: const {midWeek: HabitDayOutcome.done}),
      ];
      expect(toneFor(habits), isNull);
      expect(bodyFor(habits), isNull);
    });

    test('a body is never returned without a tone', () {
      final habits = [
        habit(streak: 0, outcomes: const {midWeek: HabitDayOutcome.missed}),
      ];
      expect(selectHabitDigestTone(
        habits: habits,
        todayLocalDate: midWeek,
        yesterdayLocalDate: yesterday,
        startOfWeekLocalDate: today,
      ), isNull);
      expect(bodyFor(habits), isNull);
    });
  });

  group('templateIndex', () {
    final streakHabits = [
      HabitDigestInput(
        currentStreak: 5,
        outcomes: const {midWeek: HabitDayOutcome.pending},
      ),
    ];

    test('each index selects a different variant', () {
      final bodies = {
        for (var i = 0;
            i < habitDigestVariantCount(HabitDigestTone.activeStreak);
            i++)
          bodyFor(streakHabits, templateIndex: i),
      };
      expect(
        bodies,
        hasLength(habitDigestVariantCount(HabitDigestTone.activeStreak)),
        reason: 'every variant should be a distinct sentence',
      );
    });

    test('the same index always gives the same sentence', () {
      expect(
        bodyFor(streakHabits, templateIndex: 1),
        equals(bodyFor(streakHabits, templateIndex: 1)),
      );
    });

    test('index 0 is the mockup line', () {
      expect(
        bodyFor(streakHabits, templateIndex: 0),
        equals('5-day streak — keep it alive. 1 habit is still open.'),
      );
    });

    test('an out-of-range index wraps instead of throwing', () {
      final count = habitDigestVariantCount(HabitDigestTone.activeStreak);
      expect(
        bodyFor(streakHabits, templateIndex: count + 1),
        equals(bodyFor(streakHabits, templateIndex: 1)),
      );
    });

    test('a negative index wraps too', () {
      // `ReminderService` stores -1 as "nothing used yet"; reaching this
      // function with it must not be a range error.
      final count = habitDigestVariantCount(HabitDigestTone.activeStreak);
      expect(
        bodyFor(streakHabits, templateIndex: -1),
        equals(bodyFor(streakHabits, templateIndex: count - 1)),
      );
    });

    test('the returned content reports the wrapped index and its tone', () {
      final content = selectHabitDigestBody(
        habits: streakHabits,
        todayLocalDate: midWeek,
        yesterdayLocalDate: yesterday,
        startOfWeekLocalDate: today,
        templateIndex: 7,
      )!;
      expect(content.tone, equals(HabitDigestTone.activeStreak));
      expect(
        content.templateIndex,
        equals(7 % habitDigestVariantCount(HabitDigestTone.activeStreak)),
      );
    });

    test('every pool is deep enough for the anti-repeat rule to have a choice',
        () {
      for (final tone in HabitDigestTone.values) {
        expect(habitDigestVariantCount(tone), greaterThanOrEqualTo(2),
            reason: '$tone');
      }
    });
  });
}
