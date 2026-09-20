import 'package:drift/drift.dart';

/// Settings table (SPEC.md §2.5) — key-value store for app configurations.
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()(); // JSON-encoded

  @override
  Set<Column> get primaryKey => {key};
}
