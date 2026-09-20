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
/// (excused rest) or pending (today, not yet due) day from ANY habit is left
/// out of both sides, exactly as it would be if that one habit were asked
/// alone. A habit with nothing scheduled in the period contributes nothing
/// either way, rather than being excluded as a whole — so one demanding
/// daily habit cannot drown out four easier ones in the pooled number.
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
