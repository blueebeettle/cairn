import 'package:drift/drift.dart';

/// Tags table (SPEC.md §2.5).
class Tags extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().unique()();

  /// UTC epoch milliseconds, written on every update (§4).
  IntColumn get updatedAt => integer()();

  /// Which install made the last write (§4, §5).
  TextColumn get deviceId => text()();

  /// Tombstone; null means live row, non-null is deletion UTC ms (§4, §6).
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
