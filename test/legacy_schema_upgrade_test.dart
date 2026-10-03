import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/data/database/app_database.dart';

import 'support/legacy_schema_v4.dart';

/// A database file as the old build left it: schema 4, a few rows in it.
///
/// Built through the `setup` hook, which runs on the raw connection before
/// drift reads `user_version`, so by the time `AppDatabase` looks at the file it
/// is exactly what a restored backup would be: an existing database at an old
/// version.
QueryExecutor _legacyV4(File file) => NativeDatabase(
      file,
      setup: (raw) {
        if (raw.userVersion != 0) return;
        for (final statement in legacySchemaV4Statements) {
          raw.execute(statement);
        }
        raw.execute(
          "INSERT INTO settings (key, value) VALUES "
          "('device_id', 'legacy-device'), ('supabase_url', 'https://example.test')",
        );
        raw.execute(
          "INSERT INTO projects (id, name, updated_at, device_id) "
          "VALUES ('proj-1', 'Legacy project', 1700000000000, 'legacy-device')",
        );
        // The three single-reminder columns schema 6 replaced hold real values.
        raw.execute(
          "INSERT INTO tasks (id, title, created_at, created_local_date, "
          "reminder_notification_id, reminder_offset_min, reminder_enabled, "
          "updated_at, device_id) VALUES ('task-1', 'Legacy task', 1700000000000, "
          "'2026-09-14', 4242, 10, 1, 1700000000000, 'legacy-device')",
        );
        raw.execute(
          "INSERT INTO events (id, type, occurred_at, recorded_at, local_date, "
          "tz_id, tz_offset_min, payload, device_id) VALUES ('ev-1', "
          "'task_created', 1700000000000, 1700000000000, '2026-09-14', "
          "'Asia/Kolkata', 330, '{\"title\":\"Legacy task\"}', 'legacy-device')",
        );
        raw.userVersion = legacySchemaV4Version;
      },
    );

Future<List<String>> _columns(AppDatabase db, String table) async {
  final rows = await db.customSelect('PRAGMA table_info("$table")').get();
  return [for (final row in rows) row.read<String>('name')];
}

Future<int> _count(AppDatabase db, String table) async {
  final row = await db
      .customSelect('SELECT COUNT(*) AS n FROM "$table"')
      .getSingle();
  return row.read<int>('n');
}

void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cairn_legacy_v4_');
    dbFile = File('${tempDir.path}/focus_stack.sqlite');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  group('a schema-4 database from an old backup', () {
    test('opens at the current schema instead of throwing', () async {
      final db = AppDatabase(_legacyV4(dbFile));
      addTearDown(db.close);

      // The first query is what opens the file and runs the migration. A throw
      // here is what left the launch screen up on a real device:
      // "no such table: main.habit_entries".
      await db.customSelect('SELECT 1').get();

      final version = await db.customSelect('PRAGMA user_version').getSingle();
      expect(version.read<int>('user_version'), db.schemaVersion);
    });

    test('gains every table and column the current schema declares', () async {
      final db = AppDatabase(_legacyV4(dbFile));
      addTearDown(db.close);

      for (final table in db.allTables) {
        final name = table.actualTableName;
        final present = await _columns(db, name);
        expect(present, isNotEmpty, reason: 'table $name was not created');
        for (final column in table.$columns) {
          expect(present, contains(column.name),
              reason: '$name is missing column ${column.name}');
        }
      }
    });

    test('keeps every row it already had, legacy columns included', () async {
      final db = AppDatabase(_legacyV4(dbFile));
      addTearDown(db.close);

      expect(await _count(db, 'settings'), 2);
      expect(await _count(db, 'projects'), 1);
      expect(await _count(db, 'events'), 1);

      final tasks = await db.select(db.tasks).get();
      expect(tasks.single.title, 'Legacy task');

      // Non-destructive: the old single-reminder columns are left alone rather
      // than dropped, so nothing the old build stored is thrown away.
      final legacy = await db
          .customSelect('SELECT reminder_offset_min, reminder_notification_id '
              'FROM tasks WHERE id = \'task-1\'')
          .getSingle();
      expect(legacy.read<int>('reminder_offset_min'), 10);
      expect(legacy.read<int>('reminder_notification_id'), 4242);
    });

    test('accepts the writes the app makes to the tables it gained', () async {
      final db = AppDatabase(_legacyV4(dbFile));
      addTearDown(db.close);

      await db.into(db.habits).insert(HabitsCompanion.insert(
            id: 'habit-1',
            title: 'Read',
            scheduleRule: 'FREQ=DAILY',
            anchorDate: '2026-10-03',
            createdAt: 1700000000000,
            createdLocalDate: '2026-10-03',
            updatedAt: 1700000000000,
            deviceId: 'legacy-device',
          ));
      await db.into(db.habitEntries).insert(HabitEntriesCompanion.insert(
            id: 'entry-1',
            habitId: 'habit-1',
            localDate: '2026-10-03',
            tzOffsetMin: 330,
            createdAt: 1700000000000,
            updatedAt: 1700000000000,
            deviceId: 'legacy-device',
          ));
      await db.into(db.taskReminderOffsets).insert(
            TaskReminderOffsetsCompanion.insert(
              id: 'tro-1',
              taskId: 'task-1',
              offsetMin: 10,
              createdAt: 1700000000000,
              updatedAt: 1700000000000,
              deviceId: 'legacy-device',
            ),
          );
      await db.into(db.habitReminderTimes).insert(
            HabitReminderTimesCompanion.insert(
              id: 'hrt-1',
              habitId: 'habit-1',
              minutesPastMidnight: 480,
              createdAt: 1700000000000,
              updatedAt: 1700000000000,
              deviceId: 'legacy-device',
            ),
          );

      expect(await db.select(db.habits).get(), hasLength(1));
      expect(await db.select(db.habitEntries).get(), hasLength(1));
      expect(await db.select(db.taskReminderOffsets).get(), hasLength(1));
      expect(await db.select(db.habitReminderTimes).get(), hasLength(1));
    });

    test('opens a second time without migrating again or losing anything',
        () async {
      final first = AppDatabase(_legacyV4(dbFile));
      await first.customSelect('SELECT 1').get();
      await first.close();

      final second = AppDatabase(_legacyV4(dbFile));
      addTearDown(second.close);
      await second.customSelect('SELECT 1').get();

      expect(await _count(second, 'settings'), 2);
      expect(await _count(second, 'projects'), 1);
      expect((await second.select(second.tasks).get()).single.title,
          'Legacy task');
    });
  });
}
