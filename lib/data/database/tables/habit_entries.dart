import 'package:drift/drift.dart';

/// One habit's record for one logical day (SPEC.md §10.1) — read model.
///
/// A row exists only for days with activity. **Absence is not a miss:** the
/// streak engine decides that, by asking whether the day was scheduled. A row
/// per scheduled day would mean writing rows for days the user never opened
/// the app, and would make a habit's history depend on when it was queried.
///
/// The row class name is pinned: Drift singularises a table name by dropping a
/// trailing "s", which would turn `HabitEntries` into `HabitEntrie`.
@DataClassName('HabitEntry')
class HabitEntries extends Table {
  /// Entry identifier (UUIDv7 string).
  TextColumn get id => text()();

  /// The habit this belongs to.
  TextColumn get habitId => text()();

  /// Logical date (YYYY-MM-DD) per SPEC.md §1.2, computed once at write time.
  ///
  /// Computed at write time, never at read time, so a check-off made at 02:00
  /// with a 04:00 day start stays on the day the user believes they did it —
  /// including after they fly somewhere else.
  TextColumn get localDate => text()();

  /// How many times it was checked off that day. Compared against
  /// `habits.target_count` to decide whether the day is complete.
  IntColumn get checkCount => integer().withDefault(const Constant(0))();

  /// The user deliberately marked this a rest day.
  ///
  /// Distinct from a miss, and distinct from being excused: whether the skip
  /// protects the streak depends on the month's remaining allowance, which the
  /// streak engine resolves. This column records only what the user did.
  BoolColumn get skipped => boolean().withDefault(const Constant(false))();

  /// Optional note for the day — the journal entry.
  TextColumn get note => text().nullable()();

  /// UTC ms of the most recent check-off, for "done at 7:14am".
  IntColumn get lastCheckedAt => integer().nullable()();

  /// Offset in minutes at write time, so a day grid can be rendered in the
  /// zone the check-off actually happened in rather than the current device's.
  IntColumn get tzOffsetMin => integer()();

  /// Created instant in UTC epoch milliseconds.
  IntColumn get createdAt => integer()();

  /// UTC epoch milliseconds, written on every update.
  IntColumn get updatedAt => integer()();

  /// Which install made the last write.
  TextColumn get deviceId => text()();

  /// Tombstone; null means live row, non-null is deletion UTC ms.
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  /// One row per habit per logical day. The repository upserts on this.
  @override
  List<Set<Column>> get uniqueKeys => [
        {habitId, localDate},
      ];
}
