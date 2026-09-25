/// Copy pools for task reminders, habit reminders and the task digest.
///
/// Same split as `habit_digest_copy.dart`, which this file deliberately
/// mirrors: pure and database-free, everything takes plain values and returns
/// a string, so wording can be tested without a database, a plugin or a clock.
///
/// **Randomness lives in the caller.** `ReminderService` picks the variant
/// index and persists the last one used per pool, then passes the index in.
/// Nothing here calls `Random`, so the same inputs always produce the same
/// sentence.
library;

/// Wraps any integer into `[0, length)`.
///
/// A second pass handles negatives so a caller that stored -1 as "nothing used
/// yet" cannot throw a range error.
int _wrap(int index, int length) => ((index % length) + length) % length;

// ───────────────────────────────────────────────────── task reminders

/// Short lead-ins for a task reminder body.
///
/// The due time and project name are load-bearing on a time-sensitive
/// reminder, so they are never varied — only this prefix is. Every line is
/// kept to a couple of words for the same reason: the body still has to read
/// as "when and where", not as a greeting.
const List<String> _taskLeadIns = [
  'Coming up',
  'Next up',
  'On deck',
  'Almost time',
];

/// How many task-reminder lead-ins there are.
int taskLeadInCount() => _taskLeadIns.length;

/// A task reminder body: `"<lead-in> · <project> • <time>"`.
///
/// [projectName] is omitted entirely when null or blank rather than rendered
/// as an empty segment. [timeStr] is required and always survives — it is the
/// one piece of information the reminder exists to carry.
String taskReminderBody({
  required String timeStr,
  String? projectName,
  required int templateIndex,
}) {
  final lead = _taskLeadIns[_wrap(templateIndex, _taskLeadIns.length)];
  final hasProject = projectName != null && projectName.trim().isNotEmpty;
  final detail = hasProject ? '$projectName • $timeStr' : timeStr;
  return '$lead · $detail';
}

// ──────────────────────────────────────────────────── habit reminders

/// Which of the three things a habit reminder can say.
///
/// Mirrors the existing branch order in `ReminderService.scheduleForHabit`:
/// a live streak outranks a multi-count target, which outranks the bare
/// "due today" fallback.
enum HabitReminderTone {
  /// There is a streak worth protecting.
  streak,

  /// The habit asks for more than one of something today.
  targetCount,

  /// Nothing else to say — it is simply on today's list.
  dueToday,
}

/// The copy pools, one per tone.
///
/// Placeholders: `{s}` is the streak length, `{target}` the target count
/// already joined to its unit label (e.g. "3 glasses", or just "3" when the
/// habit has no unit). Pools are three deep so the anti-repeat rule always has
/// somewhere to go, the same depth `habit_digest_copy.dart` uses.
const Map<HabitReminderTone, List<String>> _habitPools = {
  HabitReminderTone.streak: [
    'Keep your {s}-day streak going',
    '{s} days running — keep it up',
    "Don't break the {s}-day streak",
  ],
  HabitReminderTone.targetCount: [
    '{target} today',
    '{target} to go today',
    "Today's target: {target}",
  ],
  HabitReminderTone.dueToday: [
    'Due today',
    'On today\'s list',
    'Still open today',
  ],
};

/// How many variants [tone]'s pool holds.
int habitReminderVariantCount(HabitReminderTone tone) =>
    _habitPools[tone]!.length;

/// Which tone a habit reminder should take.
///
/// Same precedence the previous static branch used, kept deliberately so this
/// change is a copy change and not a behaviour change.
HabitReminderTone selectHabitReminderTone({
  required int currentStreak,
  required int targetCount,
}) {
  if (currentStreak > 0) return HabitReminderTone.streak;
  if (targetCount > 1) return HabitReminderTone.targetCount;
  return HabitReminderTone.dueToday;
}

/// A habit reminder body for [tone].
///
/// [templateIndex] chooses the variant and is wrapped into range, so any
/// integer is safe to pass.
String habitReminderBody({
  required HabitReminderTone tone,
  required int currentStreak,
  required int targetCount,
  String? unitLabel,
  required int templateIndex,
}) {
  final pool = _habitPools[tone]!;
  final template = pool[_wrap(templateIndex, pool.length)];
  final unit = (unitLabel == null || unitLabel.isEmpty) ? '' : ' $unitLabel';
  return template
      .replaceAll('{target}', '$targetCount$unit')
      .replaceAll('{s}', '$currentStreak');
}

// ─────────────────────────────────────────────────────── task digest

/// Title/body pairs for the daily task digest.
///
/// `{counts}` is the already-joined count phrase ("3 due today · 1 overdue"),
/// which stays intact for the same reason the task reminder's time does: it is
/// the information the digest exists to deliver. Only the framing varies.
const List<(String, String)> _taskDigestPool = [
  ('Today', '{counts}'),
  ("Here's today", '{counts}'),
  ('Your day at a glance', '{counts}'),
];

/// How many task-digest variants there are.
int taskDigestVariantCount() => _taskDigestPool.length;

/// The digest's `(title, body)` for [countsPhrase].
///
/// [templateIndex] is wrapped into range.
(String, String) taskDigestContent({
  required String countsPhrase,
  required int templateIndex,
}) {
  final (title, body) =
      _taskDigestPool[_wrap(templateIndex, _taskDigestPool.length)];
  return (title, body.replaceAll('{counts}', countsPhrase));
}
