/// The round numbers a streak is celebrated for.
///
/// One definition, shared: the Habits-list glow card (§5) and the full-screen
/// celebration (§4) must agree, or a habit glows on the list without ever
/// firing the celebration — or worse, the other way round.
///
/// 7, 14, 30, 60, 100, then every hundred. Nothing here is persisted; whether
/// a milestone has *already been celebrated* is separate state (§9).
abstract final class MilestoneThresholds {
  /// The fixed early run, ascending. After the last one, every 100.
  static const List<int> early = [7, 14, 30, 60, 100];

  /// The interval milestones repeat on once [early] is exhausted.
  static const int interval = 100;

  /// True when [streak] lands exactly on a threshold — "today is the day".
  ///
  /// Exact, not "at least": a 31-day streak has not *reached* 30 today, and
  /// treating it as though it had is what would re-fire the celebration on
  /// every app open for the rest of the run.
  static bool reached(int streak) {
    if (streak <= 0) return false;
    if (early.contains(streak)) return true;
    return streak > early.last && streak % interval == 0;
  }

  /// The highest threshold [streak] has passed, or null below the first one.
  static int? highestReached(int streak) {
    if (streak <= 0) return null;
    if (streak >= early.last) return streak ~/ interval * interval;
    int? best;
    for (final threshold in early) {
      if (streak >= threshold) best = threshold;
    }
    return best;
  }

  /// The next threshold above [streak]. Never null — they go on forever.
  static int next(int streak) {
    final from = streak < 0 ? 0 : streak;
    for (final threshold in early) {
      if (from < threshold) return threshold;
    }
    return (from ~/ interval + 1) * interval;
  }

  /// Days from [streak] to the next threshold, always one or more.
  static int daysToNext(int streak) => next(streak) - (streak < 0 ? 0 : streak);
}
