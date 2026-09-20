import 'package:drift/drift.dart';

/// One configured time-of-day reminder for a habit (SPEC.md §10.4) — read
/// model.
///
/// A habit can have several of these: a morning nudge and an evening
/// last-chance reminder for the same habit. Replaces the single
/// `habits.reminder_time_min` column.
///
/// No `deleted_at` tombstone, for the same reason as `TaskReminderOffsets`:
/// the event that writes these rows (`habit_reminder_times_set`) always
/// carries the habit's entire desired set of times, so a rebuild never needs
/// a removed row's history. Rows that fall out of the set are hard-deleted.
class HabitReminderTimes extends Table {
  /// Row identifier (UUIDv7 string).
  TextColumn get id => text()();

  /// The habit this reminder belongs to.
  TextColumn get habitId => text()();

  /// Local time of day to remind, in minutes past midnight (0–1439).
  IntColumn get minutesPastMidnight => integer()();

  /// Stable 32-bit id for this row's scheduled OS notification, allocated
  /// from the same shared counter as every other notification id in the app.
  /// Null until `ReminderService` first schedules it.
  IntColumn get notificationId => integer().nullable()();

  /// Created instant in UTC epoch milliseconds.
  IntColumn get createdAt => integer()();

  /// UTC epoch milliseconds, written whenever the row is (re)created.
  IntColumn get updatedAt => integer()();

  /// Which install made the last write.
  TextColumn get deviceId => text()();

  @override
  Set<Column> get primaryKey => {id};

  /// One row per habit per time-of-day value.
  @override
  List<Set<Column>> get uniqueKeys => [
        {habitId, minutesPastMidnight},
      ];
}
