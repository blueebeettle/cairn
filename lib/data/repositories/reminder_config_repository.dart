import 'package:drift/drift.dart';

import '../../core/constants/event_types.dart';
import '../../core/ids.dart';
import '../../core/time/time_service.dart';
import '../database/app_database.dart';
import 'events_repository.dart';
import 'settings_repository.dart';

/// Read model and event writer for per-item reminder configuration
/// (SPEC.md §10.4/§11): a task's countdown offsets and a habit's
/// times-of-day.
///
/// Kept separate from `tasks_repository.dart` and `habits_repository.dart`
/// on purpose — the same reason `habits_repository.dart` was split out from
/// day one: those two files are where Antigravity's screen work lands most,
/// and a narrowly-scoped file here means a reminder change never has to
/// merge against that.
///
/// Every mutating method writes its event *first*, in the same transaction
/// as the row changes, per SPEC.md §0.
class ReminderConfigRepository {
  ReminderConfigRepository({
    required this.db,
    required this.eventsRepository,
    required this.settingsRepo,
    required this.timeService,
    required this.deviceId,
  });

  final AppDatabase db;
  final EventsRepository eventsRepository;
  final SettingsRepository settingsRepo;
  final TimeService timeService;
  final String deviceId;

  /// At most this many reminders per task or per habit. A countdown-offset
  /// picker or a time-of-day picker with more entries than this stops being
  /// something a user chose and starts being a settings bug.
  static const int maxRemindersPerItem = 5;

  /// What a brand-new timed task gets if nothing else is configured.
  static const List<int> defaultTaskReminderOffsetsMin = [10];

  // ------------------------------------------------------------------ tasks

  Future<List<TaskReminderOffset>> taskReminderOffsets(String taskId) {
    return (db.select(db.taskReminderOffsets)
          ..where((r) => r.taskId.equals(taskId))
          ..orderBy([(r) => OrderingTerm.asc(r.offsetMin)]))
        .get();
  }

  Stream<List<TaskReminderOffset>> watchTaskReminderOffsets(String taskId) {
    return (db.select(db.taskReminderOffsets)
          ..where((r) => r.taskId.equals(taskId))
          ..orderBy([(r) => OrderingTerm.asc(r.offsetMin)]))
        .watch();
  }

  /// Replaces every countdown reminder for [taskId] with [offsetsMin].
  ///
  /// Each value is minutes before the task's due time; 0 means "at the due
  /// time". An empty list means no countdown reminders for this task — for
  /// an all-day task that's the only state that makes sense, since there is
  /// no time of day to count down to.
  ///
  /// Does not itself talk to the OS notification plugin. Callers reschedule
  /// afterwards (`ReminderService.scheduleFor`), the same way
  /// `TasksRepository.updateTask` already does for its own writes.
  Future<void> setTaskReminderOffsets(
    String taskId,
    List<int> offsetsMin, {
    Future<void> Function(int notificationId)? onCancelNotificationId,
  }) async {
    final cleaned = _cleanOffsets(offsetsMin);
    final now = timeService.nowUtcMs();

    await db.transaction(() async {
      await eventsRepository.logEvent(
        type: EventTypes.taskReminderOffsetsSet,
        subjectType: SubjectTypes.task,
        subjectId: taskId,
        payload: {'offsets_min': cleaned},
      );

      final existing = await (db.select(db.taskReminderOffsets)
            ..where((r) => r.taskId.equals(taskId)))
          .get();

      final existingByOffset = {for (final r in existing) r.offsetMin: r};

      // Delete rows whose offset is no longer in cleaned
      for (final r in existing) {
        if (!cleaned.contains(r.offsetMin)) {
          if (r.notificationId != null && onCancelNotificationId != null) {
            await onCancelNotificationId(r.notificationId!);
          }
          await (db.delete(db.taskReminderOffsets)
                ..where((row) => row.id.equals(r.id)))
              .go();
        }
      }

      // Insert newly added offsets
      final toAdd = cleaned.where((offset) => !existingByOffset.containsKey(offset)).toList();
      if (toAdd.isNotEmpty) {
        await db.batch((b) {
          b.insertAll(db.taskReminderOffsets, [
            for (final offset in toAdd)
              TaskReminderOffsetsCompanion.insert(
                id: newId(),
                taskId: taskId,
                offsetMin: offset,
                createdAt: now,
                updatedAt: now,
                deviceId: deviceId,
              ),
          ]);
        });
      }
    });
  }

  /// Gives a newly created, specifically-timed task the current global
  /// default offsets. A no-op if [taskId] already has any — call this once,
  /// right after creating the task, before the first `scheduleFor`.
  Future<void> seedDefaultTaskReminderOffsets(String taskId) async {
    final existing = await taskReminderOffsets(taskId);
    if (existing.isNotEmpty) return;
    final defaults = await defaultTaskReminderOffsetsMinSetting();
    if (defaults.isEmpty) return;
    await setTaskReminderOffsets(taskId, defaults);
  }

  /// The offsets a new timed task starts with, from `settings`
  /// (`default_reminder_offsets_min`), or [defaultTaskReminderOffsetsMin] if
  /// never configured.
  Future<List<int>> defaultTaskReminderOffsetsMinSetting() async {
    final raw = await settingsRepo.get('default_reminder_offsets_min');
    if (raw is List && raw.isNotEmpty) {
      return _cleanOffsets(raw.map((e) => (e as num).toInt()).toList());
    }
    return defaultTaskReminderOffsetsMin;
  }

  /// Device-local bookkeeping: which OS notification id backs this row.
  /// Writes no event — this is per-install bookkeeping, not something the
  /// user did.
  Future<void> setTaskReminderOffsetNotificationId(
    String rowId,
    int? notificationId,
  ) {
    return (db.update(db.taskReminderOffsets)..where((r) => r.id.equals(rowId)))
        .write(TaskReminderOffsetsCompanion(
      notificationId: Value(notificationId),
    ));
  }

  // ----------------------------------------------------------------- habits

  Future<List<HabitReminderTime>> habitReminderTimes(String habitId) {
    return (db.select(db.habitReminderTimes)
          ..where((r) => r.habitId.equals(habitId))
          ..orderBy([(r) => OrderingTerm.asc(r.minutesPastMidnight)]))
        .get();
  }

  Stream<List<HabitReminderTime>> watchHabitReminderTimes(String habitId) {
    return (db.select(db.habitReminderTimes)
          ..where((r) => r.habitId.equals(habitId))
          ..orderBy([(r) => OrderingTerm.asc(r.minutesPastMidnight)]))
        .watch();
  }

  /// Replaces every time-of-day reminder for [habitId] with
  /// [minutesPastMidnight]. An empty list means no reminders for this habit
  /// — habits have no global default to fall back to, unlike tasks: a
  /// reminder time that makes sense for one habit rarely makes sense for
  /// another.
  Future<void> setHabitReminderTimes(
    String habitId,
    List<int> minutesPastMidnight, {
    Future<void> Function(int notificationId)? onCancelNotificationId,
  }) async {
    final cleaned = _cleanTimesOfDay(minutesPastMidnight);
    final now = timeService.nowUtcMs();

    await db.transaction(() async {
      await eventsRepository.logEvent(
        type: EventTypes.habitReminderTimesSet,
        subjectType: SubjectTypes.habit,
        subjectId: habitId,
        payload: {'times_min': cleaned},
      );

      final existing = await (db.select(db.habitReminderTimes)
            ..where((r) => r.habitId.equals(habitId)))
          .get();

      final existingByTime = {for (final r in existing) r.minutesPastMidnight: r};

      // Delete rows whose time is no longer in cleaned
      for (final r in existing) {
        if (!cleaned.contains(r.minutesPastMidnight)) {
          if (r.notificationId != null && onCancelNotificationId != null) {
            await onCancelNotificationId(r.notificationId!);
          }
          await (db.delete(db.habitReminderTimes)
                ..where((row) => row.id.equals(r.id)))
              .go();
        }
      }

      // Insert newly added times
      final toAdd = cleaned.where((time) => !existingByTime.containsKey(time)).toList();
      if (toAdd.isNotEmpty) {
        await db.batch((b) {
          b.insertAll(db.habitReminderTimes, [
            for (final minutes in toAdd)
              HabitReminderTimesCompanion.insert(
                id: newId(),
                habitId: habitId,
                minutesPastMidnight: minutes,
                createdAt: now,
                updatedAt: now,
                deviceId: deviceId,
              ),
          ]);
        });
      }
    });
  }

  /// Device-local bookkeeping: which OS notification id backs this row.
  /// Writes no event.
  Future<void> setHabitReminderTimeNotificationId(
    String rowId,
    int? notificationId,
  ) {
    return (db.update(db.habitReminderTimes)..where((r) => r.id.equals(rowId)))
        .write(HabitReminderTimesCompanion(
      notificationId: Value(notificationId),
    ));
  }

  // -------------------------------------------------------------- internal

  /// Non-negative, deduplicated, ascending, capped at [maxRemindersPerItem].
  /// No upper bound: "remind me a week before" is a reasonable offset and
  /// nothing in a 64-bit int makes that dangerous.
  List<int> _cleanOffsets(List<int> values) {
    final cleaned = (values.where((v) => v >= 0).toSet().toList()..sort());
    if (cleaned.length > maxRemindersPerItem) {
      throw ArgumentError.value(
        values,
        'values',
        'At most $maxRemindersPerItem reminders per item',
      );
    }
    return cleaned;
  }

  /// Minutes past midnight: deduplicated, ascending, within a single day,
  /// capped at [maxRemindersPerItem].
  List<int> _cleanTimesOfDay(List<int> values) {
    final cleaned = (values.where((v) => v >= 0 && v < 24 * 60).toSet().toList()
      ..sort());
    if (cleaned.length > maxRemindersPerItem) {
      throw ArgumentError.value(
        values,
        'values',
        'At most $maxRemindersPerItem reminders per item',
      );
    }
    return cleaned;
  }
}
