import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/data/database/app_database.dart';

/// Test subclass that simulates a synthetic schema version bump from 6 to 7.
class SyntheticVersion7Database extends AppDatabase {
  SyntheticVersion7Database(super.executor);

  @override
  int get schemaVersion => 7;
}

void main() {
  test('Non-destructive migration regression test: preserves all data across version bump', () async {
    final tempDir = await Directory.systemTemp.createTemp('cairn_migration_test_');
    final dbFile = File('${tempDir.path}/test.db');

    try {
      // 1. Create a database at current schema version (6) backed by a real file.
      final dbV6 = AppDatabase(NativeDatabase(dbFile));

      // 2. Seed comprehensive realistic data across tables
      const eventId = 'ev-101';
      const taskId = 'task-202';
      const projectId = 'proj-303';
      const tagId = 'tag-404';
      const sessionId = 'session-505';
      const habitId = 'habit-606';
      const habitEntryId = 'entry-707';

      await dbV6.into(dbV6.events).insert(
        EventsCompanion.insert(
          id: eventId,
          type: 'task_created',
          occurredAt: 1700000000000,
          recordedAt: 1700000000000,
          localDate: '2026-09-20',
          tzId: 'America/Edmonton',
          tzOffsetMin: -360,
          payload: '{"title":"Ship Non-Destructive Migrations"}',
          deviceId: 'device-test-1',
        ),
      );

      await dbV6.into(dbV6.projects).insert(
        ProjectsCompanion.insert(
          id: projectId,
          name: 'Cairn Core',
          updatedAt: 1700000000000,
          deviceId: 'device-test-1',
        ),
      );

      await dbV6.into(dbV6.tags).insert(
        TagsCompanion.insert(
          id: tagId,
          name: 'critical',
          updatedAt: 1700000000000,
          deviceId: 'device-test-1',
        ),
      );

      await dbV6.into(dbV6.tasks).insert(
        TasksCompanion.insert(
          id: taskId,
          title: 'Ship Non-Destructive Migrations',
          projectId: const Value(projectId),
          createdAt: 1700000000000,
          createdLocalDate: '2026-09-20',
          updatedAt: 1700000000000,
          deviceId: 'device-test-1',
          dueAt: const Value(1700005000000),
        ),
      );

      await dbV6.into(dbV6.taskTags).insert(
        TaskTagsCompanion.insert(
          taskId: taskId,
          tagId: tagId,
        ),
      );

      await dbV6.into(dbV6.focusSessions).insert(
        FocusSessionsCompanion.insert(
          id: sessionId,
          mode: 'pomodoro',
          startedAt: 1700001000000,
          endedAt: 1700002500000,
          localDate: '2026-09-20',
          tzOffsetMin: -360,
          outcome: 'completed',
          actualDurationS: const Value(1500),
          taskId: const Value(taskId),
          projectId: const Value(projectId),
          updatedAt: 1700002500000,
          deviceId: 'device-test-1',
        ),
      );

      await dbV6.into(dbV6.habits).insert(
        HabitsCompanion.insert(
          id: habitId,
          title: 'Morning Code Review',
          scheduleRule: 'FREQ=DAILY',
          anchorDate: '2026-09-01',
          createdAt: 1700000000000,
          createdLocalDate: '2026-09-01',
          updatedAt: 1700000000000,
          deviceId: 'device-test-1',
        ),
      );

      await dbV6.into(dbV6.habitEntries).insert(
        HabitEntriesCompanion.insert(
          id: habitEntryId,
          habitId: habitId,
          localDate: '2026-09-20',
          checkCount: const Value(1),
          tzOffsetMin: -360,
          createdAt: 1700000000000,
          updatedAt: 1700000000000,
          deviceId: 'device-test-1',
        ),
      );

      await dbV6.into(dbV6.settings).insert(
        SettingsCompanion.insert(
          key: 'device_id',
          value: 'device-test-1',
        ),
      );

      // Verify initial row counts at version 6
      expect(await dbV6.select(dbV6.events).get(), hasLength(1));
      expect(await dbV6.select(dbV6.projects).get(), hasLength(1));
      expect(await dbV6.select(dbV6.tags).get(), hasLength(1));
      expect(await dbV6.select(dbV6.tasks).get(), hasLength(1));
      expect(await dbV6.select(dbV6.taskTags).get(), hasLength(1));
      expect(await dbV6.select(dbV6.focusSessions).get(), hasLength(1));
      expect(await dbV6.select(dbV6.habits).get(), hasLength(1));
      expect(await dbV6.select(dbV6.habitEntries).get(), hasLength(1));
      expect(await dbV6.select(dbV6.settings).get(), hasLength(1));

      final v6Version = (await dbV6.customSelect('PRAGMA user_version;').getSingle()).read<int>('user_version');
      expect(v6Version, equals(6));

      // Close database connection before upgrade
      await dbV6.close();

      // 3. Exercise synthetic version bump through new migration path (6 -> 7)
      // Open the existing file using SyntheticVersion7Database.
      // Drift detects user_version 6 < schemaVersion 7, and triggers onUpgrade(m, 6, 7).
      final dbV7 = SyntheticVersion7Database(NativeDatabase(dbFile));

      // 4. Assert that EVERY previously-seeded row is STILL PRESENT AND INTACT afterward.
      final eventsAfter = await dbV7.select(dbV7.events).get();
      expect(eventsAfter, hasLength(1));
      expect(eventsAfter.first.id, equals(eventId));
      expect(eventsAfter.first.payload, equals('{"title":"Ship Non-Destructive Migrations"}'));

      final tasksAfter = await dbV7.select(dbV7.tasks).get();
      expect(tasksAfter, hasLength(1));
      expect(tasksAfter.first.id, equals(taskId));
      expect(tasksAfter.first.title, equals('Ship Non-Destructive Migrations'));
      expect(tasksAfter.first.dueAt, equals(1700005000000));

      final sessionsAfter = await dbV7.select(dbV7.focusSessions).get();
      expect(sessionsAfter, hasLength(1));
      expect(sessionsAfter.first.id, equals(sessionId));
      expect(sessionsAfter.first.outcome, equals('completed'));
      expect(sessionsAfter.first.actualDurationS, equals(1500));

      final habitsAfter = await dbV7.select(dbV7.habits).get();
      expect(habitsAfter, hasLength(1));
      expect(habitsAfter.first.id, equals(habitId));
      expect(habitsAfter.first.title, equals('Morning Code Review'));

      final habitEntriesAfter = await dbV7.select(dbV7.habitEntries).get();
      expect(habitEntriesAfter, hasLength(1));
      expect(habitEntriesAfter.first.id, equals(habitEntryId));
      expect(habitEntriesAfter.first.checkCount, equals(1));

      final projectsAfter = await dbV7.select(dbV7.projects).get();
      expect(projectsAfter, hasLength(1));
      expect(projectsAfter.first.id, equals(projectId));
      expect(projectsAfter.first.name, equals('Cairn Core'));

      final tagsAfter = await dbV7.select(dbV7.tags).get();
      expect(tagsAfter, hasLength(1));
      expect(tagsAfter.first.id, equals(tagId));
      expect(tagsAfter.first.name, equals('critical'));

      final taskTagsAfter = await dbV7.select(dbV7.taskTags).get();
      expect(taskTagsAfter, hasLength(1));
      expect(taskTagsAfter.first.taskId, equals(taskId));

      final settingsAfter = await dbV7.select(dbV7.settings).get();
      expect(settingsAfter, hasLength(1));
      expect(settingsAfter.first.key, equals('device_id'));
      expect(settingsAfter.first.value, equals('device-test-1'));

      // Verify user_version was bumped to 7 in SQLite
      final userVersionRow = await dbV7.customSelect('PRAGMA user_version;').getSingle();
      expect(userVersionRow.read<int>('user_version'), equals(7));

      await dbV7.close();

      // 5. Verify no-op on re-open at same version (7 -> 7)
      final dbV7Reopen = SyntheticVersion7Database(NativeDatabase(dbFile));
      final tasksAfterReopen = await dbV7Reopen.select(dbV7Reopen.tasks).get();
      expect(tasksAfterReopen, hasLength(1));
      expect(tasksAfterReopen.first.id, equals(taskId));
      await dbV7Reopen.close();
    } finally {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    }
  });
}
