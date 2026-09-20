import 'package:drift/drift.dart';

/// One configured countdown reminder for a task (SPEC.md §11) — read model.
///
/// A timed task (a specific due time, not all-day) can have several of these:
/// "10 minutes before", "1 hour before", "the night before". Replaces the
/// single `tasks.reminder_offset_min` column.
///
/// No `deleted_at` tombstone, unlike most tables in this schema. The event
/// that writes these rows (`task_reminder_offsets_set`) always carries the
/// task's *entire* desired set of offsets, so replaying the latest such
/// event per task reproduces the live rows exactly — a rebuild never needs
/// to know what a removed row used to be. Rows that fall out of the set are
/// hard-deleted rather than kept as tombstones.
class TaskReminderOffsets extends Table {
  /// Row identifier (UUIDv7 string).
  TextColumn get id => text()();

  /// The task this reminder belongs to.
  TextColumn get taskId => text()();

  /// Minutes before `tasks.due_at` to fire. 0 means "at the due time".
  IntColumn get offsetMin => integer()();

  /// Stable 32-bit id for this row's scheduled OS notification, allocated
  /// from the same counter as every other notification id in the app (see
  /// `tasks.dart` for why hashing is not used instead). Null until
  /// `ReminderService` first schedules it.
  IntColumn get notificationId => integer().nullable()();

  /// Created instant in UTC epoch milliseconds.
  IntColumn get createdAt => integer()();

  /// UTC epoch milliseconds, written whenever the row is (re)created.
  IntColumn get updatedAt => integer()();

  /// Which install made the last write.
  TextColumn get deviceId => text()();

  @override
  Set<Column> get primaryKey => {id};

  /// One row per task per offset value.
  @override
  List<Set<Column>> get uniqueKeys => [
        {taskId, offsetMin},
      ];
}
