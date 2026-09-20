import 'package:drift/drift.dart';

/// Habits table (SPEC.md §10.1) — read model derived from events.
///
/// Like `tasks`, this is a projection. `events` remains the source of truth
/// per SPEC.md §0, so a habit's entire history can be rebuilt from the log.
class Habits extends Table {
  /// Habit identifier (UUIDv7 string).
  TextColumn get id => text()();

  /// What the user calls it. "Read", "Walk the dog", "No sugar".
  TextColumn get title => text()();

  /// Optional longer description shown on the detail screen.
  TextColumn get notes => text().nullable()();

  /// Index into the theme's habit palette.
  IntColumn get colorIndex => integer().withDefault(const Constant(0))();

  /// Icon identifier, resolved to an [IconData] by the presentation layer.
  /// Stored as a name, not a code point: Flutter's icon code points are not
  /// stable across versions, and a backup restored after an upgrade would
  /// otherwise show a grid of random glyphs.
  TextColumn get iconName => text().withDefault(const Constant('check'))();

  /// RRULE subset (SPEC.md §2.6), the same grammar task recurrence uses.
  /// Non-null: a habit with no schedule is never due, which is not a habit.
  TextColumn get scheduleRule => text()();

  /// The logical date intervals count from — normally the day it was created.
  ///
  /// "Every 3 days" means every third day from here, so this must be stored
  /// rather than recomputed. Deriving it from created_at would silently
  /// reschedule the whole history if a row were ever backfilled.
  TextColumn get anchorDate => text()();

  /// How many check-offs make a day complete. 1 for a plain yes/no habit.
  IntColumn get targetCount => integer().withDefault(const Constant(1))();

  /// What the target is counted in — "pages", "glasses". Null for yes/no.
  TextColumn get unitLabel => text().nullable()();

  /// Rest days a calendar month excuses without breaking the streak (§10.3).
  IntColumn get skipAllowancePerMonth =>
      integer().withDefault(const Constant(2))();

  /// 'active' | 'archived'
  TextColumn get status => text().withDefault(const Constant('active'))();

  /// Fractional ordering for drag-and-drop.
  RealColumn get sortOrder => real().withDefault(const Constant(0.0))();

  /// Created instant in UTC epoch milliseconds.
  IntColumn get createdAt => integer()();

  /// Created logical date (YYYY-MM-DD).
  TextColumn get createdLocalDate => text()();

  /// Archived instant in UTC epoch milliseconds, null while active.
  IntColumn get archivedAt => integer().nullable()();

  /// UTC epoch milliseconds, written on every update.
  IntColumn get updatedAt => integer()();

  /// Which install made the last write.
  TextColumn get deviceId => text()();

  /// Tombstone; null means live row, non-null is deletion UTC ms.
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
