/// Cross-habit statistics for the Stats screen — SPEC.md §10.5 extended from
/// "one habit's numbers on its own detail screen" to "every active habit's
/// numbers pooled together", the same relationship this file's functions
/// have to `HabitStats` in `habit_streak.dart`.
///
/// Pure and database-free, exactly like `statistics.dart` (SPEC.md §7):
/// every function here takes plain [HabitStatsInput] records — the repository
/// converts its own `HabitSnapshot` (which depends on Drift) into these
/// before calling in — and returns numbers. No query lives in this file.
///
/// **Streaks are never re-sliced by period.** A "current streak" answers "is
/// the chain unbroken right now", which has nothing to do with which stats
/// range happens to be selected. Reslicing it to "this week" would reset a
/// 40-day streak to at most 7 just because of which tab was open. So
/// [habitLeaderboard] carries `currentStreak`/`longestStreak` straight
/// through from the habit's whole history — computed once by
/// `HabitStats.computeStreaks`, exactly as the habit detail screen shows it.
/// Only the rate-style numbers below (completion rate, weekday profile,
/// check-off count, the activity heatmap) are restricted to a period — the
/// same split SPEC.md §10.3 draws between streaks and rates.
library;

import '../habits/habit_streak.dart';
import '../time/time_service.dart';
import 'statistics.dart' show StatsPeriod, HeatmapThresholds;

/// One habit's resolved history, flattened for this engine.
///
/// Mirrors [SessionRecord] in `statistics.dart`: a small, Drift-free bag of
/// values the repository builds from its own row types, so this file never
/// has to import anything from `data/`.
class HabitStatsInput {
  const HabitStatsInput({
    required this.habitId,
    required this.title,
    required this.colorIndex,
    required this.iconName,
    required this.currentStreak,
    required this.longestStreak,
    required this.outcomes,
    required this.entries,
  });

  final String habitId;
  final String title;
  final int colorIndex;
  final String iconName;

  /// Whole-history streaks — see the file doc for why a period never
  /// touches these two numbers.
  final int currentStreak;
  final int longestStreak;

  /// Every scheduled date this habit has ever had, mapped to its resolved
  /// outcome. `HabitSnapshot.streaks.outcomes`, unchanged.
  final Map<String, HabitDayOutcome> outcomes;

  /// Raw day records, for check-off counts. `HabitSnapshot.entries`,
  /// unchanged.
  final Map<String, HabitDayRecord> entries;
}

// ─────────────────────────────────────────────────────────────────────────
// Pooled completion rate
// ─────────────────────────────────────────────────────────────────────────

/// SPEC.md §10.5's completion rate, pooled across every habit instead of
/// kept per-habit — "how am I doing on habits generally", the habit
/// counterpart of `CompletionRate` in `statistics.dart`.
///
/// The same exclusions apply per scheduled day, not per habit: a neutral
/// (a freeze) or pending (today, not yet due) day from ANY habit is left
/// out of both sides, exactly as it would be if that one habit were asked
/// alone. A habit with nothing scheduled in the period contributes nothing
/// either way, rather than being excluded as a whole — so one demanding
/// daily habit cannot drown out four easier ones in the pooled number.
///
/// Leaving `pending` out is right for every window this is asked about — a
/// week or a quarter should not hold today's unfinished business against
/// you, and a settled past day has no `pending` left in it. It is wrong for
/// exactly one question: "how far through TODAY am I?", asked of the single
/// day still open. There, excluding `pending` leaves only the habits already
/// resolved, so the first tick reads as 100% however many are still to do.
/// That question has its own function, [ofToday].
class HabitCompletionRate {
  const HabitCompletionRate({required this.done, required this.eligible});

  final int done;
  final int eligible;

  /// Null when nothing in the period could be scored — a window before any
  /// habit existed, or one where every scheduled day was excused. Renders as
  /// an em dash, never 0%, per the governing rule (SPEC.md §4, §10.5).
  double? get rate => eligible == 0 ? null : done / eligible;

  static const empty = HabitCompletionRate(done: 0, eligible: 0);

  static HabitCompletionRate of(
    Iterable<HabitStatsInput> habits,
    StatsPeriod period,
  ) {
    var done = 0;
    var eligible = 0;
    for (final habit in habits) {
      for (final entry in habit.outcomes.entries) {
        if (!period.contains(entry.key)) continue;
        final outcome = entry.value;
        if (outcome == HabitDayOutcome.neutral ||
            outcome == HabitDayOutcome.pending ||
            outcome == HabitDayOutcome.future) {
          continue;
        }
        eligible++;
        if (outcome == HabitDayOutcome.done) done++;
      }
    }
    return HabitCompletionRate(done: done, eligible: eligible);
  }

  /// Same pooling as [of], but for the single day still in progress: a
  /// still-open ([HabitDayOutcome.pending]) habit counts toward the
  /// denominator as "not yet done" instead of being excluded, so progress
  /// through today is visible before the day resolves. Every other outcome
  /// (done/neutral/future) is treated exactly as [of] treats it.
  ///
  /// With four habits scheduled and one ticked off this is 1/4, where [of]
  /// says 1/1 — the other three are `pending`, and [of] cannot see them.
  ///
  /// Still null-not-zero: a day with nothing scheduled, or with everything on
  /// it excused, has no denominator and returns a null [rate]. A day with
  /// habits scheduled and none done is a real 0.0.
  ///
  /// Never call this for a day other than today — for any settled day [of] is
  /// already correct and already tested as such. [ofDay] makes that choice for
  /// callers that draw a whole week.
  static HabitCompletionRate ofToday(
    Iterable<HabitStatsInput> habits,
    String todayLocalDate,
  ) {
    var done = 0;
    var eligible = 0;
    for (final habit in habits) {
      // One date, so a direct lookup: [of]'s walk over a habit's whole history
      // finds the same single entry (or none, when it is not scheduled today)
      // by way of `StatsPeriod.day(...).contains`.
      final outcome = habit.outcomes[todayLocalDate];
      if (outcome == null) continue;
      if (outcome == HabitDayOutcome.neutral ||
          outcome == HabitDayOutcome.future) {
        continue;
      }
      // `pending` falls through to here on purpose — the one difference from
      // [of].
      eligible++;
      if (outcome == HabitDayOutcome.done) done++;
    }
    return HabitCompletionRate(done: done, eligible: eligible);
  }

  /// One day's pooled completion for a Mon–Sun chart: [ofToday] when [date] is
  /// [todayLocalDate], [of] over that single day for every other.
  ///
  /// The two charts that draw a week of these — the Habits screen's recap bars
  /// (`buildWeeklyRecap`) and the Today screen's momentum strip — both go
  /// through here, so they cannot disagree about a day. They show the same
  /// week, and a bar at 25% over a pip at 100% for the same Tuesday would be
  /// the kind of thing a user notices and stops trusting the app over.
  static HabitCompletionRate ofDay(
    Iterable<HabitStatsInput> habits,
    String date, {
    required String todayLocalDate,
  }) {
    return date == todayLocalDate
        ? ofToday(habits, todayLocalDate)
        : of(habits, StatsPeriod.day(date));
  }
}

/// Which of the activity heatmap's five ramp steps a day completed at [rate]
/// sits on — an index into `AppTokens.heatmap`.
///
/// The same "darker means more" language the Stats heatmap already speaks, so
/// a week strip and a heatmap cell read the same way. The ramp has four steps
/// above empty, so a fraction is cut into thirds with a full day as its own
/// top step: fully complete is the darkest tier, and nothing short of it is.
///
///   * `rate >= 1`      → 4, the darkest — every scheduled habit done
///   * `rate > 2/3`     → 3
///   * `rate > 1/3`     → 2
///   * `rate > 0`       → 1, the lightest tint — something done
///   * otherwise        → 0, the empty step
///
/// Takes a real rate. A day with no rate at all (nothing scheduled) has no
/// tier and must not be asked about here: null is not zero, and the caller
/// draws it differently from step 0.
int completionTier(double rate) {
  if (rate >= 1) return 4;
  if (rate > 2 / 3) return 3;
  if (rate > 1 / 3) return 2;
  if (rate > 0) return 1;
  return 0;
}

// ─────────────────────────────────────────────────────────────────────────
// Pooled day-of-week profile
// ─────────────────────────────────────────────────────────────────────────

/// One weekday's pooled bin — mirrors `WeekdayBin` in `statistics.dart`.
class HabitWeekdayBin {
  const HabitWeekdayBin({
    required this.weekday,
    required this.eligibleDays,
    required this.doneDays,
  });

  /// `DateTime.monday` (1) … `DateTime.sunday` (7).
  final int weekday;
  final int eligibleDays;
  final int doneDays;

  double? get rate => eligibleDays == 0 ? null : doneDays / eligibleDays;
}

/// SPEC.md §10.5's day-of-week profile, pooled across every habit rather
/// than kept per-habit. Neutral, pending and future days are excluded from
/// both sides, exactly as §10.3 excludes them from a single habit's rate —
/// "rates are stricter than streaks".
class HabitWeekdayProfile {
  const HabitWeekdayProfile(this.bins);

  /// Seven entries, index 0 = Monday.
  final List<HabitWeekdayBin> bins;

  HabitWeekdayBin forWeekday(int weekday) => bins[weekday - 1];

  static HabitWeekdayProfile of(
    Iterable<HabitStatsInput> habits,
    StatsPeriod period,
  ) {
    final eligible = List<int>.filled(7, 0);
    final done = List<int>.filled(7, 0);

    for (final habit in habits) {
      for (final entry in habit.outcomes.entries) {
        if (!period.contains(entry.key)) continue;
        final outcome = entry.value;
        if (outcome == HabitDayOutcome.neutral ||
            outcome == HabitDayOutcome.pending ||
            outcome == HabitDayOutcome.future) {
          continue;
        }
        final index = TimeService.parseLocalDate(entry.key).weekday - 1;
        eligible[index] += 1;
        if (outcome == HabitDayOutcome.done) done[index] += 1;
      }
    }

    return HabitWeekdayProfile([
      for (var i = 0; i < 7; i++)
        HabitWeekdayBin(
          weekday: i + 1,
          eligibleDays: eligible[i],
          doneDays: done[i],
        ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Total check-offs
// ─────────────────────────────────────────────────────────────────────────

/// SPEC.md §10.5's "total check-offs" — sum of `check_count`, not days —
/// pooled across every habit and restricted to the period.
int habitCheckOffsTotal(Iterable<HabitStatsInput> habits, StatsPeriod period) {
  var total = 0;
  for (final habit in habits) {
    for (final entry in habit.entries.entries) {
      if (!period.contains(entry.key)) continue;
      total += entry.value.count;
    }
  }
  return total;
}

// ─────────────────────────────────────────────────────────────────────────
// Freezes used
// ─────────────────────────────────────────────────────────────────────────

/// Freezes applied across every habit inside [period] — the count of
/// `HabitDayOutcome.neutral` days, pooled.
///
/// The period-scoped counterpart of `HabitSnapshot.excusedThisMonth`, which is
/// fixed to the current calendar month because that is the window the monthly
/// allowance is granted over. A "this week" card cannot use that number: early
/// in a month it would report freezes spent in days the card is not showing,
/// and late in one it would pool several weeks of them into a figure labelled
/// "this week".
///
/// Same shape as [habitCheckOffsTotal] above — walk each habit's map, keep
/// what falls inside the window, add it up.
int habitFreezeCountIn(Iterable<HabitStatsInput> habits, StatsPeriod period) {
  var total = 0;
  for (final habit in habits) {
    for (final entry in habit.outcomes.entries) {
      if (!period.contains(entry.key)) continue;
      if (entry.value == HabitDayOutcome.neutral) total++;
    }
  }
  return total;
}

// ─────────────────────────────────────────────────────────────────────────
// Streak leaderboard
// ─────────────────────────────────────────────────────────────────────────

/// One habit's row in the Stats screen's streak leaderboard.
class HabitLeaderboardEntry {
  const HabitLeaderboardEntry({
    required this.habitId,
    required this.title,
    required this.colorIndex,
    required this.iconName,
    required this.currentStreak,
    required this.longestStreak,
  });

  final String habitId;
  final String title;
  final int colorIndex;
  final String iconName;
  final int currentStreak;
  final int longestStreak;
}

/// Active habits ranked by current streak, longest first.
///
/// Ties break on title, alphabetically — not on input order — so the list is
/// deterministic between rebuilds rather than following whatever order
/// [habits] happened to arrive in. Same reasoning as `TimeAllocation.of`'s
/// tie-break in `statistics.dart`.
List<HabitLeaderboardEntry> habitLeaderboard(Iterable<HabitStatsInput> habits) {
  final entries = [
    for (final habit in habits)
      HabitLeaderboardEntry(
        habitId: habit.habitId,
        title: habit.title,
        colorIndex: habit.colorIndex,
        iconName: habit.iconName,
        currentStreak: habit.currentStreak,
        longestStreak: habit.longestStreak,
      ),
  ];
  entries.sort((a, b) {
    final byStreak = b.currentStreak.compareTo(a.currentStreak);
    if (byStreak != 0) return byStreak;
    return a.title.compareTo(b.title);
  });
  return entries;
}

// ─────────────────────────────────────────────────────────────────────────
// Assembly
// ─────────────────────────────────────────────────────────────────────────

/// Everything the Stats screen's habit cards need for one period, from one
/// consistent read — the habit counterpart of `StatsBundle`. One object
/// rather than several providers, so the numbers cannot disagree with each
/// other the way two snapshots taken a moment apart could.
class HabitStatsBundle {
  const HabitStatsBundle({
    required this.period,
    required this.completionRate,
    required this.weekdayProfile,
    required this.totalCheckOffs,
    required this.activeHabitCount,
    required this.leaderboard,
  });

  final StatsPeriod period;
  final HabitCompletionRate completionRate;
  final HabitWeekdayProfile weekdayProfile;
  final int totalCheckOffs;
  final int activeHabitCount;

  /// Longest streak first. Empty when there are no active habits.
  final List<HabitLeaderboardEntry> leaderboard;

  /// Whether the habits section has anything to show at all. Gates on
  /// whether any habit exists, not on whether one has data in this
  /// particular period — a habit created yesterday still deserves a card
  /// that says "—" for this quarter, rather than the whole section vanishing.
  bool get hasAnyData => activeHabitCount > 0;
}

HabitStatsBundle buildHabitStatsBundle({
  required List<HabitStatsInput> habits,
  required StatsPeriod period,
}) {
  return HabitStatsBundle(
    period: period,
    completionRate: HabitCompletionRate.of(habits, period),
    weekdayProfile: HabitWeekdayProfile.of(habits, period),
    totalCheckOffs: habitCheckOffsTotal(habits, period),
    activeHabitCount: habits.length,
    leaderboard: habitLeaderboard(habits),
  );
}

// ─────────────────────────────────────────────────────────────────────────
// Weekly recap — the Habits screen's "This week" card
// ─────────────────────────────────────────────────────────────────────────

/// One day's column in the recap's Mon–Sun mini chart.
///
/// [rate] is that day's pooled completion, or null when nothing on it could be
/// scored. Null is deliberately not zero: a day where every habit was excused,
/// and a day where nothing was scheduled, are both "no claim to make" rather
/// than "you did nothing".
///
/// For a settled day that is [HabitCompletionRate.of] over the day. For today
/// it is [HabitCompletionRate.ofToday], which counts a habit still to do as
/// "not yet" rather than leaving it out — otherwise today's bar would leap
/// from its empty stub to full on the first check-off, with every other habit
/// still pending and invisible to the arithmetic.
class WeeklyRecapDay {
  const WeeklyRecapDay({
    required this.date,
    required this.rate,
    required this.isToday,
    required this.isFuture,
  });

  final String date;
  final double? rate;
  final bool isToday;

  /// Later in the week than today. Drawn as a placeholder rather than an empty
  /// bar — a day that has not happened yet is not a day where nothing was
  /// done, and drawing the two the same way would accuse the user of missing
  /// Thursday on a Tuesday.
  final bool isFuture;
}

/// Everything the Habits screen's "This week" card shows, from one read.
///
/// Fixed to the current calendar week on purpose. The Stats screen's range
/// picker drives `HabitStatsBundle`; this card always answers "this week", so
/// it must not be wired to that picker — a card headed "This week" that
/// silently followed a 90-day selection would be lying in its own title.
class WeeklyRecap {
  const WeeklyRecap({
    required this.weekStart,
    required this.weekEnd,
    required this.completionRate,
    required this.priorCompletionRate,
    required this.days,
    required this.bestStreak,
    required this.habitsKept,
    required this.freezesUsed,
    required this.activeHabitCount,
  });

  final String weekStart;
  final String weekEnd;

  /// This week's pooled rate; null when nothing this week could be scored.
  final double? completionRate;

  /// Last week's, for the comparison line. Null for a first-ever week — the
  /// card then shows the plain rate with no comparison rather than inventing
  /// a baseline of zero to be "up" from.
  final double? priorCompletionRate;

  /// Seven entries, starting on the user's configured first day of the week
  /// (`TimeService.weekStart`) — Monday by default, but Sunday or Saturday
  /// when that setting says so. Read each entry's own `date` rather than
  /// assuming index 0 is a Monday.
  final List<WeeklyRecapDay> days;

  /// The highest current streak across active habits. Whole-history, never
  /// re-sliced to the week — see this file's header — and the same number the
  /// habit digest's active-streak line cites, so the card and the notification
  /// cannot disagree about it.
  final int bestStreak;

  final int habitsKept;
  final int freezesUsed;
  final int activeHabitCount;

  /// Change in completion against last week, in points, or null when either
  /// side has no data to compare.
  double? get rateDelta {
    final now = completionRate;
    final prior = priorCompletionRate;
    if (now == null || prior == null) return null;
    return now - prior;
  }

  /// Same gate as [HabitStatsBundle.hasAnyData]: a user with no habits gets no
  /// card rather than a card full of em dashes.
  bool get hasAnyData => activeHabitCount > 0;
}

/// Builds the recap for the week beginning [weekStartLocalDate].
///
/// Every number comes from the same in-memory [habits] list, so the seven
/// per-day rates, the two weekly rates and the three tiles are all one
/// consistent read — and the whole thing costs exactly the queries that built
/// [habits], no matter how many periods it asks about.
///
/// The day bars and the week's headline rate deliberately answer different
/// questions about today. A bar asks "how far through the day am I", so
/// today's counts habits still to do ([HabitCompletionRate.ofToday]). The
/// weekly rate asks "how has the week gone", and keeps
/// [HabitCompletionRate.of]'s exclusion of today's open habits: an afternoon
/// at 1 of 4 should not drag the week's headline down for a day that is not
/// over. So today's bar can read 25% while the line above it reads a rate
/// made only of settled days — that is the two questions, not a disagreement.
WeeklyRecap buildWeeklyRecap({
  required List<HabitStatsInput> habits,
  required String todayLocalDate,
  required String weekStartLocalDate,
}) {
  final weekEnd = TimeService.addDays(weekStartLocalDate, 6);
  final thisWeek = StatsPeriod(start: weekStartLocalDate, end: weekEnd);

  final priorStart = TimeService.addDays(weekStartLocalDate, -7);
  final lastWeek = StatsPeriod(
    start: priorStart,
    end: TimeService.addDays(priorStart, 6),
  );

  var bestStreak = 0;
  for (final habit in habits) {
    if (habit.currentStreak > bestStreak) bestStreak = habit.currentStreak;
  }

  return WeeklyRecap(
    weekStart: weekStartLocalDate,
    weekEnd: weekEnd,
    completionRate: HabitCompletionRate.of(habits, thisWeek).rate,
    priorCompletionRate: HabitCompletionRate.of(habits, lastWeek).rate,
    days: [
      for (var i = 0; i < 7; i++)
        () {
          final date = TimeService.addDays(weekStartLocalDate, i);
          return WeeklyRecapDay(
            date: date,
            rate: HabitCompletionRate.ofDay(
              habits,
              date,
              todayLocalDate: todayLocalDate,
            ).rate,
            isToday: date == todayLocalDate,
            isFuture: date.compareTo(todayLocalDate) > 0,
          );
        }(),
    ],
    bestStreak: bestStreak,
    habitsKept: habitCheckOffsTotal(habits, thisWeek),
    freezesUsed: habitFreezeCountIn(habits, thisWeek),
    activeHabitCount: habits.length,
  );
}

// ─────────────────────────────────────────────────────────────────────────
// Activity heatmap — the habit counterpart of SPEC.md §4.13
// ─────────────────────────────────────────────────────────────────────────

/// One cell of the habit activity heatmap. Mirrors `HeatmapCell` in
/// `statistics.dart`, but counts **distinct habits completed** that day
/// rather than focused minutes: each habit contributes at most 1, so a
/// count-based habit like "8 glasses of water" cannot make one day look
/// busier than a day where five separate habits were each done once.
class HabitHeatmapCell {
  const HabitHeatmapCell({
    required this.date,
    required this.doneCount,
    required this.level,
  });

  final String date;
  final int doneCount;
  final int level;
}

/// Fallback thresholds for a user with fewer than
/// `HeatmapThresholds.minimumNonZeroDays` non-zero days of habit history.
///
/// Scaled for a habit count, not a minute count — `HeatmapThresholds`'s own
/// [HeatmapThresholds.fallback] (25/50/100/180) is calibrated for focus
/// minutes and would make every real day of habit activity read as level 1.
/// Most people run somewhere between one and half a dozen habits at once, so
/// this fallback saturates by 5 rather than by 180.
const habitHeatmapFallbackThresholds = HeatmapThresholds(
  level1Max: 1,
  level2Max: 2,
  level3Max: 3,
  level4Nominal: 5,
  provisional: true,
  nonZeroDayCount: 0,
);

/// Distinct habits resolved `done`, per date, across [habits] — the input
/// both [HeatmapThresholds.fromDailyMinutes] (for the legend's percentiles)
/// and [buildHabitHeatmap] (for the cells) are built from. Kept as one map so
/// the two never read a different day's count.
///
/// Deliberately NOT restricted by [period] in the same sense as the rate
/// functions above — the caller passes whatever window it wants counted
/// (normally the trailing-365-day heatmap window, independent of the range
/// picker, exactly as SPEC.md §4.13 fixes the focus heatmap's window).
Map<String, int> habitDoneCountsByDate(
  Iterable<HabitStatsInput> habits,
  StatsPeriod window,
) {
  final counts = <String, int>{};
  for (final habit in habits) {
    for (final entry in habit.outcomes.entries) {
      if (entry.value != HabitDayOutcome.done) continue;
      if (!window.contains(entry.key)) continue;
      counts[entry.key] = (counts[entry.key] ?? 0) + 1;
    }
  }
  return counts;
}

/// One cell per day in [period]. Every date gets a cell, including days with
/// no data — a gap in the heatmap is information, and an absent square would
/// silently shift every later square into the wrong column (same rule as
/// `buildHeatmap` in `statistics.dart`).
List<HabitHeatmapCell> buildHabitHeatmap({
  required StatsPeriod period,
  required Map<String, int> doneCountsByDate,
  required HeatmapThresholds thresholds,
}) {
  return [
    for (final date in period.dates())
      HabitHeatmapCell(
        date: date,
        doneCount: doneCountsByDate[date] ?? 0,
        level: thresholds.levelFor(doneCountsByDate[date] ?? 0),
      ),
  ];
}
