/// Copy selection for the once-daily habit digest notification.
///
/// Pure and database-free, like `core/stats/statistics.dart`: everything takes
/// plain values and returns a string, so wording and priority order can be
/// tested without a database, plugin or clock.
///
/// **Randomness lives in the caller.** `ReminderService` picks the variant
/// within a tone's pool, remembers the last one, and passes the index in.
/// Nothing here calls `Random`, so the same inputs always produce the same
/// sentence.
library;

import '../../core/habits/habit_streak.dart';

/// One habit's state, reduced to just what the digest reads. Not
/// `HabitStatsInput`: that carries a title, icon, colour and full entry map the
/// notification body never mentions, and requiring it would make
/// `ReminderService` fabricate four fields it has no use for.
class HabitDigestInput {
  const HabitDigestInput({
    required this.currentStreak,
    required this.outcomes,
  });

  /// Whole-history current streak, straight off `HabitSnapshot.streaks`.
  final int currentStreak;

  /// Scheduled date → resolved outcome, straight off
  /// `HabitSnapshot.streaks.outcomes`. A date being present at all is what
  /// "scheduled that day" means here.
  final Map<String, HabitDayOutcome> outcomes;
}

/// Which of the three things the digest can say today.
enum HabitDigestTone {
  /// A freeze absorbed a miss yesterday.
  freezeUsed,

  /// Today is the first day of the week and there is something scheduled.
  weekRollover,

  /// There is a live streak and something still open to protect it with.
  activeStreak,
}

/// The chosen line, plus which pool it came from.
class HabitDigestContent {
  const HabitDigestContent({
    required this.body,
    required this.tone,
    required this.templateIndex,
  });

  final String body;

  final HabitDigestTone tone;

  /// Which variant within [tone]'s pool this is, already wrapped into range.
  /// `ReminderService` persists it so the next digest of the same tone can
  /// avoid repeating the line.
  final int templateIndex;
}

/// The copy pools, one per tone.
///
/// Placeholders: `{s}` is the streak length, `{nHabits}` the habit count with
/// its noun ("1 habit" / "3 habits"), and `{nHabitsAre}` the same plus the
/// agreeing verb ("1 habit is" / "3 habits are"). Pools are three deep so the
/// anti-repeat rule always has somewhere to go.
const Map<HabitDigestTone, List<String>> _pools = {
  HabitDigestTone.freezeUsed: [
    'Missed yesterday — no big deal. A freeze kept your streak standing.',
    'Yesterday slipped by. A freeze caught it, and the streak is still yours.',
    'A freeze covered yesterday. Nothing broken — pick it back up today.',
  ],
  HabitDigestTone.weekRollover: [
    'New week, clean slate. {nHabitsAre} waiting whenever you are.',
    'A fresh week starts here. {nHabitsAre} ready when you are.',
    'The week just turned over. {nHabitsAre} waiting whenever you are.',
  ],
  HabitDigestTone.activeStreak: [
    '{s}-day streak — keep it alive. {nHabitsAre} still open.',
    '{s} days in a row so far. {nHabitsAre} still open today.',
    'Your {s}-day streak is still going. {nHabits} left to keep it that way.',
  ],
};

/// How many variants [tone]'s pool holds.
///
/// `ReminderService` needs this before it picks an index, so it can choose
/// uniformly among the variants that are not the last one used.
int habitDigestVariantCount(HabitDigestTone tone) => _pools[tone]!.length;

/// Which tone today's digest should take, or null when it should not fire.
///
/// **Priority order, most specific first**; the first match wins:
///
/// 1. [HabitDigestTone.freezeUsed]: any habit's yesterday was excused. Outranks
///    everything because it is the only line that reassures rather than nudges,
///    and a user who just lost a day is the one most likely to read a nudge as
///    nagging.
/// 2. [HabitDigestTone.weekRollover]: today begins the week *and* something is
///    scheduled. "New week, 0 habits waiting" would be worse than silence, so
///    the count gate is part of the condition rather than left to the template.
/// 3. [HabitDigestTone.activeStreak]: there is a streak to cite *and* something
///    still open. Both are required: with nothing open the line would read "0
///    habits are still open", a status report nobody asked for.
/// 4. Nothing: no active habits, or every condition above came up empty. As
///    with the task digest, an empty digest is worse than no digest.
///
/// [startOfWeekLocalDate] is passed in because which day a week starts on is a
/// user setting on `TimeService`, and this file doesn't take a `TimeService`.
HabitDigestTone? selectHabitDigestTone({
  required List<HabitDigestInput> habits,
  required String todayLocalDate,
  required String yesterdayLocalDate,
  required String startOfWeekLocalDate,
}) {
  if (habits.isEmpty) return null;

  for (final habit in habits) {
    if (habit.outcomes[yesterdayLocalDate] == HabitDayOutcome.neutral) {
      return HabitDigestTone.freezeUsed;
    }
  }

  if (todayLocalDate == startOfWeekLocalDate &&
      _scheduledToday(habits, todayLocalDate) > 0) {
    return HabitDigestTone.weekRollover;
  }

  if (_bestStreak(habits) > 0 && _pendingToday(habits, todayLocalDate) > 0) {
    return HabitDigestTone.activeStreak;
  }

  return null;
}

/// The digest's body for today, or null when it should not fire.
/// [templateIndex] chooses the variant within the selected tone's pool and is
/// wrapped into range, so any integer is safe to pass. See
/// [selectHabitDigestTone] for the priority order.
HabitDigestContent? selectHabitDigestBody({
  required List<HabitDigestInput> habits,
  required String todayLocalDate,
  required String yesterdayLocalDate,
  required String startOfWeekLocalDate,
  required int templateIndex,
}) {
  final tone = selectHabitDigestTone(
    habits: habits,
    todayLocalDate: todayLocalDate,
    yesterdayLocalDate: yesterdayLocalDate,
    startOfWeekLocalDate: startOfWeekLocalDate,
  );
  if (tone == null) return null;

  final pool = _pools[tone]!;
  // Modulo, and a second pass for negatives, so a caller that stored -1 as
  // "nothing used yet" cannot throw a range error here.
  final index = ((templateIndex % pool.length) + pool.length) % pool.length;

  final count = switch (tone) {
    HabitDigestTone.freezeUsed => 0, // unused by that pool's templates
    HabitDigestTone.weekRollover => _scheduledToday(habits, todayLocalDate),
    HabitDigestTone.activeStreak => _pendingToday(habits, todayLocalDate),
  };

  return HabitDigestContent(
    body: _render(pool[index], count: count, streak: _bestStreak(habits)),
    tone: tone,
    templateIndex: index,
  );
}

/// Substitutes `{s}`, `{nHabits}` and `{nHabitsAre}`. The noun and its verb
/// travel together because English makes them agree ("1 habit is waiting" vs "3
/// habits are waiting"); one placeholder for the pair is what stops a template
/// reading "1 habits are".
String _render(String template, {required int count, required int streak}) {
  final nHabits = '$count ${count == 1 ? 'habit' : 'habits'}';
  return template
      .replaceAll('{nHabitsAre}', '$nHabits ${count == 1 ? 'is' : 'are'}')
      .replaceAll('{nHabits}', nHabits)
      .replaceAll('{s}', '$streak');
}

int _scheduledToday(List<HabitDigestInput> habits, String today) {
  var count = 0;
  for (final habit in habits) {
    final outcome = habit.outcomes[today];
    // `future` would mean the resolver looked past today, which cannot happen
    // for today itself; everything else present means the habit is on today's
    // list, done or not.
    if (outcome != null && outcome != HabitDayOutcome.future) count++;
  }
  return count;
}

int _pendingToday(List<HabitDigestInput> habits, String today) {
  var count = 0;
  for (final habit in habits) {
    if (habit.outcomes[today] == HabitDayOutcome.pending) count++;
  }
  return count;
}

int _bestStreak(List<HabitDigestInput> habits) {
  var best = 0;
  for (final habit in habits) {
    if (habit.currentStreak > best) best = habit.currentStreak;
  }
  return best;
}
