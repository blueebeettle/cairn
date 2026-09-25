import 'package:drift/drift.dart';

import 'connection/connection.dart';
import 'tables/events.dart';
import 'tables/habit_entries.dart';
import 'tables/habit_reminder_times.dart';
import 'tables/habits.dart';
import 'tables/focus_sessions.dart';
import 'tables/projects.dart';
import 'tables/settings.dart';
import 'tables/tags.dart';
import 'tables/task_reminder_offsets.dart';
import 'tables/task_tags.dart';
import 'tables/tasks.dart';
import 'tables/timer_state.dart';

part 'app_database.g.dart';

/// Primary Drift database for Focus Stack per SPEC.md.
///
/// Features:
/// - Immutable append-only `events` table with required indexes (§2.1)
/// - Read model tables: `focus_sessions`, `tasks` (§2.3, §2.4)
/// - Supporting tables: `projects`, `tags`, `task_tags`, `settings`, `timer_state` (§2.5)
@DriftDatabase(tables: [
  Events,
  FocusSessions,
  Tasks,
  TaskReminderOffsets,
  Habits,
  HabitEntries,
  HabitReminderTimes,
  Projects,
  Tags,
  TaskTags,
  Settings,
  TimerStates,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? openConnection());

  // 4: tasks gained reminder_notification_id, reminder_offset_min, and
  //    reminder_enabled for task reminder scheduling.
  // 5: habits and habit_entries (SPEC.md §10).
  // 6: reminders redesigned around multiple reminders per item (SPEC.md
  //    §10.4/§11). tasks.reminder_notification_id/reminder_offset_min/
  //    reminder_enabled and habits.reminder_time_min/reminder_enabled/
  //    reminder_notification_id are dropped; task_reminder_offsets and
  //    habit_reminder_times replace them, one row per configured reminder.
  //
  // NOTE: Schema migrations must always be non-destructive and preserve user
  // data across upgrades. Stepped migration dispatch handles per-version transitions
  // additively (using m.addColumn, m.createTable, m.alterTable, or raw SQL).
  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await _createIndexes();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          // Stepped non-destructive migration. Never drop-and-recreate.
          // Disabling foreign keys during schema modification is recommended by SQLite.
          await customStatement('PRAGMA foreign_keys = OFF;');
          try {
            for (var version = from + 1; version <= to; version++) {
              await _migrateStep(m, version);
            }
            await _createIndexes();
          } finally {
            await customStatement('PRAGMA foreign_keys = ON;');
          }
        },
        beforeOpen: (details) async {
          // Ensure all required indexes exist even when opening an existing database
          // that has not bumped its schema version.
          await _createIndexes();
        },
      );

  /// Stepped per-version migration scaffolding for future schema version bumps.
  Future<void> _migrateStep(Migrator m, int targetVersion) async {
    switch (targetVersion) {
      case 7:
        // Future schema version 7 additions.
        break;
      default:
        break;
    }
  }

  Future<void> _createIndexes() async {
    // Explicitly ensure the 3 required indexes on events table per SPEC.md §2.1:
    // 1. (local_date)
    // 2. (type, local_date)
    // 3. (subject_type, subject_id)
    await customStatement(
      'CREATE INDEX IF NOT EXISTS events_local_date_idx ON events (local_date);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS events_type_local_date_idx ON events (type, local_date);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS events_subject_idx ON events (subject_type, subject_id);',
    );

    // Focus sessions read model indexes (§2.3)
    await customStatement(
      'CREATE INDEX IF NOT EXISTS focus_sessions_local_date_idx ON focus_sessions (local_date);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS focus_sessions_outcome_idx ON focus_sessions (outcome);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS focus_sessions_task_id_idx ON focus_sessions (task_id);',
    );

    // Tasks read model indexes (§2.4)
    await customStatement(
      'CREATE INDEX IF NOT EXISTS tasks_status_idx ON tasks (status);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS tasks_parent_id_idx ON tasks (parent_id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS tasks_due_at_idx ON tasks (due_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS tasks_completed_local_date_idx ON tasks (completed_local_date);',
    );

    // Habit read model (SPEC.md §10.1).
    //
    // No unique index on (habit_id, local_date) here: `uniqueKeys` on the
    // table already emits that constraint inside CREATE TABLE, and declaring
    // it twice means a later change has two places to miss.
    await customStatement(
      'CREATE INDEX IF NOT EXISTS habit_entries_date_idx ON habit_entries (local_date);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS habits_status_idx ON habits (status, deleted_at);',
    );

    // Reminder config (SPEC.md §10.4/§11). No unique index here either, for
    // the same reason: `uniqueKeys` on each table already covers
    // (task_id, offset_min) and (habit_id, minutes_past_midnight).
    await customStatement(
      'CREATE INDEX IF NOT EXISTS task_reminder_offsets_task_idx ON task_reminder_offsets (task_id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS habit_reminder_times_habit_idx ON habit_reminder_times (habit_id);',
    );
  }
}
