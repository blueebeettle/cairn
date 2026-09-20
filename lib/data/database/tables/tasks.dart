import 'package:drift/drift.dart';

/// Tasks table (SPEC.md §2.4) — read model derived from events.
class Tasks extends Table {
  /// Task identifier (UUID string).
  TextColumn get id => text()();

  /// Task title.
  TextColumn get title => text()();

  /// Optional notes.
  TextColumn get notes => text().nullable()();

  /// Associated project ID, if any.
  TextColumn get projectId => text().nullable()();

  /// Parent task ID for subtasks (one level of subtask only).
  TextColumn get parentId => text().nullable()();

  /// Priority 1–4 (1 = highest).
  IntColumn get priority => integer().withDefault(const Constant(4))();

  /// Due instant in UTC epoch milliseconds, if set.
  IntColumn get dueAt => integer().nullable()();

  /// Whether the due date is all-day (0 = specific time, 1 = all day).
  BoolColumn get dueIsAllDay => boolean().withDefault(const Constant(false))();

  /// Estimated pomodoro count.
  IntColumn get estimatePomodoros => integer().nullable()();

  /// 'open' | 'done' | 'archived'
  TextColumn get status => text().withDefault(const Constant('open'))();

  /// Created instant in UTC epoch milliseconds.
  IntColumn get createdAt => integer()();

  /// Created logical date (YYYY-MM-DD).
  TextColumn get createdLocalDate => text()();

  /// Completed instant in UTC epoch milliseconds, null if open.
  IntColumn get completedAt => integer().nullable()();

  /// Completed logical date (YYYY-MM-DD), null if open.
  TextColumn get completedLocalDate => text().nullable()();

  /// Number of times rescheduled to a later date (§4.12).
  IntColumn get rescheduleCount => integer().withDefault(const Constant(0))();

  /// RRULE subset string.
  TextColumn get recurrenceRule => text().nullable()();

  /// 'on_schedule' | 'after_completion' (§2.6).
  TextColumn get recurrenceMode => text().nullable()();

  /// Links instances of a recurring series (§2.6).
  TextColumn get recurrenceParentId => text().nullable()();

  /// Fractional ordering for drag-and-drop.
  RealColumn get sortOrder => real().withDefault(const Constant(0.0))();

  /// UTC epoch milliseconds, written on every update (§4).
  IntColumn get updatedAt => integer()();

  /// Which install made the last write (§4, §5).
  TextColumn get deviceId => text()();

  /// Tombstone; null means live row, non-null is deletion UTC ms (§4, §6).
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
