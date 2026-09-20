/// Event types defined in SPEC.md §2.2.
abstract final class EventTypes {
  // Session events
  static const sessionStarted = 'session_started';
  static const sessionCompleted = 'session_completed';
  static const sessionAbandoned = 'session_abandoned';
  static const sessionInterrupted = 'session_interrupted';
  static const breakStarted = 'break_started';
  static const breakCompleted = 'break_completed';

  // Task events
  static const taskCreated = 'task_created';
  static const taskCompleted = 'task_completed';
  static const taskUncompleted = 'task_uncompleted';
  static const taskRescheduled = 'task_rescheduled';
  static const taskArchived = 'task_archived';
  static const taskDeleted = 'task_deleted';

  // Habit events (SPEC.md §10.1). The four check-off events were reserved in
  // v1; the lifecycle events below were added with the feature, because §0
  // requires every user action to be an event and creating a habit is one.
  static const habitCreated = 'habit_created';
  static const habitUpdated = 'habit_updated';
  static const habitArchived = 'habit_archived';
  static const habitRestored = 'habit_restored';
  static const habitDeleted = 'habit_deleted';
  static const habitChecked = 'habit_checked';
  static const habitUnchecked = 'habit_unchecked';
  static const habitSkipped = 'habit_skipped';

  /// Written *in addition to* [habitSkipped], when that skip falls inside the
  /// month's allowance and therefore protects the streak. Two facts, two
  /// events: what the user did, and what it cost them.
  static const habitFreezeUsed = 'habit_freeze_used';
  static const habitNoteSet = 'habit_note_set';

  // Reminder config events (SPEC.md §10.4/§11). Each carries the item's
  // *entire* desired set of reminders in its payload — replaying the latest
  // one per subject reproduces the live `task_reminder_offsets` /
  // `habit_reminder_times` rows exactly, so no per-row add/remove events are
  // needed.
  static const taskReminderOffsetsSet = 'task_reminder_offsets_set';
  static const habitReminderTimesSet = 'habit_reminder_times_set';
}

/// Habit statuses defined in SPEC.md §10.1.
abstract final class HabitStatuses {
  static const active = 'active';
  static const archived = 'archived';
}

/// Subject types defined in SPEC.md §2.1.
abstract final class SubjectTypes {
  static const session = 'session';
  static const task = 'task';
  static const habit = 'habit';
}

/// Session modes defined in SPEC.md §2.3.
abstract final class SessionModes {
  static const pomodoro = 'pomodoro';
  static const flow = 'flow';
}

/// Session outcomes defined in SPEC.md §2.3.
abstract final class SessionOutcomes {
  static const completed = 'completed';
  static const abandoned = 'abandoned';
}

/// Session abandonment reasons defined in SPEC.md §2.2.
abstract final class AbandonReasons {
  static const userStopped = 'user_stopped';
  static const strictModeForfeit = 'strict_mode_forfeit';
}

/// Interruption kinds defined in SPEC.md §2.2.
abstract final class InterruptionKinds {
  static const internalKind = 'internal';
  static const externalKind = 'external';
}

/// Task statuses defined in SPEC.md §2.4.
abstract final class TaskStatuses {
  static const open = 'open';
  static const done = 'done';
  static const archived = 'archived';
}

/// Recurrence modes defined in SPEC.md §2.6.
abstract final class RecurrenceModes {
  static const onSchedule = 'on_schedule';
  static const afterCompletion = 'after_completion';
}
