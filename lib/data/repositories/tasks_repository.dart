import 'package:drift/drift.dart';

import '../../core/ids.dart';
import '../../core/recurrence/recurrence.dart';
import '../../core/time/time_service.dart';
import '../../features/reminders/reminder_service.dart';
import '../database/app_database.dart';
import 'events_repository.dart';
import 'reminder_config_repository.dart';
import 'settings_repository.dart';

/// Task with associated project, tags, and subtasks for presentation.
class TaskWithDetails {
  const TaskWithDetails({
    required this.task,
    this.project,
    this.tags = const [],
    this.subtasks = const [],
  });

  final Task task;
  final Project? project;
  final List<Tag> tags;
  final List<Task> subtasks;

  String get id => task.id;
  String get title => task.title;
  String? get notes => task.notes;
  int get priority => task.priority;
  int? get dueAt => task.dueAt;
  bool get dueIsAllDay => task.dueIsAllDay;
  int? get estimatePomodoros => task.estimatePomodoros;
  String get status => task.status;
  bool get isOpen => task.status == 'open';
  bool get isDone => task.status == 'done';
  bool get isArchived => task.status == 'archived';
  int get rescheduleCount => task.rescheduleCount;
  String? get recurrenceRule => task.recurrenceRule;
  String? get recurrenceMode => task.recurrenceMode;
  bool get isRecurring => task.recurrenceRule != null && task.recurrenceRule!.isNotEmpty;
  String? get parentId => task.parentId;
  bool get isSubtask => task.parentId != null;
}

/// Represents an archived task with its timestamp of archival per §2.2.
class ArchivedTaskItem {
  const ArchivedTaskItem({
    required this.taskDetails,
    required this.archivedAtMs,
  });

  final TaskWithDetails taskDetails;
  final int archivedAtMs;

  Task get task => taskDetails.task;
  Project? get project => taskDetails.project;
  List<Tag> get tags => taskDetails.tags;
  String get id => task.id;
  String get title => task.title;
  int get priority => task.priority;
}

/// History details for a task before deletion (§3).
class TaskHistoryInfo {
  const TaskHistoryInfo({
    required this.completionsCount,
    required this.focusSessionsCount,
    required this.completedSeriesInstancesCount,
  });

  final int completionsCount;
  final int focusSessionsCount;
  final int completedSeriesInstancesCount;

  bool get hasHistory =>
      completionsCount > 0 ||
      focusSessionsCount > 0 ||
      completedSeriesInstancesCount > 0;

  String buildWarningMessage(String title) {
    final parts = <String>[];
    final totalCompletions = completionsCount > 0
        ? completionsCount
        : completedSeriesInstancesCount;
    if (totalCompletions > 0) {
      parts.add('$totalCompletions ${totalCompletions == 1 ? 'completion' : 'completions'}');
    }
    if (focusSessionsCount > 0) {
      parts.add('$focusSessionsCount focus ${focusSessionsCount == 1 ? 'session' : 'sessions'}');
    }
    final historyDesc = parts.isNotEmpty ? parts.join(' and ') : 'history';
    return '$title has $historyDesc. Deleting removes it from your history and past statistics will change.';
  }
}

/// In-memory handle representing a task staged for deletion during the 6-second undo window (§6).
class PendingTaskDeletion {
  PendingTaskDeletion({
    required this.taskId,
    required Future<void> Function() onUndo,
    required Future<void> Function() onCommit,
  })  : _undo = onUndo,
        _commit = onCommit;

  final String taskId;
  final Future<void> Function() _undo;
  final Future<void> Function() _commit;

  bool _committed = false;
  bool _undone = false;

  bool get isResolved => _committed || _undone;

  Future<void> undo() async {
    if (isResolved) return;
    _undone = true;
    await _undo();
  }

  Future<void> commit() async {
    if (isResolved) return;
    _committed = true;
    await _commit();
  }
}

/// Standard task comparator per §1.1:
/// - Open tasks first, completed tasks last.
/// - For open tasks:
///   a. priority ascending (1 is highest: 1 < 2 < 3 < 4)
///   b. overdue tasks sort above today's; then due time ascending; tasks with no time last
///   c. then created_at ascending
int compareTasks(Task a, Task b, TimeService timeService, [String? referenceLocalDate]) {
  final today = referenceLocalDate ?? timeService.todayLocalDate();

  // 1. Open work on top, finished work at bottom
  if (a.status == 'open' && b.status != 'open') return -1;
  if (a.status != 'open' && b.status == 'open') return 1;

  // 2. Priority ascending (1 is highest: 1 < 2 < 3 < 4)
  final priorityComp = a.priority.compareTo(b.priority);
  if (priorityComp != 0) return priorityComp;

  // 3. Due time comparison:
  final aDue = a.dueAt;
  final bDue = b.dueAt;

  if (aDue != null || bDue != null) {
    final aDate = aDue != null ? timeService.computeLocalDate(aDue) : null;
    final bDate = bDue != null ? timeService.computeLocalDate(bDue) : null;

    final aOverdue = aDate != null && aDate.compareTo(today) < 0;
    final bOverdue = bDate != null && bDate.compareTo(today) < 0;

    // Overdue tasks sort above today's (and upcoming/none)
    if (aOverdue && !bOverdue) return -1;
    if (!aOverdue && bOverdue) return 1;

    // If both overdue or neither overdue:
    if (aDate != null && bDate != null && aDate != bDate) {
      final dateComp = aDate.compareTo(bDate);
      if (dateComp != 0) return dateComp;
    }

    // Specific time vs no time (all-day / null)
    final aHasTime = aDue != null && !a.dueIsAllDay;
    final bHasTime = bDue != null && !b.dueIsAllDay;

    if (aHasTime && !bHasTime) return -1;
    if (!aHasTime && bHasTime) return 1;

    if (aHasTime && bHasTime) {
      final timeComp = aDue.compareTo(bDue);
      if (timeComp != 0) return timeComp;
    }
  }

  // 4. created_at ascending
  final createdComp = a.createdAt.compareTo(b.createdAt);
  if (createdComp != 0) return createdComp;

  return a.id.compareTo(b.id);
}

/// Repository for managing tasks per SPEC.md §0, §2.2, §2.4, §2.6, and §4.12.
///
/// Implements event-sourcing: every state mutation logs an immutable event to `events`.
/// The `tasks` table is a read model derived from those events, never the source of truth.
class TasksRepository {
  TasksRepository({
    required this.db,
    required this.eventsRepository,
    required this.timeService,
    this.deviceId = 'default-device-id',
    this.reminderService,
    this.reminderConfigRepository,
  });

  final AppDatabase db;
  final EventsRepository eventsRepository;
  final TimeService timeService;
  final String deviceId;
  final ReminderService? reminderService;

  /// Reminder-offset reads and writes go through here — nothing outside it
  /// writes to `task_reminder_offsets`. The fallback logs no event of its
  /// own besides `task_reminder_offsets_set`, which correctly attributes to
  /// this device id regardless of which instance did the writing.
  final ReminderConfigRepository? reminderConfigRepository;
  late final ReminderConfigRepository _reminderConfig =
      reminderConfigRepository ??
          ReminderConfigRepository(
            db: db,
            eventsRepository: eventsRepository,
            settingsRepo: SettingsRepository(db: db),
            timeService: timeService,
            deviceId: deviceId,
          );

  AppDatabase get _db => db;

  final Set<String> _pendingDeletionIds = {};

  bool isPendingDeletion(String taskId) => _pendingDeletionIds.contains(taskId);

  // ── Task Creation ──────────────────────────────────────────────────────────

  /// Creates a new task and writes an immutable `task_created` event per §2.2.
  ///
  /// Subtask rule (§2.4): enforces at most one level of subtask nesting.
  Future<Task> createTask({
    required String title,
    String? notes,
    String? projectId,
    String? parentId,
    int priority = 4,
    int? dueAt,
    bool dueIsAllDay = false,
    int? estimatePomodoros,
    String? recurrenceRule,
    String? recurrenceMode,
    List<String> tagNames = const [],
    double sortOrder = 0.0,
  }) async {
    // Validate single-level subtask constraint (§2.4)
    if (parentId != null) {
      final parent = await getTask(parentId);
      if (parent == null) {
        throw ArgumentError('Parent task $parentId does not exist.');
      }
      if (parent.parentId != null) {
        throw ArgumentError('Subtasks cannot be nested more than one level.');
      }
    }

    final nowUtcMs = timeService.nowUtcMs();
    final todayLocalDate = timeService.todayLocalDate();
    final taskId = newId();

    // 1. Insert tasks read-model row
    final companion = TasksCompanion.insert(
      id: taskId,
      title: title,
      notes: notes != null ? Value(notes) : const Value.absent(),
      projectId: projectId != null ? Value(projectId) : const Value.absent(),
      parentId: parentId != null ? Value(parentId) : const Value.absent(),
      priority: Value(priority),
      dueAt: dueAt != null ? Value(dueAt) : const Value.absent(),
      dueIsAllDay: Value(dueIsAllDay),
      estimatePomodoros: estimatePomodoros != null
          ? Value(estimatePomodoros)
          : const Value.absent(),
      status: const Value('open'),
      createdAt: nowUtcMs,
      createdLocalDate: todayLocalDate,
      rescheduleCount: const Value(0),
      recurrenceRule: recurrenceRule != null ? Value(recurrenceRule) : const Value.absent(),
      recurrenceMode: recurrenceMode != null ? Value(recurrenceMode) : const Value.absent(),
      sortOrder: Value(sortOrder),
      updatedAt: nowUtcMs,
      deviceId: deviceId,
      deletedAt: const Value(null),
    );

    await _db.into(_db.tasks).insert(companion);

    // 2. Associate tags
    if (tagNames.isNotEmpty) {
      await _attachTagsToTask(taskId, tagNames);
    }

    // 3. Write immutable event (§2.2)
    final payload = <String, dynamic>{
      'title': title,
      'project_id': ?projectId,
      'priority': priority,
      'due_at': ?dueAt,
      'estimate_pomodoros': ?estimatePomodoros,
      'parent_id': ?parentId,
      'recurrence_rule': ?recurrenceRule,
      'recurrence_mode': ?recurrenceMode,
      'due_is_all_day': dueIsAllDay,
    };

    await eventsRepository.logEvent(
      type: 'task_created',
      subjectType: 'task',
      subjectId: taskId,
      payload: payload,
    );

    // A brand-new timed task starts with the current global default
    // countdown offsets (SPEC §11) — every creation path gets this for free,
    // not just the edit sheet, so quick capture and a recurring series'
    // next instance land the same way a manually created task does. A
    // caller that wants something different (or nothing) writes over it
    // afterwards with `ReminderConfigRepository.setTaskReminderOffsets` —
    // that call always replaces the full set, so this seed is never additive.
    if (dueAt != null && !dueIsAllDay) {
      await _reminderConfig.seedDefaultTaskReminderOffsets(taskId);
    }

    final created = (await getTask(taskId))!;
    if (created.dueAt != null) {
      await reminderService?.scheduleFor(created);
      return (await getTask(taskId))!;
    }
    return created;
  }

  // ── Task Completion & Recurrence ───────────────────────────────────────────

  /// Completes a task:
  /// - Writes `task_completed` event per §2.2.
  /// - Sets `status = 'done'`, `completed_at`, `completed_local_date`, `updated_at`, and `device_id`.
  /// - If recurring (§2.6), advances via [nextOccurrence] and creates the next instance
  ///   linked by `recurrence_parent_id`.
  Future<void> completeTask(String taskId) async {
    final task = await getTask(taskId);
    if (task == null || task.status == 'done') return;

    final nowUtcMs = timeService.nowUtcMs();
    final todayLocalDate = timeService.todayLocalDate();

    // 1. Mark this instance done
    await (_db.update(_db.tasks)..where((t) => t.id.equals(taskId))).write(
      TasksCompanion(
        status: const Value('done'),
        completedAt: Value(nowUtcMs),
        completedLocalDate: Value(todayLocalDate),
        updatedAt: Value(nowUtcMs),
        deviceId: Value(deviceId),
      ),
    );

    // Cancel scheduled reminder for completed task
    await reminderService?.cancelFor(task);

    // 2. Log immutable event
    await eventsRepository.logEvent(
      type: 'task_completed',
      subjectType: 'task',
      subjectId: taskId,
      payload: const {},
    );

    // 3. Handle recurring task (§2.6)
    if (task.recurrenceRule != null && task.recurrenceRule!.isNotEmpty) {
      await _spawnNextRecurrenceInstance(task, todayLocalDate);
    }
  }

  /// Spawns the next instance of a recurring task per SPEC.md §2.6.
  Future<void> _spawnNextRecurrenceInstance(Task completedTask, String completedLocalDate) async {
    final rule = RecurrenceRule.parse(completedTask.recurrenceRule);
    if (rule == null) return;

    final mode = completedTask.recurrenceMode == 'after_completion'
        ? RecurrenceMode.afterCompletion
        : RecurrenceMode.onSchedule;

    final scheduledLocalDate = completedTask.dueAt != null
        ? timeService.computeLocalDate(completedTask.dueAt!)
        : completedLocalDate;

    final nextLocalDate = nextOccurrence(
      rule: rule,
      mode: mode,
      scheduledDate: scheduledLocalDate,
      completedDate: completedLocalDate,
      todayLocalDate: timeService.todayLocalDate(),
    );

    if (nextLocalDate == null) return;

    // Compute dueAt UTC ms preserving original time of day if not all-day
    int nextDueAtUtcMs;
    if (completedTask.dueIsAllDay || completedTask.dueAt == null) {
      final parts = nextLocalDate.split('-');
      nextDueAtUtcMs = DateTime.utc(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
        12, // midday default for all-day
      ).millisecondsSinceEpoch;
    } else {
      final originalLocal = timeService.toLocal(completedTask.dueAt!);
      final parts = nextLocalDate.split('-');
      final nextLocalDt = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
        originalLocal.hour,
        originalLocal.minute,
        originalLocal.second,
      );
      nextDueAtUtcMs = timeService.toUtcMs(nextLocalDt);
    }

    final nowUtcMs = timeService.nowUtcMs();
    final todayLocalDate = timeService.todayLocalDate();
    final recurrenceParentId = completedTask.recurrenceParentId ?? completedTask.id;

    // Duplicate guard (§2.6 / PART 3): check if an open non-deleted instance already exists
    final existingOpenTasks = await (_db.select(_db.tasks)
          ..where((t) =>
              (t.id.equals(recurrenceParentId) | t.recurrenceParentId.equals(recurrenceParentId)) &
              t.status.equals('open') &
              t.dueAt.isNotNull() &
              t.deletedAt.isNull()))
        .get();

    final duplicateExists = existingOpenTasks.any((t) {
      final localDate = timeService.computeLocalDate(t.dueAt!);
      return localDate == nextLocalDate;
    });

    if (duplicateExists) {
      return;
    }

    final newTaskId = newId();

    // Insert next instance into read model
    final companion = TasksCompanion.insert(
      id: newTaskId,
      title: completedTask.title,
      notes: completedTask.notes != null ? Value(completedTask.notes) : const Value.absent(),
      projectId: completedTask.projectId != null
          ? Value(completedTask.projectId)
          : const Value.absent(),
      parentId: completedTask.parentId != null
          ? Value(completedTask.parentId)
          : const Value.absent(),
      priority: Value(completedTask.priority),
      dueAt: Value(nextDueAtUtcMs),
      dueIsAllDay: Value(completedTask.dueIsAllDay),
      estimatePomodoros: completedTask.estimatePomodoros != null
          ? Value(completedTask.estimatePomodoros)
          : const Value.absent(),
      status: const Value('open'),
      createdAt: nowUtcMs,
      createdLocalDate: todayLocalDate,
      rescheduleCount: const Value(0),
      recurrenceRule: Value(completedTask.recurrenceRule),
      recurrenceMode: Value(completedTask.recurrenceMode),
      recurrenceParentId: Value(recurrenceParentId),
      sortOrder: Value(completedTask.sortOrder),
      updatedAt: nowUtcMs,
      deviceId: deviceId,
      deletedAt: const Value(null),
    );

    await _db.into(_db.tasks).insert(companion);

    // Copy tags from parent task
    final existingTags = await getTagsForTask(completedTask.id);
    for (final tag in existingTags) {
      await _db.into(_db.taskTags).insert(
        TaskTagsCompanion.insert(taskId: newTaskId, tagId: tag.id),
      );
    }

    // Log task_created for next instance
    await eventsRepository.logEvent(
      type: 'task_created',
      subjectType: 'task',
      subjectId: newTaskId,
      payload: {
        'title': completedTask.title,
        if (completedTask.projectId != null) 'project_id': completedTask.projectId,
        'priority': completedTask.priority,
        'due_at': nextDueAtUtcMs,
        if (completedTask.estimatePomodoros != null)
          'estimate_pomodoros': completedTask.estimatePomodoros,
        if (completedTask.recurrenceRule != null)
          'recurrence_rule': completedTask.recurrenceRule,
        if (completedTask.recurrenceMode != null)
          'recurrence_mode': completedTask.recurrenceMode,
        'recurrence_parent_id': recurrenceParentId,
      },
    );

    final nextTask = await getTask(newTaskId);
    if (nextTask != null && nextTask.dueAt != null) {
      await reminderService?.scheduleFor(nextTask);
    }
  }

  // ── Task Uncompletion (Undo) ───────────────────────────────────────────────

  /// Uncompletes a task (undo):
  /// - Writes `task_uncompleted` event per §2.2.
  /// - Sets `status = 'open'`, `completed_at = null`, `completed_local_date = null`, `updated_at`, `device_id`.
  Future<void> uncompleteTask(String taskId) async {
    final task = await getTask(taskId);
    if (task == null || task.status != 'done') return;
    final nowUtcMs = timeService.nowUtcMs();

    await (_db.update(_db.tasks)..where((t) => t.id.equals(taskId))).write(
      TasksCompanion(
        status: const Value('open'),
        completedAt: const Value(null),
        completedLocalDate: const Value(null),
        updatedAt: Value(nowUtcMs),
        deviceId: Value(deviceId),
      ),
    );

    await eventsRepository.logEvent(
      type: 'task_uncompleted',
      subjectType: 'task',
      subjectId: taskId,
      payload: const {},
    );

    final reopened = await getTask(taskId);
    if (reopened != null && reopened.dueAt != null) {
      await reminderService?.scheduleFor(reopened);
    }
  }

  // ── Task Rescheduling & Procrastination Index (§4.12) ──────────────────────

  /// Reschedules a task to a new due date/time.
  ///
  /// Increments `reschedule_count` ONLY when the new due date is strictly later
  /// than the previous due date per SPEC.md §4.12.
  Future<void> rescheduleTask(
    String taskId, {
    required int? newDueAt,
    bool dueIsAllDay = false,
  }) async {
    final task = await getTask(taskId);
    if (task == null) return;

    final oldDueAt = task.dueAt;
    var newRescheduleCount = task.rescheduleCount;
    final nowUtcMs = timeService.nowUtcMs();

    // Reschedule count rule (§4.12): increments ONLY when moved later
    if (oldDueAt != null && newDueAt != null && newDueAt > oldDueAt) {
      newRescheduleCount += 1;
    }

    await (_db.update(_db.tasks)..where((t) => t.id.equals(taskId))).write(
      TasksCompanion(
        dueAt: Value(newDueAt),
        dueIsAllDay: Value(dueIsAllDay),
        rescheduleCount: Value(newRescheduleCount),
        updatedAt: Value(nowUtcMs),
        deviceId: Value(deviceId),
      ),
    );

    await eventsRepository.logEvent(
      type: 'task_rescheduled',
      subjectType: 'task',
      subjectId: taskId,
      payload: {
        'from_due_at': oldDueAt,
        'to_due_at': newDueAt,
      },
    );

    final rescheduled = await getTask(taskId);
    if (rescheduled != null) {
      if (rescheduled.dueAt != null) {
        await reminderService?.scheduleFor(rescheduled);
      } else {
        await reminderService?.cancelFor(rescheduled);
      }
    }
  }

  /// Convenience method: defers an open task to tomorrow at noon.
  Future<void> deferToTomorrow(String taskId) async {
    final task = await getTask(taskId);
    if (task == null) return;

    final tomorrowLocalDate = TimeService.addDays(timeService.todayLocalDate(), 1);
    final parts = tomorrowLocalDate.split('-');
    final tomorrowNoon = DateTime.utc(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
      12,
    ).millisecondsSinceEpoch;

    await rescheduleTask(
      taskId,
      newDueAt: tomorrowNoon,
      dueIsAllDay: true,
    );
  }

  // ── Task Archival ─────────────────────────────────────────────────────────

  /// Soft deletes a task per §6 and §2.2: sets `status = 'archived'`.
  /// Never hard-deletes; past statistics and event history are preserved.
  Future<void> archiveTask(String taskId) async {
    final task = await getTask(taskId);
    if (task == null || task.status == 'archived') return;
    final nowUtcMs = timeService.nowUtcMs();

    await (_db.update(_db.tasks)..where((t) => t.id.equals(taskId))).write(
      TasksCompanion(
        status: const Value('archived'),
        updatedAt: Value(nowUtcMs),
        deviceId: Value(deviceId),
      ),
    );

    await eventsRepository.logEvent(
      type: 'task_archived',
      subjectType: 'task',
      subjectId: taskId,
      payload: const {},
    );

    await reminderService?.cancelFor(task);
  }

  /// Restores an archived task back to 'open' (§2.3).
  Future<String> restoreTask(String taskId) async {
    final task = await getTask(taskId);
    if (task == null || task.status != 'archived') {
      return 'Today';
    }

    final todayLocalDate = timeService.todayLocalDate();
    final destination = _computeDestination(task.dueAt, todayLocalDate);

    // If the task belongs to a still-active recurring series, check for
    // an existing open instance on that due date first.
    if (task.recurrenceRule != null || task.recurrenceParentId != null) {
      final recurrenceParentId = task.recurrenceParentId ?? task.id;
      if (task.dueAt != null) {
        final taskLocalDate = timeService.computeLocalDate(task.dueAt!);
        final existingOpen = await (_db.select(_db.tasks)
              ..where((t) =>
                  (t.id.equals(recurrenceParentId) |
                      t.recurrenceParentId.equals(recurrenceParentId)) &
                  t.status.equals('open') &
                  t.dueAt.isNotNull() &
                  t.deletedAt.isNull()))
            .get();

        final hasDuplicateOnDate = existingOpen.any((t) =>
            t.id != task.id &&
            timeService.computeLocalDate(t.dueAt!) == taskLocalDate);

        if (hasDuplicateOnDate) {
          return destination;
        }
      }
    }

    final wasDone = task.completedAt != null;
    final nowUtcMs = timeService.nowUtcMs();

    // Update status to 'open' (and reset completed timestamps if it was done)
    await (_db.update(_db.tasks)..where((t) => t.id.equals(taskId))).write(
      TasksCompanion(
        status: const Value('open'),
        completedAt: const Value(null),
        completedLocalDate: const Value(null),
        updatedAt: Value(nowUtcMs),
        deviceId: Value(deviceId),
      ),
    );

    // If it had been completed, write task_uncompleted per §2.3
    if (wasDone) {
      await eventsRepository.logEvent(
        type: 'task_uncompleted',
        subjectType: 'task',
        subjectId: taskId,
        payload: const {},
      );
    }

    return destination;
  }

  String _computeDestination(int? dueAtUtcMs, String todayLocalDate) {
    if (dueAtUtcMs == null) return 'Inbox';
    final taskLocalDate = timeService.computeLocalDate(dueAtUtcMs);
    if (taskLocalDate.compareTo(todayLocalDate) > 0) {
      return 'Upcoming';
    }
    return 'Today';
  }

  // ── Task Deletion (§2, §3, §4, §6) ──────────────────────────────────────────

  /// Checks if a task has history per §3:
  /// - Ever completed
  /// - Has focus sessions attached
  /// - Has completed instances in its recurring series
  Future<TaskHistoryInfo> checkTaskHistory(String taskId) async {
    final task = await getTask(taskId);
    if (task == null) {
      return const TaskHistoryInfo(
        completionsCount: 0,
        focusSessionsCount: 0,
        completedSeriesInstancesCount: 0,
      );
    }

    // 1. Completion count:
    final completionEvents = await (_db.select(_db.events)
          ..where((e) =>
              e.subjectType.equals('task') &
              e.subjectId.equals(taskId) &
              e.type.equals('task_completed')))
        .get();
    var completionsCount = completionEvents.length;
    if (completionsCount == 0 && (task.status == 'done' || task.completedAt != null)) {
      completionsCount = 1;
    }

    // 2. Focus sessions attached to this task:
    final sessions = await (_db.select(_db.focusSessions)
          ..where((s) => s.taskId.equals(taskId)))
        .get();
    var focusSessionsCount = sessions.length;

    // 3. Completed instances in recurring series (§3):
    var completedSeriesInstancesCount = 0;
    if (task.recurrenceRule != null || task.recurrenceParentId != null) {
      final seriesParentId = task.recurrenceParentId ?? task.id;
      final seriesTasks = await (_db.select(_db.tasks)
            ..where((t) =>
                (t.id.equals(seriesParentId) |
                    t.recurrenceParentId.equals(seriesParentId)) &
                t.deletedAt.isNull()))
          .get();

      completedSeriesInstancesCount =
          seriesTasks.where((t) => t.status == 'done').length;

      final seriesTaskIds = seriesTasks.map((t) => t.id).toSet();
      final seriesSessions = await (_db.select(_db.focusSessions)
            ..where((s) => s.taskId.isIn(seriesTaskIds)))
          .get();
      if (seriesSessions.length > focusSessionsCount) {
        focusSessionsCount = seriesSessions.length;
      }
    }

    return TaskHistoryInfo(
      completionsCount: completionsCount,
      focusSessionsCount: focusSessionsCount,
      completedSeriesInstancesCount: completedSeriesInstancesCount,
    );
  }

  /// Deletes a task, its subtasks, and marks rows tombstoned per §4 and §6.
  /// Writes a `task_deleted` event to the immutable events log first.
  ///
  /// Recurring series handling (§4):
  /// - If [deleteSeries] is true: stops new instances spawning by clearing
  ///   recurrence rules and deleting other open future instances.
  /// - If [deleteCompletedSeriesInstances] is true: also deletes already-completed
  ///   instances in the series.
  Future<void> deleteTask(
    String taskId, {
    bool deleteSeries = false,
    bool deleteCompletedSeriesInstances = false,
  }) async {
    final task = await getTask(taskId);
    if (task == null) return;

    await reminderService?.cancelFor(task);

    final history = await checkTaskHistory(taskId);
    final wasDone = task.status == 'done' || task.completedAt != null;
    final hadCompletions = wasDone || history.completionsCount > 0;
    final nowUtcMs = timeService.nowUtcMs();

    // 1. Write task_deleted event first (§2)
    await eventsRepository.logEvent(
      type: 'task_deleted',
      subjectType: 'task',
      subjectId: taskId,
      payload: {
        'title': task.title,
        'was_completed': wasDone,
        'ever_completed': hadCompletions,
        'created_local_date': task.createdLocalDate,
        if (task.projectId != null) 'project_id': task.projectId,
        'priority': task.priority,
        if (task.recurrenceParentId != null)
          'recurrence_parent_id': task.recurrenceParentId,
      },
    );

    // 2. Handle recurring series (§4)
    if (deleteSeries &&
        (task.recurrenceRule != null || task.recurrenceParentId != null)) {
      final seriesParentId = task.recurrenceParentId ?? task.id;

      // Stop new instances spawning: clear recurrence rule and mode across the series
      await (_db.update(_db.tasks)
            ..where((t) =>
                (t.id.equals(seriesParentId) |
                    t.recurrenceParentId.equals(seriesParentId)) &
                t.deletedAt.isNull()))
          .write(
        TasksCompanion(
          recurrenceRule: const Value(null),
          recurrenceMode: const Value(null),
          updatedAt: Value(nowUtcMs),
          deviceId: Value(deviceId),
        ),
      );

      // Delete other open future instances of the series
      final otherOpenSeries = await (_db.select(_db.tasks)
            ..where((t) =>
                (t.id.equals(seriesParentId) |
                    t.recurrenceParentId.equals(seriesParentId)) &
                t.id.isNotValue(taskId) &
                t.status.equals('open') &
                t.deletedAt.isNull()))
          .get();

      for (final other in otherOpenSeries) {
        await deleteTask(other.id);
      }

      // Delete already-completed instances if chosen (§4)
      if (deleteCompletedSeriesInstances) {
        final completedSeries = await (_db.select(_db.tasks)
              ..where((t) =>
                  (t.id.equals(seriesParentId) |
                      t.recurrenceParentId.equals(seriesParentId)) &
                  t.id.isNotValue(taskId) &
                  t.status.equals('done') &
                  t.deletedAt.isNull()))
            .get();

        for (final completed in completedSeries) {
          await deleteTask(completed.id);
        }
      }
    }

    // 3. Delete subtasks (§2)
    final subtasks = await (_db.select(_db.tasks)
          ..where((t) => t.parentId.equals(taskId) & t.deletedAt.isNull()))
        .get();
    for (final sub in subtasks) {
      await deleteTask(sub.id);
    }

    // 4. Tombstone the tasks row (§4, §6)
    await (_db.update(_db.tasks)..where((t) => t.id.equals(taskId))).write(
      TasksCompanion(
        deletedAt: Value(nowUtcMs),
        updatedAt: Value(nowUtcMs),
        deviceId: Value(deviceId),
      ),
    );

    _pendingDeletionIds.remove(taskId);
  }

  /// Deletes all archived tasks (§1) and writes task_deleted for each.
  Future<int> deleteAllArchived() async {
    final archived = await (_db.select(_db.tasks)
          ..where((t) =>
              t.status.equals('archived') &
              t.parentId.isNull() &
              t.deletedAt.isNull()))
        .get();

    for (final task in archived) {
      await deleteTask(task.id);
    }
    return archived.length;
  }

  /// Stages task deletion in memory for the 6-second undo window (§6).
  ///
  /// Holds the task row in memory without touching SQLite.
  /// If undo() is called, task is restored instantly.
  /// If commit() is called, deleteTask() executes.
  Future<PendingTaskDeletion> stageDeleteTask(String taskId) async {
    final subtasks = await (_db.select(_db.tasks)
          ..where((t) => t.parentId.equals(taskId) & t.deletedAt.isNull()))
        .get();
    final idsToHide = {taskId, ...subtasks.map((s) => s.id)};

    _pendingDeletionIds.addAll(idsToHide);
    _notifyTasksChanged();

    return PendingTaskDeletion(
      taskId: taskId,
      onUndo: () async {
        _pendingDeletionIds.removeAll(idsToHide);
        _notifyTasksChanged();
      },
      onCommit: () async {
        _pendingDeletionIds.removeAll(idsToHide);
        await deleteTask(taskId);
      },
    );
  }

  void _notifyTasksChanged() {
    try {
      _db.notifyUpdates({TableUpdate.onTable(_db.tasks)});
    } catch (_) {}
  }

  // ── Task Updates ──────────────────────────────────────────────────────────

  /// Updates task details (title, notes, priority, estimate, project).
  Future<void> updateTask(
    String taskId, {
    String? title,
    String? notes,
    String? projectId,
    bool clearProject = false,
    int? priority,
    int? estimatePomodoros,
    bool clearEstimate = false,
    String? recurrenceRule,
    String? recurrenceMode,
    bool clearRecurrence = false,
  }) async {
    final nowUtcMs = timeService.nowUtcMs();
    final companion = TasksCompanion(
      title: title != null ? Value(title) : const Value.absent(),
      notes: notes != null ? Value(notes) : const Value.absent(),
      projectId: clearProject
          ? const Value(null)
          : (projectId != null ? Value(projectId) : const Value.absent()),
      priority: priority != null ? Value(priority) : const Value.absent(),
      estimatePomodoros: clearEstimate
          ? const Value(null)
          : (estimatePomodoros != null
              ? Value(estimatePomodoros)
              : const Value.absent()),
      recurrenceRule: clearRecurrence
          ? const Value(null)
          : (recurrenceRule != null ? Value(recurrenceRule) : const Value.absent()),
      recurrenceMode: clearRecurrence
          ? const Value(null)
          : (recurrenceMode != null ? Value(recurrenceMode) : const Value.absent()),
      updatedAt: Value(nowUtcMs),
      deviceId: Value(deviceId),
    );

    await (_db.update(_db.tasks)..where((t) => t.id.equals(taskId))).write(companion);

    final updated = await getTask(taskId);
    if (updated != null) {
      if (updated.dueAt != null) {
        await reminderService?.scheduleFor(updated);
      } else {
        await reminderService?.cancelFor(updated);
      }
    }
  }

  // ── Queries & Streams ─────────────────────────────────────────────────────

  /// Fetches a single non-deleted task by ID.
  Future<Task?> getTask(String taskId) {
    return (_db.select(_db.tasks)
          ..where((t) => t.id.equals(taskId) & t.deletedAt.isNull()))
        .getSingleOrNull();
  }

  /// Watches a task with its project and tags.
  Stream<TaskWithDetails?> watchTaskWithDetails(String taskId) {
    return (_db.select(_db.tasks)
          ..where((t) => t.id.equals(taskId) & t.deletedAt.isNull()))
        .watchSingleOrNull()
        .asyncMap((task) async {
      if (task == null || _pendingDeletionIds.contains(task.id)) return null;
      return _enrichTask(task);
    });
  }

  /// Watches all open subtasks for a parent task.
  Stream<List<Task>> watchSubtasks(String parentId) {
    return (_db.select(_db.tasks)
          ..where((t) =>
              t.parentId.equals(parentId) &
              t.status.isNotValue('archived') &
              t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch()
        .map((tasks) =>
            tasks.where((t) => !_pendingDeletionIds.contains(t.id)).toList());
  }

  /// Watches tasks for the **Today** view:
  /// Includes open tasks due on [localDate] or overdue (due before [localDate]),
  /// plus tasks completed on [localDate].
  Stream<List<TaskWithDetails>> watchTodayTasks(String localDate) {
    final maxDueAtUtc = TimeService.parseLocalDate(
      TimeService.addDays(localDate, 2),
    ).millisecondsSinceEpoch;

    return (_db.select(_db.tasks)
          ..where((t) =>
              t.parentId.isNull() &
              t.deletedAt.isNull() &
              ((t.status.equals('done') & t.completedLocalDate.equals(localDate)) |
                  (t.status.equals('open') &
                      t.dueAt.isNotNull() &
                      t.dueAt.isSmallerOrEqualValue(maxDueAtUtc))))
          ..orderBy([
            (t) => OrderingTerm.asc(t.priority),
            (t) => OrderingTerm.asc(t.dueAt),
          ]))
        .watch()
        .asyncMap((tasks) async {
      final filtered = tasks.where((t) {
        if (_pendingDeletionIds.contains(t.id)) return false;
        if (t.status == 'done') {
          return t.completedLocalDate == localDate;
        }
        if (t.dueAt == null) return false;
        final taskLocalDate = timeService.computeLocalDate(t.dueAt!);
        return taskLocalDate == localDate || taskLocalDate.compareTo(localDate) < 0;
      }).toList();

      final enriched = (await _enrichTasks(filtered)).toList();
      enriched.sort((a, b) => compareTasks(a.task, b.task, timeService, localDate));
      return enriched;
    });
  }

  /// Watches all archived tasks, most recently archived first (§2.2).
  Stream<List<ArchivedTaskItem>> watchArchivedTasks() {
    return (_db.select(_db.tasks)
          ..where((t) =>
              t.status.equals('archived') &
              t.parentId.isNull() &
              t.deletedAt.isNull()))
        .watch()
        .asyncMap((tasks) async {
      final nonPending =
          tasks.where((t) => !_pendingDeletionIds.contains(t.id)).toList();
      if (nonPending.isEmpty) return <ArchivedTaskItem>[];

      final details = await _enrichTasks(nonPending);

      // Scoped query for task_archived events of only non-pending tasks.
      final taskIds = nonPending.map((t) => t.id).toList();
      final archiveEvents = await _chunkedQuery(
        taskIds,
        (chunk) => (_db.select(_db.events)
              ..where((e) =>
                  e.subjectType.equals('task') &
                  e.type.equals('task_archived') &
                  e.subjectId.isIn(chunk))
              ..orderBy([(e) => OrderingTerm.desc(e.occurredAt)]))
            .get(),
      );
      final latestArchivedAt = <String, int>{};
      for (final event in archiveEvents) {
        final subjectId = event.subjectId;
        if (subjectId != null) {
          latestArchivedAt.putIfAbsent(subjectId, () => event.occurredAt);
        }
      }

      final items = [
        for (final d in details)
          ArchivedTaskItem(
            taskDetails: d,
            archivedAtMs: latestArchivedAt[d.task.id] ??
                d.task.completedAt ??
                d.task.createdAt,
          ),
      ];

      items.sort((a, b) => b.archivedAtMs.compareTo(a.archivedAtMs));
      return items;
    });
  }

  /// Watches tasks for the **Upcoming** view:
  /// Open tasks with due dates strictly after [todayLocalDate].
  Stream<List<TaskWithDetails>> watchUpcomingTasks(String todayLocalDate) {
    final minDueAtUtc = TimeService.parseLocalDate(todayLocalDate)
        .subtract(const Duration(days: 1))
        .millisecondsSinceEpoch;

    return (_db.select(_db.tasks)
          ..where((t) =>
              t.parentId.isNull() &
              t.status.equals('open') &
              t.dueAt.isNotNull() &
              t.dueAt.isBiggerOrEqualValue(minDueAtUtc) &
              t.deletedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm.asc(t.dueAt),
            (t) => OrderingTerm.asc(t.priority),
          ]))
        .watch()
        .asyncMap((tasks) async {
      final filtered = tasks.where((t) {
        if (_pendingDeletionIds.contains(t.id)) return false;
        if (t.dueAt == null) return false;
        final taskLocalDate = timeService.computeLocalDate(t.dueAt!);
        return taskLocalDate.compareTo(todayLocalDate) > 0;
      }).toList();

      return _enrichTasks(filtered);
    });
  }

  /// Watches tasks for the **Inbox** view:
  /// Open root tasks with NO due date (`dueAt == null`).
  Stream<List<TaskWithDetails>> watchInboxTasks() {
    return (_db.select(_db.tasks)
          ..where((t) =>
              t.parentId.isNull() &
              t.status.equals('open') &
              t.dueAt.isNull() &
              t.deletedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm.asc(t.priority),
            (t) => OrderingTerm.desc(t.createdAt),
          ]))
        .watch()
        .asyncMap((tasks) {
      final nonPending = tasks.where((t) => !_pendingDeletionIds.contains(t.id)).toList();
      return _enrichTasks(nonPending);
    });
  }

  /// Helper to enrich a [Task] with its project, tags, and subtasks.
  Future<TaskWithDetails> _enrichTask(Task task) async {
    Project? project;
    if (task.projectId != null) {
      project = await (_db.select(_db.projects)
            ..where((p) => p.id.equals(task.projectId!) & p.deletedAt.isNull()))
          .getSingleOrNull();
    }
    final tags = await getTagsForTask(task.id);
    final subtasks = await (_db.select(_db.tasks)
          ..where((t) =>
              t.parentId.equals(task.id) &
              t.status.isNotValue('archived') &
              t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();

    return TaskWithDetails(
      task: task,
      project: project,
      tags: tags,
      subtasks: subtasks,
    );
  }

  static const _maxVariablesPerQuery = 500;

  Future<List<T>> _chunkedQuery<T>(
    List<String> ids,
    Future<List<T>> Function(List<String> chunk) queryFn,
  ) async {
    if (ids.length <= _maxVariablesPerQuery) {
      return queryFn(ids);
    }
    final results = <T>[];
    for (var i = 0; i < ids.length; i += _maxVariablesPerQuery) {
      final chunk = ids.sublist(
        i,
        (i + _maxVariablesPerQuery > ids.length)
            ? ids.length
            : i + _maxVariablesPerQuery,
      );
      results.addAll(await queryFn(chunk));
    }
    return results;
  }

  /// Enriches many tasks with queries scoped to the actual task list being enriched.
  Future<List<TaskWithDetails>> _enrichTasks(List<Task> tasks) async {
    if (tasks.isEmpty) return <TaskWithDetails>[];

    final taskIds = tasks.map((t) => t.id).toList();
    final projectIds = tasks
        .map((t) => t.projectId)
        .whereType<String>()
        .toSet()
        .toList();

    // 1. Fetch only relevant projects
    final List<Project> projects;
    if (projectIds.isEmpty) {
      projects = const [];
    } else {
      projects = await _chunkedQuery(
        projectIds,
        (chunk) => (_db.select(_db.projects)
              ..where((p) => p.id.isIn(chunk) & p.deletedAt.isNull()))
            .get(),
      );
    }
    final projectById = {for (final p in projects) p.id: p};

    // 2. Fetch only relevant tags
    final tagRows = await _chunkedQuery(
      taskIds,
      (chunk) => (_db.select(_db.tags).join([
        innerJoin(_db.taskTags, _db.taskTags.tagId.equalsExp(_db.tags.id)),
      ])..where(_db.taskTags.taskId.isIn(chunk) & _db.tags.deletedAt.isNull()))
          .get(),
    );
    final tagsByTaskId = <String, List<Tag>>{};
    for (final row in tagRows) {
      final taskId = row.readTable(_db.taskTags).taskId;
      (tagsByTaskId[taskId] ??= <Tag>[]).add(row.readTable(_db.tags));
    }

    // 3. Fetch only relevant subtasks
    final subtaskRows = await _chunkedQuery(
      taskIds,
      (chunk) => (_db.select(_db.tasks)
            ..where((t) =>
                t.parentId.isIn(chunk) &
                t.status.isNotValue('archived') &
                t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .get(),
    );
    final subtasksByParentId = <String, List<Task>>{};
    for (final subtask in subtaskRows) {
      final parentId = subtask.parentId;
      if (parentId != null) {
        (subtasksByParentId[parentId] ??= <Task>[]).add(subtask);
      }
    }

    final out = <TaskWithDetails>[];
    for (final task in tasks) {
      final projectId = task.projectId;
      out.add(TaskWithDetails(
        task: task,
        project: projectId == null ? null : projectById[projectId],
        tags: tagsByTaskId[task.id] ?? const <Tag>[],
        subtasks: subtasksByParentId[task.id] ?? const <Task>[],
      ));
    }
    return out;
  }

  // ── Tags Management ───────────────────────────────────────────────────────

  /// Gets all non-deleted tags associated with a non-deleted task.
  Future<List<Tag>> getTagsForTask(String taskId) async {
    final task = await getTask(taskId);
    if (task == null) return [];

    final query = _db.select(_db.tags).join([
      innerJoin(
        _db.taskTags,
        _db.taskTags.tagId.equalsExp(_db.tags.id),
      ),
    ])..where(_db.taskTags.taskId.equals(taskId) & _db.tags.deletedAt.isNull());

    final rows = await query.get();
    return rows.map((row) => row.readTable(_db.tags)).toList();
  }

  /// Attaches tags by name to a task, creating any that do not exist yet.
  Future<void> _attachTagsToTask(String taskId, List<String> tagNames) async {
    final nowUtcMs = timeService.nowUtcMs();
    for (final rawName in tagNames) {
      final clean = rawName.trim().replaceAll('#', '').toLowerCase();
      if (clean.isEmpty) continue;

      var tag = await (_db.select(_db.tags)..where((t) => t.name.equals(clean))).getSingleOrNull();
      if (tag == null) {
        final tagId = newId();
        await _db.into(_db.tags).insert(
          TagsCompanion.insert(
            id: tagId,
            name: clean,
            updatedAt: nowUtcMs,
            deviceId: deviceId,
            deletedAt: const Value(null),
          ),
        );
        tag = Tag(
          id: tagId,
          name: clean,
          updatedAt: nowUtcMs,
          deviceId: deviceId,
          deletedAt: null,
        );
      } else if (tag.deletedAt != null) {
        await (_db.update(_db.tags)..where((t) => t.id.equals(tag!.id))).write(
          TagsCompanion(
            deletedAt: const Value(null),
            updatedAt: Value(nowUtcMs),
            deviceId: Value(deviceId),
          ),
        );
      }

      await _db.into(_db.taskTags).insertOnConflictUpdate(
        TaskTagsCompanion.insert(taskId: taskId, tagId: tag.id),
      );
    }
  }

  /// Watches all non-deleted tags in the database.
  Stream<List<Tag>> watchTags() {
    return (_db.select(_db.tags)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  // ── Projects Management (§2.5) ────────────────────────────────────────────

  /// Creates a project with a name and a color index into AppTokens.series (0..5).
  Future<Project> createProject({
    required String name,
    int colorIndex = 0,
  }) async {
    final projectId = newId();
    final nowUtcMs = timeService.nowUtcMs();
    final companion = ProjectsCompanion.insert(
      id: projectId,
      name: name.trim(),
      colorIndex: Value(colorIndex % 6),
      archived: const Value(false),
      updatedAt: nowUtcMs,
      deviceId: deviceId,
      deletedAt: const Value(null),
    );
    await _db.into(_db.projects).insert(companion);
    return Project(
      id: projectId,
      name: name.trim(),
      colorIndex: colorIndex % 6,
      archived: false,
      updatedAt: nowUtcMs,
      deviceId: deviceId,
      deletedAt: null,
    );
  }

  /// Watches all non-archived, non-deleted projects.
  Stream<List<Project>> watchProjects() {
    return (_db.select(_db.projects)
          ..where((p) => p.archived.equals(false) & p.deletedAt.isNull())
          ..orderBy([(p) => OrderingTerm.asc(p.name)]))
        .watch();
  }

  /// Gets all active non-deleted projects.
  Future<List<Project>> getProjects() {
    return (_db.select(_db.projects)
          ..where((p) => p.archived.equals(false) & p.deletedAt.isNull())
          ..orderBy([(p) => OrderingTerm.asc(p.name)]))
        .get();
  }
}
