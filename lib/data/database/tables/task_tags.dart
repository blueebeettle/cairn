import 'package:drift/drift.dart';

/// TaskTags junction table (SPEC.md §2.5).
class TaskTags extends Table {
  TextColumn get taskId => text()();
  TextColumn get tagId => text()();

  @override
  Set<Column> get primaryKey => {taskId, tagId};
}
